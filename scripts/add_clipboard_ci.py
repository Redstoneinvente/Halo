from pathlib import Path

surface_path = Path("Halo/Views/SurfaceView.swift")
settings_path = Path("Halo/Views/WorkspaceSettingsView.swift")

surface = surface_path.read_text()
settings = settings_path.read_text()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing anchor: {label}")
    return text.replace(old, new, 1)

# -----------------------------------------------------------------------------
# Surface runtime + UI
# -----------------------------------------------------------------------------
clipboard_runtime = r'''
private enum ClipboardContextKind: String {
    case link = "Link"
    case email = "Email"
    case phone = "Phone"
    case file = "File"
    case json = "JSON"
    case address = "Address"
    case text = "Text"

    var symbol: String {
        switch self {
        case .link: return "link"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .file: return "doc.fill"
        case .json: return "curlybraces"
        case .address: return "mappin.and.ellipse"
        case .text: return "text.alignleft"
        }
    }

    var accent: Color {
        switch self {
        case .link: return Color(hue: 0.58, saturation: 0.72, brightness: 1.0)
        case .email: return Color(hue: 0.52, saturation: 0.62, brightness: 0.98)
        case .phone: return Color(hue: 0.37, saturation: 0.66, brightness: 0.92)
        case .file: return Color(hue: 0.10, saturation: 0.70, brightness: 1.0)
        case .json: return Color(hue: 0.78, saturation: 0.58, brightness: 1.0)
        case .address: return Color(hue: 0.02, saturation: 0.72, brightness: 1.0)
        case .text: return Color(hue: 0.62, saturation: 0.16, brightness: 0.98)
        }
    }
}

private struct ClipboardContextAction: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
}

@MainActor
private final class ClipboardContextMonitor: ObservableObject {
    static let shared = ClipboardContextMonitor()

    @Published private(set) var text = ""
    @Published private(set) var kind: ClipboardContextKind = .text
    @Published private(set) var isActive = false
    @Published private(set) var copiedAt: Date?
    @Published private(set) var expiresAt: Date?
    @Published private(set) var remainingFraction = 0.0
    @Published private(set) var sourceAppName = ""
    @Published private(set) var eventSerial = 0

    private var changeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private var interactionActive = false
    private let interval = 0.20

    private init() {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    var triggerMode: String {
        UserDefaults.standard.string(forKey: "HaloContextClipboardTriggerMode") ?? "Hover to Open"
    }

    var preview: String {
        let collapsed = text
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return String(collapsed.prefix(220))
    }

    var actions: [ClipboardContextAction] {
        var result: [ClipboardContextAction] = []
        switch kind {
        case .link:
            result += [
                .init(id: "open", title: "Open Link", symbol: "safari"),
                .init(id: "search", title: "Search", symbol: "magnifyingglass")
            ]
        case .email:
            result += [
                .init(id: "compose", title: "New Email", symbol: "envelope.badge"),
                .init(id: "search", title: "Search", symbol: "magnifyingglass")
            ]
        case .phone:
            result += [
                .init(id: "facetime", title: "FaceTime", symbol: "video.fill"),
                .init(id: "search", title: "Search", symbol: "magnifyingglass")
            ]
        case .file:
            result += [
                .init(id: "openFile", title: "Open", symbol: "arrow.up.forward.app"),
                .init(id: "reveal", title: "Reveal", symbol: "folder")
            ]
        case .json:
            result += [
                .init(id: "pretty", title: "Pretty Copy", symbol: "curlybraces.square"),
                .init(id: "search", title: "Search", symbol: "magnifyingglass")
            ]
        case .address:
            result += [
                .init(id: "maps", title: "Open in Maps", symbol: "map.fill"),
                .init(id: "search", title: "Search", symbol: "magnifyingglass")
            ]
        case .text:
            if boolDefault("HaloContextClipboardShowSearch", true) {
                result.append(.init(id: "search", title: "Search Web", symbol: "magnifyingglass"))
            }
            if boolDefault("HaloContextClipboardShowTransforms", true) {
                result += [
                    .init(id: "trim", title: "Trim + Copy", symbol: "scissors"),
                    .init(id: "upper", title: "UPPERCASE", symbol: "textformat.size.larger"),
                    .init(id: "lower", title: "lowercase", symbol: "textformat.size.smaller")
                ]
            }
        }
        result.append(.init(id: "copy", title: kind == .file ? "Copy Path" : "Copy", symbol: "doc.on.doc"))
        let configured = UserDefaults.standard.object(forKey: "HaloContextClipboardMaxActions") == nil
            ? 5
            : UserDefaults.standard.integer(forKey: "HaloContextClipboardMaxActions")
        return Array(result.prefix(min(8, max(2, configured))))
    }

    func setInteractionActive(_ active: Bool) {
        interactionActive = active
    }

    func dismiss() {
        deactivate()
    }

    func perform(_ action: ClipboardContextAction) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch action.id {
        case "open":
            if let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
        case "openFile":
            NSWorkspace.shared.open(URL(fileURLWithPath: trimmed))
        case "reveal":
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: trimmed)])
        case "compose":
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = trimmed
            if let url = components.url { NSWorkspace.shared.open(url) }
        case "facetime":
            let allowed = CharacterSet(charactersIn: "+0123456789")
            let clean = trimmed.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
            if let url = URL(string: "facetime://\(clean)") { NSWorkspace.shared.open(url) }
        case "maps":
            var components = URLComponents(string: "https://maps.apple.com/")
            components?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
            if let url = components?.url { NSWorkspace.shared.open(url) }
        case "search":
            openSearch(trimmed)
        case "pretty":
            if let data = trimmed.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data),
               JSONSerialization.isValidJSONObject(object),
               let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
               let string = String(data: pretty, encoding: .utf8) {
                writeToPasteboard(string)
            }
        case "trim":
            writeToPasteboard(trimmed)
        case "upper":
            writeToPasteboard(text.uppercased())
        case "lower":
            writeToPasteboard(text.lowercased())
        case "copy":
            writeToPasteboard(text)
        default:
            break
        }

        if boolDefault("HaloContextClipboardAutoCloseAfterAction", true) {
            deactivate()
        }
    }

    private func poll() {
        let board = NSPasteboard.general
        let enabled = boolDefault("HaloContextClipboardEnabled", true)
        guard enabled else {
            changeCount = board.changeCount
            if isActive { deactivate() }
            return
        }

        if board.changeCount != changeCount {
            changeCount = board.changeCount
            capture(board)
        }

        guard isActive, let expiry = expiresAt else { return }
        if triggerMode == "Hover to Open", interactionActive {
            expiresAt = expiry.addingTimeInterval(interval)
        }
        let timeout = timeoutSeconds
        let remaining = max(0, expiresAt?.timeIntervalSinceNow ?? 0)
        remainingFraction = min(1, remaining / max(0.1, timeout))
        if remaining <= 0 { deactivate() }
    }

    private func capture(_ board: NSPasteboard) {
        let app = NSWorkspace.shared.frontmostApplication
        let bundleID = app?.bundleIdentifier ?? ""
        let excluded = Set((UserDefaults.standard.string(forKey: "HaloContextClipboardExcludedApps") ?? "")
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })
        guard !excluded.contains(bundleID) else { deactivate(); return }

        let sensitive = [
            "org.nspasteboard.ConcealedType",
            "org.nspasteboard.TransientType",
            "org.nspasteboard.AutoGeneratedType"
        ]
        if sensitive.contains(where: { board.types?.contains(NSPasteboard.PasteboardType($0)) == true }) {
            deactivate()
            return
        }

        var candidate: String?
        if let rawFile = board.string(forType: .fileURL),
           let fileURL = URL(string: rawFile), fileURL.isFileURL {
            candidate = fileURL.path
        }
        if candidate == nil { candidate = board.string(forType: .string) }

        guard let raw = candidate,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              raw.utf8.count <= 250_000 else {
            deactivate()
            return
        }

        text = raw
        kind = classify(raw)
        sourceAppName = app?.localizedName ?? "Mac"
        let now = Date()
        copiedAt = now
        expiresAt = now.addingTimeInterval(timeoutSeconds)
        remainingFraction = 1
        eventSerial &+= 1
        isActive = true
    }

    private func classify(_ raw: String) -> ClipboardContextKind {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if FileManager.default.fileExists(atPath: value) { return .file }

        if let url = URL(string: value),
           ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
           !value.contains(where: { $0.isWhitespace }) {
            return .link
        }

        if value.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
                       options: [.regularExpression, .caseInsensitive]) != nil {
            return .email
        }

        let phoneAllowed = CharacterSet(charactersIn: "+()-. 0123456789")
        let phoneScalars = value.unicodeScalars
        let digitCount = phoneScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        if digitCount >= 7, digitCount <= 15, phoneScalars.allSatisfy({ phoneAllowed.contains($0) }) {
            return .phone
        }

        if let data = value.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           object is [Any] || object is [String: Any] {
            return .json
        }

        let nsLength = (value as NSString).length
        if nsLength >= 6,
           let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue),
           let match = detector.firstMatch(in: value, range: NSRange(location: 0, length: nsLength)),
           match.resultType == .address,
           match.range.location == 0, match.range.length == nsLength {
            return .address
        }
        return .text
    }

    private var timeoutSeconds: Double {
        let defaults = UserDefaults.standard
        let value = defaults.object(forKey: "HaloContextClipboardTimeoutSeconds") == nil
            ? 8.0
            : defaults.double(forKey: "HaloContextClipboardTimeoutSeconds")
        return min(120, max(1, value))
    }

    private func boolDefault(_ key: String, _ defaultValue: Bool) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private func deactivate() {
        isActive = false
        expiresAt = nil
        remainingFraction = 0
        interactionActive = false
    }

    private func writeToPasteboard(_ value: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(value, forType: .string)
        changeCount = board.changeCount
    }

    private func openSearch(_ query: String) {
        let engine = UserDefaults.standard.string(forKey: "HaloContextClipboardSearchEngine") ?? "Google"
        let base: String
        switch engine {
        case "DuckDuckGo": base = "https://duckduckgo.com/"
        case "Bing": base = "https://www.bing.com/search"
        default: base = "https://www.google.com/search"
        }
        var components = URLComponents(string: base)
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        if let url = components?.url { NSWorkspace.shared.open(url) }
    }
}

private enum ClipboardCISizing {
    static func minimumExpandedWidth(physicalNotchWidth: CGFloat) -> CGFloat {
        max(360, physicalNotchWidth > 0 ? physicalNotchWidth + 120 : 360)
    }

    static func closedPreferredWidth(monitor: ClipboardContextMonitor, physicalNotchWidth: CGFloat) -> CGFloat {
        let defaults = UserDefaults.standard
        let showPreview = defaults.object(forKey: "HaloContextClipboardShowClosedPreview") == nil
            ? true : defaults.bool(forKey: "HaloContextClipboardShowClosedPreview")
        let physicalFloor = physicalNotchWidth > 0 ? physicalNotchWidth + 18 : 118
        guard showPreview else { return max(physicalFloor, 156) }
        let estimated = CGFloat(min(44, monitor.preview.count)) * 5.3 + 112
        return min(520, max(physicalFloor, max(220, estimated)))
    }

    static func openPreferredSize(actionCount: Int? = nil) -> CGSize {
        let defaults = UserDefaults.standard
        let compact = defaults.bool(forKey: "HaloContextClipboardCompact")
        let lines = defaults.object(forKey: "HaloContextClipboardPreviewLines") == nil
            ? 3 : min(6, max(1, defaults.integer(forKey: "HaloContextClipboardPreviewLines")))
        let count = max(1, actionCount ?? 5)
        let columns = compact ? min(3, count) : min(4, count)
        let rows = Int(ceil(Double(count) / Double(max(1, columns))))
        let width: CGFloat = compact ? max(410, CGFloat(columns) * 126 + 48) : max(520, CGFloat(columns) * 138 + 54)
        let baseHeight: CGFloat = compact ? 116 : 144
        let previewHeight = CGFloat(lines) * (compact ? 13 : 16)
        let actionHeight = CGFloat(rows) * (compact ? 38 : 44)
        return CGSize(width: min(760, width), height: min(390, baseHeight + previewHeight + actionHeight))
    }
}

private struct ClipboardSurfaceBackground: View {
    @ObservedObject var monitor: ClipboardContextMonitor
    @AppStorage("HaloContextClipboardBackgroundStyle") private var style = "Adaptive"

    var body: some View {
        Group {
            switch style {
            case "Glass":
                Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(0.48))
            case "Black":
                Color.black
            default:
                LinearGradient(
                    colors: [monitor.kind.accent.opacity(0.28), Color.black.opacity(0.98), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct ClipboardClosedContextView: View {
    @ObservedObject var monitor: ClipboardContextMonitor
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextClipboardShowClosedPreview") private var showPreview = true
    @AppStorage("HaloContextClipboardShowType") private var showType = true

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: monitor.kind.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(monitor.kind.accent)
                .frame(width: 18, height: 18)
                .background(monitor.kind.accent.opacity(0.12), in: Circle())
            if showType {
                Text(monitor.kind.rawValue)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            if showPreview {
                Text(monitor.preview)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ZStack {
                Circle().stroke(.white.opacity(0.10), lineWidth: 1.5)
                Circle()
                    .trim(from: 0, to: monitor.remainingFraction)
                    .stroke(monitor.kind.accent.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { updateSizing() }
        .onChange(of: monitor.eventSerial) { _ in updateSizing() }
        .onChange(of: showPreview) { _ in updateSizing() }
        .onChange(of: showType) { _ in updateSizing() }
    }

    private func updateSizing() {
        surfaceState.contextMinimumExpandedWidth = ClipboardCISizing.minimumExpandedWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
        surfaceState.contextPreferredCompactWidth = ClipboardCISizing.closedPreferredWidth(monitor: monitor, physicalNotchWidth: surfaceState.physicalNotchWidth)
        if !surfaceState.expanded {
            surfaceState.contextPreferredSize = ClipboardCISizing.openPreferredSize(actionCount: monitor.actions.count)
        }
    }
}

private struct ClipboardContextView: View {
    @ObservedObject var monitor: ClipboardContextMonitor
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextClipboardCompact") private var compact = false
    @AppStorage("HaloContextClipboardPreviewLines") private var previewLines = 3
    @AppStorage("HaloContextClipboardShowType") private var showType = true
    @AppStorage("HaloContextClipboardShowSource") private var showSource = true
    @AppStorage("HaloContextClipboardShowCharacterCount") private var showCharacterCount = true
    @AppStorage("HaloContextClipboardMaxActions") private var maxActions = 5

    private var sizingSignature: String {
        [compact.description, String(previewLines), showType.description, showSource.description,
         showCharacterCount.description, String(maxActions), String(monitor.actions.count)].joined(separator: "|")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 12) {
            HStack(spacing: 9) {
                Image(systemName: monitor.kind.symbol)
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .foregroundStyle(monitor.kind.accent)
                    .frame(width: compact ? 25 : 30, height: compact ? 25 : 30)
                    .background(monitor.kind.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    if showType { Text(monitor.kind.rawValue).font(.system(size: compact ? 11 : 12.5, weight: .semibold, design: .rounded)) }
                    if showSource, !monitor.sourceAppName.isEmpty {
                        Text("Copied from \(monitor.sourceAppName)")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }
                Spacer()
                Text("\(Int(max(0, monitor.remainingFraction) * 100))%")
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.34))
                Button { monitor.dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(0.055), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.62))
                .help("Dismiss Clipboard CI")
            }

            Text(monitor.text)
                .font(.system(size: compact ? 10.5 : 12, weight: .medium, design: monitor.kind == .json ? .monospaced : .rounded))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(min(6, max(1, previewLines)))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, compact ? 9 : 11)
                .padding(.vertical, compact ? 7 : 9)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.055), lineWidth: 0.5))

            let actions = monitor.actions
            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 104 : 118, maximum: 180), spacing: 7)], spacing: 7) {
                ForEach(actions) { action in
                    Button { monitor.perform(action) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: action.symbol).font(.system(size: 10, weight: .semibold))
                            Text(action.title).font(.system(size: 9.5, weight: .semibold, design: .rounded)).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 9)
                        .frame(height: compact ? 30 : 34)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(.white.opacity(0.055), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.78))
                }
            }

            if showCharacterCount {
                HStack(spacing: 8) {
                    Text("\(monitor.text.count) characters")
                    Text("•")
                    Text("\(monitor.text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count) words")
                    Spacer()
                    Text(monitor.triggerMode == "Pop Up" ? "Auto popup" : "Hover to open")
                }
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.32))
            }
        }
        .padding(.horizontal, compact ? 13 : 16)
        .padding(.vertical, compact ? 11 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { updateSizing() }
        .onChange(of: monitor.eventSerial) { _ in updateSizing() }
        .onChange(of: sizingSignature) { _ in updateSizing() }
    }

    private func updateSizing() {
        surfaceState.contextMinimumExpandedWidth = ClipboardCISizing.minimumExpandedWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
        surfaceState.contextPreferredCompactWidth = ClipboardCISizing.closedPreferredWidth(monitor: monitor, physicalNotchWidth: surfaceState.physicalNotchWidth)
        surfaceState.contextPreferredSize = ClipboardCISizing.openPreferredSize(actionCount: monitor.actions.count)
    }
}

'''

