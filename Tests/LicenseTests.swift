import XCTest
import CryptoKit
#if SWIFT_PACKAGE
@testable import HaloCore
#endif

final class LicenseTests: XCTestCase {
    func testPerpetualLicenseVerifiesOffline() throws {
        let key = Curve25519.Signing.PrivateKey()
        let claims = LicenseClaims(version: 1, product: "Halo", licenseID: "test", features: ["pro"], expiresAt: nil)
        let payload = try JSONEncoder().encode(claims)
        let license = SignedLicense(payload: payload, signature: try key.signature(for: payload))
        XCTAssertEqual(try license.verified(publicKey: key.publicKey.rawRepresentation), claims)
    }
    func testTamperedLicenseFails() throws {
        let key = Curve25519.Signing.PrivateKey()
        let payload = Data("original".utf8)
        let license = SignedLicense(payload: Data("changed".utf8), signature: try key.signature(for: payload))
        XCTAssertThrowsError(try license.verified(publicKey: key.publicKey.rawRepresentation))
    }
    func testExpiredLicenseFails() throws {
        let key = Curve25519.Signing.PrivateKey()
        let claims = LicenseClaims(version: 1, product: "Halo", licenseID: "expired", features: [], expiresAt: Date(timeIntervalSince1970: 0))
        let payload = try JSONEncoder().encode(claims)
        let license = SignedLicense(payload: payload, signature: try key.signature(for: payload))
        XCTAssertThrowsError(try license.verified(publicKey: key.publicKey.rawRepresentation))
    }
}
