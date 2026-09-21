import Foundation

/// Shared audio spectrum contract used by UI and CI components.
///
/// Direct builds provide the ScreenCaptureKit-backed implementation while App Store
/// builds provide a sandbox-safe disabled implementation.
protocol AudioSpectrumProviding: AnyObject {
    func snapshot() -> AudioSpectrumSnapshot
    func setActive(_ active: Bool)
}

extension AudioSpectrumProviding {
    func setActive(_ active: Bool) {}
}