surface = replace_once(
    surface,
    'private enum ActiveContextInterface: String {\n    case drop, teleprompter, transfer, music, bluetooth, retro\n}',
    clipboard_runtime + 'private enum ActiveContextInterface: String {\n    case drop, teleprompter, transfer, clipboard, music, bluetooth, retro\n}',
    'ActiveContextInterface enum'
)

surface = replace_once(
    surface,
    '    @ObservedObject private var transfer = TransferActivityMonitor.shared\n    @State private var teleprompterActive = false',
    '    @ObservedObject private var transfer = TransferActivityMonitor.shared\n    @ObservedObject private var clipboardCI = ClipboardContextMonitor.shared\n    @State private var clipboardOpenedNotch = false\n    @State private var teleprompterActive = false',
    'SurfaceView clipboard monitor state'
)

surface = replace_once(
    surface,
    '    @AppStorage("HaloContextTransferPriority") private var transferPriority = 65.0\n    @AppStorage("HaloContextTransferUseFullNotchArea") private var transferUsesFullNotchArea = true',
    '    @AppStorage("HaloContextTransferPriority") private var transferPriority = 65.0\n    @AppStorage("HaloContextClipboardEnabled") private var clipboardCIEnabled = true\n    @AppStorage("HaloContextClipboardPriority") private var clipboardPriority = 68.0\n    @AppStorage("HaloContextTransferUseFullNotchArea") private var transferUsesFullNotchArea = true',
    'SurfaceView clipboard AppStorage'
)

