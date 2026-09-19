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
    @Published private(set) var hasCompletedRefresh = false

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
            hasCompletedRefresh = true
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
                Self.actionSupports(action, files: fileURLs)
                    ? (integration: integration, action: action)
                    : nil
            }
        }
    }

    nonisolated static func actionSupports(
        _ action: HaloIntegrationAction,
        files: [URL]
    ) -> Bool {
        let supported = Set(
            action.supportedExtensions.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            }
        )

        if supported.isEmpty { return files.isEmpty }
        guard !files.isEmpty else { return false }
        if supported.contains("*") { return true }

        return files.allSatisfy { file in
            let ext = file.pathExtension.lowercased()
            return !ext.isEmpty && supported.contains(ext)
        }
    }
}


struct HaloIntegrationInvocation: Identifiable, Hashable, Sendable {
    let integration: HaloIntegration
    let action: HaloIntegrationAction

    var id: String { integration.bundleIdentifier + "::" + action.id }
}

enum HaloIntegrationInvocationError: LocalizedError {
    case integrationUnavailable(String)
    case actionUnavailable(String)
    case noFiles
    case unsupportedFiles
    case invalidOptions

    var errorDescription: String? {
        switch self {
        case .integrationUnavailable(let bundleID):
            return "The compatible app \(bundleID) is no longer available."
        case .actionUnavailable(let actionID):
            return "The app no longer exposes the action \(actionID)."
        case .noFiles:
            return "This app action requires at least one file."
        case .unsupportedFiles:
            return "The selected app action does not support every selected file."
        case .invalidOptions:
            return "The integration options could not be encoded as JSON."
        }
    }
}

extension HaloIntegrationCatalog {
    func invocation(bundleIdentifier: String, actionID: String) -> HaloIntegrationInvocation? {
        guard let integration = integrations.first(where: { $0.bundleIdentifier == bundleIdentifier }),
              let action = integration.manifest.actions.first(where: { $0.id == actionID }) else {
            return nil
        }
        return HaloIntegrationInvocation(integration: integration, action: action)
    }

    /// Re-read and revalidate the partner manifest at the action boundary.
    /// A stale CI button cannot invoke an action that the installed app no longer advertises.
    func freshInvocation(bundleIdentifier: String, actionID: String) throws -> HaloIntegrationInvocation {
        let known = integrations.first(where: { $0.bundleIdentifier == bundleIdentifier })
        let candidateURL = known?.appURL
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)

        guard let appURL = candidateURL,
              FileManager.default.fileExists(atPath: appURL.path),
              let bundle = Bundle(url: appURL),
              let resourcesURL = bundle.resourceURL else {
            throw HaloIntegrationInvocationError.integrationUnavailable(bundleIdentifier)
        }

        let manifestURL = resourcesURL.appendingPathComponent("HaloIntegration.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw HaloIntegrationInvocationError.integrationUnavailable(bundleIdentifier)
        }

        let data = try Data(contentsOf: manifestURL, options: [.mappedIfSafe])
        let manifest = try HaloIntegrationManifestCodec.decodeAndValidate(
            data,
            actualBundleIdentifier: bundle.bundleIdentifier
        )

        guard let action = manifest.actions.first(where: { $0.id == actionID }) else {
            throw HaloIntegrationInvocationError.actionUnavailable(actionID)
        }

