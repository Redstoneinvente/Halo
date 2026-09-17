from pathlib import Path


def replace_exact(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match in {path}, found {count}")
    p.write_text(text.replace(old, new, 1))
    print(f"patched: {label}")


# Persisted hover-open delay with backward-compatible decoding for existing configs.
replace_exact(
    "Halo/Core/Models.swift",
    """    var hoverToExpand = true
    var allDisplays = false
""",
    """    var hoverToExpand = true
    // Optional keeps existing saved Configuration payloads backward-compatible.
    var hoverOpenDelay: Double? = nil
    var allDisplays = false

    var resolvedHoverOpenDelay: Double {
        min(10, max(0, hoverOpenDelay ?? 0))
    }
""",
    "configuration hover delay",
)

# Settings UI cleanup + hover delay control.
replace_exact(
    "Halo/Views/WorkspaceSettingsView.swift",
    """            Toggle(\"Expand on hover\", isOn: $store.configuration.hoverToExpand)
            Toggle(\"Show on all displays\", isOn: $store.configuration.allDisplays)
""",
    """            Toggle(\"Expand on hover\", isOn: $store.configuration.hoverToExpand)
            if store.configuration.hoverToExpand {
                LabeledContent(\"Hover delay\") {
                    HStack(spacing: 10) {
                        SwiftUI.Slider(
                            value: Binding(
                                get: { store.configuration.resolvedHoverOpenDelay },
                                set: { store.configuration.hoverOpenDelay = min(10, max(0, $0)) }
                            ),
                            in: 0...10,
                            step: 0.1
                        )
                        .frame(width: 220)
                        Group {
                            if store.configuration.resolvedHoverOpenDelay == 0 {
                                Text(\"Instant\")
                            } else {
                                Text(\"\\(store.configuration.resolvedHoverOpenDelay, specifier: \"%.1f\") s\")
                            }
                        }
                        .monospacedDigit()
                        .frame(width: 58, alignment: .trailing)
                    }
                }
            }
            Toggle(\"Show on all displays\", isOn: $store.configuration.allDisplays)
""",
    "hover delay settings control",
)

replace_exact(
    "Halo/Views/WorkspaceSettingsView.swift",
    """        Section(\"How access works\") {
            Text(\"Your Halo account and your software license are separate credentials. Firebase handles identity and session recovery; LicenseSeat handles the purchased license and device seat. Halo stores the Firebase refresh token, the activated license key, and its stable installation fingerprint in macOS Keychain.\")
                .font(.caption).foregroundStyle(.secondary)
            Link(\"Manage LicenseSeat account\", destination: URL(string: \"https://licenseseat.com\")!)
            Link(\"Contact Halo support · r.support@redstoneinvente.com\", destination: URL(string: \"mailto:r.support@redstoneinvente.com\")!)
        }
""",
    """        Section(\"Support\") {
            Link(\"Contact Halo support · r.support@redstoneinvente.com\", destination: URL(string: \"mailto:r.support@redstoneinvente.com\")!)
        }
""",
    "account and license explanatory UI",
)

replace_exact(
    "Halo/Views/WorkspaceSettingsView.swift",
    """                Text(\"Automation is requested when detecting or controlling Apple Music or Spotify. System Audio uses Screen Recording permission to analyse the Mac's output audio. Screen Recording is also requested when you capture a region. Microphone access is not requested. Accessibility/Post Event access is requested only if you use Clipboard CI direct Paste, so Halo can send Command–V to the app you were using. Bluetooth state is read only when the Bluetooth CI/connection-state features are used. No analytics. Enabling artwork colors downloads Spotify artwork; Apple Music artwork is read from the player. Plugin URLs open only after confirmation.\")
                Text(\"This direct-distribution build is not sandboxed. Files and notes are stored locally.\")
""",
    """""",
    "privacy explanatory copy",
)

replace_exact(
    "Halo/Views/WorkspaceSettingsView.swift",
    """            if updates.isConfigured {
                Text(\"Halo uses Sparkle 2 to securely check, verify, download, and install signed updates.\")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label(\"Update configuration is unavailable in this build.\", systemImage: \"exclamationmark.triangle\")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
""",
    """            if !updates.isConfigured {
                Label(\"Update configuration is unavailable in this build.\", systemImage: \"exclamationmark.triangle\")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
""",
    "about Sparkle explanatory copy",
)

replace_exact(
    "Halo/Views/WorkspaceSettingsView.swift",
    """                Text(\"This is Halo's existing persisted Surface blur; the renderer already applies it to Solid, Gradient, Image, Video, and timed backgrounds.\")
                    .font(.caption).foregroundStyle(.secondary)
""",
    """""",
    "surface blur implementation note",
)

# Activation Sequence settings cleanup.
replace_exact(
    "Halo/Views/ActivationSequence.swift",
    """            Text(\"Sound is off by default. Built-in sounds are short synthesized cues with soft envelopes rather than long startup jingles.\")
                .font(.caption).foregroundStyle(.secondary)
""",
    """""",
    "activation sound default note",
)

replace_exact(
    "Halo/Views/ActivationSequence.swift",
    """        Section(\"Accessibility & performance\") {
            Text(\"Halo automatically substitutes a simple fade/glow when macOS Reduce Motion is enabled. Low Power Mode lowers the activation renderer to 30 fps and halves particle counts. The effect never receives mouse events, and immediate notch interaction cancels it gracefully.\")
                .font(.caption).foregroundStyle(.secondary)
        }
""",
    """""",
    "activation accessibility and performance section",
)

# Notch Ambient UI cleanup; keep the internal layer contract untouched.
replace_exact(
    "Halo/Views/DecorationsView.swift",
    """            DisclosureGroup(\"Decoration Studio architecture\") {
                Text(\"Built-in decorations already resolve through reusable Shape, Image, Animated Image, Video, Particle Emitter, Glow, Line, Gradient, Shader and Procedural layer roles with explicit depth. The manifest contract is versioned so a future Decoration Studio and importable packs can add assets, layers, animations, reactions and previews without replacing the runtime ownership system.\")
                    .font(.caption).foregroundStyle(.secondary)
            }
""",
    """""",
    "notch ambient Decoration Studio architecture UI",
)

# Runtime hover delay: cancel cleanly when pointer leaves or another interaction takes ownership.
replace_exact(
    "Halo/NotchEngine/WindowManager.swift",
    """    @Published var pinned = false {
        didSet { if pinned { collapseTask?.cancel(); expanded = true } }
    }
""",
    """    @Published var pinned = false {
        didSet {
            if pinned {
                hoverExpandTask?.cancel()
                collapseTask?.cancel()
                expanded = true
            }
        }
    }
""",
    "cancel delayed hover when pinned",
)

replace_exact(
    "Halo/NotchEngine/WindowManager.swift",
    """    var collapseTask: Task<Void, Never>?
    var dropExitTask: Task<Void, Never>?
""",
    """    var collapseTask: Task<Void, Never>?
    var hoverExpandTask: Task<Void, Never>?
    var dropExitTask: Task<Void, Never>?
""",
    "hover expansion task storage",
)

replace_exact(
    "Halo/NotchEngine/WindowManager.swift",
    """    func beginFileDrop(count: Int) {
        dropExitTask?.cancel()
        collapseTask?.cancel()
""",
    """    func beginFileDrop(count: Int) {
        dropExitTask?.cancel()
        hoverExpandTask?.cancel()
        collapseTask?.cancel()
""",
    "cancel delayed hover for file drop",
)

replace_exact(
    "Halo/NotchEngine/WindowManager.swift",
    """    func hover(_ inside: Bool, enabled: Bool) {
        collapseTask?.cancel()
        guard enabled, !editingGeometry else { return }
        if dropTargeted {
            if inside && !expanded { expanded = true }
            return
        }
        if inside { expanded = true }
        else if !pinned {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled, let self, !self.pinned, !self.editingGeometry, !self.dropTargeted else { return }
                self.expanded = false
            }
        }
    }
""",
    """    func hover(_ inside: Bool, enabled: Bool, openDelay: Double = 0) {
        collapseTask?.cancel()
        if !inside {
            hoverExpandTask?.cancel()
            hoverExpandTask = nil
        }
        guard enabled, !editingGeometry else {
            hoverExpandTask?.cancel()
            hoverExpandTask = nil
            return
        }
        if dropTargeted {
            hoverExpandTask?.cancel()
            hoverExpandTask = nil
            if inside && !expanded { expanded = true }
            return
        }
        if inside {
            guard !expanded else {
                hoverExpandTask?.cancel()
                hoverExpandTask = nil
                return
            }
            let delay = min(10, max(0, openDelay))
            hoverExpandTask?.cancel()
            guard delay > 0.001 else {
                hoverExpandTask = nil
                expanded = true
                return
            }
            hoverExpandTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled,
                      let self,
                      !self.editingGeometry,
                      !self.dropTargeted else { return }
                self.hoverExpandTask = nil
                self.expanded = true
            }
        } else if !pinned {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled, let self, !self.pinned, !self.editingGeometry, !self.dropTargeted else { return }
                self.expanded = false
            }
        }
    }
""",
    "delayed hover expansion behavior",
)

replace_exact(
    "Halo/NotchEngine/WindowManager.swift",
    """            animator.cancel(); state.collapseTask?.cancel(); state.dropExitTask?.cancel()
""",
    """            animator.cancel(); state.hoverExpandTask?.cancel(); state.collapseTask?.cancel(); state.dropExitTask?.cancel()
""",
    "cancel hover task on host stop",
)

replace_exact(
    "Halo/Views/SurfaceView.swift",
    """                state.hover(hovering, enabled: store.configuration.hoverToExpand || clipboardHover)
""",
    """                state.hover(
                    hovering,
                    enabled: store.configuration.hoverToExpand || clipboardHover,
                    openDelay: store.configuration.hoverToExpand ? store.configuration.resolvedHoverOpenDelay : 0
                )
""",
    "surface hover delay wiring",
)

print("UI stability cleanup applied successfully")
