//
//  HaloIntegration.swift
//  Halo
//
//  Discovery and validation for third-party app integrations.
//

import AppKit
import Combine
import Foundation

struct HaloIntegrationOption: Codable, Hashable, Identifiable, Sendable {
    let key: String
    let name: String
    let type: String
    let required: Bool
    let description: String?

    var id: String { key }
}

struct HaloIntegrationAction: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let supportedExtensions: [String]
    let options: [HaloIntegrationOption]
}

struct HaloIntegrationManifest: Codable, Hashable, Sendable {
    let protocolVersion: Int
    let name: String
    let bundleIdentifier: String
    let actions: [HaloIntegrationAction]
}

struct HaloIntegration: Hashable, Identifiable, Sendable {
    let appURL: URL
    let manifest: HaloIntegrationManifest

    var id: String { manifest.bundleIdentifier }
    var name: String { manifest.name }
    var bundleIdentifier: String { manifest.bundleIdentifier }
}

enum HaloIntegrationManifestError: LocalizedError {
    case manifestTooLarge(Int)
    case unsupportedProtocol(Int)
    case missingAppName
    case missingBundleIdentifier
    case bundleIdentifierMismatch(manifest: String, actual: String)
    case missingActions
    case emptyActionID
    case duplicateActionID(String)
    case emptyOptionKey(actionID: String)
    case duplicateOptionKey(actionID: String, key: String)
    case unsupportedOptionType(actionID: String, type: String)

    var errorDescription: String? {
        switch self {
        case .manifestTooLarge(let bytes):
            return "HaloIntegration.json is too large (\(bytes) bytes)."
        case .unsupportedProtocol(let version):
            return "unsupported Halo integration protocol v\(version)."
        case .missingAppName:
            return "manifest is missing its app name."
        case .missingBundleIdentifier:
            return "manifest is missing its bundle identifier."
        case .bundleIdentifierMismatch(let manifest, let actual):
            return "manifest bundle identifier \(manifest) does not match \(actual)."
        case .missingActions:
            return "manifest must expose at least one action."
        case .emptyActionID:
            return "actions must have non-empty IDs."
        case .duplicateActionID(let id):
            return "action ID \(id) is declared more than once."
        case .emptyOptionKey(let actionID):
            return "action \(actionID) has an empty option key."
        case .duplicateOptionKey(let actionID, let key):
            return "action \(actionID) declares option key \(key) more than once."
        case .unsupportedOptionType(let actionID, let type):
            return "action \(actionID) declares unsupported option type \(type)."
        }
    }
}

enum HaloIntegrationManifestCodec {
    static let currentProtocolVersion = 1
    static let maximumManifestBytes = 256_000
    static let supportedOptionTypes: Set<String> = [
        "string", "integer", "double", "boolean",
        "stringArray", "integerArray", "doubleArray"
    ]

    static func decodeAndValidate(
        _ data: Data,
        actualBundleIdentifier: String? = nil
    ) throws -> HaloIntegrationManifest {
        guard data.count <= maximumManifestBytes else {
            throw HaloIntegrationManifestError.manifestTooLarge(data.count)
        }

        let manifest = try JSONDecoder().decode(HaloIntegrationManifest.self, from: data)
        try validate(manifest, actualBundleIdentifier: actualBundleIdentifier)
        return manifest
    }

    static func validate(
        _ manifest: HaloIntegrationManifest,
        actualBundleIdentifier: String? = nil
    ) throws {
        guard manifest.protocolVersion == currentProtocolVersion else {
            throw HaloIntegrationManifestError.unsupportedProtocol(manifest.protocolVersion)
        }

        guard !manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HaloIntegrationManifestError.missingAppName
        }

        guard !manifest.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HaloIntegrationManifestError.missingBundleIdentifier
        }

        if let actualBundleIdentifier,
           actualBundleIdentifier != manifest.bundleIdentifier {
            throw HaloIntegrationManifestError.bundleIdentifierMismatch(
                manifest: manifest.bundleIdentifier,
                actual: actualBundleIdentifier
            )
        }

        guard !manifest.actions.isEmpty else {
            throw HaloIntegrationManifestError.missingActions
        }

        var actionIDs = Set<String>()
        for action in manifest.actions {
            let actionID = action.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !actionID.isEmpty else {
                throw HaloIntegrationManifestError.emptyActionID
            }
            guard actionIDs.insert(actionID).inserted else {
                throw HaloIntegrationManifestError.duplicateActionID(actionID)
            }

            var optionKeys = Set<String>()
            for option in action.options {
                let optionKey = option.key.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !optionKey.isEmpty else {
                    throw HaloIntegrationManifestError.emptyOptionKey(actionID: actionID)
                }
                guard optionKeys.insert(optionKey).inserted else {
                    throw HaloIntegrationManifestError.duplicateOptionKey(
                        actionID: actionID,
                        key: optionKey
                    )
                }
                guard supportedOptionTypes.contains(option.type) else {
                    throw HaloIntegrationManifestError.unsupportedOptionType(
                        actionID: actionID,
                        type: option.type
                    )
                }
            }
        }
    }
}