        return HaloIntegrationInvocation(
            integration: HaloIntegration(appURL: appURL, manifest: manifest),
            action: action
        )
    }

    func invoke(
        _ invocation: HaloIntegrationInvocation,
        files: [URL],
        options: [String: Any]
    ) throws {
        let fileURLs = files.filter(\.isFileURL)
        if invocation.action.supportedExtensions.isEmpty {
            guard fileURLs.isEmpty else {
                throw HaloIntegrationInvocationError.unsupportedFiles
            }
        } else {
            guard !fileURLs.isEmpty else {
                throw HaloIntegrationInvocationError.noFiles
            }
            guard Self.actionSupports(invocation.action, files: fileURLs) else {
                throw HaloIntegrationInvocationError.unsupportedFiles
            }
        }

        let requestID = UUID().uuidString
        let requestDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HaloIntegrationRequests", isDirectory: true)
        try FileManager.default.createDirectory(
            at: requestDirectory,
            withIntermediateDirectories: true
        )

        let requestURL = requestDirectory
            .appendingPathComponent(requestID)
            .appendingPathExtension("halorequest")

        let payload: [String: Any] = [
            "protocolVersion": HaloIntegrationManifestCodec.currentProtocolVersion,
            "requestID": requestID,
            "sourceBundleIdentifier": Bundle.main.bundleIdentifier ?? "com.redstoneinvente.Halo",
            "action": invocation.action.id,
            "options": options
        ]

        guard JSONSerialization.isValidJSONObject(payload) else {
            throw HaloIntegrationInvocationError.invalidOptions
        }

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: requestURL, options: .atomic)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(
            [requestURL] + fileURLs,
            withApplicationAt: invocation.integration.appURL,
            configuration: configuration
        ) { _, error in
            if let error {
                NSLog(
                    "Halo app integration launch failed for %@: %@",
                    invocation.integration.bundleIdentifier,
                    error.localizedDescription
                )
            }
        }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 120) {
            try? FileManager.default.removeItem(at: requestURL)
        }
    }
}

@MainActor
enum HaloIntegrationFilePrompt {
    static func collect(
        for invocation: HaloIntegrationInvocation,
        parentWindow: NSWindow?
    ) -> [URL]? {
        let extensions = normalizedExtensions(invocation.action.supportedExtensions)
        guard !extensions.isEmpty else { return [] }

        let panel = NSOpenPanel()
        panel.title = invocation.action.name
        panel.message = fileMessage(appName: invocation.integration.name, extensions: extensions)
        panel.prompt = "Use Files"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true

        NSApp.activate(ignoringOtherApps: true)
        parentWindow?.makeKeyAndOrderFront(nil)
        guard panel.runModal() == .OK else { return nil }

        let files = panel.urls.filter(\.isFileURL)
        guard !files.isEmpty,
              HaloIntegrationCatalog.actionSupports(invocation.action, files: files) else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Unsupported files"
            alert.informativeText = "Every selected file must be supported by \(invocation.action.name)."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return nil
        }
        return files
    }

    private static func normalizedExtensions(_ values: [String]) -> [String] {
        Array(Set(values.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }.filter { !$0.isEmpty })).sorted()
    }

    private static func fileMessage(appName: String, extensions: [String]) -> String {
        if extensions.contains("*") {
            return "Choose one or more files to send to \(appName)."
        }
        let formats = extensions.map { ".\($0)" }.joined(separator: ", ")
        return "Choose one or more supported files for \(appName): \(formats)"
    }
}

@MainActor
enum HaloIntegrationOptionPrompt {
    private struct FieldBinding {
        let option: HaloIntegrationOption
        let textField: NSTextField?
        let checkbox: NSButton?
    }

