import AppKit
import Vision
import CoreGraphics

@MainActor
final class CaptureService: ObservableObject {
    @Published var busy = false
    @Published var recognizedText = ""
    @Published var error: String?
    func capture(completion: @escaping (URL) -> Void) {
        guard !busy else { return }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            error = "Allow Screen Recording in System Settings, then relaunch Halo if macOS requests it."; return
        }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.png]; panel.nameFieldStringValue = "Halo-\(Int(Date().timeIntervalSince1970)).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        busy = true
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-x", "-t", "png", url.path]
        task.terminationHandler = { [weak self] task in
            Task { @MainActor in
                self?.busy = false
                if task.terminationStatus == 0, FileManager.default.fileExists(atPath: url.path) { completion(url) }
            }
        }
        do { try task.run() } catch { busy = false; self.error = error.localizedDescription }
    }
    func recognize(_ url: URL) {
        guard !busy else { return }; busy = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
                try VNImageRequestHandler(url: url, options: [:]).perform([request])
                let text = request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") ?? ""
                Task { @MainActor in self?.recognizedText = text; self?.busy = false }
            } catch { Task { @MainActor in self?.error = error.localizedDescription; self?.busy = false } }
        }
    }
    func chooseImage() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url { recognize(url) }
    }
}