surface = replace_once(
    surface,
    '        if transferCIEnabled && transfer.isActive {\n            candidates.append((.transfer, transferPriority, 3))\n        }\n        if contextOptions.enabled && workspace.media.isPlaying {',
    '        if transferCIEnabled && transfer.isActive {\n            candidates.append((.transfer, transferPriority, 3))\n        }\n        if clipboardCIEnabled && clipboardCI.isActive {\n            candidates.append((.clipboard, clipboardPriority, 3))\n        }\n        if contextOptions.enabled && workspace.media.isPlaying {',
    'Clipboard CI priority candidate'
)

surface = replace_once(
    surface,
    '    private var transferContextActive: Bool { activeContext == .transfer }\n    private var contextOwnsFullSurface: Bool {',
    '    private var transferContextActive: Bool { activeContext == .transfer }\n    private var clipboardContextActive: Bool { activeContext == .clipboard }\n    private var contextOwnsFullSurface: Bool {',
    'Clipboard context active helper'
)

surface = replace_once(
    surface,
    '        case .teleprompter: return true\n        case .transfer: return false\n        case .none: return false',
    '        case .teleprompter: return true\n        case .transfer: return false\n        case .clipboard: return false\n        case .none: return false',
    'Clipboard full surface switch'
)

surface = replace_once(
    surface,
    '        case .teleprompter: return false\n        case .transfer: return false\n        case .none:',
    '        case .teleprompter: return false\n        case .transfer: return false\n        case .clipboard: return false\n        case .none:',
    'Clipboard closed contents switch'
)

