import SwiftUI

@MainActor
struct UpdateAnimationSettingsView: View {
    private let updates = HaloUpdateController.shared

    @AppStorage("HaloUpdateAnimationStyle") private var updateAnimationStyle = "Edge Fill"
    @AppStorage("HaloUpdateAnimationIntensity") private var updateAnimationIntensity = "Balanced"
    @AppStorage("HaloUpdateProgressPresentation") private var updateProgressPresentation = "Bottom Edge"
    @AppStorage("HaloUpdateAnimationSpeed") private var updateAnimationSpeed = 1.0
    @AppStorage("HaloUpdateGlowStrength") private var updateGlowStrength = 0.45
    @AppStorage("HaloUpdateProgressThickness") private var updateProgressThickness = 2.0
    @AppStorage("HaloUpdateShowPercentage") private var updateShowPercentage = true
    @AppStorage("HaloUpdateShowVersion") private var updateShowVersion = true
    @AppStorage("HaloUpdateShowStatus") private var updateShowStatus = true
    @AppStorage("HaloUpdateShowDownloadedSize") private var updateShowDownloadedSize = false
    @AppStorage("HaloUpdateShowDownloadSpeed") private var updateShowDownloadSpeed = false
    @AppStorage("HaloUpdateShowETA") private var updateShowETA = false
    @AppStorage("HaloUpdateSoundsEnabled") private var updateSoundsEnabled = true
    @AppStorage("HaloUpdateSoundVolume") private var updateSoundVolume = 0.55

    @State private var previewProgress = 0.42
    @State private var previewPhase = "Downloading"

    var body: some View {
        Section("Presentation") {
            Text("Customize how update progress is presented through Halo's notch. Sparkle still owns the real download, verification, installation, and relaunch process.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Style", selection: $updateAnimationStyle) {
                ForEach(["Minimal", "Edge Fill", "Energy", "Particles", "Liquid", "Portal", "Digital", "Circuit", "None"], id: \.self) { Text($0).tag($0) }
            }
            Picker("Intensity", selection: $updateAnimationIntensity) {
                ForEach(["Subtle", "Balanced", "Expressive"], id: \.self) { Text($0).tag($0) }
            }
            Picker("Progress presentation", selection: $updateProgressPresentation) {
                ForEach(["Bottom Edge", "Full Perimeter", "Inside Fill", "Ring", "Segments", "Particles", "Percentage Only", "Hidden"], id: \.self) { Text($0).tag($0) }
            }
        }

        Section("Motion & Glow") {
            LabeledContent("Animation speed") {
                Slider(value: $updateAnimationSpeed, in: 0.5...2.0, step: 0.05).frame(width: 220)
                Text("\(updateAnimationSpeed, specifier: "%.2f")×").monospacedDigit().frame(width: 52, alignment: .trailing)
            }
            LabeledContent("Glow strength") {
                Slider(value: $updateGlowStrength, in: 0...1, step: 0.05).frame(width: 220)
                Text("\(Int(updateGlowStrength * 100))%").monospacedDigit().frame(width: 52, alignment: .trailing)
            }
            LabeledContent("Progress thickness") {
                Slider(value: $updateProgressThickness, in: 1...8, step: 0.5).frame(width: 220)
                Text("\(updateProgressThickness, specifier: "%.1f") pt").monospacedDigit().frame(width: 62, alignment: .trailing)
            }
        }

        Section("Progress Information") {
            Toggle("Show percentage", isOn: $updateShowPercentage)
            Toggle("Show version", isOn: $updateShowVersion)
            Toggle("Show current phase", isOn: $updateShowStatus)
            Toggle("Show downloaded / total size", isOn: $updateShowDownloadedSize)
            Toggle("Show download speed", isOn: $updateShowDownloadSpeed)
            Toggle("Show estimated time", isOn: $updateShowETA)
        }

        Section("Sounds") {
            Toggle("Enable update sounds", isOn: $updateSoundsEnabled)
            LabeledContent("Volume") {
                Slider(value: $updateSoundVolume, in: 0...1, step: 0.05)
                    .frame(width: 220)
                    .disabled(!updateSoundsEnabled)
                Text("\(Int(updateSoundVolume * 100))%")
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
        }

        Section("Preview") {
            VStack(spacing: 10) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.black)
                        .frame(width: 360, height: 92)
                        .shadow(color: Color.accentColor.opacity(updateGlowStrength), radius: 18)

                    VStack(spacing: 4) {
                        if updateShowPercentage { Text("\(Int(previewProgress * 100))%").font(.title3.bold()).monospacedDigit() }
                        if updateShowStatus { Text(previewPhase).font(.caption).foregroundStyle(.secondary) }
                        if updateShowVersion { Text("Halo \(updates.currentVersion)").font(.caption2).foregroundStyle(.tertiary) }
                    }
                    .padding(.bottom, 14)

                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.accentColor.opacity(0.18))
                            .frame(height: updateProgressThickness)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: proxy.size.width * previewProgress, height: updateProgressThickness)
                            }
                    }
                    .frame(width: 330, height: updateProgressThickness)
                    .padding(.bottom, 5)
                }

                HStack {
                    Button("Download") {
                        previewPhase = "Downloading"
                        previewProgress = previewProgress >= 1 ? 0.08 : min(1, previewProgress + 0.18)
                    }
                    Button("Verify") { previewPhase = "Verifying"; previewProgress = 1 }
                    Button("Install") { previewPhase = "Installing"; previewProgress = 1 }
                    Button("Reset") { previewPhase = "Downloading"; previewProgress = 0.08 }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}
