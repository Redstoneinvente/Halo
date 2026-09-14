from pathlib import Path
import re

surface_path = Path('Halo/Views/SurfaceView.swift')
settings_path = Path('Halo/Views/WorkspaceSettingsView.swift')

surface = surface_path.read_text()
settings = settings_path.read_text()

if 'import UniformTypeIdentifiers' not in surface:
    surface = surface.replace('import AppKit\n', 'import AppKit\nimport UniformTypeIdentifiers\n', 1)

clipboard_runtime = r'''private enum ClipboardContextKind: String {
    case link = "Link"
    case email = "Email"
    case phone = "Phone"
    case file = "File"
    case image = "Image"
    case video = "Video"
    case json = "JSON"
    case address = "Address"
    case text = "Text"

    var symbol: String {
        switch self {
        case .link: return "link"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .file: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
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
        case .image: return Color(hue: 0.88, saturation: 0.52, brightness: 1.0)
        case .video: return Color(hue: 0.73, saturation: 0.62, brightness: 1.0)
        case .json: return Color(hue: 0.78, saturation: 0.58, brightness: 1.0)
        case .address: return Color(hue: 0.02, saturation: 0.72, brightness: 1.0)
        case .text: return Color(hue: 0.62, saturation: 0.16, brightness: 0.98)
        }
    }

    var isMedia: Bool { self == .image || self == .video }
}

private struct ClipboardContextAction: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
}

private struct ClipboardHistoryItem: Identifiable {
    let id = UUID()
    let text: String
    let kind: ClipboardContextKind
    let sourceAppName: String
    let copiedAt: Date
    let image: NSImage?
    let fileURL: URL?

    var preview: String {
        if let fileURL { return fileURL.lastPathComponent }
        if kind == .image { return text.isEmpty ? "Copied image" : text }
        let collapsed = text
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return String(collapsed.prefix(90))
    }
}

@MainActor
private final class ClipboardContextMonitor: ObservableObject {
    static let shared = ClipboardContextMonitor()

    @Published private(set) var text = ""
    @Published private(set) var kind: ClipboardContextKind = .text
    @Published private(set) var image: NSImage?
    @Published private(set) var fileURL: URL?
    @Published private(set) var history: [ClipboardHistoryItem] = []
    @Published private(set) var isActive = false
    @Published private(set) var copiedAt: Date?
    @Published private(set) var expiresAt: Date?
    @Published private(set) var remainingFraction = 0.0
    @Published private(set) var remainingSeconds = 0.0
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
        if let fileURL { return fileURL.lastPathComponent }
        if kind == .image { return text.isEmpty ? "Copied image" : text }
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
        case .image:
            if fileURL != nil {
                result += [
                    .init(id: "openFile", title: "Open Image", symbol: "photo"),
                    .init(id: "reveal", title: "Reveal", symbol: "folder")
                ]
            } else {
                result.append(.init(id: "saveImage", title: "Save Image", symbol: "square.and.arrow.down"))
            }
        case .video:
            result += [
                .init(id: "openFile", title: "Open Video", symbol: "play.rectangle.fill"),
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

        let copyTitle: String
        switch kind {
        case .image: copyTitle = "Copy Image"
        case .video: copyTitle = "Copy Video"
        case .file: copyTitle = "Copy Path"
        default: copyTitle = "Copy"
        }
        result.append(.init(id: "copy", title: copyTitle, symbol: "doc.on.doc"))
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

    func clearHistory() {
        history.removeAll()
    }

    func activateHistory(_ item: ClipboardHistoryItem) {
        text = item.text
        kind = item.kind
        image = item.image
        fileURL = item.fileURL
        sourceAppName = item.sourceAppName
        copiedAt = item.copiedAt
        restartTimeout()
        eventSerial &+= 1
        isActive = true
    }

    func perform(_ action: ClipboardContextAction) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch action.id {
        case "open":
            if let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
        case "openFile":
            if let url = fileURL ?? existingFileURL(from: trimmed) { NSWorkspace.shared.open(url) }
        case "reveal":
            if let url = fileURL ?? existingFileURL(from: trimmed) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
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
        case "saveImage":
            if let image { saveImage(image) }
        case "copy":
            if kind == .image, let image {
                writeImageToPasteboard(image)
            } else if (kind == .video || kind == .image), let fileURL {
                writeFileToPasteboard(fileURL)
            } else {
                writeToPasteboard(text)
            }
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
        // Hovering the Clipboard CI pauses its lifetime regardless of trigger mode.
        // This is pointer-driven, not merely "the notch happens to be expanded".
        if interactionActive {
            expiresAt = expiry.addingTimeInterval(interval)
        }
        let timeout = timeoutSeconds
        let remaining = max(0, expiresAt?.timeIntervalSinceNow ?? 0)
        remainingSeconds = remaining
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

        var capturedText: String?
        var capturedKind: ClipboardContextKind = .text
        var capturedImage: NSImage?
        var capturedFileURL: URL?

        if let rawFile = board.string(forType: .fileURL),
           let url = URL(string: rawFile), url.isFileURL {
            capturedFileURL = url
            capturedText = url.path
            capturedKind = classifyFile(url)
            if capturedKind == .image { capturedImage = NSImage(contentsOf: url) }
        } else if let pastedImage = readImage(from: board) {
            capturedImage = pastedImage
            capturedKind = .image
            let size = pastedImage.size
            capturedText = "Copied image · \(Int(size.width.rounded()))×\(Int(size.height.rounded()))"
        } else if let raw = board.string(forType: .string),
                  !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  raw.utf8.count <= 250_000 {
            capturedText = raw
            capturedKind = classify(raw)
        }

        guard let capturedText else {
            deactivate()
            return
        }

        text = capturedText
        kind = capturedKind
        image = capturedImage
        fileURL = capturedFileURL
        sourceAppName = app?.localizedName ?? "Mac"
        copiedAt = Date()
        restartTimeout()
        appendCurrentToHistory()
        eventSerial &+= 1
        isActive = true
    }

    private func classify(_ raw: String) -> ClipboardContextKind {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if FileManager.default.fileExists(atPath: value) { return classifyFile(URL(fileURLWithPath: value)) }

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

    private func classifyFile(_ url: URL) -> ClipboardContextKind {
        if let type = UTType(filenameExtension: url.pathExtension) {
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .movie) { return .video }
        }
        return .file
    }

    private func readImage(from board: NSPasteboard) -> NSImage? {
        let types: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.jpeg"),
            .tiff
        ]
        for type in types {
            if let data = board.data(forType: type), data.count <= 30_000_000,
               let image = NSImage(data: data) {
                return image
            }
        }
        return nil
    }

    private func appendCurrentToHistory() {
        guard boolDefault("HaloContextClipboardHistoryEnabled", true) else { return }
        let limit = historyLimit
        let item = ClipboardHistoryItem(
            text: text,
            kind: kind,
            sourceAppName: sourceAppName,
            copiedAt: copiedAt ?? Date(),
            image: image,
            fileURL: fileURL
        )
        history.insert(item, at: 0)
        if history.count > limit { history.removeLast(history.count - limit) }
    }

    private var historyLimit: Int {
        let defaults = UserDefaults.standard
        let configured = defaults.object(forKey: "HaloContextClipboardHistoryLimit") == nil
            ? 8 : defaults.integer(forKey: "HaloContextClipboardHistoryLimit")
        return min(20, max(2, configured))
    }

    private func restartTimeout() {
        let timeout = timeoutSeconds
        let now = Date()
        expiresAt = now.addingTimeInterval(timeout)
        remainingSeconds = timeout
        remainingFraction = 1
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
        remainingSeconds = 0
        interactionActive = false
    }

    private func existingFileURL(from value: String) -> URL? {
        guard FileManager.default.fileExists(atPath: value) else { return nil }
        return URL(fileURLWithPath: value)
    }

    private func writeToPasteboard(_ value: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(value, forType: .string)
        changeCount = board.changeCount
    }

    private func writeImageToPasteboard(_ image: NSImage) {
        let board = NSPasteboard.general
        board.clearContents()
        board.writeObjects([image])
        changeCount = board.changeCount
    }

    private func writeFileToPasteboard(_ url: URL) {
        let board = NSPasteboard.general
        board.clearContents()
        board.writeObjects([url as NSURL])
        changeCount = board.changeCount
    }

    private func saveImage(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Clipboard Image.png"
        guard panel.runModal() == .OK, let url = panel.url,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url, options: .atomic)
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

'''