surface = replace_once(
    surface,
    '                        if transferContextActive {\n                            TransferClosedContextView(monitor: transfer, surfaceState: state)\n                        } else {\n                            ClosedNotchView(store: store, workspace: workspace, layout: layout, occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)\n                        }',
    '                        if transferContextActive {\n                            TransferClosedContextView(monitor: transfer, surfaceState: state)\n                        } else if clipboardContextActive {\n                            ClipboardClosedContextView(monitor: clipboardCI, surfaceState: state)\n                        } else {\n                            ClosedNotchView(store: store, workspace: workspace, layout: layout, occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)\n                        }',
    'Clipboard closed renderer'
)

surface = replace_once(
    surface,
    '                    if transferContextActive {\n                        TransferContextView(monitor: transfer, surfaceState: state)\n                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)\n                            .transition(.opacity.combined(with: .scale(scale: 0.985)))\n                    } else if dropContextActive {',
    '                    if transferContextActive {\n                        TransferContextView(monitor: transfer, surfaceState: state)\n                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)\n                            .transition(.opacity.combined(with: .scale(scale: 0.985)))\n                    } else if clipboardContextActive {\n                        ClipboardContextView(monitor: clipboardCI, surfaceState: state)\n                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)\n                            .transition(.opacity.combined(with: .scale(scale: 0.985)))\n                    } else if dropContextActive {',
    'Clipboard open renderer'
)

