import Foundation
import AppKit
import Combine
import SwiftUI
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
                ForEach(intervals.indices, id: \.self) { index in
                    Text(intervals[index].0).tag(intervals[index].1)
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
