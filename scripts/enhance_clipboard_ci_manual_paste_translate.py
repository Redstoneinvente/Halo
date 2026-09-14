from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing patch anchor: {label}")
    return text.replace(old, new, 1)

# ---- SurfaceView.swift ----
surface_path = Path("Halo/Views/SurfaceView.swift")
s = surface_path.read_text()

if "import CoreGraphics" not in s:
    s = replace_once(s, "import AppKit\nimport Darwin\n", "import AppKit\nimport CoreGraphics\nimport Darwin\n", "CoreGraphics import")

s = replace_once(
    s,
    '@Published private(set) var history: [ClipboardHistoryItem] = []\n    @Published private(set) var isActive = false',
    '@Published private(set) var history: [ClipboardHistoryItem] = []\n    @Published private(set) var manualPresentation = false\n    @Published private(set) var isActive = false',
    "manual presentation state",
)

s = replace_once(
    s,
    '    private var interactionActive = false\n    private let interval = 0.20',
    '    private var interactionActive = false\n    private var pasteTargetPID: pid_t?\n    private let interval = 0.20',
    "paste target state",
)

text_actions_old = '''        case .text:\n            if boolDefault("HaloContextClipboardShowSearch", true) {\n                result.append(.init(id: "search", title: "Search Web", symbol: "magnifyingglass"))\n            }\n            if boolDefault("HaloContextClipboardShowTransforms", true) {'''
text_actions_new = '''        case .text:\n            if boolDefault("HaloContextClipboardShowSearch", true) {\n                result.append(.init(id: "search", title: "Search Web", symbol: "magnifyingglass"))\n            }\n            if boolDefault("HaloContextClipboardShowTranslate", true) {\n                result.append(.init(id: "translate", title: "Translate", symbol: "character.bubble.fill"))\n            }\n            if boolDefault("HaloContextClipboardShowTransforms", true) {'''
s = replace_once(s, text_actions_old, text_actions_new, "translate text action")

s = replace_once(
    s,
    '''        let copyTitle: String\n        switch kind {''',
    '''        // Paste is deliberately first so it remains visible even when the user\n        // limits the number of contextual actions.\n        result.insert(.init(id: "paste", title: "Paste", symbol: "doc.on.clipboard.fill"), at: 0)\n\n        let copyTitle: String\n        switch kind {''',
    "paste action priority",
)

s = replace_once(
    s,
    '''    func setInteractionActive(_ active: Bool) {\n        interactionActive = active\n    }\n\n    func dismiss() {''',
    '''    func setInteractionActive(_ active: Bool) {\n        interactionActive = active\n    }\n\n    /// Opens Clipboard CI intentionally, independent of whether a fresh copy event occurred.\n    /// The most recent in-memory history item is preferred, then the current pasteboard.\n    @discardableResult\n    func presentHistory() -> Bool {\n        rememberPasteTarget()\n        manualPresentation = true\n\n        if isActive, !text.isEmpty {\n            restartTimeout()\n            eventSerial &+= 1\n            return true\n        }\n\n        if let latest = history.first {\n            activateHistory(latest)\n            manualPresentation = true\n            return true\n        }\n\n        capture(NSPasteboard.general)\n        manualPresentation = isActive\n        return isActive\n    }\n\n    func dismiss() {''',
    "manual presentation method",
)

s = replace_once(
    s,
    '''        case "search":\n            openSearch(trimmed)\n        case "pretty":''',
    '''        case "search":\n            openSearch(trimmed)\n        case "translate":\n            openTranslation(trimmed)\n        case "paste":\n            pasteCurrentPayload()\n        case "pretty":''',
    "perform paste translate",
)

# Capture the app that should receive a future Paste and mark new copy events as automatic.
s = replace_once(
    s,
    '''        sourceAppName = app?.localizedName ?? "Mac"\n        copiedAt = Date()\n        restartTimeout()''',
    '''        sourceAppName = app?.localizedName ?? "Mac"\n        if app?.bundleIdentifier != Bundle.main.bundleIdentifier {\n            pasteTargetPID = app?.processIdentifier\n        }\n        manualPresentation = false\n        copiedAt = Date()\n        restartTimeout()''',
    "capture paste target",
)

# Manual presentation should not survive expiry/dismissal.
s = replace_once(
    s,
    '''    private func deactivate() {\n        isActive = false''',
    '''    private func deactivate() {\n        manualPresentation = false\n        isActive = false''',
    "clear manual state",
)