surface = replace_once(
    surface,
    '            } else {\n                state.hover(hovering, enabled: store.configuration.hoverToExpand)\n            }',
    '            } else {\n                let clipboardHover = clipboardContextActive && clipboardCI.triggerMode == "Hover to Open"\n                state.hover(hovering, enabled: store.configuration.hoverToExpand || clipboardHover)\n            }',
    'Clipboard hover trigger behavior'
)

surface = replace_once(
    surface,
    '                        state.contextPreferredSize = TransferCISizing.openPreferredSize()\n                    }\n                }\n                retroGameRequested = false',
    '                        state.contextPreferredSize = TransferCISizing.openPreferredSize()\n                    }\n                } else if clipboardContextActive {\n                    DispatchQueue.main.async {\n                        guard clipboardContextActive, !state.expanded else { return }\n                        state.contextMinimumExpandedWidth = ClipboardCISizing.minimumExpandedWidth(physicalNotchWidth: state.physicalNotchWidth)\n                        state.contextPreferredCompactWidth = ClipboardCISizing.closedPreferredWidth(monitor: clipboardCI, physicalNotchWidth: state.physicalNotchWidth)\n                        state.contextPreferredSize = ClipboardCISizing.openPreferredSize(actionCount: clipboardCI.actions.count)\n                    }\n                }\n                retroGameRequested = false',
    'Clipboard collapsed size priming'
)

