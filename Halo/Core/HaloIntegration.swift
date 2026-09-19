//
//  HaloIntegration.swift
//  Halo
//
//  Discovery and manifest models for third-party app integrations.
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

        // Include apps currently launched from Xcode/DerivedData. This keeps
        // development integrations testable without requiring a copy to /Applications.
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

    nonisolated private static func discoverInstalledIntegrations(
        additionalAppURLs: [URL]
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

        let decoder = JSONDecoder()
        var discovered: [String: HaloIntegration] = [:]
        var diagnostics: [String] = []

        func inspectApp(at appURL: URL) {
            guard appURL.pathExtension.lowercased() == "app",
                  let bundle = Bundle(url: appURL),
                  let resourcesURL = bundle.resourceURL else { return }

            let manifestURL = resourcesURL.appendingPathComponent("HaloIntegration.json")
            guard fileManager.fileExists(atPath: manifestURL.path) else { return }

            do {
                let data = try Data(contentsOf: manifestURL)
                let manifest = try decoder.decode(HaloIntegrationManifest.self, from: data)

                guard manifest.protocolVersion == 1 else {
                    diagnostics.append("\(appURL.lastPathComponent): unsupported Halo integration protocol v\(manifest.protocolVersion).")
                    return
                }

                guard !manifest.bundleIdentifier.isEmpty,
                      !manifest.name.isEmpty else {
                    diagnostics.append("\(appURL.lastPathComponent): manifest is missing its app name or bundle identifier.")
                    return
                }

                if let actualBundleID = bundle.bundleIdentifier,
                   actualBundleID != manifest.bundleIdentifier {
                    diagnostics.append("\(appURL.lastPathComponent): manifest bundle identifier \(manifest.bundleIdentifier) does not match \(actualBundleID).")
                    return
                }

                let actionIDs = manifest.actions.map(\.id)
                guard !actionIDs.isEmpty,
                      Set(actionIDs).count == actionIDs.count,
                      actionIDs.allSatisfy({ !$0.isEmpty }) else {
                    diagnostics.append("\(appURL.lastPathComponent): actions must have unique, non-empty IDs.")
                    return
                }

                let supportedTypes: Set<String> = [
                    "string", "integer", "double", "boolean",
                    "stringArray", "integerArray", "doubleArray"
                ]

                for action in manifest.actions {
                    let optionKeys = action.options.map(\.key)
                    guard Set(optionKeys).count == optionKeys.count,
                          !optionKeys.contains(where: { $0.isEmpty }) else {
                        diagnostics.append("\(appURL.lastPathComponent): action \(action.id) has duplicate or empty option keys.")
                        return
                    }

                    guard !action.options.contains(where: {
                        !supportedTypes.contains($0.type)
                    }) else {
                        diagnostics.append("\(appURL.lastPathComponent): action \(action.id) declares an unsupported option type.")
                        return
                    }
                }

                // Prefer the running copy (for example an Xcode DerivedData build)
                // because additionalAppURLs are inspected before filesystem roots.
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

        for appURL in additionalAppURLs {
            inspectApp(at: appURL)
        }

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let appURL as URL in enumerator {
                inspectApp(at: appURL)
            }
        }

        let integrations = discovered.values.sorted {
            $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending
        }

        return (integrations, diagnostics.sorted())
    }
}


struct HaloIntegrationInvocation: Identifiable, Hashable, Sendable {
    let integration: HaloIntegration
    let action: HaloIntegrationAction

    var id: String {
        integration.bundleIdentifier + "::" + action.id
    }
}

extension HaloIntegrationCatalog {
    func compatibleInvocations(for files: [URL]) -> [HaloIntegrationInvocation] {
        let fileURLs = files.filter(\.isFileURL)
        guard !fileURLs.isEmpty else { return [] }

        return integrations.flatMap { integration in
            integration.manifest.actions.compactMap { action in
                guard Self.action(action, supports: fileURLs) else { return nil }
                return HaloIntegrationInvocation(integration: integration, action: action)
            }
        }
        .sorted {
            if $0.integration.name != $1.integration.name {
                return $0.integration.name.localizedCaseInsensitiveCompare($1.integration.name) == .orderedAscending
            }
            return $0.action.name.localizedCaseInsensitiveCompare($1.action.name) == .orderedAscending
        }
    }

