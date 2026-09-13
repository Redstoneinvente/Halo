from pathlib import Path

ROOT = Path('.')

update_manager = r'''import Foundation
import AppKit
import Combine
import Sparkle

@MainActor
final class HaloUpdateManager: NSObject, ObservableObject {
    static let shared = HaloUpdateManager()

    @Published private(set) var isConfigured = false
    @Published private(set) var configurationMessage = ""
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    @Published private(set) var sendsSystemProfile = false
    @Published private(set) var updateCheckInterval: TimeInterval = 86_400
    @Published private(set) var lastUpdateCheckDate: Date?

    private let controller: SPUStandardUpdaterController
    private var started = false

    private override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        evaluateConfiguration()
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    var feedURLString: String {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
    }

    var feedHost: String? {
        URL(string: feedURLString)?.host
    }

    func start() {
        evaluateConfiguration()
        guard isConfigured, !started else {
            refresh()
            return
        }
        controller.startUpdater()
        started = true
        refresh()
    }

    func refresh() {
        guard started else { return }
        let updater = controller.updater
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        sendsSystemProfile = updater.sendsSystemProfile
        updateCheckInterval = updater.updateCheckInterval
        lastUpdateCheckDate = updater.lastUpdateCheckDate
    }

    func checkForUpdates() {
        guard isConfigured else {
            let alert = NSAlert()
            alert.messageText = "Updates are not configured in this build"
            alert.informativeText = configurationMessage
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        if !started { start() }
        controller.checkForUpdates(nil)
        refresh()
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        guard started else { return }
        controller.updater.automaticallyChecksForUpdates = enabled
        refresh()
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        guard started else { return }
        controller.updater.automaticallyDownloadsUpdates = enabled
        refresh()
    }

    func setSendsSystemProfile(_ enabled: Bool) {
        guard started else { return }
        controller.updater.sendsSystemProfile = enabled
        refresh()
    }

    func setUpdateCheckInterval(_ interval: TimeInterval) {
        guard started else { return }
        controller.updater.updateCheckInterval = max(3_600, interval)
        refresh()
    }

    private func evaluateConfiguration() {
        let feed = feedURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let hasFeed = URL(string: feed)?.scheme?.lowercased() == "https"
        let hasKey = key.count >= 32 && !key.contains("$(")
        isConfigured = hasFeed && hasKey

        switch (hasFeed, hasKey) {
        case (true, true):
            configurationMessage = "Halo updates are signed and ready."
        case (false, false):
            configurationMessage = "Set Halo's HTTPS Sparkle appcast URL and HALO_SPARKLE_PUBLIC_KEY before shipping."
        case (false, true):
            configurationMessage = "Set a valid HTTPS SUFeedURL before shipping."
        case (true, false):
            configurationMessage = "Sparkle is integrated, but this build still needs Halo's Ed25519 public update key. Generate it locally with Sparkle's generate_keys tool and set HALO_SPARKLE_PUBLIC_KEY in Secrets.xcconfig."
        }
    }
}

@MainActor
struct HaloUpdateSettingsView: View {
    @ObservedObject private var updater = HaloUpdateManager.shared

    private let intervals: [(String, TimeInterval)] = [
        ("Daily", 86_400),
        ("Every 3 days", 259_200),
        ("Weekly", 604_800)
    ]

    var body: some View {
        Section("Halo Updates") {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Halo \(updater.currentVersion)").font(.headline)
                    Text("Build \(updater.currentBuild)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.isConfigured)
            }

            if updater.isConfigured {
                Label("Sparkle 2 updater ready", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Publishing setup incomplete", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(updater.configurationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Automatic Updates") {
            Toggle("Automatically check for updates", isOn: Binding(
                get: { updater.automaticallyChecksForUpdates },
                set: { updater.setAutomaticallyChecksForUpdates($0) }
            ))
            .disabled(!updater.isConfigured)

            Toggle("Automatically download and install updates", isOn: Binding(
                get: { updater.automaticallyDownloadsUpdates },
                set: { updater.setAutomaticallyDownloadsUpdates($0) }
            ))
            .disabled(!updater.isConfigured || !updater.automaticallyChecksForUpdates)

            Picker("Check frequency", selection: Binding(
                get: { closestInterval(updater.updateCheckInterval) },
                set: { updater.setUpdateCheckInterval($0) }
            )) {
                ForEach(intervals, id: \.1) { label, interval in
                    Text(label).tag(interval)
                }
            }
            .disabled(!updater.isConfigured || !updater.automaticallyChecksForUpdates)

            if let date = updater.lastUpdateCheckDate {
                LabeledContent("Last checked") {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            } else {
                LabeledContent("Last checked") { Text("Not yet").foregroundStyle(.secondary) }
            }
        }

        Section("Release Notes") {
            Button { HaloWhatsNewCoordinator.shared.present() } label: {
                Label("What's New in Halo", systemImage: "sparkles.rectangle.stack")
            }
            Text("Halo shows its own What's New experience once after the installed app version changes. Sparkle also shows version-specific release notes when an update is available.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Privacy & Security") {
            Toggle("Send anonymous system profile with update checks", isOn: Binding(
                get: { updater.sendsSystemProfile },
                set: { updater.setSendsSystemProfile($0) }
            ))
            .disabled(!updater.isConfigured)
            Text("Off by default. Updates are delivered over HTTPS and must be signed with Halo's Sparkle Ed25519 key before Sparkle will install them. Halo does not use update checks for analytics.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { updater.start(); updater.refresh() }
    }

    private func closestInterval(_ value: TimeInterval) -> TimeInterval {
        intervals.min(by: { abs($0.1 - value) < abs($1.1 - value) })?.1 ?? 86_400
    }
}
'''