# Insert paste + translation helpers immediately before the existing web search helper.
s = replace_once(
    s,
    '''    private func openSearch(_ query: String) {''',
    '''    private func rememberPasteTarget() {\n        guard let app = NSWorkspace.shared.frontmostApplication,\n              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }\n        pasteTargetPID = app.processIdentifier\n    }\n\n    private func writeCurrentPayloadToPasteboard() {\n        if let fileURL, kind == .file || kind == .video || kind == .image {\n            writeFileToPasteboard(fileURL)\n        } else if kind == .image, let image {\n            writeImageToPasteboard(image)\n        } else {\n            writeToPasteboard(text)\n        }\n    }\n\n    private func pasteCurrentPayload() {\n        writeCurrentPayloadToPasteboard()\n        guard let pid = pasteTargetPID,\n              let target = NSRunningApplication(processIdentifier: pid) else { return }\n\n        // Posting Command-V is the only general way to paste into an arbitrary macOS app.\n        // Request this capability lazily: users who never use direct Paste never see a prompt.\n        guard CGPreflightPostEventAccess() || CGRequestPostEventAccess() else {\n            NSSound.beep()\n            return\n        }\n\n        target.activate(options: [.activateIgnoringOtherApps])\n        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {\n            let source = CGEventSource(stateID: .combinedSessionState)\n            let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(9), keyDown: true)\n            let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(9), keyDown: false)\n            down?.flags = .maskCommand\n            up?.flags = .maskCommand\n            down?.post(tap: .cghidEventTap)\n            up?.post(tap: .cghidEventTap)\n        }\n    }\n\n    private func openTranslation(_ value: String) {\n        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)\n        guard !value.isEmpty else { return }\n        let defaults = UserDefaults.standard\n        let provider = defaults.string(forKey: "HaloContextClipboardTranslateProvider") ?? "Google Translate"\n        let target = defaults.string(forKey: "HaloContextClipboardTranslateTarget") ?? "en"\n\n        if provider == "DeepL" {\n            var allowed = CharacterSet.alphanumerics\n            allowed.insert(charactersIn: "-._~")\n            let escaped = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value\n            if let url = URL(string: "https://www.deepl.com/translator#auto/\\(target)/\\(escaped)") {\n                NSWorkspace.shared.open(url)\n            }\n            return\n        }\n\n        var components = URLComponents(string: "https://translate.google.com/")\n        components?.queryItems = [\n            URLQueryItem(name: "sl", value: "auto"),\n            URLQueryItem(name: "tl", value: target),\n            URLQueryItem(name: "text", value: value),\n            URLQueryItem(name: "op", value: "translate")\n        ]\n        if let url = components?.url { NSWorkspace.shared.open(url) }\n    }\n\n    private func openSearch(_ query: String) {''',
    "paste translation helpers",
)

s = replace_once(
    s,
    'candidates.append((.clipboard, clipboardPriority, 3))',
    'candidates.append((.clipboard, clipboardCI.manualPresentation ? 1000 : clipboardPriority, 3))',
    "manual clipboard priority",
)

# Hover state, not expanded state, owns the timeout pause.
s = replace_once(
    s,
    '''        .onHover { hovering in\n            if teleprompterContextActive {''',
    '''        .onHover { hovering in\n            if clipboardContextActive {\n                clipboardCI.setInteractionActive(hovering)\n            } else {\n                clipboardCI.setInteractionActive(false)\n            }\n            if teleprompterContextActive {''',
    "pointer-driven clipboard pause",
)

s = s.replace('            clipboardCI.setInteractionActive(expanded && clipboardContextActive)\n', '')
s = s.replace('                clipboardCI.setInteractionActive(state.expanded)\n', '')

# Explicit shortcut/manual trigger. Press again while open to dismiss.
s = replace_once(
    s,
    '''        .onReceive(NotificationCenter.default.publisher(for: .init("HaloRetroGameToggle"))) { _ in''',
    '''        .onReceive(NotificationCenter.default.publisher(for: .init("HaloClipboardCIToggle"))) { _ in\n            guard clipboardCIEnabled else { return }\n            if clipboardContextActive && state.expanded {\n                clipboardCI.dismiss()\n                clipboardOpenedNotch = false\n                if !state.pinned { state.expanded = false }\n                return\n            }\n            guard clipboardCI.presentHistory() else { return }\n            DispatchQueue.main.async {\n                guard clipboardCIEnabled, clipboardCI.isActive else { return }\n                state.collapseTask?.cancel()\n                clipboardOpenedNotch = true\n                state.expanded = true\n            }\n        }\n        .onReceive(NotificationCenter.default.publisher(for: .init("HaloRetroGameToggle"))) { _ in''',
    "manual clipboard notification",
)