    func invoke(
        _ invocation: HaloIntegrationInvocation,
        files: [URL],
        options: [String: Any]
    ) throws {
        let fileURLs = files.filter(\.isFileURL)
        guard !fileURLs.isEmpty else {
            throw HaloIntegrationInvocationError.noFiles
        }
        guard Self.action(invocation.action, supports: fileURLs) else {
            throw HaloIntegrationInvocationError.unsupportedFiles
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
            "protocolVersion": 1,
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

        // The receiving application reads the request immediately during its open-URL callback.
        // Keep the request around long enough for a cold launch, then clean it up.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 120) {
            try? FileManager.default.removeItem(at: requestURL)
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

enum HaloIntegrationInvocationError: LocalizedError {
    case noFiles
    case unsupportedFiles
    case invalidOptions

    var errorDescription: String? {
        switch self {
        case .noFiles:
            return "No files were supplied to the app integration."
        case .unsupportedFiles:
            return "The selected integration action does not support every dropped file."
        case .invalidOptions:
            return "The integration options could not be encoded as JSON."
        }
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
                showValidationError(
                    "\(option.name) must be a valid \(option.type) value."
                )
                return nil
            }

            result[option.key] = value
        }

        if !missingRequired.isEmpty {
            showValidationError(
                "Enter a value for: " + missingRequired.joined(separator: ", ")
            )
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


@MainActor
final class HaloIntegrationExecutionSession: ObservableObject {
    static let shared = HaloIntegrationExecutionSession()

    @Published private(set) var candidates: [HaloIntegrationInvocation] = []
    @Published private(set) var invocation: HaloIntegrationInvocation?
    @Published private(set) var files: [URL] = []
    @Published private(set) var targetDisplayID: String?
    @Published private(set) var dropCommitted = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private var sourceSignature = ""

    private init() {}

    var isActive: Bool {
        invocation != nil || !candidates.isEmpty
    }

    func presentChoices(
        _ candidates: [HaloIntegrationInvocation],
        files: [URL],
        displayID: String
    ) {
        let cleanFiles = files.filter(\.isFileURL)
        let uniqueCandidates = Array(
            Dictionary(
                uniqueKeysWithValues: candidates.map { ($0.id, $0) }
            ).values
        )
        .sorted {
            if $0.integration.name != $1.integration.name {
                return $0.integration.name.localizedCaseInsensitiveCompare(
                    $1.integration.name
                ) == .orderedAscending
            }
            return $0.action.name.localizedCaseInsensitiveCompare(
                $1.action.name
            ) == .orderedAscending
        }

        guard !uniqueCandidates.isEmpty, !cleanFiles.isEmpty else {
            cancel()
            return
        }

        let signature = cleanFiles.map(\.path).sorted().joined(separator: "\n")
            + "\n--\n"
            + uniqueCandidates.map(\.id).sorted().joined(separator: "\n")

        // The global drag monitor polls frequently. Do not reset the chooser
        // or selected action every 50 ms for the same drag payload.
        guard sourceSignature != signature else { return }

        sourceSignature = signature
        self.candidates = uniqueCandidates
        invocation = nil
        self.files = cleanFiles
        targetDisplayID = displayID
        dropCommitted = false
        statusMessage = nil
        errorMessage = nil
    }

    func present(
        _ invocation: HaloIntegrationInvocation,
        files: [URL],
        displayID: String
    ) {
        sourceSignature = ""
        candidates = [invocation]
        self.invocation = invocation
        self.files = files.filter(\.isFileURL)
        targetDisplayID = displayID
        dropCommitted = true
        statusMessage = nil
        errorMessage = nil
    }

    func select(_ invocation: HaloIntegrationInvocation) {
        guard candidates.contains(where: { $0.id == invocation.id }) else {
            return
        }
        self.invocation = invocation
        statusMessage = nil
        errorMessage = nil
    }

    func showActionPicker() {
        guard !candidates.isEmpty else { return }
        invocation = nil
        statusMessage = nil
        errorMessage = nil
    }

    func commitDrop(files: [URL]) {
        let cleanFiles = files.filter(\.isFileURL)
        guard !cleanFiles.isEmpty else { return }
        self.files = cleanFiles
        dropCommitted = true
    }

    func updateFiles(_ files: [URL]) {
        let cleanFiles = files.filter(\.isFileURL)
        guard !cleanFiles.isEmpty else { return }
        self.files = cleanFiles
    }

    func cancelUncommittedDrag(on displayID: String? = nil) {
        guard !dropCommitted else { return }
        if let displayID, targetDisplayID != displayID { return }
        cancel()
    }

    func isActive(on displayID: String) -> Bool {
        isActive && targetDisplayID == displayID
    }

    func cancel() {
        sourceSignature = ""
        candidates = []
        invocation = nil
        files = []
        targetDisplayID = nil
        dropCommitted = false
        statusMessage = nil
        errorMessage = nil
    }

    @discardableResult
    func run(options: [String: Any]) -> Bool {
        guard let invocation else { return false }

        do {
            try HaloIntegrationCatalog.shared.invoke(
                invocation,
                files: files,
                options: options
            )
            statusMessage = "Sent to \(invocation.integration.name)"
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
            return false
        }
    }
}
