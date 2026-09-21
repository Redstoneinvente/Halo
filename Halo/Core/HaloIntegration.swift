import AppKit
import Combine
import Foundation

struct DiscoveredIntegration: Hashable, Identifiable, Sendable {
    let appURL: URL
    let definition: IntegrationDefinition

    var id: String { definition.app.bundleIdentifier }
    var name: String { definition.app.name }
    var bundleIdentifier: String { definition.app.bundleIdentifier }
}

enum IntegrationDiscoveryError: LocalizedError {
    case unavailable(String)
    case invalidApplication(URL)
    case missingManifest(URL)

    var errorDescription: String? {
        switch self {
        case .unavailable(let bundleID): return "The partner app \(bundleID) is no longer installed."
        case .invalidApplication(let url): return "\(url.lastPathComponent) is not a valid macOS application bundle."
        case .missingManifest(let url): return "\(url.lastPathComponent) no longer contains HaloIntegration.json."
        }
    }
}

/// Installed-app discovery only. It does not create CI packages, register triggers, arbitrate
/// surfaces, retain drag payloads, render UI or execute partner actions.
@MainActor
final class HaloIntegrationCatalog: ObservableObject {
    static let shared = HaloIntegrationCatalog()

    @Published private(set) var integrations: [DiscoveredIntegration] = []
    @Published private(set) var diagnostics: [String] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasCompletedRefresh = false

    private var subscriptions = Set<AnyCancellable>()

    private init() {}

    func start() {
        guard HaloDistribution.current.supportsPartnerIntegrations else {
            integrations = []
            diagnostics = []
            isRefreshing = false
            hasCompletedRefresh = true
            return
        }
        guard subscriptions.isEmpty else { return }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didWakeNotification] {
            NSWorkspace.shared.notificationCenter.publisher(for: name)
                .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
                .sink { [weak self] _ in self?.refresh() }
                .store(in: &subscriptions)
        }
        refresh()
    }

    func stop() {
        subscriptions.removeAll()
    }

    func refresh() {
        guard HaloDistribution.current.supportsPartnerIntegrations else {
            integrations = []
            diagnostics = []
            isRefreshing = false
            hasCompletedRefresh = true
            return
        }
        guard !isRefreshing else { return }
        isRefreshing = true
        let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleURL)
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Self.discoverInstalledIntegrations(additionalAppURLs: running)
            }.value
            guard let self else { return }
            integrations = result.integrations
            diagnostics = result.diagnostics
            hasCompletedRefresh = true
            isRefreshing = false
        }
    }

    nonisolated static func discoverInstalledIntegrations(
        additionalAppURLs: [URL] = [],
        searchRoots: [URL]? = nil
    ) -> (integrations: [DiscoveredIntegration], diagnostics: [String]) {
        let fileManager = FileManager.default
        let roots = searchRoots ?? [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true)
        ]

        var discovered: [String: DiscoveredIntegration] = [:]
        var diagnostics: [String] = []

        func inspect(_ appURL: URL) {
            do {
                let integration = try loadIntegration(at: appURL)
                if discovered[integration.bundleIdentifier] == nil {
                    discovered[integration.bundleIdentifier] = integration
                }
            } catch IntegrationDiscoveryError.missingManifest {
                // Ordinary apps are not diagnostics; only apps declaring HaloIntegration.json matter.
            } catch {
                let manifestURL = appURL.appendingPathComponent("Contents/Resources/HaloIntegration.json")
                if fileManager.fileExists(atPath: manifestURL.path) {
                    diagnostics.append("\(appURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        // Running/Xcode copies win over installed copies for development.
        for appURL in additionalAppURLs { inspect(appURL) }

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }
            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                inspect(url)
            }
        }

        return (
            discovered.values.sorted {
                let byName = $0.name.localizedCaseInsensitiveCompare($1.name)
                return byName == .orderedSame ? $0.bundleIdentifier < $1.bundleIdentifier : byName == .orderedAscending
            },
            diagnostics.sorted()
        )
    }

    nonisolated static func loadIntegration(at appURL: URL) throws -> DiscoveredIntegration {
        guard appURL.pathExtension.lowercased() == "app",
              FileManager.default.fileExists(atPath: appURL.path),
              let bundle = Bundle(url: appURL),
              let actualBundleID = bundle.bundleIdentifier,
              let resources = bundle.resourceURL else {
            throw IntegrationDiscoveryError.invalidApplication(appURL)
        }
        let manifestURL = resources.appendingPathComponent("HaloIntegration.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw IntegrationDiscoveryError.missingManifest(appURL)
        }
        if let size = try? manifestURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > IntegrationManifestCodec.maximumManifestBytes {
            throw IntegrationManifestError.manifestTooLarge(size)
        }
        let data = try Data(contentsOf: manifestURL, options: [.mappedIfSafe])
        let definition = try IntegrationManifestCodec.decodeAndNormalize(data, actualBundleIdentifier: actualBundleID)
        return DiscoveredIntegration(appURL: appURL, definition: definition)
    }

    func integration(bundleIdentifier: String) -> DiscoveredIntegration? {
        integrations.first(where: { $0.bundleIdentifier == bundleIdentifier })
    }

    /// Security boundary used immediately before partner delivery. The manifest is read again
    /// from disk and bundle identity is checked again; cached discovery state is not trusted.
    func freshIntegration(bundleIdentifier: String) throws -> DiscoveredIntegration {
        let knownURL = integrations.first(where: { $0.bundleIdentifier == bundleIdentifier })?.appURL
        let resolvedURL: URL?
        if let knownURL, FileManager.default.fileExists(atPath: knownURL.path) {
            resolvedURL = knownURL
        } else {
            resolvedURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        }
        guard let appURL = resolvedURL else { throw IntegrationDiscoveryError.unavailable(bundleIdentifier) }
        let fresh = try Self.loadIntegration(at: appURL)
        guard fresh.bundleIdentifier == bundleIdentifier else {
            throw IntegrationManifestError.bundleIdentifierMismatch(manifest: fresh.bundleIdentifier, actual: bundleIdentifier)
        }
        return fresh
    }
}