pattern = re.compile(r'private enum ClipboardContextKind: String \{.*?\n\}\n\nprivate enum ClipboardCISizing', re.S)
match = pattern.search(surface)
if not match:
    raise SystemExit('Clipboard runtime block not found')
surface = surface[:match.start()] + clipboard_runtime + 'private enum ClipboardCISizing' + surface[match.end():]

sizing = r'''private enum ClipboardCISizing {
    static func minimumExpandedWidth(physicalNotchWidth: CGFloat) -> CGFloat {
        max(360, physicalNotchWidth > 0 ? physicalNotchWidth + 120 : 360)
    }

    @MainActor
    static func closedPreferredWidth(monitor: ClipboardContextMonitor, physicalNotchWidth: CGFloat) -> CGFloat {
        let defaults = UserDefaults.standard
        let showPreview = defaults.object(forKey: "HaloContextClipboardShowClosedPreview") == nil
            ? true : defaults.bool(forKey: "HaloContextClipboardShowClosedPreview")
        let physicalFloor = physicalNotchWidth > 0 ? physicalNotchWidth + 18 : 118
        guard showPreview else { return max(physicalFloor, 156) }
        let estimated = CGFloat(min(44, monitor.preview.count)) * 5.3 + 130
        return min(540, max(physicalFloor, max(220, estimated)))
    }

    static func openPreferredSize(actionCount: Int? = nil, historyCount: Int = 0, kind: ClipboardContextKind = .text) -> CGSize {
        let defaults = UserDefaults.standard
        let compact = defaults.bool(forKey: "HaloContextClipboardCompact")
        let lines = defaults.object(forKey: "HaloContextClipboardPreviewLines") == nil
            ? 3 : min(6, max(1, defaults.integer(forKey: "HaloContextClipboardPreviewLines")))
        let historyEnabled = defaults.object(forKey: "HaloContextClipboardHistoryEnabled") == nil
            ? true : defaults.bool(forKey: "HaloContextClipboardHistoryEnabled")
        let showHistory = defaults.object(forKey: "HaloContextClipboardShowHistory") == nil
            ? true : defaults.bool(forKey: "HaloContextClipboardShowHistory")
        let count = max(1, actionCount ?? 5)
        let columns = compact ? min(3, count) : min(4, count)
        let rows = Int(ceil(Double(count) / Double(max(1, columns))))
        let width: CGFloat = compact ? max(410, CGFloat(columns) * 126 + 48) : max(520, CGFloat(columns) * 138 + 54)
        let baseHeight: CGFloat = compact ? 116 : 144
        let previewHeight: CGFloat
        switch kind {
        case .image: previewHeight = compact ? 94 : 132
        case .video: previewHeight = compact ? 62 : 78
        default: previewHeight = CGFloat(lines) * (compact ? 13 : 16)
        }
        let actionHeight = CGFloat(rows) * (compact ? 38 : 44)
        let historyHeight: CGFloat = historyEnabled && showHistory && historyCount > 1 ? (compact ? 62 : 74) : 0
        return CGSize(width: min(780, width), height: min(520, baseHeight + previewHeight + actionHeight + historyHeight))
    }
}

'''
pattern = re.compile(r'private enum ClipboardCISizing \{.*?\n\}\n\nprivate struct ClipboardSurfaceBackground', re.S)
match = pattern.search(surface)
if not match:
    raise SystemExit('Clipboard sizing block not found')
