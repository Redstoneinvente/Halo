import SwiftUI

/// Full Capture settings shared by the normal widget inspector and Visual Workspace inspector.
struct CaptureSettingsControls: View {
    @ObservedObject private var service = CaptureService.shared
    private var settings: HaloCapturePreferences { service.preferences }

    var body: some View {
        Section("Capture Modes") {
            Picker("Default screenshot", selection: binding(\.defaultMode)) {
                ForEach(HaloCaptureMode.allCases) { Text($0.rawValue).tag($0) }
            }
            Stepper("Delayed capture: \(settings.delaySeconds)s", value: binding(\.delaySeconds), in: 1...60)
            Stepper("Repeated captures: \(settings.repeatCount)", value: binding(\.repeatCount), in: 2...60)
            PreciseSlider(title: "Repeat interval", value: binding(\.repeatInterval), range: 0.25...60, step: 0.25, suffix: "s", decimals: 2)
            Text("Region and Window use macOS interactive selection. Display targets the display chosen in the Capture workspace; Full Screen uses the main display.")
                .font(.caption2).foregroundStyle(.secondary)
        }

        Section("Destination & Naming") {
            Picker("Destination", selection: binding(\.destination)) {
                ForEach(HaloCaptureDestination.allCases) { Text($0.rawValue).tag($0) }
            }
            if settings.destination == .custom {
                HStack {
                    TextField("Folder", text: binding(\.customFolderPath))
                    Button("Choose…") { service.chooseDestinationFolder() }
                }
            }
            TextField("Naming template", text: binding(\.namingTemplate))
            Text("Tokens: {app}, {date}, {time}, {seq}, {prefix}")
                .font(.caption2).foregroundStyle(.secondary)
            TextField("Prefix", text: binding(\.prefix))
            Picker("Image format", selection: binding(\.format)) {
                ForEach(HaloCaptureFormat.allCases) { Text($0.rawValue).tag($0) }
            }
            if settings.format == .jpeg || settings.format == .heic {
                PreciseSlider(title: "Quality", value: binding(\.quality), range: 0.2...1, step: 0.05, decimals: 2)
            }
        }

        Section("After Capture") {
            Toggle("Copy image to Clipboard", isOn: binding(\.copyAfterCapture))
            Toggle("Run OCR automatically", isOn: binding(\.ocrAfterCapture))
            Toggle("Copy OCR text", isOn: binding(\.copyOCRAfterRecognition))
            Toggle("Paste OCR text into active app", isOn: binding(\.pasteOCRAfterRecognition))
            Toggle("Add capture to Shelf", isOn: binding(\.addToShelfAfterCapture))
            Toggle("Capture to Note", isOn: binding(\.addToNotesAfterCapture))
            Toggle("Open after capture", isOn: binding(\.openAfterCapture))
            Text("Every Capture workspace action also mirrors the latest capture/OCR result into Halo Clipboard history for fast reuse.")
                .font(.caption2).foregroundStyle(.secondary)
        }

        Section("Screen Recording") {
            Toggle("System audio", isOn: binding(\.recordSystemAudio))
                .disabled(!service.supportsSystemAudioRecording)
            Toggle("Microphone", isOn: binding(\.recordMicrophone))
            Toggle("Show clicks", isOn: binding(\.showRecordingClicks))
            Stepper("Countdown: \(settings.recordCountdown)s", value: binding(\.recordCountdown), in: 0...10)
            Text(service.supportsSystemAudioRecording
                 ? "System audio uses ScreenCaptureKit and records a selected display. Region/window recording uses macOS's native recorder; microphone recording remains available there too."
                 : "System-audio file recording requires macOS 15 or newer. Region/window/display recording and microphone capture remain available through macOS's native recorder.")
                .font(.caption2).foregroundStyle(.secondary)
        }

        Section("Privacy & History") {
            Toggle("Never persist capture history", isOn: binding(\.neverStoreCaptures))
            TextField("Excluded bundle IDs", text: excludedAppsBinding)
            Text("Comma-separate apps Halo must refuse to capture. 1Password and Keychain Access are excluded by default.")
                .font(.caption2).foregroundStyle(.secondary)
            Stepper("History limit: \(settings.historyLimit)", value: binding(\.historyLimit), in: 10...250)
            Button("Clear Capture History") { service.clearHistory() }
            Text("Halo blocks configured sensitive source apps before capture. Generic notification redaction is not claimed because macOS does not expose a reliable semantic notification-window filter across every app.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<HaloCapturePreferences, T>) -> Binding<T> {
        Binding(
            get: { service.preferences[keyPath: keyPath] },
            set: { newValue in service.updatePreferences { $0[keyPath: keyPath] = newValue } }
        )
    }

    private var excludedAppsBinding: Binding<String> {
        Binding(
            get: { service.preferences.excludedBundleIDs.joined(separator: ", ") },
            set: { raw in
                service.updatePreferences { value in
                    value.excludedBundleIDs = raw.split(separator: ",").map {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        )
    }
}