whats_new = r'''import SwiftUI
import AppKit

private struct HaloReleaseHighlight: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
    let accent: Color
}

private struct HaloReleaseStory {
    let version: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let highlights: [HaloReleaseHighlight]

    static func forCurrentBuild() -> HaloReleaseStory {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        if version == "0.2.0" {
            return HaloReleaseStory(
                version: version,
                eyebrow: "HALO \(version)",
                title: "Your notch feels more alive.",
                subtitle: "A more expressive workspace, richer ambient detail, smarter adaptive surfaces, and now a secure update system built into Halo.",
                highlights: [
                    .init(symbol: "rectangle.3.group.bubble", title: "Visual Workspace, refined", detail: "Adaptive widget layouts and stronger presets make the opened notch feel intentionally composed at every footprint.", accent: .cyan),
                    .init(symbol: "sparkles", title: "Notch Ambient", detail: "Turn the inactive notch into a subtle decorative canvas with geometry-aware ambient treatments.", accent: .purple),
                    .init(symbol: "power.circle", title: "Activation Sequence", detail: "Halo can now wake up with a polished startup signature before handing control to the normal notch.", accent: .orange),
                    .init(symbol: "arrow.triangle.2.circlepath.circle.fill", title: "Updates, built in", detail: "Sparkle 2 handles secure update checks, release notes, automatic downloads, and smooth in-place upgrades.", accent: .green)
                ]
            )
        }
        return HaloReleaseStory(
            version: version,
            eyebrow: "HALO \(version)",
            title: "Halo just got better.",
            subtitle: "This release brings a new round of polish, fixes, and improvements across your notch experience.",
            highlights: [
                .init(symbol: "wand.and.stars", title: "Refined experience", detail: "The things you use every day have been tuned for clarity, responsiveness, and visual consistency.", accent: .purple),
                .init(symbol: "gauge.with.dots.needle.67percent", title: "Performance work", detail: "Background work stays restrained so Halo can remain present without becoming demanding.", accent: .cyan),
                .init(symbol: "checkmark.seal.fill", title: "Quality fixes", detail: "This build includes reliability and compatibility improvements throughout Halo.", accent: .green)
            ]
        )
    }
}

@MainActor
final class HaloWhatsNewCoordinator {
    static let shared = HaloWhatsNewCoordinator()

    private let defaults = UserDefaults.standard
    private let lastSeenKey = "HaloWhatsNewLastSeenVersion"
    private var window: NSWindow?
    private var checkedThisLaunch = false

    private init() {}

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func presentIfNeeded() {
        guard !checkedThisLaunch else { return }
        checkedThisLaunch = true

        let current = currentVersion
        let previous = defaults.string(forKey: lastSeenKey)
        if previous == current { return }

        if previous == nil {
            let looksLikeExistingInstall = defaults.object(forKey: "HaloSetupCompletedV1") != nil ||
                defaults.object(forKey: "onboarded") != nil
            if !looksLikeExistingInstall {
                defaults.set(current, forKey: lastSeenKey)
                return
            }
        }

        present()
    }

    func present() {
        defaults.set(currentVersion, forKey: lastSeenKey)
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "What's New in Halo"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.contentMinSize = NSSize(width: 660, height: 600)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: HaloWhatsNewView { [weak self, weak window] in
            window?.close()
            self?.window = nil
        })
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct HaloWhatsNewView: View {
    let onDone: () -> Void
    private let story = HaloReleaseStory.forCurrentBuild()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.03, blue: 0.075),
                    Color(red: 0.105, green: 0.045, blue: 0.18),
                    Color(red: 0.02, green: 0.095, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.purple.opacity(0.20))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: 260, y: -260)
            Circle()
                .fill(Color.cyan.opacity(0.14))
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: -300, y: 260)

            ScrollView {
                VStack(spacing: 26) {
                    hero
                    highlights
                    footer
                }
                .padding(.horizontal, 38)
                .padding(.top, 42)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.white.opacity(0.08)).frame(width: 112, height: 112)
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 1).frame(width: 112, height: 112)
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().scaledToFit()
                    .frame(width: 82, height: 82)
                    .shadow(color: .purple.opacity(0.5), radius: 28)
            }
            Text(story.eyebrow)
                .font(.caption.weight(.bold))
                .tracking(2.2)
                .foregroundStyle(Color.white.opacity(0.62))
            Text(story.title)
                .font(.system(size: 35, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(story.subtitle)
                .font(.title3)
                .foregroundStyle(Color.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 610)
        }
    }

    private var highlights: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(story.highlights) { item in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(item.accent)
                        .frame(width: 38, height: 38)
                        .background(item.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title).font(.headline)
                        Text(item.detail)
                            .font(.callout)
                            .foregroundStyle(Color.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(17)
                .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08)))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button { HaloUpdateManager.shared.checkForUpdates() } label: {
                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
            Spacer()
            Text("Thanks for using Halo.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.48))
            Spacer()
            Button("Continue") { onDone() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.top, 2)
    }
}
'''