surface = surface[:match.start()] + sizing + 'private struct ClipboardSurfaceBackground' + surface[match.end():]

closed_view = r'''private struct ClipboardClosedContextView: View {
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
            Text("\(max(0, Int(ceil(monitor.remainingSeconds))))s")
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.46))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.white.opacity(0.055), in: Capsule())
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
            surfaceState.contextPreferredSize = ClipboardCISizing.openPreferredSize(
                actionCount: monitor.actions.count,
                historyCount: monitor.history.count,
                kind: monitor.kind
            )
        }
    }
}

'''
pattern = re.compile(r'private struct ClipboardClosedContextView: View \{.*?\n\}\n\nprivate struct ClipboardContextView', re.S)
match = pattern.search(surface)
if not match:
    raise SystemExit('Clipboard closed view not found')
surface = surface[:match.start()] + closed_view + 'private struct ClipboardContextView' + surface[match.end():]

open_view = r'''private struct ClipboardContextView: View {
    @ObservedObject var monitor: ClipboardContextMonitor
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextClipboardCompact") private var compact = false
    @AppStorage("HaloContextClipboardPreviewLines") private var previewLines = 3
    @AppStorage("HaloContextClipboardShowType") private var showType = true
    @AppStorage("HaloContextClipboardShowSource") private var showSource = true
    @AppStorage("HaloContextClipboardShowCharacterCount") private var showCharacterCount = true
    @AppStorage("HaloContextClipboardMaxActions") private var maxActions = 5
    @AppStorage("HaloContextClipboardHistoryEnabled") private var historyEnabled = true
    @AppStorage("HaloContextClipboardShowHistory") private var showHistory = true
    @AppStorage("HaloContextClipboardHistoryLimit") private var historyLimit = 8

    private var sizingSignature: String {
        [compact.description, String(previewLines), showType.description, showSource.description,
         showCharacterCount.description, String(maxActions), String(monitor.actions.count),
         historyEnabled.description, showHistory.description, String(historyLimit),
         String(monitor.history.count), monitor.kind.rawValue].joined(separator: "|")
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
                Text("\(max(0, Int(ceil(monitor.remainingSeconds))))s")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.055), in: Capsule())
                    .help("Time remaining — pauses while the pointer is over Clipboard CI")
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

            payloadPreview

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

            if historyEnabled && showHistory && monitor.history.count > 1 {
                historyStrip
            }

            footer
        }
        .padding(.horizontal, compact ? 13 : 16)
        .padding(.vertical, compact ? 11 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { updateSizing() }
        .onChange(of: monitor.eventSerial) { _ in updateSizing() }
        .onChange(of: sizingSignature) { _ in updateSizing() }
    }

    @ViewBuilder private var payloadPreview: some View {
        if monitor.kind == .image, let image = monitor.image {
            ZStack(alignment: .bottomLeading) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: compact ? 92 : 128)
                Text(monitor.preview)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.58), in: Capsule())
                    .padding(7)
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 82 : 112, maxHeight: compact ? 94 : 132)
            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        } else if monitor.kind == .video {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(monitor.kind.accent.opacity(0.12))
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(monitor.kind.accent)
                }
                .frame(width: compact ? 46 : 58, height: compact ? 46 : 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text(monitor.fileURL?.lastPathComponent ?? "Copied video")
                        .font(.system(size: compact ? 10.5 : 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    if let ext = monitor.fileURL?.pathExtension, !ext.isEmpty {
                        Text(ext.uppercased() + " video")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }
                Spacer()
            }
            .padding(compact ? 8 : 10)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
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
        }
    }

    private var historyStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                Text("\(monitor.history.count)")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.30))
                Spacer()
                Button("Clear") { monitor.clearHistory() }
                    .buttonStyle(.plain)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(monitor.history.prefix(min(20, max(2, historyLimit))))) { item in
                        Button { monitor.activateHistory(item) } label: {
                            HStack(spacing: 7) {
                                if item.kind == .image, let image = item.image {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 28, height: 28)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                } else {
                                    Image(systemName: item.kind.symbol)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(item.kind.accent)
                                        .frame(width: 28, height: 28)
                                        .background(item.kind.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.preview)
                                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.72))
                                        .lineLimit(1)
                                    Text(item.kind.rawValue)
                                        .font(.system(size: 7.5, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.32))
                                }
                            }
                            .padding(.horizontal, 7)
                            .frame(width: compact ? 126 : 148, height: compact ? 38 : 44, alignment: .leading)
                            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder private var footer: some View {
        if showCharacterCount {
            HStack(spacing: 8) {
                if monitor.kind == .image, let image = monitor.image {
                    Text("\(Int(image.size.width.rounded())) × \(Int(image.size.height.rounded()))")
                    Text("•")
                    Text("image")
                } else if monitor.kind == .video {
                    Text(monitor.fileURL?.pathExtension.uppercased() ?? "VIDEO")
                    Text("•")
                    Text("media file")
                } else {
                    Text("\(monitor.text.count) characters")
                    Text("•")
                    Text("\(monitor.text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count) words")
                }
                Spacer()
                Text(monitor.triggerMode == "Pop Up" ? "Auto popup" : "Hover to open")
            }
            .font(.system(size: 8.5, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.32))
        }
    }

    private func updateSizing() {
        surfaceState.contextMinimumExpandedWidth = ClipboardCISizing.minimumExpandedWidth(physicalNotchWidth: surfaceState.physicalNotchWidth)
        surfaceState.contextPreferredCompactWidth = ClipboardCISizing.closedPreferredWidth(monitor: monitor, physicalNotchWidth: surfaceState.physicalNotchWidth)
        surfaceState.contextPreferredSize = ClipboardCISizing.openPreferredSize(
            actionCount: monitor.actions.count,
            historyCount: monitor.history.count,
            kind: monitor.kind
        )
    }
}

'''
pattern = re.compile(r'private struct ClipboardContextView: View \{.*?\n\}\n\nprivate enum ActiveContextInterface', re.S)
match = pattern.search(surface)
if not match:
    raise SystemExit('Clipboard open view not found')
