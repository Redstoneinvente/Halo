import Foundation

/// App Store fallback implementation.
///
/// The direct distribution can use ScreenCaptureKit based audio capture, while
/// App Store builds can provide this implementation when system audio capture is
/// unavailable or intentionally excluded.
final class DisabledAudioSpectrumService {
    static let shared = DisabledAudioSpectrumService()

    private init() {}

    func snapshot() -> AudioSpectrumSnapshot {
        AudioSpectrumSnapshot()
    }

    func setActive(_ active: Bool) {
        // Intentionally disabled.
    }
}