    static func collect(
        for invocation: HaloIntegrationInvocation,
        parentWindow: NSWindow?
    ) -> [String: Any]? {
        let options = invocation.action.options
        guard !options.isEmpty else { return [:] }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = invocation.action.name
        alert.informativeText = "Set the request options for \(invocation.integration.name)."
        alert.addButton(withTitle: "Run Action")
        alert.addButton(withTitle: "Cancel")

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false

        var bindings: [FieldBinding] = []

        for option in options {
            let row = NSStackView()
            row.orientation = .vertical
            row.alignment = .leading
            row.spacing = 4

            let requiredSuffix = option.required ? " · required" : " · optional"
            let title = NSTextField(labelWithString: option.name + requiredSuffix)
            title.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
            row.addArrangedSubview(title)

            var textField: NSTextField?
            var checkbox: NSButton?

            if option.type == "boolean" {
                let control = NSButton(
                    checkboxWithTitle: option.key,
                    target: nil,
                    action: nil
                )
                control.allowsMixedState = !option.required
                control.state = option.required ? .off : .mixed
                control.toolTip = option.required
                    ? "Off = false, On = true"
                    : "Mixed = omit this optional value; Off = false; On = true"
                row.addArrangedSubview(control)
                checkbox = control
            } else {
                let field = NSTextField(string: "")
                field.placeholderString = placeholder(for: option)
                field.widthAnchor.constraint(equalToConstant: 420).isActive = true
                row.addArrangedSubview(field)
                textField = field
            }

            if let description = option.description, !description.isEmpty {
                let detail = NSTextField(wrappingLabelWithString: description)
                detail.font = .systemFont(ofSize: NSFont.smallSystemFontSize - 1)
                detail.textColor = .secondaryLabelColor
                detail.maximumNumberOfLines = 2
                row.addArrangedSubview(detail)
            }

            stack.addArrangedSubview(row)
            bindings.append(
                FieldBinding(
                    option: option,
                    textField: textField,
                    checkbox: checkbox
                )
            )
        }

        let accessory = NSView()
        accessory.translatesAutoresizingMaskIntoConstraints = false
        accessory.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: accessory.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: accessory.trailingAnchor),
            stack.topAnchor.constraint(equalTo: accessory.topAnchor),
            stack.bottomAnchor.constraint(equalTo: accessory.bottomAnchor),
            accessory.widthAnchor.constraint(equalToConstant: 440)
        ])
        alert.accessoryView = accessory

        NSApp.activate(ignoringOtherApps: true)
        parentWindow?.makeKeyAndOrderFront(nil)

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }

        var result: [String: Any] = [:]
        var missingRequired: [String] = []

        for binding in bindings {
            let option = binding.option

            if option.type == "boolean", let checkbox = binding.checkbox {
                if !option.required && checkbox.state == .mixed {
                    continue
                }
                result[option.key] = checkbox.state == .on
                continue
            }

            let raw = binding.textField?.stringValue
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if raw.isEmpty {
                if option.required { missingRequired.append(option.name) }
                continue
            }

            guard let value = parse(raw, as: option.type) else {
                showValidationError("\(option.name) must be a valid \(option.type) value.")
                return nil
            }

            result[option.key] = value
        }

        if !missingRequired.isEmpty {
            showValidationError("Enter a value for: " + missingRequired.joined(separator: ", "))
            return nil
        }

        return result
    }

    private static func placeholder(for option: HaloIntegrationOption) -> String {
        switch option.type {
        case "integer": return "42"
        case "double": return "0.9"
        case "stringArray": return "one, two, three"
        case "integerArray": return "1, 2, 3"
        case "doubleArray": return "0.25, 0.5, 1.0"
        default: return option.key
        }
    }

    private static func parse(_ raw: String, as type: String) -> Any? {
        switch type {
        case "string":
            return raw
        case "integer":
            return Int(raw)
        case "double":
            return Double(raw)
        case "stringArray":
            return commaSeparated(raw)
        case "integerArray":
            let values = commaSeparated(raw)
            let parsed = values.compactMap(Int.init)
            return parsed.count == values.count ? parsed : nil
        case "doubleArray":
            let values = commaSeparated(raw)
            let parsed = values.compactMap(Double.init)
            return parsed.count == values.count ? parsed : nil
        default:
            return nil
        }
    }

    private static func commaSeparated(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func showValidationError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Invalid integration options"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct HaloGeneratedIntegrationCIMetadata: Codable, Equatable {
    let generatorVersion: Int
    let bundleIdentifier: String
    let packageID: String
    let sourceFingerprint: String
}

struct HaloAutoIntegrationCISyncResult {
    var changed = false
    var installed: [String] = []
    var removed: [String] = []
    var diagnostics: [String] = []
}

enum HaloAutoIntegrationCIGenerator {
    static let generatorVersion = 1
    static let markerFileName = ".halo-generated-integration.json"
    private static let packagePrefix = "com.redstoneinvente.halo.integration."