surface = surface[:match.start()] + open_view + 'private enum ActiveContextInterface' + surface[match.end():]

# Ensure hover, not expanded state, is the authoritative timeout pause source.
old_hover = '''        .onHover { hovering in\n            if teleprompterContextActive {\n                state.collapseTask?.cancel()\n                if !state.pinned { state.expanded = false }\n            } else {\n                let clipboardHover = clipboardContextActive && clipboardCI.triggerMode == "Hover to Open"\n                state.hover(hovering, enabled: store.configuration.hoverToExpand || clipboardHover)\n            }\n        }'''
new_hover = '''        .onHover { hovering in\n            clipboardCI.setInteractionActive(clipboardContextActive && hovering)\n            if teleprompterContextActive {\n                state.collapseTask?.cancel()\n                if !state.pinned { state.expanded = false }\n            } else {\n                let clipboardHover = clipboardContextActive && clipboardCI.triggerMode == "Hover to Open"\n                state.hover(hovering, enabled: store.configuration.hoverToExpand || clipboardHover)\n            }\n        }'''
if old_hover not in surface:
    raise SystemExit('Surface hover block not found')
surface = surface.replace(old_hover, new_hover, 1)

old_expanded_interaction = '''        .onChange(of: state.expanded) { expanded in\n            clipboardCI.setInteractionActive(expanded && clipboardContextActive)\n            if !expanded { clipboardOpenedNotch = false }\n        }'''
new_expanded_interaction = '''        .onChange(of: state.expanded) { expanded in\n            if !expanded { clipboardOpenedNotch = false }\n        }'''
if old_expanded_interaction not in surface:
    raise SystemExit('Clipboard expanded interaction block not found')
