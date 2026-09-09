import Foundation
import CryptoKit

/// Providers are deliberately not instantiated or networked by the core app.
struct WeatherSnapshot: Sendable { var temperatureCelsius: Double; var condition: String; var updated: Date }
protocol WeatherProvider { func forecast(latitude: Double, longitude: Double) async throws -> WeatherSnapshot }
protocol AIActionProvider {
    var disclosure: String { get }
    var isOnDevice: Bool { get }
    /// The caller must obtain explicit consent with the exact content and destination before invoking this method.
    func transform(text: String, instruction: String) async throws -> String
}
protocol NotchCommand { var id: String { get }; var title: String { get }; @MainActor func execute() }
protocol AutomationTrigger { var id: String { get }; func matches(context: [String: String]) -> Bool }
protocol AutomationAction { var id: String { get }; @MainActor func perform() }

struct LicenseClaims: Codable, Equatable {
    var version: Int
    var product: String
    var licenseID: String
    var features: [String]
    /// nil is a perpetual entitlement; verification has no server dependency.
    var expiresAt: Date?
}
struct SignedLicense: Codable {
    var payload: Data
    var signature: Data
    func verified(publicKey: Data, now: Date = Date()) throws -> LicenseClaims {
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        guard key.isValidSignature(signature, for: payload) else { throw CocoaError(.fileReadCorruptFile) }
        let claims = try JSONDecoder().decode(LicenseClaims.self, from: payload)
        guard claims.version == 1, claims.product == "Halo", !claims.licenseID.isEmpty,
              claims.expiresAt.map({ $0 > now }) ?? true else { throw CocoaError(.fileReadCorruptFile) }
        return claims
    }
}