Path('Halo/Services/UpdateManager.swift').write_text(update_manager)
Path('Halo/Views/WhatsNewView.swift').write_text(whats_new)

# Info.plist Sparkle defaults.
plist_path = Path('Halo/Info.plist')
plist = plist_path.read_text()
anchor = '\t<key>HaloFirebaseAPIKey</key>\n'
insert = '''\t<key>SUFeedURL</key>\n\t<string>https://halo.redstoneinvente.com/appcast.xml</string>\n\t<key>SUPublicEDKey</key>\n\t<string>$(HALO_SPARKLE_PUBLIC_KEY)</string>\n\t<key>SUEnableAutomaticChecks</key>\n\t<true/>\n\t<key>SUAllowsAutomaticUpdates</key>\n\t<true/>\n\t<key>SUAutomaticallyUpdate</key>\n\t<false/>\n\t<key>SUScheduledCheckInterval</key>\n\t<real>86400</real>\n\t<key>SUShowReleaseNotes</key>\n\t<true/>\n'''
if 'SUFeedURL' not in plist:
    plist = plist.replace(anchor, insert + anchor)
plist_path.write_text(plist)

# Public key belongs in ignored Secrets.xcconfig, never in Git.
config_path = Path('Halo/Config/Base.xcconfig')
config = config_path.read_text()
if 'HALO_SPARKLE_PUBLIC_KEY' not in config:
    config = config.replace('HALO_LICENSESEAT_PRODUCT_SLUG = halo-macos-notch-utility\n', 'HALO_LICENSESEAT_PRODUCT_SLUG = halo-macos-notch-utility\nHALO_SPARKLE_PUBLIC_KEY =\n')
config_path.write_text(config)