surface = surface.replace(old_expanded_interaction, new_expanded_interaction, 1)

surface = surface.replace('                clipboardCI.setInteractionActive(state.expanded)\n', '', 1)

surface = surface.replace(
    'ClipboardCISizing.openPreferredSize(actionCount: clipboardCI.actions.count)',
    'ClipboardCISizing.openPreferredSize(actionCount: clipboardCI.actions.count, historyCount: clipboardCI.history.count, kind: clipboardCI.kind)'
)

# Settings: update card copy if the exact earlier text is still present.
settings = settings.replace(
    'Turns the notch into a contextual action bar after you copy text, links, email addresses, phone numbers, files, JSON or addresses.',
    'Turns the notch into a contextual action bar after you copy text, links, images, videos, files and more — with optional in-memory history.'
)

settings_block = r'''private struct ClipboardContextSettings: View {
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
    @AppStorage("HaloContextClipboardHistoryEnabled") private var historyEnabled = true
    @AppStorage("HaloContextClipboardShowHistory") private var showHistory = true
    @AppStorage("HaloContextClipboardHistoryLimit") private var historyLimit = 8

    var body: some View {
        Group {
            Section("Activation") {
                Toggle("Enable Clipboard CI", isOn: $enabled)
                Picker("After copying", selection: $triggerMode) {
                    Text("Pop Up").tag("Pop Up")
                    Text("Stay closed — hover to open").tag("Hover to Open")
                }
                LabeledContent("Timeout") {
                    Slider(value: $timeout, in: 1...120, step: 1)
                    Text("\(Int(timeout)) s").font(.caption.monospacedDigit()).frame(width: 52)
                }
                Text(triggerMode == "Pop Up"
                     ? "A copy immediately opens Clipboard CI. The countdown pauses only while your pointer is over the CI, then resumes when you leave."
                     : "A copy replaces the closed notch with Clipboard CI without opening it. Hovering opens it even if Halo's global hover-to-expand setting is off. The countdown pauses while your pointer is over the CI.")
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
                Toggle("Show content details", isOn: $showCharacterCount)
                LabeledContent("Text preview lines") {
                    Stepper("\(previewLines)", value: $previewLines, in: 1...6).labelsHidden()
                    Text("\(previewLines)").font(.caption.monospacedDigit()).frame(width: 24)
                }
                LabeledContent("Maximum actions") {
                    Stepper("\(maxActions)", value: $maxActions, in: 2...8).labelsHidden()
                    Text("\(maxActions)").font(.caption.monospacedDigit()).frame(width: 24)
                }
                Text("Clipboard CI resizes for the selected content. Images get a visual preview, videos get a media card, and text uses your chosen number of preview lines.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Clipboard history") {
                Toggle("Keep in-memory history", isOn: $historyEnabled)
                Toggle("Show history in Clipboard CI", isOn: $showHistory).disabled(!historyEnabled)
                LabeledContent("History items") {
                    Stepper("\(historyLimit)", value: $historyLimit, in: 2...20)
                        .labelsHidden()
                    Text("\(historyLimit)").font(.caption.monospacedDigit()).frame(width: 28)
                }
                .disabled(!historyEnabled)
                Text("History can contain text, links, file references, image previews and videos. It lives only in memory and is cleared when Halo quits; sensitive/transient clipboard types are never added.")
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
                Text("Actions adapt to the payload: open links, compose email, FaceTime numbers, reveal files, open videos, preview/save/copy images, pretty-print JSON, open addresses in Maps, search text, transform text, or restore an earlier history item.")
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
                Text("Clipboard CI only inspects a new pasteboard item while this CI is enabled. macOS concealed/transient clipboard types are ignored, excluded apps suppress the trigger, and Clipboard CI never persists clipboard contents or history to disk.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

'''
pattern = re.compile(r'private struct ClipboardContextSettings: View \{.*?\n\}\n\nprivate struct TransferContextInterfaceCard', re.S)
match = pattern.search(settings)
if not match:
    raise SystemExit('Clipboard settings block not found')
settings = settings[:match.start()] + settings_block + 'private struct TransferContextInterfaceCard' + settings[match.end():]

surface_path.write_text(surface)
settings_path.write_text(settings)

print('Enhanced Clipboard CI with hover-paused seconds countdown, image/video payloads, and history.')
