import SwiftUI
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