clipboard_change_handlers = r'''        .onChange(of: clipboardCI.eventSerial) { _ in
            guard clipboardCIEnabled, clipboardCI.isActive, clipboardCI.triggerMode == "Pop Up" else { return }
            DispatchQueue.main.async {
                guard clipboardCIEnabled, clipboardCI.isActive, activeContext == .clipboard, !state.pinned else { return }
                if !state.expanded {
                    clipboardOpenedNotch = true
                    state.collapseTask?.cancel()
                    state.expanded = true
                }
            }
        }
        .onChange(of: clipboardCI.isActive) { active in
            if !active {
                clipboardCI.setInteractionActive(false)
                if clipboardOpenedNotch && !state.pinned { state.expanded = false }
                clipboardOpenedNotch = false
            }
        }
        .onChange(of: state.expanded) { expanded in
            clipboardCI.setInteractionActive(expanded && clipboardContextActive)
            if !expanded { clipboardOpenedNotch = false }
        }
'''

surface = replace_once(
    surface,
    '        .onChange(of: activeContext) { _ in',
    clipboard_change_handlers + '        .onChange(of: activeContext) { _ in',
    'Clipboard change handlers'
)

surface = replace_once(
    surface,
    '            if !transferContextActive {\n                state.contextPreferredCompactWidth = nil\n                state.contextMinimumExpandedWidth = nil\n                if activeContext != nil { state.contextPreferredSize = nil }\n            }',
    '            if clipboardContextActive {\n                state.contextMinimumExpandedWidth = ClipboardCISizing.minimumExpandedWidth(physicalNotchWidth: state.physicalNotchWidth)\n                state.contextPreferredCompactWidth = ClipboardCISizing.closedPreferredWidth(monitor: clipboardCI, physicalNotchWidth: state.physicalNotchWidth)\n                state.contextPreferredSize = ClipboardCISizing.openPreferredSize(actionCount: clipboardCI.actions.count)\n                clipboardCI.setInteractionActive(state.expanded)\n                if clipboardCI.triggerMode == "Pop Up", !state.expanded, !state.pinned {\n                    clipboardOpenedNotch = true\n                    state.collapseTask?.cancel()\n                    state.expanded = true\n                }\n            } else {\n                clipboardCI.setInteractionActive(false)\n                if activeContext != nil { clipboardOpenedNotch = false }\n            }\n            if !transferContextActive && !clipboardContextActive {\n                state.contextPreferredCompactWidth = nil\n                state.contextMinimumExpandedWidth = nil\n                if activeContext != nil { state.contextPreferredSize = nil }\n            }',
    'Clipboard active context sizing and cleanup'
)

surface = replace_once(
    surface,
    '            if transferContextActive {\n                TransferSurfaceBackground(monitor: transfer)\n            } else if state.expanded && activeContext == nil && usesVisualWorkspace {',
    '            if transferContextActive {\n                TransferSurfaceBackground(monitor: transfer)\n            } else if clipboardContextActive {\n                ClipboardSurfaceBackground(monitor: clipboardCI)\n            } else if state.expanded && activeContext == nil && usesVisualWorkspace {',
    'Clipboard background renderer'
)

surface = replace_once(
    surface,
    '            if !transferContextActive && (!state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true) {',
    '            if !transferContextActive && !clipboardContextActive && (!state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true) {',
    'Suppress normal background under Clipboard CI'
)

