import AppKit

extension CaptureService {
    var supportsSystemAudioRecording: Bool {
        if #available(macOS 15.0, *) { return true }
        return false
    }

    func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            updatePreferences { value in
                value.destination = .custom
                value.customFolderPath = url.path
            }
        }
    }

    func export(_ url: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        guard panel.runModal() == .OK, let target = panel.url else { return }
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: url, to: target)
            status = "Exported \(target.lastPathComponent)"
        } catch {
            self.error = error.localizedDescription
        }
    }
}