# App lifecycle + status menu.
app_path = Path('Halo/App/HaloApp.swift')
app = app_path.read_text()
app = app.replace('    let store = AppStore()\n', '    let store = AppStore()\n    private let updater = HaloUpdateManager.shared\n    private let whatsNew = HaloWhatsNewCoordinator.shared\n', 1)
app = app.replace('        NSApp.setActivationPolicy(.accessory)\n', '        NSApp.setActivationPolicy(.accessory)\n        updater.start()\n', 1)
settings_block = '''        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")\n        settingsItem.target = self\n        menu.addItem(settingsItem)\n'''
menu_insert = settings_block + '''\n        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")\n        updateItem.target = self\n        menu.addItem(updateItem)\n        let whatsNewItem = NSMenuItem(title: "What's New…", action: #selector(showWhatsNew), keyEquivalent: "")\n        whatsNewItem.target = self\n        menu.addItem(whatsNewItem)\n'''
app = app.replace(settings_block, menu_insert, 1)
app = app.replace('            presentSetupIfNeeded()\n', '            presentSetupIfNeeded()\n            if setupWindow == nil { whatsNew.presentIfNeeded() }\n', 1)
app = app.replace('            self.setupWindow = nil\n        })\n', '            self.setupWindow = nil\n            self.whatsNew.presentIfNeeded()\n        })\n', 1)
app = app.replace('    @objc private func toggle() { engine?.toggleAll() }\n', '    @objc private func toggle() { engine?.toggleAll() }\n    @objc private func checkForUpdates() { updater.checkForUpdates() }\n    @objc private func showWhatsNew() { whatsNew.present() }\n', 1)
app_path.write_text(app)

# Settings destination.
settings_path = Path('Halo/Views/WorkspaceSettingsView.swift')
settings = settings_path.read_text()
settings = settings.replace('"Plugins", "Privacy", "About"]', '"Plugins", "Updates", "Privacy", "About"]', 1)
settings = settings.replace('        case "Privacy": return "hand.raised"\n', '        case "Updates": return "arrow.triangle.2.circlepath"\n        case "Privacy": return "hand.raised"\n', 1)
settings = settings.replace('        case "Plugins":\n', '        case "Updates": HaloUpdateSettingsView()\n        case "Plugins":\n', 1)
settings_path.write_text(settings)

# Xcode project: two Swift sources + Sparkle 2.9.6 package product.
pbx_path = Path('Halo.xcodeproj/project.pbxproj')
pbx = pbx_path.read_text()

BF_UPDATE = 'A11C0F1A0000000000000331'
FR_UPDATE = 'A11C0F1A0000000000000332'
BF_WHATS = 'A11C0F1A0000000000000333'
FR_WHATS = 'A11C0F1A0000000000000334'
BF_SPARKLE = 'A11C0F1A0000000000000341'
PROD_SPARKLE = 'A11C0F1A0000000000000342'
PKG_SPARKLE = 'A11C0F1A0000000000000343'