    static func packageID(for bundleIdentifier: String) -> String {
        let slug = sanitizedSlug(bundleIdentifier)
        return packagePrefix + String(slug.prefix(72)) + "." + stableHash(bundleIdentifier)
    }

    static func isGeneratedPackage(at packageURL: URL) -> Bool {
        metadata(at: packageURL) != nil
    }

    static func metadata(at packageURL: URL) -> HaloGeneratedIntegrationCIMetadata? {
        let url = packageURL.appendingPathComponent(markerFileName)
        guard let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(HaloGeneratedIntegrationCIMetadata.self, from: data),
              value.generatorVersion == generatorVersion else {
            return nil
        }
        return value
    }

    static func synchronize(
        integrations: [HaloIntegration],
        installRoot: URL
    ) -> HaloAutoIntegrationCISyncResult {
        var result = HaloAutoIntegrationCISyncResult()
        let fm = FileManager.default

        do {
            try fm.createDirectory(at: installRoot, withIntermediateDirectories: true)
        } catch {
            result.diagnostics.append("Could not create the Custom CI install directory: \(error.localizedDescription)")
            return result
        }

        var desiredIDs = Set<String>()
        for integration in integrations {
            let packageID = packageID(for: integration.bundleIdentifier)
            desiredIDs.insert(packageID)
            let destination = installRoot
                .appendingPathComponent(packageID)
                .appendingPathExtension("haloCI")
            let fingerprint = sourceFingerprint(integration.manifest)

            if fm.fileExists(atPath: destination.path) {
                guard let existing = metadata(at: destination) else {
                    result.diagnostics.append(
                        "\(integration.name): Halo will not overwrite an existing non-generated Custom CI at \(destination.lastPathComponent)."
                    )
                    continue
                }
                guard existing.bundleIdentifier == integration.bundleIdentifier else {
                    result.diagnostics.append(
                        "\(integration.name): generated CI identity does not match the existing package marker."
                    )
                    continue
                }
                let report = HaloCIPackageValidator.validatePackage(at: destination)
                if existing.sourceFingerprint == fingerprint, report.package != nil {
                    continue
                }
            }

            do {
                try writePackage(
                    for: integration,
                    packageID: packageID,
                    fingerprint: fingerprint,
                    installRoot: installRoot,
                    destination: destination
                )
                result.changed = true
                result.installed.append(packageID)
            } catch {
                result.diagnostics.append("\(integration.name): \(error.localizedDescription)")
            }
        }

        let installedURLs = (try? fm.contentsOfDirectory(
            at: installRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for url in installedURLs where url.pathExtension.lowercased() == "haloci" {
            guard let marker = metadata(at: url),
                  marker.packageID == url.deletingPathExtension().lastPathComponent,
                  !desiredIDs.contains(marker.packageID) else {
                continue
            }
            do {
                try fm.removeItem(at: url)
                result.changed = true
                result.removed.append(marker.packageID)
            } catch {
                result.diagnostics.append(
                    "Could not remove stale generated CI \(url.lastPathComponent): \(error.localizedDescription)"
                )
            }
        }

        return result
    }

    static func removeGeneratedPackages(at installRoot: URL) -> HaloAutoIntegrationCISyncResult {
        var result = HaloAutoIntegrationCISyncResult()
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(
            at: installRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for url in urls where url.pathExtension.lowercased() == "haloci" {
            guard let marker = metadata(at: url),
                  marker.packageID == url.deletingPathExtension().lastPathComponent else {
                continue
            }
            do {
                try fm.removeItem(at: url)
                result.changed = true
                result.removed.append(marker.packageID)
            } catch {
                result.diagnostics.append(
                    "Could not remove generated CI \(url.lastPathComponent): \(error.localizedDescription)"
                )
            }
        }
        return result
    }

    private static func writePackage(
        for integration: HaloIntegration,
        packageID: String,
        fingerprint: String,
        installRoot: URL,
        destination: URL
    ) throws {
        let fm = FileManager.default
        let staging = installRoot
            .appendingPathComponent(".generated-\(UUID().uuidString)")
            .appendingPathExtension("haloCI")
        let backup = installRoot.appendingPathComponent(".generated-backup-\(UUID().uuidString)")
        defer {
            try? fm.removeItem(at: staging)
            try? fm.removeItem(at: backup)
        }

        try fm.createDirectory(at: staging, withIntermediateDirectories: true)

        let manifest = generatedManifest(for: integration, packageID: packageID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(
            to: staging.appendingPathComponent("manifest.json"),
            options: .atomic
        )

        let interface = generatedInterface(for: integration)
        let interfaceData = try JSONSerialization.data(
            withJSONObject: interface,
            options: [.prettyPrinted, .sortedKeys]
        )
        try interfaceData.write(
            to: staging.appendingPathComponent("interface.json"),
            options: .atomic
        )

        let marker = HaloGeneratedIntegrationCIMetadata(
            generatorVersion: generatorVersion,
            bundleIdentifier: integration.bundleIdentifier,
            packageID: packageID,
            sourceFingerprint: fingerprint
        )
        try encoder.encode(marker).write(
            to: staging.appendingPathComponent(markerFileName),
            options: .atomic
        )

        let report = HaloCIPackageValidator.validatePackage(at: staging)
        guard report.package != nil else {
            let details = report.issues
                .filter { $0.severity == .error }
                .prefix(4)
                .map { "\($0.path): \($0.message)" }
                .joined(separator: "; ")
            throw HaloAutoIntegrationCIGeneratorError.validationFailed(details)
        }

        if fm.fileExists(atPath: destination.path) {
            try fm.moveItem(at: destination, to: backup)
        }

        do {
            try fm.moveItem(at: staging, to: destination)
            if fm.fileExists(atPath: backup.path) {
                try? fm.removeItem(at: backup)
            }
        } catch {
            if fm.fileExists(atPath: backup.path),
               !fm.fileExists(atPath: destination.path) {
                try? fm.moveItem(at: backup, to: destination)
            }
            throw error
        }
    }

    private static func generatedManifest(
        for integration: HaloIntegration,
        packageID: String
    ) -> HaloCIManifest {
        let visibleRows = min(6, max(1, integration.manifest.actions.count))
        let expandedHeight = min(620.0, max(260.0, 210.0 + Double(visibleRows) * 54.0))
        return HaloCIManifest(
            schemaVersion: 1,
            sdkVersion: "0.2",
            id: packageID,
            name: integration.name,
            author: "Halo App Integration",
            version: "1.0.0",
            minimumHaloVersion: "1.0.0",
            entryInterface: "interface.json",
            description: "Automatically generated from \(integration.bundleIdentifier). Actions are revalidated against the installed app before execution.",
            permissions: ["AppIntegration.Execute"],
            capabilities: ["AppIntegrations"],
            supportedSurfaces: ["notch"],
            supportedStates: ["closed", "expanded"],
            surface: HaloCISurfaceContract(
                sizing: HaloCISurfaceSizing(
                    mode: "static",
                    closed: HaloCISizeRule(width: 280, height: 42),
                    expanded: HaloCISizeRule(width: 580, height: expandedHeight)
                ),
                background: HaloCIBackgroundContract(
                    closed: HaloCIBackgroundStyle(
                        type: "gradient",
                        color: "#0B0D12",
                        secondaryColor: "#151A2A",
                        opacity: 1,
                        blur: 0
                    ),
                    expanded: HaloCIBackgroundStyle(
                        type: "gradient",
                        color: "#0B0D12",
                        secondaryColor: "#151A2A",
                        opacity: 1,
                        blur: 0
                    )
                )
            )
        )
    }

    private static func generatedInterface(for integration: HaloIntegration) -> [String: Any] {
        var actionChildren: [[String: Any]] = []

        for action in integration.manifest.actions {
            actionChildren.append([
                "type": "Button",
                "text": action.name,
                "systemName": "bolt.fill",
                "accessibilityLabel": "Run \(action.name) in \(integration.name)",
                "action": [
                    "id": "app.integration.invoke",
                    "arguments": [
                        "bundleIdentifier": integration.bundleIdentifier,
                        "actionID": action.id
                    ]
                ]
            ])

            let detail = actionDetail(action)
            if !detail.isEmpty {
                actionChildren.append([
                    "type": "Text",
                    "text": detail,
                    "style": "caption",
                    "foreground": "secondary",
                    "lineLimit": 2
                ])
            }
        }

        let expandedChildren: [[String: Any]] = [
            [
                "type": "HStack",
                "spacing": 8,
                "children": [
                    [
                        "type": "Icon",
                        "systemName": "app.connected.to.app.below.fill",
                        "width": 18,
                        "height": 18,
                        "foreground": "accent"
                    ],
                    [
                        "type": "Text",
                        "text": integration.name,
                        "style": "headline",
                        "lineLimit": 1
                    ],
                    ["type": "Spacer"],
                    [
                        "type": "Badge",
                        "text": "\(integration.manifest.actions.count) actions"
                    ]
                ]
            ],
            [
                "type": "Text",
                "text": "Actions exposed by \(integration.name). Halo asks for files and typed options only when an action needs them.",
                "style": "caption",
                "foreground": "secondary",
                "lineLimit": 3
            ],
            ["type": "Divider"],
            [
                "type": "ScrollView",
                "axis": "vertical",
                "spacing": 8,
                "children": actionChildren
            ],
            ["type": "Divider"],
            [
                "type": "Button",
                "text": "Close",
                "systemName": "xmark",
                "accessibilityLabel": "Close \(integration.name) interface",
                "action": ["id": "halo.ci.close"]
            ]
        ]

        return [
            "closed": [
                "type": "HStack",
                "spacing": 7,
                "padding": 8,
                "children": [
                    [
                        "type": "Icon",
                        "systemName": "app.connected.to.app.below.fill",
                        "width": 14,
                        "height": 14,
                        "foreground": "accent"
                    ],
                    [
                        "type": "Text",
                        "text": integration.name,
                        "style": "caption",
                        "lineLimit": 1
                    ],
                    [
                        "type": "Badge",
                        "text": "\(integration.manifest.actions.count)"
                    ]
                ]
            ],
            "expanded": [
                "type": "NotchContainer",
                "spacing": 10,
                "padding": 18,
                "children": expandedChildren
            ]
        ]
    }

    private static func actionDetail(_ action: HaloIntegrationAction) -> String {
        let extensions = action.supportedExtensions
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            }
            .filter { !$0.isEmpty }

        let files: String
        if extensions.isEmpty {
            files = "No file input"
        } else if extensions.contains("*") {
            files = "Any file"
        } else {
            files = extensions.map { ".\($0)" }.joined(separator: ", ")
        }

        let options = action.options.isEmpty
            ? "No options"
            : "\(action.options.count) option\(action.options.count == 1 ? "" : "s")"
        return "\(files) · \(options)"
    }

    private static func sourceFingerprint(_ manifest: HaloIntegrationManifest) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(manifest)) ?? Data()
        return stableHash(String(decoding: data, as: UTF8.self))
    }

    private static func sanitizedSlug(_ value: String) -> String {
        var output = ""
        var lastWasSeparator = false
        for scalar in value.lowercased().unicodeScalars {
            let allowed = CharacterSet.alphanumerics.contains(scalar)
            if allowed {
                output.unicodeScalars.append(scalar)
                lastWasSeparator = false
            } else if !lastWasSeparator && !output.isEmpty {
                output.append("-")
                lastWasSeparator = true
            }
        }
        while output.hasSuffix("-") { output.removeLast() }
        return output.isEmpty ? "app" : output
    }

    private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(format: "%016llx", hash)
    }
}

enum HaloAutoIntegrationCIGeneratorError: LocalizedError {
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .validationFailed(let details):
            return details.isEmpty
                ? "Generated Custom CI failed validation."
                : "Generated Custom CI failed validation: \(details)"
        }
    }
}