# -----------------------------------------------------------------------------
# Clipboard CI settings + library card
# -----------------------------------------------------------------------------
settings = replace_once(
    settings,
    'private enum ContextInterfaceSelection: String, Identifiable {\n    case drop, music, teleprompter, transfer, bluetooth, retro',
    'private enum ContextInterfaceSelection: String, Identifiable {\n    case drop, music, teleprompter, transfer, clipboard, bluetooth, retro',
    'ContextInterfaceSelection clipboard case'
)

settings = replace_once(
    settings,
    '    @AppStorage("HaloContextTransferEnabled") private var transferEnabled = true\n    @AppStorage("HaloContextBluetoothEnabled") private var bluetoothEnabled = false',
    '    @AppStorage("HaloContextTransferEnabled") private var transferEnabled = true\n    @AppStorage("HaloContextClipboardEnabled") private var clipboardEnabled = true\n    @AppStorage("HaloContextBluetoothEnabled") private var bluetoothEnabled = false',
    'Clipboard library enabled state'
)

settings = replace_once(
    settings,
    '                    TransferContextInterfaceCard(enabled: transferEnabled) {\n                        withAnimation(.easeInOut(duration: 0.18)) { selection = .transfer }\n                    }\n                    BluetoothContextInterfaceCard(enabled: bluetoothEnabled) {',
    '                    TransferContextInterfaceCard(enabled: transferEnabled) {\n                        withAnimation(.easeInOut(duration: 0.18)) { selection = .transfer }\n                    }\n                    ClipboardContextInterfaceCard(enabled: clipboardEnabled) {\n                        withAnimation(.easeInOut(duration: 0.18)) { selection = .clipboard }\n                    }\n                    BluetoothContextInterfaceCard(enabled: bluetoothEnabled) {',
    'Clipboard library card insertion'
)

clipboard_detail = r'''        } else if selection == .clipboard {
            Section {
                HStack(spacing: 12) {
                    Button { withAnimation(.easeInOut(duration: 0.18)) { selection = nil } } label: { Label("All CI", systemImage: "chevron.left") }
                    Spacer()
                    Label("Clipboard CI", systemImage: "doc.on.clipboard.fill").font(.headline)
                }
            }
            ClipboardContextSettings()
'''
settings = replace_once(
    settings,
    '        } else if selection == .transfer {',
    clipboard_detail + '        } else if selection == .transfer {',
    'Clipboard settings detail route'
)