if FR_UPDATE not in pbx:
    pbx = pbx.replace('/* End PBXBuildFile section */', f'''\t\t{BF_UPDATE} /* Services/UpdateManager.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_UPDATE} /* Services/UpdateManager.swift */; }};\n\t\t{BF_WHATS} /* Views/WhatsNewView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_WHATS} /* Views/WhatsNewView.swift */; }};\n\t\t{BF_SPARKLE} /* Sparkle in Frameworks */ = {{isa = PBXBuildFile; productRef = {PROD_SPARKLE} /* Sparkle */; }};\n/* End PBXBuildFile section */''', 1)
    pbx = pbx.replace('/* End PBXFileReference section */', f'''\t\t{FR_UPDATE} /* Services/UpdateManager.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Services/UpdateManager.swift; sourceTree = "<group>"; }};\n\t\t{FR_WHATS} /* Views/WhatsNewView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Views/WhatsNewView.swift; sourceTree = "<group>"; }};\n/* End PBXFileReference section */''', 1)
    pbx = pbx.replace('\t\t\tfiles = (\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n\t\t000000000000000000000018 /* Frameworks */', f'''\t\t\tfiles = (\n\t\t\t\t{BF_SPARKLE} /* Sparkle in Frameworks */,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n\t\t000000000000000000000018 /* Frameworks */''', 1)
    pbx = pbx.replace('\t\t\t\t00000000000000000000006D /* Services/Integrations.swift */,\n', f'''\t\t\t\t00000000000000000000006D /* Services/Integrations.swift */,\n\t\t\t\t{FR_UPDATE} /* Services/UpdateManager.swift */,\n\t\t\t\t{FR_WHATS} /* Views/WhatsNewView.swift */,\n''', 1)
    pbx = pbx.replace('\t\t\tdependencies = (\n\t\t\t);\n\t\t\tname = Halo;\n', f'''\t\t\tdependencies = (\n\t\t\t);\n\t\t\tpackageProductDependencies = (\n\t\t\t\t{PROD_SPARKLE} /* Sparkle */,\n\t\t\t);\n\t\t\tname = Halo;\n''', 1)
    pbx = pbx.replace('\t\t\tproductRefGroup = 000000000000000000000004 /* Products */;\n', f'''\t\t\tproductRefGroup = 000000000000000000000004 /* Products */;\n\t\t\tpackageReferences = (\n\t\t\t\t{PKG_SPARKLE} /* XCRemoteSwiftPackageReference "Sparkle" */,\n\t\t\t);\n''', 1)
    source_anchor = '\t\t\t\t0000000000000000000002C6 /* NotchEngine/DisplayClock.swift in Sources */,\n'
    pbx = pbx.replace(source_anchor, source_anchor + f'''\t\t\t\t{BF_UPDATE} /* Services/UpdateManager.swift in Sources */,\n\t\t\t\t{BF_WHATS} /* Views/WhatsNewView.swift in Sources */,\n''', 1)
    package_sections = f'''\n/* Begin XCRemoteSwiftPackageReference section */\n\t\t{PKG_SPARKLE} /* XCRemoteSwiftPackageReference "Sparkle" */ = {{\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = "https://github.com/sparkle-project/Sparkle";\n\t\t\trequirement = {{\n\t\t\t\tkind = exactVersion;\n\t\t\t\tversion = 2.9.6;\n\t\t\t}};\n\t\t}};\n/* End XCRemoteSwiftPackageReference section */\n\n/* Begin XCSwiftPackageProductDependency section */\n\t\t{PROD_SPARKLE} /* Sparkle */ = {{\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = {PKG_SPARKLE} /* XCRemoteSwiftPackageReference "Sparkle" */;\n\t\t\tproductName = Sparkle;\n\t\t}};\n/* End XCSwiftPackageProductDependency section */\n'''
    pbx = pbx.replace('/* Begin XCConfigurationList section */', package_sections + '\n/* Begin XCConfigurationList section */', 1)
pbx_path.write_text(pbx)

# Release/publishing documentation.
docs = r'''# Halo Updates (Sparkle 2)

Halo uses Sparkle 2.9.6 for direct-distribution updates. The app expects its appcast at:

`https://halo.redstoneinvente.com/appcast.xml`

## One-time signing setup

Do **not** commit a Sparkle private key to this repository or put it in CI logs.

1. Resolve/build the Sparkle package once in Xcode.
2. Run Sparkle's `generate_keys` tool on the release-signing Mac.
3. Keep the private Ed25519 key in that Mac's Keychain (and back it up securely).
4. Put only the printed public key in the ignored `Halo/Config/Secrets.xcconfig`:

   `HALO_SPARKLE_PUBLIC_KEY = <base64 public key>`

The checked-in `Base.xcconfig` intentionally leaves this value blank. Halo will not start Sparkle in a build without a valid public key; Settings > Updates explains the missing configuration instead of presenting a broken updater.

## Publishing a release

1. Archive and distribute Halo with Developer ID signing + notarization.
2. Export the final app as a `.zip` or `.dmg` suitable for Sparkle.
3. Place release archives and matching `.html` or `.md` release-note files in your Sparkle updates directory.
4. Run Sparkle's `generate_appcast` tool. It creates the appcast, Ed25519 signatures, and supported delta updates.
5. Upload the generated appcast as `https://halo.redstoneinvente.com/appcast.xml` and upload the release archives/release notes referenced by it.
6. Test **Check for Updates…** from a previously shipped build before publishing broadly.

Never hand-edit an archive's `sparkle:edSignature`. Regenerate the appcast after changing release assets.

## What's New

`HaloWhatsNewCoordinator` remembers the last version shown. After an installed version changes it presents Halo's native What's New window once. It is also available from the status menu and Settings > Updates.

Add release-specific cards to `HaloReleaseStory.forCurrentBuild()` when preparing a new marketing version. Unknown versions fall back to a generic polished release summary rather than failing to show.
'''
Path('Docs/Updates.md').write_text(docs)

print('Sparkle 2 + What\'s New integration applied.')