@MainActor
final class HaloIntegrationCatalog: ObservableObject {
    static let shared = HaloIntegrationCatalog()

    @Published private(set) var integrations: [HaloIntegration] = []
    @Published private(set) var diagnostics: [String] = []
    @Published private(set) var isRefreshing = false

    private init() {
        refresh()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        // Include apps launched directly from Xcode/DerivedData so partner
        // integrations can be developed without first copying them to /Applications.
        let runningApplicationURLs = NSWorkspace.shared.runningApplications
            .compactMap(\.bundleURL)

        Task {
            let result = await Task.detached(priority: .utility) {
                Self.discoverInstalledIntegrations(
                    additionalAppURLs: runningApplicationURLs
                )
            }.value

            integrations = result.integrations
            diagnostics = result.diagnostics
            isRefreshing = false
        }
    }

    nonisolated static func discoverInstalledIntegrations(
        additionalAppURLs: [URL] = []
    ) -> (
        integrations: [HaloIntegration],
        diagnostics: [String]
    ) {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true)
        ]

        var discovered: [String: HaloIntegration] = [:]
        var diagnostics: [String] = []

        func inspectApp(at appURL: URL) {
            guard appURL.pathExtension.lowercased() == "app",
                  let bundle = Bundle(url: appURL),
                  let resourcesURL = bundle.resourceURL else {
                return
            }

            let manifestURL = resourcesURL.appendingPathComponent("HaloIntegration.json")
            guard fileManager.fileExists(atPath: manifestURL.path) else {
                return
            }

            do {
                let resourceValues = try? manifestURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues?.fileSize,
                   fileSize > HaloIntegrationManifestCodec.maximumManifestBytes {
                    throw HaloIntegrationManifestError.manifestTooLarge(fileSize)
                }

                let data = try Data(contentsOf: manifestURL, options: [.mappedIfSafe])
                let manifest = try HaloIntegrationManifestCodec.decodeAndValidate(
                    data,
                    actualBundleIdentifier: bundle.bundleIdentifier
                )

                // Running/Xcode copies are inspected first. Keep the first valid
                // app for a bundle identifier so the developer build wins.
                if discovered[manifest.bundleIdentifier] == nil {
                    discovered[manifest.bundleIdentifier] = HaloIntegration(
                        appURL: appURL,
                        manifest: manifest
                    )
                }
            } catch {
                diagnostics.append(
                    "\(appURL.lastPathComponent): could not load HaloIntegration.json — \(error.localizedDescription)"
                )
            }
        }

        for appURL in additionalAppURLs {
            inspectApp(at: appURL)
        }

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else {
                continue
            }

            for case let appURL as URL in enumerator {
                inspectApp(at: appURL)
            }
        }

        let integrations = discovered.values.sorted {
            $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending
        }

        return (integrations, diagnostics.sorted())
    }

    func compatibleActions(for files: [URL]) -> [(integration: HaloIntegration, action: HaloIntegrationAction)] {
        let fileURLs = files.filter(\.isFileURL)
        guard !fileURLs.isEmpty else { return [] }

        return integrations.flatMap { integration in
            integration.manifest.actions.compactMap { action in
                Self.action(action, supports: fileURLs)
                    ? (integration: integration, action: action)
                    : nil
            }
        }
    }

    nonisolated private static func action(
        _ action: HaloIntegrationAction,
        supports files: [URL]
    ) -> Bool {
        let supported = Set(
            action.supportedExtensions.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            }
        )

        guard !supported.isEmpty else { return false }
        if supported.contains("*") { return true }

        return files.allSatisfy { file in
            let ext = file.pathExtension.lowercased()
            return !ext.isEmpty && supported.contains(ext)
        }
    }
}
