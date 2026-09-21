import Foundation

/// App Store fallback for Halo's system-wide audio spectrum service.
///
/// It deliberately exposes the same shared contract while performing no capture,
/// requesting no screen-recording permission, and always reporting unavailable audio.
final class DisabledAudioSpectrumService: AudioSpectrumProviding {
    static let shared = DisabledAudioSpectrumService()

    private init() {}

    func snapshot() -> AudioSpectrumSnapshot {
        AudioSpectrumSnapshot()
    }

    func setActive(_ active: Bool) {
        // Intentionally disabled for App Store builds.
    }
}

#if HALO_APPSTORE
/// Preserve existing AudioSpectrumService.shared call sites in the App Store build
/// without compiling the ScreenCaptureKit-backed implementation.
typealias AudioSpectrumService = DisabledAudioSpectrumService
#endif
