import AppKit
import Foundation

struct IntegrationDeliveryRequest: Hashable, Sendable {
    var protocolVersion: Int
    var requestID: UUID
    var sourceBundleIdentifier: String
    var actionID: String
    var options: [String: CIValue]
    var files: [URL]
    var delivery: IntegrationDeliveryDefinition
}

enum IntegrationTransportError: LocalizedError {
    case unsupportedProtocol(Int)
    case unsupportedDelivery(String)
    case invalidOptions
    case invalidFiles
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedProtocol(let version): return "Unsupported integration transport protocol v\(version)."
        case .unsupportedDelivery(let value): return "Unsupported partner delivery type \(value)."
        case .invalidOptions: return "The integration options cannot be encoded safely."
        case .invalidFiles: return "The integration request contains invalid file URLs."
        case .launchFailed(let detail): return "The partner app could not be opened: \(detail)"
        }
    }
}

@MainActor
protocol IntegrationTransporting: AnyObject {
    func deliver(_ request: IntegrationDeliveryRequest, to appURL: URL) async throws
}

/// Versioned, bounded delivery transport. The only supported mechanism is opening a validated
/// request file and explicitly selected file URLs with the partner application through NSWorkspace.
@MainActor
final class IntegrationTransport: IntegrationTransporting {
    static let shared = IntegrationTransport()

    private let fileManager: FileManager
    private let cleanupDelay: TimeInterval

    init(fileManager: FileManager = .default, cleanupDelay: TimeInterval = 120) {
        self.fileManager = fileManager
        self.cleanupDelay = cleanupDelay
    }

    func deliver(_ request: IntegrationDeliveryRequest, to appURL: URL) async throws {
        guard IntegrationManifestCodec.supportedProtocolVersions.contains(request.protocolVersion) else {
            throw IntegrationTransportError.unsupportedProtocol(request.protocolVersion)
        }
        guard request.delivery.type == "openRequest" else {
            throw IntegrationTransportError.unsupportedDelivery(request.delivery.type)
        }
        guard request.files.allSatisfy({ $0.isFileURL && !$0.hasDirectoryPath }) else {
            throw IntegrationTransportError.invalidFiles
        }

        let directory = fileManager.temporaryDirectory.appendingPathComponent("HaloIntegrationRequests", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let requestURL = directory.appendingPathComponent(request.requestID.uuidString).appendingPathExtension("halorequest")

        let optionObject = request.options.mapValues(\.jsonObject)
        var payload: [String: Any] = [
            "protocolVersion": request.protocolVersion,
            "requestID": request.requestID.uuidString,
            "sourceBundleIdentifier": request.sourceBundleIdentifier,
            "action": request.actionID,
            "actionID": request.actionID,
            "options": optionObject
        ]
        if request.protocolVersion >= 2 { payload["delivery"] = ["type": request.delivery.type] }
        guard JSONSerialization.isValidJSONObject(payload) else { throw IntegrationTransportError.invalidOptions }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: requestURL, options: [.atomic])
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: requestURL.path)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                NSWorkspace.shared.open([requestURL] + request.files, withApplicationAt: appURL, configuration: configuration) { _, error in
                    if let error { continuation.resume(throwing: IntegrationTransportError.launchFailed(error.localizedDescription)) }
                    else { continuation.resume(returning: ()) }
                }
            }
        } catch {
            try? fileManager.removeItem(at: requestURL)
            throw error
        }

        let cleanupURL = requestURL
        let delay = cleanupDelay
        Task.detached(priority: .utility) {
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            try? FileManager.default.removeItem(at: cleanupURL)
        }
    }
}

private extension CIValue {
    var jsonObject: Any {
        switch self {
        case .string(let value): return value
        case .integer(let value): return value
        case .double(let value): return value
        case .boolean(let value): return value
        case .stringArray(let value): return value
        case .integerArray(let value): return value
        case .doubleArray(let value): return value
        }
    }
}
