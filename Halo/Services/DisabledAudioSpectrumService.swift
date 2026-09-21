import Foundation

/// App Store fallback for Halo's system-wide audio spectrum service.
///
/// It deliberately exposes the same public surface used by Halo while performing
/// no capture, requesting no screen-recording permission, and always reporting
/// unavailable audio.
final class DisabledAudioSpectrumService: AudioSpectrumProviding {
    static let shared = DisabledAudioSpectrumService()

    private init() {}

    func snapshot() -> AudioSpectrumSnapshot {
        AudioSpectrumSnapshot()
    }

    func setActive(_ active: Bool) {
        // Intentionally disabled for App Store builds.
    }

    func setActive(_ active: Bool, owner: String) {
        // Preserve direct-build call sites without activating system audio.
    }

    func recognizeCurrentAudio(
        timeout: TimeInterval = 8,
        completion: @escaping (AudioRecognitionMatch?) -> Void
    ) {
        // System-audio recognition is unavailable in the App Store build.
        DispatchQueue.main.async {
            completion(nil)
        }
    }

    func cancelRecognition() {
        // No recognition session exists in the disabled implementation.
    }
}

#if HALO_APPSTORE
/// Preserve existing AudioSpectrumService.shared call sites in the App Store build
/// without compiling the ScreenCaptureKit-backed implementation.
typealias AudioSpectrumService = DisabledAudioSpectrumService
#endif