# An opened Clipboard CI is a real opened notch for workspace visibility bookkeeping.
s = s.replace(
    '(activeContext == nil || transferContextActive)',
    '(activeContext == nil || transferContextActive || clipboardContextActive)'
)

surface_path.write_text(s)

# ---- WorkspaceStore.swift ----
store_path = Path("Halo/Core/WorkspaceStore.swift")
w = store_path.read_text()

w = replace_once(
    w,
    '    private let retroGameHotkey = HotkeyService(identifierID: 2, notificationName: .init("HaloRetroGameToggle"))',
    '    private let retroGameHotkey = HotkeyService(identifierID: 2, notificationName: .init("HaloRetroGameToggle"))\n    private let clipboardCIHotkey = HotkeyService(identifierID: 3, notificationName: .init("HaloClipboardCIToggle"))',
    "clipboard hotkey service",
)

w = replace_once(
    w,
    '    private var installedRetroGameHotkey = ""',
    '    private var installedRetroGameHotkey = ""\n    private var installedClipboardCIHotkey = ""',
    "clipboard installed hotkey",
)

w = replace_once(
    w,
    'evaluateSchedules(); system.refresh(); audio.refresh(); refreshApps(); updateHotkey(); updateRetroGameHotkey()',
    'evaluateSchedules(); system.refresh(); audio.refresh(); refreshApps(); updateHotkey(); updateRetroGameHotkey(); updateClipboardCIHotkey()',
    "start clipboard hotkey",
)

w = replace_once(
    w,
    'self?.disableLegacyHUDRenderer()\n                self?.updateRetroGameHotkey()',
    'self?.disableLegacyHUDRenderer()\n                self?.updateRetroGameHotkey()\n                self?.updateClipboardCIHotkey()',
    "refresh clipboard hotkey defaults",
)

w = replace_once(
    w,
    'hotkey.stop(); retroGameHotkey.stop(); clipboard.reset(); media.disconnect()',
    'hotkey.stop(); retroGameHotkey.stop(); clipboardCIHotkey.stop(); clipboard.reset(); media.disconnect()',
    "stop clipboard hotkey",
)

clipboard_hotkey_func = '''    private func updateClipboardCIHotkey() {\n        let ciEnabled = defaults.object(forKey: "HaloContextClipboardEnabled") as? Bool ?? true\n        let shortcutEnabled = defaults.object(forKey: "HaloContextClipboardShortcutEnabled") as? Bool ?? true\n        let code = defaults.object(forKey: "HaloContextClipboardShortcutCode") == nil ? 9 : defaults.integer(forKey: "HaloContextClipboardShortcutCode")\n        let modifiers = defaults.object(forKey: "HaloContextClipboardShortcutModifiers") == nil ? 6144 : defaults.integer(forKey: "HaloContextClipboardShortcutModifiers")\n        let key = "\\(ciEnabled)-\\(shortcutEnabled)-\\(code)-\\(modifiers)"\n        guard key != installedClipboardCIHotkey else { return }\n        installedClipboardCIHotkey = key\n        clipboardCIHotkey.stop()\n        guard ciEnabled, shortcutEnabled else { return }\n        if !clipboardCIHotkey.register(code: UInt32(max(0, code)), modifiers: UInt32(max(0, modifiers))) {\n            DispatchQueue.main.async { [weak self] in\n                self?.error = "The Clipboard CI shortcut is unavailable or already used. Choose another shortcut."\n            }\n        }\n    }\n'''
w = replace_once(w, '    private func scheduleWinner(at date: Date)', clipboard_hotkey_func + '    private func scheduleWinner(at date: Date)', "clipboard hotkey updater")
store_path.write_text(w)

# ---- WorkspaceSettingsView.swift ----
settings_path = Path("Halo/Views/WorkspaceSettingsView.swift")
v = settings_path.read_text()
start = v.index('private struct ClipboardContextSettings: View')
# Keep all replacements scoped to this settings view so similarly-named sections elsewhere are untouched.
next_struct = v.find('\nprivate struct ', start + 10)
if next_struct == -1:
    next_struct = len(v)
region = v[start:next_struct]

