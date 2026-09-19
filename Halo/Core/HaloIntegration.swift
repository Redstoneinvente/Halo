//
//  HaloIntegration.swift
//  Halo
//
//  Discovery and manifest models for third-party app integrations.
//

import AppKit
import Combine
import Foundation

struct HaloIntegrationOption: Codable, Hashable, Identifiable {
    let key: String
    let name: String
    let type: String
    let required: Bool
    let description: String?

    var id: String { key }
}

struct HaloIntegrationAction: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let supportedExtensions: [String]
    let options: [HaloIntegrationOption]
}

struct HaloIntegrationManifest: Codable, Hashable {
    let protocolVersion: Int
    let name: String
    let bundleIdentifier: String
    let actions: [HaloIntegrationAction]
}

struct HaloIntegration: Hashable, Identifiable {
    let appURL: URL
    let manifest: HaloIntegrationManifest

    var id: String { manifest.bundleIdentifier }
    var name: String { manifest.name }
    var bundleIdentifier: String { manifest.bundleIdentifier }
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

        Task {
            let result = await Task.detached(priority: .utility) {
                Self.discoverInstalledIntegrations()
            }.value

            integrations = result.integrations
            diagnostics = result.diagnostics
            isRefreshing = false
        }
    }

    nonisolated private static func discoverInstalledIntegrations() -> (
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

        let decoder = JSONDecoder()
        var discovered: [String: HaloIntegration] = [:]
        var diagnostics: [String] = []

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let appURL as URL in enumerator {
                guard appURL.pathExtension.lowercased() == "app",
                      let bundle = Bundle(url: appURL),
                      let resourcesURL = bundle.resourceURL else { continue }

                let manifestURL = resourcesURL.appendingPathComponent("HaloIntegration.json")
                guard fileManager.fileExists(atPath: manifestURL.path) else { continue }

                do {
                    let data = try Data(contentsOf: manifestURL)
                    let manifest = try decoder.decode(HaloIntegrationManifest.self, from: data)

                    guard manifest.protocolVersion == 1 else {
                        diagnostics.append("\(appURL.lastPathComponent): unsupported Halo integration protocol v\(manifest.protocolVersion).")
                        continue
                    }

                    guard !manifest.bundleIdentifier.isEmpty,
                          !manifest.name.isEmpty else {
                        diagnostics.append("\(appURL.lastPathComponent): manifest is missing its app name or bundle identifier.")
                        continue
                    }

                    if let actualBundleID = bundle.bundleIdentifier,
                       actualBundleID != manifest.bundleIdentifier {
                        diagnostics.append("\(appURL.lastPathComponent): manifest bundle identifier \(manifest.bundleIdentifier) does not match \(actualBundleID).")
                        continue
                    }

                    let actionIDs = manifest.actions.map(\.id)
                    guard !actionIDs.isEmpty,
                          Set(actionIDs).count == actionIDs.count,
                          actionIDs.allSatisfy({ !$0.isEmpty }) else {
                        diagnostics.append("\(appURL.lastPathComponent): actions must have unique, non-empty IDs.")
                        continue
                    }

                    var valid = true
                    for action in manifest.actions {
                        let optionKeys = action.options.map(\.key)
                        if Set(optionKeys).count != optionKeys.count || optionKeys.contains(where: { $0.isEmpty }) {
                            diagnostics.append("\(appURL.lastPathComponent): action \(action.id) has duplicate or empty option keys.")
                            valid = false
                            break
                        }

                        let supportedTypes: Set<String> = [
                            "string", "integer", "double", "boolean",
                            "stringArray", "integerArray", "doubleArray"
                        ]
                        if action.options.contains(where: { !supportedTypes.contains($0.type) }) {
                            diagnostics.append("\(appURL.lastPathComponent): action \(action.id) declares an unsupported option type.")
                            valid = false
                            break
                        }
                    }
                    guard valid else { continue }

                    if discovered[manifest.bundleIdentifier] == nil {
                        discovered[manifest.bundleIdentifier] = HaloIntegration(
                            appURL: appURL,
                            manifest: manifest
                        )
                    }
                } catch {
                    diagnostics.append("\(appURL.lastPathComponent): could not read HaloIntegration.json — \(error.localizedDescription)")
                }
            }
        }

        let integrations = discovered.values.sorted {
            $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending
        }

        return (integrations, diagnostics.sorted())
    }
}
