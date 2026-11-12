import SwiftUI

struct TouchpadNotchSettingsView: View {
    @ObservedObject private var service = TouchpadNotchService.shared
    @ObservedObject private var ci = HaloCustomCIRuntimeStore.shared
    @ObservedObject private var access = HaloFeatureAccess.shared

    var body: some View {
        Section("Touchpad Notch") {
            Text("Hold a saved spot on your touchpad to open or close Halo.")
            if HaloDistribution.current == .appStore {
                Text("System-wide touchpad spots are available in Halo’s direct-download edition.")
            } else {
                Toggle("Enable Touchpad Notch", isOn: $service.settings.enabled)
                Text(service.status).font(.caption).foregroundStyle(.secondary)
                if service.settings.enabled {
                    spotControls
                    Picker("Open", selection: $service.settings.destination) {
                        Text("Halo notch").tag(TouchpadNotchSettings.Destination.notch)
                        Text("Touchpad CI").tag(TouchpadNotchSettings.Destination.touchpadCI)
                    }
                    if service.settings.destination == .touchpadCI { ciControls }
                    duration("Hold to open", value: $service.settings.openHold)
                    duration("Hold to close", value: $service.settings.closeHold)
                    LabeledContent("Required pressure") {
                        Slider(value: $service.settings.minimumPressure, in: 0...1, step: 0.05)
                        Text(service.settings.minimumPressure == 0 ? "Any" : "\(Int(service.settings.minimumPressure * 100))%")
                            .monospacedDigit().frame(width: 48)
                    }
                    LabeledContent("Reported pressure", value: service.pressure.map { "\(Int($0 * 100))%" } ?? "Not reported")
                    Text("Pressure uses Force Touch stage 1 events when macOS provides them. If no pressure is reported, a nonzero threshold prevents activation. Use Any for touch-only activation.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Haptic feedback when saved, opened or closed", isOn: $service.settings.haptics)
                    Text("Haptics require a compatible Force Touch trackpad. The spot does not block normal pointer movement or clicks; multi-finger gestures do not activate it.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Retry touchpad connection") { service.sync() }
                }
            }
        }
        .onDisappear { service.cancelRecording() }
    }

    private var spotControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.1))
                    RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.3))
                    if service.settings.hasSpot || service.recording {
                        let x = service.recording ? service.liveX : service.settings.x
                        let y = service.recording ? service.liveY : service.settings.y
                        Ellipse().fill(Color.accentColor.opacity(0.25))
                            .frame(width: geometry.size.width * service.settings.radius * 2,
                                   height: geometry.size.height * service.settings.radius * 2)
                            .overlay(Image(systemName: "hand.point.up.fill").foregroundStyle(Color.accentColor))
                            .position(x: x * geometry.size.width, y: (1 - y) * geometry.size.height)
                    }
                }.clipped()
            }.frame(width: 320, height: 180)
                .accessibilityLabel(service.settings.hasSpot ? "Saved touchpad spot" : "No touchpad spot saved")
            HStack {
                Button(service.recording ? "Recording…" : service.settings.hasSpot ? "Record a new spot" : "Record spot") { service.recordSpot() }
                    .disabled(service.recording)
                if service.recording { Button("Cancel") { service.cancelRecording() } }
            }
            Text("Click Record, lift your hand, then hold one finger still at the desired physical spot for one second. Recording ends after 15 seconds. The saved spot belongs to that touchpad.")
                .font(.caption).foregroundStyle(.secondary)
            LabeledContent("Spot size") {
                Slider(value: $service.settings.radius, in: 0.02...0.25, step: 0.01)
                Text("\(Int(service.settings.radius * 200))% wide").monospacedDigit()
            }
        }
    }

    @ViewBuilder private var ciControls: some View {
        if !access.allows(.customCI) {
            Text("Touchpad CI requires Halo Full.").foregroundStyle(.secondary)
        } else {
            Button(ci.package(id: TouchpadNotchService.packageID) == nil ? "Install Touchpad CI" : "Update Touchpad CI") { service.installCI() }
            if ci.package(id: TouchpadNotchService.packageID) != nil {
                Toggle("Enable Touchpad CI", isOn: Binding(get: { ci.isEnabled(TouchpadNotchService.packageID) }, set: { ci.setEnabled($0, packageID: TouchpadNotchService.packageID) }))
                ForEach(["Media.ReadState", "Media.Control"], id: \.self) { permission in
                    Toggle(permission == "Media.Control" ? "Allow media controls" : "Allow media information", isOn: Binding(
                        get: { ci.grantedPermissions(TouchpadNotchService.packageID).contains(permission) },
                        set: { ci.setPermission(permission, granted: $0, packageID: TouchpadNotchService.packageID) }))
                }
            }
            Text("Media controls use the normal Custom CI permission and priority system. Custom CI must be enabled in Context Notch Interface settings.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = ci.errorMessage { Text(error).foregroundStyle(.red) }
        }
    }

    private func duration(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            Slider(value: value, in: 0.1...5, step: 0.1)
            Text(String(format: "%.1f s", value.wrappedValue)).monospacedDigit().frame(width: 48)
        }
    }
}