clipboard_settings = r'''
private struct ClipboardContextInterfaceCard: View {
    let enabled: Bool
    let action: () -> Void
    @AppStorage("HaloContextClipboardPriority") private var priority = 68.0
    @AppStorage("HaloContextClipboardTriggerMode") private var triggerMode = "Hover to Open"
    @AppStorage("HaloContextClipboardTimeoutSeconds") private var timeout = 8.0
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 38, height: 38)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clipboard CI").font(.headline)
                        Text("Copy Actions").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(enabled ? "ON COPY" : "OFF")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background((enabled ? Color.accentColor : Color.secondary).opacity(0.12), in: Capsule())
                }
                Text("Turns the notch into a contextual action bar after you copy text, links, email addresses, phone numbers, files, JSON or addresses.")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(3)
                HStack(spacing: 7) {
                    Label(triggerMode, systemImage: triggerMode == "Pop Up" ? "rectangle.portrait.and.arrow.forward" : "cursorarrow.motionlines")
                    Text("•")
                    Text("\(Int(timeout))s")
                    Text("•")
                    Text("Priority \(Int(priority))")
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(hovered ? 0.075 : 0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(hovered ? Color.accentColor.opacity(0.42) : Color.primary.opacity(0.08), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.14), value: hovered)
    }
}

private struct ClipboardContextSettings: View {
    @AppStorage("HaloContextClipboardEnabled") private var enabled = true
    @AppStorage("HaloContextClipboardPriority") private var priority = 68.0
    @AppStorage("HaloContextClipboardTriggerMode") private var triggerMode = "Hover to Open"
    @AppStorage("HaloContextClipboardTimeoutSeconds") private var timeout = 8.0
    @AppStorage("HaloContextClipboardCompact") private var compact = false
    @AppStorage("HaloContextClipboardShowClosedPreview") private var showClosedPreview = true
    @AppStorage("HaloContextClipboardShowType") private var showType = true
    @AppStorage("HaloContextClipboardShowSource") private var showSource = true
    @AppStorage("HaloContextClipboardShowCharacterCount") private var showCharacterCount = true
    @AppStorage("HaloContextClipboardPreviewLines") private var previewLines = 3
    @AppStorage("HaloContextClipboardMaxActions") private var maxActions = 5
    @AppStorage("HaloContextClipboardAutoCloseAfterAction") private var autoCloseAfterAction = true
    @AppStorage("HaloContextClipboardShowSearch") private var showSearch = true
    @AppStorage("HaloContextClipboardShowTransforms") private var showTransforms = true
    @AppStorage("HaloContextClipboardSearchEngine") private var searchEngine = "Google"
    @AppStorage("HaloContextClipboardBackgroundStyle") private var backgroundStyle = "Adaptive"
    @AppStorage("HaloContextClipboardExcludedApps") private var excludedApps = ""

    var body: some View {
        Group {
            Section("Activation") {
                Toggle("Enable Clipboard CI", isOn: $enabled)
                Picker("After copying", selection: $triggerMode) {
                    Text("Pop Up").tag("Pop Up")
                    Text("Stay closed — hover to open").tag("Hover to Open")
                }
                LabeledContent("Timeout") {
                    Slider(value: $timeout, in: 1...60, step: 1)
                    Text("\(Int(timeout)) s").font(.caption.monospacedDigit()).frame(width: 48)
                }
                Text(triggerMode == "Pop Up"
                     ? "A copy immediately opens Clipboard CI. It closes again when the timeout expires unless Halo is pinned."
                     : "A copy replaces the closed notch with Clipboard CI, but does not open it. Hovering the notch opens it even if Halo's global hover-to-expand setting is off. The timeout pauses while you are interacting with the opened CI.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Context priority") {
                LabeledContent("Priority") {
                    Slider(value: $priority, in: 0...100, step: 1)
                    Text("\(Int(priority))").font(.caption.monospacedDigit()).frame(width: 36)
                }
                Text("Higher-priority Context Interfaces win when several contexts are active at once. Clipboard defaults just below Teleprompter and above Transfer.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Layout") {
                Toggle("Compact opened layout", isOn: $compact)
                Toggle("Show copied preview while closed", isOn: $showClosedPreview)
                Toggle("Show content type", isOn: $showType)
                Toggle("Show source app", isOn: $showSource)
                Toggle("Show character / word count", isOn: $showCharacterCount)
                LabeledContent("Preview lines") {
                    Stepper("\(previewLines)", value: $previewLines, in: 1...6).labelsHidden()
                    Text("\(previewLines)").font(.caption.monospacedDigit()).frame(width: 24)
                }
                LabeledContent("Maximum actions") {
                    Stepper("\(maxActions)", value: $maxActions, in: 2...8).labelsHidden()
                    Text("\(maxActions)").font(.caption.monospacedDigit()).frame(width: 24)
                }
                Text("Both the closed and opened notch resize from the content you choose to show. Disabling preview/details makes Clipboard CI physically smaller.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Actions") {
                Toggle("Offer web search", isOn: $showSearch)
                Picker("Search engine", selection: $searchEngine) {
                    Text("Google").tag("Google")
                    Text("DuckDuckGo").tag("DuckDuckGo")
                    Text("Bing").tag("Bing")
                }.disabled(!showSearch)
                Toggle("Offer text transforms", isOn: $showTransforms)
                Toggle("Dismiss CI after an action", isOn: $autoCloseAfterAction)
                Text("Halo chooses actions from the copied content: open links, compose email, FaceTime numbers, reveal files, pretty-print JSON, open addresses in Maps, search text, transform text, or copy the result.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Background", selection: $backgroundStyle) {
                    Text("Adaptive tint").tag("Adaptive")
                    Text("Glass").tag("Glass")
                    Text("Black").tag("Black")
                }
                Text("Adaptive tint changes subtly with the copied content type while keeping the notch dark and readable.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Privacy") {
                TextField("Excluded app bundle IDs, comma-separated", text: $excludedApps)
                Text("Clipboard CI only inspects a new pasteboard item while this CI is enabled. macOS concealed/transient clipboard types are ignored, excluded apps suppress the trigger, and Clipboard CI itself does not persist copied content to disk.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

'''

settings = replace_once(
    settings,
    'private struct TransferContextInterfaceCard: View {',
    clipboard_settings + 'private struct TransferContextInterfaceCard: View {',
    'Clipboard card/settings definitions'
)

surface_path.write_text(surface)
settings_path.write_text(settings)
print("Clipboard CI patch applied")
