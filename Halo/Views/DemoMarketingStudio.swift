import SwiftUI
import AppKit

@MainActor
final class DemoMarketingStudio {
    static let shared = DemoMarketingStudio()

    static let enabledKey = "HaloMarketingDemoEnabled"
    static let titleKey = "HaloMarketingDemoTitle"
    static let artistKey = "HaloMarketingDemoArtist"
    static let playingKey = "HaloMarketingDemoPlaying"
    static let batteryKey = "HaloMarketingDemoBattery"
    static let chargingKey = "HaloMarketingDemoCharging"
    static let onBatteryKey = "HaloMarketingDemoOnBattery"
    static let lowPowerKey = "HaloMarketingDemoLowPower"

    private weak var workspace: WorkspaceStore?
    private var window: NSWindow?

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    private init() {
        UserDefaults.standard.register(defaults: [
            Self.enabledKey: false,
            Self.titleKey: "Neon Afterglow",
            Self.artistKey: "Luma Vale",
            Self.playingKey: true,
            Self.batteryKey: 78.0,
            Self.chargingKey: true,
            Self.onBatteryKey: false,
            Self.lowPowerKey: false
        ])
    }

    func attach(workspace: WorkspaceStore) {
        self.workspace = workspace
        show()
        if isEnabled { apply(to: workspace) }
    }

    func show() {
        guard let workspace else { return }
        if window == nil {
            let panel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 430, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.title = "Halo · Marketing Demo Studio"
            panel.contentMinSize = NSSize(width: 390, height: 560)
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: DemoMarketingView(workspace: workspace))
            panel.center()
            window = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func apply(to workspace: WorkspaceStore) {
        guard isEnabled else { return }
        let defaults = UserDefaults.standard
        workspace.media.title = defaults.string(forKey: Self.titleKey) ?? "Neon Afterglow"
        workspace.media.artist = defaults.string(forKey: Self.artistKey) ?? "Luma Vale"
        workspace.media.isPlaying = defaults.bool(forKey: Self.playingKey)
        workspace.media.error = nil

        workspace.system.battery = Int(defaults.double(forKey: Self.batteryKey).rounded())
        workspace.system.charging = defaults.bool(forKey: Self.chargingKey)
        workspace.system.onBattery = defaults.bool(forKey: Self.onBatteryKey)
        workspace.system.lowPower = defaults.bool(forKey: Self.lowPowerKey)
    }

    func clear(from workspace: WorkspaceStore) {
        workspace.media.disconnect()
        workspace.system.refresh()
    }
}

@MainActor
private struct DemoMarketingView: View {
    @ObservedObject var workspace: WorkspaceStore

    @AppStorage(DemoMarketingStudio.enabledKey) private var enabled = false
    @AppStorage(DemoMarketingStudio.titleKey) private var title = "Neon Afterglow"
    @AppStorage(DemoMarketingStudio.artistKey) private var artist = "Luma Vale"
    @AppStorage(DemoMarketingStudio.playingKey) private var playing = true
    @AppStorage(DemoMarketingStudio.batteryKey) private var battery = 78.0
    @AppStorage(DemoMarketingStudio.chargingKey) private var charging = true
    @AppStorage(DemoMarketingStudio.onBatteryKey) private var onBattery = false
    @AppStorage(DemoMarketingStudio.lowPowerKey) private var lowPower = false

    @State private var activityTitle = "Focus Session"
    @State private var activityDetail = "Deep work · 18 min remaining"
    @State private var activityProgress = 0.64
    @State private var hudValue = 0.72

    var body: some View {
        Form {
            Section("Marketing Demo") {
                Toggle("Enable dummy data", isOn: $enabled)
                    .onChange(of: enabled) { value in
                        if value { apply() }
                        else { DemoMarketingStudio.shared.clear(from: workspace) }
                    }
                Text("This panel exists only on the Demo branch. It freezes selected app data so you can compose repeatable screenshots without depending on live services.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Music") {
                TextField("Track title", text: $title)
                TextField("Artist", text: $artist)
                Toggle("Playing", isOn: $playing)
                HStack {
                    Button("Hero preset") {
                        title = "Neon Afterglow"
                        artist = "Luma Vale"
                        playing = true
                        apply()
                    }
                    Button("Ambient preset") {
                        title = "Glass Horizon"
                        artist = "Aster & Co."
                        playing = true
                        apply()
                    }
                    Button("Paused") {
                        playing = false
                        apply()
                    }
                }
                Button("Apply music data") { apply() }
            }

            Section("System") {
                HStack {
                    Text("Battery")
                    Spacer()
                    Text("\(Int(battery.rounded()))%").monospacedDigit().foregroundStyle(.secondary)
                }
                SwiftUI.Slider(value: $battery, in: 1...100, step: 1)
                    .onChange(of: battery) { _ in apply() }
                Toggle("Charging", isOn: $charging).onChange(of: charging) { _ in apply() }
                Toggle("On battery power", isOn: $onBattery).onChange(of: onBattery) { _ in apply() }
                Toggle("Low Power Mode", isOn: $lowPower).onChange(of: lowPower) { _ in apply() }
                HStack {
                    Button("Charging 78%") {
                        battery = 78; charging = true; onBattery = false; lowPower = false; apply()
                    }
                    Button("Low battery 18%") {
                        battery = 18; charging = false; onBattery = true; lowPower = true; apply()
                    }
                }
            }

            Section("Live Activity") {
                TextField("Title", text: $activityTitle)
                TextField("Detail", text: $activityDetail)
                HStack {
                    Text("Progress")
                    Spacer()
                    Text("\(Int(activityProgress * 100))%").monospacedDigit().foregroundStyle(.secondary)
                }
                SwiftUI.Slider(value: $activityProgress, in: 0...1)
                HStack {
                    Button("Show activity") {
                        workspace.publish(activityTitle, detail: activityDetail, progress: activityProgress)
                    }
                    Button("Clear") { workspace.activities = [] }
                }
            }

            Section("HUD shots") {
                HStack {
                    Text("Preview value")
                    Spacer()
                    Text("\(Int(hudValue * 100))%").monospacedDigit().foregroundStyle(.secondary)
                }
                SwiftUI.Slider(value: $hudValue, in: 0...1)
                HStack {
                    Button("Volume") { previewHUD("volume") }
                    Button("Brightness") { previewHUD("displayBrightness") }
                    Button("Keyboard") { previewHUD("keyboardBrightness") }
                }
                HStack {
                    Button("Battery") { previewHUD("batteryStatus") }
                    Button("Charging") { previewHUD("chargingState") }
                    Button("Media") { previewHUD("mediaChanged") }
                }
            }

            Section("Capture controls") {
                HStack {
                    Button("Toggle Halo") {
                        NotificationCenter.default.post(name: .init("HaloToggle"), object: nil)
                    }
                    Button("Open Settings") {
                        NotificationCenter.default.post(name: .init("HaloOpenSettings"), object: nil)
                    }
                }
                Button("Apply everything now") { apply() }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 390, minHeight: 560)
        .onAppear { if enabled { apply() } }
        .onChange(of: title) { _ in if enabled { apply() } }
        .onChange(of: artist) { _ in if enabled { apply() } }
        .onChange(of: playing) { _ in if enabled { apply() } }
    }

    private func apply() {
        guard enabled else { return }
        DemoMarketingStudio.shared.apply(to: workspace)
    }

    private func previewHUD(_ kind: String) {
        NotificationCenter.default.post(
            name: .init("HaloHUDPreview"),
            object: nil,
            userInfo: ["kind": kind, "value": hudValue]
        )
    }
}