region = replace_once(
    region,
    '    @AppStorage("HaloContextClipboardHistoryLimit") private var historyLimit = 8',
    '''    @AppStorage("HaloContextClipboardHistoryLimit") private var historyLimit = 8\n    @AppStorage("HaloContextClipboardShortcutEnabled") private var shortcutEnabled = true\n    @AppStorage("HaloContextClipboardShortcutCode") private var shortcutCode = 9\n    @AppStorage("HaloContextClipboardShortcutModifiers") private var shortcutModifiers = 6144\n    @AppStorage("HaloContextClipboardShowTranslate") private var showTranslate = true\n    @AppStorage("HaloContextClipboardTranslateProvider") private var translateProvider = "Google Translate"\n    @AppStorage("HaloContextClipboardTranslateTarget") private var translateTarget = "en"''',
    "clipboard settings properties",
)

region = replace_once(
    region,
    '            Section("Context priority") {',
    '''            Section("Manual access") {\n                Toggle("Enable global Clipboard CI shortcut", isOn: $shortcutEnabled)\n                Picker("Shortcut key", selection: $shortcutCode) {\n                    Text("V").tag(9)\n                    Text("C").tag(8)\n                    Text("B").tag(11)\n                    Text("H").tag(4)\n                    Text("Space").tag(49)\n                }.disabled(!shortcutEnabled)\n                Picker("Shortcut modifiers", selection: $shortcutModifiers) {\n                    Text("Control + Option").tag(6144)\n                    Text("Option + Command").tag(2304)\n                    Text("Control + Shift").tag(4608)\n                }.disabled(!shortcutEnabled)\n                Button("Open Clipboard CI now") {\n                    NotificationCenter.default.post(name: .init("HaloClipboardCIToggle"), object: nil)\n                }\n                Text("The default shortcut is Control–Option–V. Manual invocation opens the most recent history item even when nothing was just copied; press the shortcut again while Clipboard CI is open to dismiss it.")\n                    .font(.caption).foregroundStyle(.secondary)\n            }\n\n            Section("Context priority") {''',
    "manual access settings",
)

region = replace_once(
    region,
    '                }.disabled(!showSearch)\n                Toggle("Offer text transforms", isOn: $showTransforms)',
    '''                }.disabled(!showSearch)\n                Toggle("Offer Translate action", isOn: $showTranslate)\n                Picker("Translation provider", selection: $translateProvider) {\n                    Text("Google Translate").tag("Google Translate")\n                    Text("DeepL").tag("DeepL")\n                }.disabled(!showTranslate)\n                Picker("Translate to", selection: $translateTarget) {\n                    Text("English").tag("en")\n                    Text("French").tag("fr")\n                    Text("Spanish").tag("es")\n                    Text("German").tag("de")\n                    Text("Italian").tag("it")\n                    Text("Portuguese").tag("pt")\n                    Text("Dutch").tag("nl")\n                    Text("Japanese").tag("ja")\n                    Text("Korean").tag("ko")\n                    Text("Chinese (Simplified)").tag("zh-CN")\n                    Text("Hindi").tag("hi")\n                    Text("Arabic").tag("ar")\n                    Text("Russian").tag("ru")\n                }.disabled(!showTranslate)\n                Toggle("Offer text transforms", isOn: $showTransforms)''',
    "translation settings",
)

region = region.replace(
    'search text, transform text, or restore an earlier history item.',
    'search or translate text, transform text, paste the selected payload into the previous app, or restore an earlier history item.'
)

# Add a direct-paste explanation under Actions.
region = replace_once(
    region,
    '                Toggle("Dismiss CI after an action", isOn: $autoCloseAfterAction)',
    '''                Toggle("Dismiss CI after an action", isOn: $autoCloseAfterAction)\n                Text("Paste restores the selected text, image, video or file to the macOS pasteboard and sends Command–V to the app that was frontmost when Clipboard CI opened. macOS may request Accessibility/Post Event permission the first time you use it.")\n                    .font(.caption).foregroundStyle(.secondary)''',
    "paste settings explanation",
)

v = v[:start] + region + v[next_struct:]

# The privacy copy previously promised Halo never asks for Accessibility; direct paste now does so lazily.
v = v.replace(
    'Microphone and Accessibility are not requested. Bluetooth state is read only when the Bluetooth CI/connection-state features are used.',
    'Microphone access is not requested. Accessibility/Post Event access is requested only if you use Clipboard CI direct Paste, so Halo can send Command–V to the app you were using. Bluetooth state is read only when the Bluetooth CI/connection-state features are used.'
)
settings_path.write_text(v)

print("Clipboard CI manual access, paste, and translation patch applied")
