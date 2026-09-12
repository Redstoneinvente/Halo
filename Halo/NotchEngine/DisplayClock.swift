import AppKit
import SwiftUI
import QuartzCore
import UniformTypeIdentifiers
import ImageIO

// MARK: - Drop CI zones

enum HaloDropZoneLayout: String, Codable, CaseIterable, Identifiable {
    case adaptive = "Adaptive"
    case horizontal = "Horizontal"
    case vertical = "Vertical"
    case twoColumns = "2 Columns"
    case threeColumns = "3 Columns"
    case fourColumns = "4 Columns"
    case spotlight = "Spotlight"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .adaptive: return "square.grid.2x2"
        case .horizontal: return "rectangle.split.3x1"
        case .vertical: return "rectangle.split.1x2"
        case .twoColumns: return "rectangle.split.2x1"
        case .threeColumns: return "rectangle.split.3x1"
        case .fourColumns: return "square.grid.4x3.fill"
        case .spotlight: return "rectangle.split.2x1.fill"
        }
    }
}

enum HaloDropZoneAcceptance: String, Codable, CaseIterable, Identifiable {
    case all = "Anything"
    case files = "Files"
    case folders = "Folders"
    case images = "Images"
    case video = "Video"
    case audio = "Audio"
    case archives = "Archives"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .all: return "square.stack.3d.up"
        case .files: return "doc"
        case .folders: return "folder"
        case .images: return "photo"
        case .video: return "film"
        case .audio: return "waveform"
        case .archives: return "archivebox"
        }
    }

    func accepts(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        let directory = values?.isDirectory == true
        switch self {
        case .all: return true
        case .files: return !directory
        case .folders: return directory
        case .images, .video, .audio, .archives:
            guard !directory, let type = UTType(filenameExtension: url.pathExtension) else { return false }
            switch self {
            case .images: return type.conforms(to: .image)
            case .video: return type.conforms(to: .movie)
            case .audio: return type.conforms(to: .audio)
            case .archives: return type.conforms(to: .archive) || type.conforms(to: .zip)
            default: return false
            }
        }
    }
}

enum HaloDropZoneAction: String, Codable, CaseIterable, Identifiable {
    case shelf = "Add to Shelf"
    case quickLook = "Quick Look"
    case open = "Open"
    case reveal = "Reveal in Finder"
    case copyPath = "Copy Path"
    case copyName = "Copy Name"
    case copyURL = "Copy File URL"
    case duplicate = "Duplicate"
    case rename = "Rename"
    case compress = "Compress to ZIP"
    case extract = "Extract ZIP"
    case convertPNG = "Convert to PNG"
    case convertJPEG = "Convert to JPEG"
    case copyDesktop = "Copy to Desktop"
    case copyDownloads = "Copy to Downloads"
    case copyFolder = "Copy to Custom Folder"
    case wallpaper = "Set as Wallpaper"
    case trash = "Move to Trash"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .shelf: return "tray.and.arrow.down.fill"
        case .quickLook: return "eye.fill"
        case .open: return "arrow.up.forward.app.fill"
        case .reveal: return "folder.fill"
        case .copyPath: return "doc.on.clipboard"
        case .copyName: return "textformat"
        case .copyURL: return "link"
        case .duplicate: return "plus.square.on.square"
        case .rename: return "pencil"
        case .compress: return "archivebox.fill"
        case .extract: return "archivebox"
        case .convertPNG, .convertJPEG: return "arrow.triangle.2.circlepath"
        case .copyDesktop: return "desktopcomputer"
        case .copyDownloads: return "arrow.down.circle.fill"
        case .copyFolder: return "folder.badge.plus"
        case .wallpaper: return "photo.on.rectangle.angled"
        case .trash: return "trash.fill"
        }
    }

    var isDestructive: Bool { self == .rename || self == .trash }
}

struct HaloDropZone: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var subtitle: String
    var symbol: String
    var action: HaloDropZoneAction
    var accepts: HaloDropZoneAcceptance
    var color: WidgetColor
    var parameter: String = ""
    var alsoAddToShelf = false

    static func preset(_ action: HaloDropZoneAction, index: Int = 0) -> HaloDropZone {
        let palette: [WidgetColor] = [
            WidgetColor(red: 0.20, green: 0.55, blue: 1.0),
            WidgetColor(red: 0.55, green: 0.35, blue: 1.0),
            WidgetColor(red: 0.20, green: 0.78, blue: 0.52),
            WidgetColor(red: 1.0, green: 0.58, blue: 0.18),
            WidgetColor(red: 0.95, green: 0.30, blue: 0.52),
            WidgetColor(red: 0.15, green: 0.72, blue: 0.82),
            WidgetColor(red: 0.72, green: 0.44, blue: 0.95),
            WidgetColor(red: 0.85, green: 0.34, blue: 0.28)
        ]

        let acceptance: HaloDropZoneAcceptance
        let subtitle: String
        let parameter: String
        switch action {
        case .shelf:
            acceptance = .all; subtitle = "Keep a reference in Halo"; parameter = ""
        case .quickLook:
            acceptance = .all; subtitle = "Preview without opening"; parameter = ""
        case .compress:
            acceptance = .all; subtitle = "Create a ZIP beside it"; parameter = ""
        case .copyPath:
            acceptance = .all; subtitle = "Copy paths to clipboard"; parameter = ""
        case .convertPNG:
            acceptance = .images; subtitle = "Create a PNG copy"; parameter = ""
        case .convertJPEG:
            acceptance = .images; subtitle = "Create a JPEG copy"; parameter = ""
        case .extract:
            acceptance = .archives; subtitle = "Extract ZIP archive"; parameter = ""
        case .rename:
            acceptance = .all; subtitle = "Rename with a template"; parameter = "{name}-renamed"
        case .copyFolder:
            acceptance = .all; subtitle = "Copy to a chosen folder"; parameter = ""
        case .trash:
            acceptance = .all; subtitle = "Move originals to Trash"; parameter = ""
        default:
            acceptance = .all; subtitle = action.rawValue; parameter = ""
        }

        return HaloDropZone(
            title: action.rawValue,
            subtitle: subtitle,
            symbol: action.symbol,
            action: action,
            accepts: acceptance,
            color: palette[index % palette.count],
            parameter: parameter
        )
    }
}

struct HaloDropZoneConfiguration: Codable, Equatable {
    var version = 2
    var layout: HaloDropZoneLayout = .adaptive
    var zones: [HaloDropZone] = [
        .preset(.shelf, index: 0),
        .preset(.quickLook, index: 1),
        .preset(.compress, index: 2),
        .preset(.copyPath, index: 3)
    ]
    var boardPadding = 10.0
    var zoneSpacing = 8.0
    var cornerRadius = 18.0
    var backgroundOpacity = 0.94
    var highlightStrength = 0.85
    var showIcons = true
    var showSubtitles = true
    var showActionBadges = true
    var headerTitle = "Drop into Halo"
    var headerSubtitle = "Choose what should happen to the dragged item"

    mutating func normalize() {
        if zones.count > 8 { zones = Array(zones.prefix(8)) }
        boardPadding = min(28, max(0, boardPadding))
        zoneSpacing = min(24, max(2, zoneSpacing))
        cornerRadius = min(36, max(6, cornerRadius))
        backgroundOpacity = min(1, max(0.45, backgroundOpacity))
        highlightStrength = min(1, max(0.15, highlightStrength))
        headerTitle = String(headerTitle.prefix(80))
        headerSubtitle = String(headerSubtitle.prefix(160))
        for index in zones.indices {
            zones[index].title = String(zones[index].title.prefix(60))
            zones[index].subtitle = String(zones[index].subtitle.prefix(120))
            zones[index].symbol = String(zones[index].symbol.prefix(80))
            zones[index].parameter = String(zones[index].parameter.prefix(500))
        }
    }
}

@MainActor
final class HaloDropZoneSettingsStore: ObservableObject {
    static let shared = HaloDropZoneSettingsStore()
    private let defaults = UserDefaults.standard
    private let key = "HaloDropZones.v2"

    @Published var configuration: HaloDropZoneConfiguration {
        didSet { persist() }
    }

    private init() {
        if let data = defaults.data(forKey: key),
           var decoded = try? JSONDecoder().decode(HaloDropZoneConfiguration.self, from: data) {
            decoded.normalize()
            configuration = decoded
        } else {
            configuration = HaloDropZoneConfiguration()
        }
    }

    func reset() { configuration = HaloDropZoneConfiguration() }

    func addZone() {
        guard configuration.zones.count < 8 else { return }
        var next = configuration
        let suggestions: [HaloDropZoneAction] = [
            .shelf, .quickLook, .compress, .copyPath, .convertPNG, .duplicate, .copyDownloads, .rename
        ]
        next.zones.append(.preset(suggestions[next.zones.count % suggestions.count], index: next.zones.count))
        next.normalize()
        configuration = next
    }

    func removeZone(at index: Int) {
        guard configuration.zones.indices.contains(index) else { return }
        var next = configuration
        next.zones.remove(at: index)
        configuration = next
    }

    func moveZone(from index: Int, by delta: Int) {
        let destination = index + delta
        guard configuration.zones.indices.contains(index), configuration.zones.indices.contains(destination) else { return }
        var next = configuration
        let item = next.zones.remove(at: index)
        next.zones.insert(item, at: destination)
        configuration = next
    }

    private func persist() {
        var next = configuration
        next.normalize()
        guard let data = try? JSONEncoder().encode(next) else { return }
        defaults.set(data, forKey: key)
    }
}

private enum HaloDropZoneLayoutResolver {
    private static let headerHeight: CGFloat = 58
    private static let footerHeight: CGFloat = 22

    static func frames(size: CGSize, configuration: HaloDropZoneConfiguration) -> [CGRect] {
        let count = configuration.zones.count
        guard count > 0, size.width > 80, size.height > 100 else { return [] }

        let padding = CGFloat(configuration.boardPadding)
        let gap = CGFloat(configuration.zoneSpacing)
        let top = headerHeight + padding
        let availableHeight = max(20, size.height - top - footerHeight - padding)
        let rect = CGRect(
            x: padding,
            y: top,
            width: max(20, size.width - padding * 2),
            height: availableHeight
        )

        func grid(columns requested: Int) -> [CGRect] {
            let columns = max(1, min(count, requested))
            let rows = max(1, Int(ceil(Double(count) / Double(columns))))
            let cellWidth = max(1, (rect.width - gap * CGFloat(columns - 1)) / CGFloat(columns))
            let cellHeight = max(1, (rect.height - gap * CGFloat(rows - 1)) / CGFloat(rows))
            return (0..<count).map { index in
                let column = index % columns
                let row = index / columns
                return CGRect(
                    x: rect.minX + CGFloat(column) * (cellWidth + gap),
                    y: rect.minY + CGFloat(row) * (cellHeight + gap),
                    width: cellWidth,
                    height: cellHeight
                )
            }
        }

        switch configuration.layout {
        case .horizontal:
            return grid(columns: count)
        case .vertical:
            return grid(columns: 1)
        case .twoColumns:
            return grid(columns: 2)
        case .threeColumns:
            return grid(columns: 3)
        case .fourColumns:
            return grid(columns: 4)
        case .adaptive:
            switch count {
            case 1: return grid(columns: 1)
            case 2: return grid(columns: 2)
            case 3...4: return grid(columns: 2)
            case 5...6: return grid(columns: 3)
            default: return grid(columns: 4)
            }
        case .spotlight:
            guard count > 1 else { return [rect] }
            let leftWidth = rect.width * 0.44
            let rightX = rect.minX + leftWidth + gap
            let rightWidth = max(1, rect.maxX - rightX)
            let remaining = count - 1
            let rightColumns = remaining <= 3 ? 1 : 2
            let rows = max(1, Int(ceil(Double(remaining) / Double(rightColumns))))
            let cellWidth = max(1, (rightWidth - gap * CGFloat(rightColumns - 1)) / CGFloat(rightColumns))
            let cellHeight = max(1, (rect.height - gap * CGFloat(rows - 1)) / CGFloat(rows))
            var result = [CGRect(x: rect.minX, y: rect.minY, width: leftWidth, height: rect.height)]
            for position in 0..<remaining {
                let column = position % rightColumns
                let row = position / rightColumns
                result.append(CGRect(
                    x: rightX + CGFloat(column) * (cellWidth + gap),
                    y: rect.minY + CGFloat(row) * (cellHeight + gap),
                    width: cellWidth,
                    height: cellHeight
                ))
            }
            return result
        }
    }

    static func index(at localAppKitPoint: CGPoint, size: CGSize, configuration: HaloDropZoneConfiguration) -> Int? {
        let swiftUIPoint = CGPoint(x: localAppKitPoint.x, y: size.height - localAppKitPoint.y)
        return frames(size: size, configuration: configuration).firstIndex { $0.contains(swiftUIPoint) }
    }
}

@MainActor
private protocol HaloGlobalDropTarget: AnyObject {
    var dragStateHandler: ((Bool, Int) -> Void)? { get }
    var dropHandler: (([URL]) -> Void)? { get set }
}

extension HaloDropHostingView: HaloGlobalDropTarget {}

@MainActor
private enum HaloDropZoneActionExecutor {
    static func perform(
        zone: HaloDropZone,
        urls: [URL],
        shelfHandler: (([URL]) -> Void)?,
        closeHandler: () -> Void
    ) -> String {
        let accepted = urls.filter { zone.accepts.accepts($0) }
        guard !accepted.isEmpty else {
            return "Nothing matched this zone's \(zone.accepts.rawValue.lowercased()) filter."
        }

        let outcome: String
        do {
            switch zone.action {
            case .shelf:
                shelfHandler?(accepted)
                outcome = accepted.count == 1 ? "Added to Shelf" : "Added \(accepted.count) items to Shelf"
            case .quickLook:
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
                process.arguments = ["-p"] + accepted.map(\.path)
                try process.run()
                outcome = "Opened Quick Look"
            case .open:
                accepted.forEach { NSWorkspace.shared.open($0) }
                outcome = accepted.count == 1 ? "Opened item" : "Opened \(accepted.count) items"
            case .reveal:
                NSWorkspace.shared.activateFileViewerSelecting(accepted)
                outcome = "Revealed in Finder"
            case .copyPath:
                writeText(accepted.map(\.path).joined(separator: "\n"))
                outcome = accepted.count == 1 ? "Copied path" : "Copied paths"
            case .copyName:
                writeText(accepted.map(\.lastPathComponent).joined(separator: "\n"))
                outcome = accepted.count == 1 ? "Copied name" : "Copied names"
            case .copyURL:
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects(accepted.map { $0 as NSURL })
                outcome = accepted.count == 1 ? "Copied file URL" : "Copied file URLs"
            case .duplicate:
                try accepted.forEach { url in
                    try FileManager.default.copyItem(at: url, to: uniqueSibling(for: url, suffix: " copy"))
                }
                outcome = accepted.count == 1 ? "Created duplicate" : "Created \(accepted.count) duplicates"
            case .rename:
                let template = zone.parameter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "{name}-renamed" : zone.parameter
                try accepted.forEach { try rename($0, template: template) }
                outcome = accepted.count == 1 ? "Renamed item" : "Renamed \(accepted.count) items"
            case .compress:
                try accepted.forEach { try launchDittoCompress($0) }
                outcome = accepted.count == 1 ? "Compression started" : "Started \(accepted.count) ZIP jobs"
            case .extract:
                let archives = accepted.filter { $0.pathExtension.lowercased() == "zip" }
                guard !archives.isEmpty else { return "Extract currently supports ZIP files." }
                try archives.forEach { try launchDittoExtract($0) }
                outcome = archives.count == 1 ? "Extraction started" : "Started \(archives.count) extraction jobs"
            case .convertPNG:
                let count = try convertImages(accepted, output: .png)
                outcome = count == 1 ? "Created PNG copy" : "Created \(count) PNG copies"
            case .convertJPEG:
                let count = try convertImages(accepted, output: .jpeg)
                outcome = count == 1 ? "Created JPEG copy" : "Created \(count) JPEG copies"
            case .copyDesktop:
                let folder = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                try copy(accepted, to: folder)
                outcome = "Copied to Desktop"
            case .copyDownloads:
                let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                try copy(accepted, to: folder)
                outcome = "Copied to Downloads"
            case .copyFolder:
                let path = zone.parameter.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !path.isEmpty else { return "Choose a destination folder in Drop Zone Studio first." }
                let folder = URL(fileURLWithPath: path, isDirectory: true)
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    return "The configured destination folder is unavailable."
                }
                try copy(accepted, to: folder)
                outcome = "Copied to \(folder.lastPathComponent)"
            case .wallpaper:
                guard let image = accepted.first(where: { HaloDropZoneAcceptance.images.accepts($0) }) else {
                    return "Wallpaper needs an image."
                }
                for screen in NSScreen.screens {
                    try? NSWorkspace.shared.setDesktopImageURL(image, for: screen, options: [:])
                }
                outcome = "Wallpaper updated"
            case .trash:
                NSWorkspace.shared.recycle(accepted, completionHandler: nil)
                outcome = accepted.count == 1 ? "Moved to Trash" : "Moved \(accepted.count) items to Trash"
            }
        } catch {
            return "Action failed: \(error.localizedDescription)"
        }

        if zone.action != .shelf && zone.alsoAddToShelf {
            shelfHandler?(accepted)
        } else if zone.action != .shelf {
            closeHandler()
        }
        return outcome
    }

    private enum ImageOutput { case png, jpeg }

    private static func writeText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func uniqueSibling(for url: URL, suffix: String, forcedExtension: String? = nil) -> URL {
        let directory = url.deletingLastPathComponent()
        let ext = forcedExtension ?? url.pathExtension
        let stem = url.deletingPathExtension().lastPathComponent + suffix
        return uniqueURL(in: directory, stem: stem, extension: ext)
    }

    private static func uniqueURL(in directory: URL, stem: String, extension ext: String) -> URL {
        var index = 0
        while true {
            let suffix = index == 0 ? "" : " \(index + 1)"
            let name = ext.isEmpty ? stem + suffix : stem + suffix + "." + ext
            let candidate = directory.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    private static func rename(_ url: URL, template: String) throws {
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var name = template
            .replacingOccurrences(of: "{name}", with: stem)
            .replacingOccurrences(of: "{ext}", with: ext)
            .replacingOccurrences(of: "{date}", with: formatter.string(from: Date()))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = stem + "-renamed" }
        if !ext.isEmpty && !template.contains("{ext}") && URL(fileURLWithPath: name).pathExtension.isEmpty {
            name += "." + ext
        }
        let directory = url.deletingLastPathComponent()
        var destination = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: destination.path) {
            destination = uniqueURL(
                in: directory,
                stem: destination.deletingPathExtension().lastPathComponent,
                extension: destination.pathExtension
            )
        }
        try FileManager.default.moveItem(at: url, to: destination)
    }

    private static func launchDittoCompress(_ url: URL) throws {
        let destination = uniqueSibling(for: url, suffix: "", forcedExtension: "zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", url.path, destination.path]
        try process.run()
    }

    private static func launchDittoExtract(_ url: URL) throws {
        let directory = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        var destination = directory.appendingPathComponent(base + " extracted", isDirectory: true)
        var index = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent(base + " extracted \(index)", isDirectory: true)
            index += 1
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", url.path, destination.path]
        try process.run()
    }

    private static func copy(_ urls: [URL], to folder: URL) throws {
        for url in urls {
            let destination = uniqueURL(
                in: folder,
                stem: url.deletingPathExtension().lastPathComponent,
                extension: url.pathExtension
            )
            try FileManager.default.copyItem(at: url, to: destination)
        }
    }

    private static func convertImages(_ urls: [URL], output: ImageOutput) throws -> Int {
        var converted = 0
        for url in urls {
            guard HaloDropZoneAcceptance.images.accepts(url),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }

            let ext = output == .png ? "png" : "jpg"
            let destination = uniqueSibling(for: url, suffix: " converted", forcedExtension: ext)
            let identifier = output == .png ? UTType.png.identifier : UTType.jpeg.identifier
            guard let writer = CGImageDestinationCreateWithURL(destination as CFURL, identifier as CFString, 1, nil) else { continue }
            let properties: CFDictionary? = output == .jpeg
                ? [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary
                : nil
            CGImageDestinationAddImage(writer, image, properties)
            if CGImageDestinationFinalize(writer) { converted += 1 }
        }
        if converted == 0 { throw CocoaError(.fileReadUnsupportedScheme) }
        return converted
    }
}

// MARK: - Embedded Drop CI board

@MainActor
private final class HaloDropZoneRuntimeModel: ObservableObject {
    @Published var hoveredZone: Int?
    @Published var itemCount = 1
    @Published var result: String?
}

@MainActor
private struct HaloDropZoneBoardView: View {
    @ObservedObject var settings: HaloDropZoneSettingsStore
    @ObservedObject var model: HaloDropZoneRuntimeModel

    var body: some View {
        GeometryReader { proxy in
            let configuration = settings.configuration
            let frames = HaloDropZoneLayoutResolver.frames(size: proxy.size, configuration: configuration)
            let compactMode = configuration.zones.count > 4 || proxy.size.height < 250

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(configuration.backgroundOpacity))
                    .overlay(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.18), Color.clear, Color.black.opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.11), lineWidth: 1)
                    )
                    .padding(3)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(configuration.headerTitle.isEmpty ? "Drop into Halo" : configuration.headerTitle)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        Text(model.result ?? (configuration.headerSubtitle.isEmpty ? "Choose an action" : configuration.headerSubtitle))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(model.result == nil ? Color.secondary : Color.green)
                            .lineLimit(1)
                    }
                    Spacer()
                    Label("\(model.itemCount)", systemImage: model.itemCount == 1 ? "doc.fill" : "doc.on.doc.fill")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                .padding(.horizontal, max(13, configuration.boardPadding + 3))
                .padding(.top, 12)

                if configuration.zones.isEmpty {
                    VStack(spacing: 7) {
                        Image(systemName: "rectangle.stack.badge.plus").font(.title2)
                        Text("No Drop zones configured").font(.headline)
                        Text("Open Drop Zone Studio to add up to 8 zones.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    ForEach(Array(configuration.zones.enumerated()), id: \.element.id) { index, zone in
                        if frames.indices.contains(index) {
                            let frame = frames[index]
                            zoneCard(
                                zone,
                                active: model.hoveredZone == index,
                                configuration: configuration,
                                compact: compactMode
                            )
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }

                HStack(spacing: 5) {
                    Circle().fill(model.hoveredZone == nil ? Color.secondary : Color.green).frame(width: 5, height: 5)
                    Text(model.hoveredZone == nil ? "Move onto a zone, then release" : "Release to run this zone")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .position(x: proxy.size.width / 2, y: max(12, proxy.size.height - 10))
            }
            .foregroundStyle(.white)
        }
    }

    private func zoneCard(
        _ zone: HaloDropZone,
        active: Bool,
        configuration: HaloDropZoneConfiguration,
        compact: Bool
    ) -> some View {
        VStack(spacing: compact ? 3 : 6) {
            if configuration.showIcons {
                Image(systemName: zone.symbol.isEmpty ? zone.action.symbol : zone.symbol)
                    .font(.system(size: compact ? 17 : (active ? 24 : 21), weight: .semibold))
                    .foregroundStyle(zone.color.color)
            }
            Text(zone.title.isEmpty ? zone.action.rawValue : zone.title)
                .font(.system(size: compact ? 10 : 12, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if configuration.showSubtitles && !compact && !zone.subtitle.isEmpty {
                Text(zone.subtitle)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            if configuration.showActionBadges && !compact {
                Label(zone.accepts.rawValue, systemImage: zone.accepts.symbol)
                    .font(.system(size: 7, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.07), in: Capsule())
            }
        }
        .padding(compact ? 5 : 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            zone.color.color.opacity(active ? 0.17 + configuration.highlightStrength * 0.18 : 0.065),
            in: RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                .stroke(zone.color.color.opacity(active ? configuration.highlightStrength : 0.22), lineWidth: active ? 2 : 1)
        )
        .scaleEffect(active ? 1.018 : 1)
        .shadow(color: zone.color.color.opacity(active ? 0.22 : 0), radius: 9)
        .animation(.easeOut(duration: 0.10), value: active)
    }
}

@MainActor
private final class HaloDropZoneHostView: NSView {
    private let model: HaloDropZoneRuntimeModel
    private let settings = HaloDropZoneSettingsStore.shared
    private let hosting: NSHostingView<HaloDropZoneBoardView>
    var onDrop: (([URL], NSPoint) -> Void)?

    init(model: HaloDropZoneRuntimeModel) {
        self.model = model
        hosting = NSHostingView(rootView: HaloDropZoneBoardView(settings: settings, model: model))
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
        autoresizingMask = [.width, .height]
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        update(sender)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        update(sender)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        model.hoveredZone = nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(sender)
        guard !urls.isEmpty else { return false }
        let local = convert(sender.draggingLocation, from: nil)
        onDrop?(urls, local)
        return true
    }

    private func update(_ sender: NSDraggingInfo) {
        let local = convert(sender.draggingLocation, from: nil)
        model.hoveredZone = HaloDropZoneLayoutResolver.index(
            at: local,
            size: bounds.size,
            configuration: settings.configuration
        )
        let count = sender.draggingPasteboard.pasteboardItems?.reduce(into: 0) { result, item in
            if item.availableType(from: [.fileURL]) != nil { result += 1 }
        } ?? 0
        if count > 0 { model.itemCount = count }
    }

    private func fileURLs(_ sender: NSDraggingInfo) -> [URL] {
        let objects = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) ?? []
        return objects.compactMap { ($0 as? NSURL).map { $0 as URL } }
    }
}

@MainActor
private final class HaloEmbeddedDropZoneController {
    static let shared = HaloEmbeddedDropZoneController()

    private let model = HaloDropZoneRuntimeModel()
    private let settings = HaloDropZoneSettingsStore.shared
    private weak var target: (any HaloGlobalDropTarget)?
    private var targetView: NSView?
    private var hostView: HaloDropZoneHostView?
    private var originalDropHandler: (([URL]) -> Void)?
    private(set) var dropHandled = false

    func begin(target: any HaloGlobalDropTarget, itemCount: Int) {
        dropHandled = false
        model.result = nil
        model.itemCount = max(1, itemCount)

        let sameTarget = self.target === target
        if !sameTarget {
            restoreParentDropHandler()
            hostView?.removeFromSuperview()
            hostView = nil
            targetView = nil
            self.target = target
            originalDropHandler = target.dropHandler
            target.dropHandler = { [weak self] urls in
                self?.handleParentDrop(urls)
            }
        }

        guard let view = target as? NSView else { return }
        targetView = view

        let host: HaloDropZoneHostView
        if let existing = hostView {
            host = existing
        } else {
            let created = HaloDropZoneHostView(model: model)
            created.onDrop = { [weak self] urls, point in self?.handleDrop(urls, localPoint: point) }
            hostView = created
            host = created
        }

        if host.superview !== view {
            host.removeFromSuperview()
            host.frame = view.bounds
            view.addSubview(host, positioned: .above, relativeTo: nil)
        }
        host.frame = view.bounds
        view.addSubview(host, positioned: .above, relativeTo: nil)
    }

    func containsScreenPoint(_ point: NSPoint) -> Bool {
        guard let view = targetView, let window = view.window else { return false }
        let windowPoint = window.convertPoint(fromScreen: point)
        let local = view.convert(windowPoint, from: nil)
        return view.bounds.contains(local)
    }

    func completeDrop(result: String) {
        dropHandled = true
        model.result = result
        model.hoveredZone = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) { [weak self] in
            self?.dismiss()
        }
    }

    func cancelIfNeeded() {
        guard !dropHandled else { return }
        dismiss()
    }

    func dismiss() {
        restoreParentDropHandler()
        hostView?.removeFromSuperview()
        hostView = nil
        targetView = nil
        target = nil
        originalDropHandler = nil
        model.hoveredZone = nil
        model.result = nil
        dropHandled = false
    }

    private func handleParentDrop(_ urls: [URL]) {
        guard let view = targetView, let window = view.window else {
            originalDropHandler?(urls)
            return
        }
        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let local = view.convert(windowPoint, from: nil)
        handleDrop(urls, localPoint: local)
    }

    private func handleDrop(_ urls: [URL], localPoint: NSPoint) {
        guard let target else {
            originalDropHandler?(urls)
            return
        }

        let index = HaloDropZoneLayoutResolver.index(
            at: localPoint,
            size: targetView?.bounds.size ?? .zero,
            configuration: settings.configuration
        )

        guard let index, settings.configuration.zones.indices.contains(index) else {
            originalDropHandler?(urls)
            completeDrop(result: "Added to Shelf")
            return
        }

        let zone = settings.configuration.zones[index]
        let result = HaloDropZoneActionExecutor.perform(
            zone: zone,
            urls: urls,
            shelfHandler: originalDropHandler,
            closeHandler: { [weak target] in target?.dragStateHandler?(false, 0) }
        )
        completeDrop(result: result)
    }

    private func restoreParentDropHandler() {
        target?.dropHandler = originalDropHandler
    }
}

// MARK: - Drop Zone Studio

@MainActor
final class HaloDropZoneStudioWindowController: NSObject {
    static let shared = HaloDropZoneStudioWindowController()
    private var window: NSWindow?
    private var menuInstalled = false

    func installMenuItem() {
        guard !menuInstalled else { return }
        guard let menu = NSApp.mainMenu?.items.first?.submenu else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.installMenuItem() }
            return
        }
        let identifier = NSUserInterfaceItemIdentifier("HaloDropZoneStudioMenuItem")
        if menu.items.contains(where: { $0.identifier == identifier }) {
            menuInstalled = true
            return
        }
        menu.addItem(.separator())
        let item = NSMenuItem(title: "Drop Zone Studio…", action: #selector(openFromMenu), keyEquivalent: "8")
        item.keyEquivalentModifierMask = [.command, .option]
        item.target = self
        item.identifier = identifier
        menu.addItem(item)
        menuInstalled = true
    }

    @objc private func openFromMenu() { show() }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let controller = NSHostingController(rootView: HaloDropZoneStudioView())
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 820, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Halo · Drop Zone Studio"
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 720, height: 620)
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private struct HaloDropZoneStudioView: View {
    @ObservedObject private var store = HaloDropZoneSettingsStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Drop Zone Studio").font(.title2.bold())
                    Text("These zones appear inside Drop CI while you drag.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Reset Defaults") { store.reset() }
                Button { store.addZone() } label: { Label("Add Zone", systemImage: "plus") }
                    .disabled(store.configuration.zones.count >= 8)
            }
            .padding(18)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox("Drop CI preview") {
                        HaloDropZoneStaticPreview(configuration: store.configuration)
                            .frame(height: 260)
                            .padding(.vertical, 6)
                    }

                    GroupBox("Layout") {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Zone layout", selection: configurationBinding(\.layout)) {
                                ForEach(HaloDropZoneLayout.allCases) {
                                    Label($0.rawValue, systemImage: $0.symbol).tag($0)
                                }
                            }
                            Picker("Number of zones", selection: zoneCountBinding) {
                                ForEach(0...8, id: \.self) { Text("\($0)").tag($0) }
                            }
                            HStack {
                                valueSlider("Padding", \.boardPadding, 0...28)
                                valueSlider("Spacing", \.zoneSpacing, 2...24)
                            }
                            HStack {
                                valueSlider("Corner radius", \.cornerRadius, 6...36)
                                valueSlider("Background", \.backgroundOpacity, 0.45...1)
                            }
                            valueSlider("Hover highlight", \.highlightStrength, 0.15...1)
                            Toggle("Show icons", isOn: configurationBinding(\.showIcons))
                            Toggle("Show subtitles", isOn: configurationBinding(\.showSubtitles))
                            Toggle("Show type badges", isOn: configurationBinding(\.showActionBadges))
                            TextField("Header", text: configurationBinding(\.headerTitle))
                            TextField("Instruction", text: configurationBinding(\.headerSubtitle))
                        }
                        .padding(.vertical, 4)
                    }

                    GroupBox("Zones") {
                        VStack(spacing: 10) {
                            if store.configuration.zones.isEmpty {
                                Button("Add first zone") { store.addZone() }
                                    .frame(maxWidth: .infinity)
                                    .padding(20)
                            }
                            ForEach(Array(store.configuration.zones.enumerated()), id: \.element.id) { index, _ in
                                zoneEditor(index)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Text("Rename and Move to Trash change the original item. Halo never assigns them by default.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(18)
            }
        }
    }

    private func zoneEditor(_ index: Int) -> some View {
        let zone = zoneBinding(index)
        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    TextField("Zone title", text: zone.title)
                    TextField("SF Symbol", text: zone.symbol).frame(width: 180)
                }
                TextField("Subtitle", text: zone.subtitle)
                Picker("Action", selection: zone.action) {
                    ForEach(HaloDropZoneAction.allCases) {
                        Label($0.rawValue, systemImage: $0.symbol).tag($0)
                    }
                }
                Picker("Accept", selection: zone.accepts) {
                    ForEach(HaloDropZoneAcceptance.allCases) {
                        Label($0.rawValue, systemImage: $0.symbol).tag($0)
                    }
                }
                ColorPicker(
                    "Zone color",
                    selection: Binding(
                        get: { zone.wrappedValue.color.color },
                        set: { color in
                            var next = zone.wrappedValue
                            next.color = WidgetColor(color)
                            zone.wrappedValue = next
                        }
                    ),
                    supportsOpacity: false
                )

                if zone.wrappedValue.action == .rename {
                    TextField("Rename template", text: zone.parameter)
                    Text("Use {name}, {ext}, and {date}.").font(.caption).foregroundStyle(.secondary)
                } else if zone.wrappedValue.action == .copyFolder {
                    HStack {
                        TextField("Destination folder", text: zone.parameter)
                        Button("Choose…") { chooseFolder(for: index) }
                    }
                }

                if zone.wrappedValue.action != .shelf {
                    Toggle("Also add accepted items to File Shelf", isOn: zone.alsoAddToShelf)
                }
                if zone.wrappedValue.action.isDestructive {
                    Label("This action changes the original item.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Button { store.moveZone(from: index, by: -1) } label: { Label("Earlier", systemImage: "arrow.up") }
                        .disabled(index == 0)
                    Button { store.moveZone(from: index, by: 1) } label: { Label("Later", systemImage: "arrow.down") }
                        .disabled(index == store.configuration.zones.count - 1)
                    Spacer()
                    Button(role: .destructive) { store.removeZone(at: index) } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: zone.wrappedValue.symbol.isEmpty ? zone.wrappedValue.action.symbol : zone.wrappedValue.symbol)
                    .foregroundStyle(zone.wrappedValue.color.color)
                    .frame(width: 22)
                Text(zone.wrappedValue.title.isEmpty ? zone.wrappedValue.action.rawValue : zone.wrappedValue.title)
                    .font(.headline)
                Spacer()
                Text(zone.wrappedValue.action.rawValue).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var zoneCountBinding: Binding<Int> {
        Binding(
            get: { store.configuration.zones.count },
            set: { requested in
                let count = min(8, max(0, requested))
                while store.configuration.zones.count < count { store.addZone() }
                while store.configuration.zones.count > count {
                    store.removeZone(at: store.configuration.zones.count - 1)
                }
            }
        )
    }

    private func configurationBinding<T>(_ keyPath: WritableKeyPath<HaloDropZoneConfiguration, T>) -> Binding<T> {
        Binding(
            get: { store.configuration[keyPath: keyPath] },
            set: { value in
                var next = store.configuration
                next[keyPath: keyPath] = value
                next.normalize()
                store.configuration = next
            }
        )
    }

    private func zoneBinding(_ index: Int) -> Binding<HaloDropZone> {
        Binding(
            get: { store.configuration.zones[index] },
            set: { value in
                guard store.configuration.zones.indices.contains(index) else { return }
                var next = store.configuration
                next.zones[index] = value
                next.normalize()
                store.configuration = next
            }
        )
    }

    private func chooseFolder(for index: Int) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            var next = store.configuration
            next.zones[index].parameter = url.path
            store.configuration = next
        }
    }

    private func valueSlider(
        _ title: String,
        _ keyPath: WritableKeyPath<HaloDropZoneConfiguration, Double>,
        _ range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.1f", store.configuration[keyPath: keyPath]))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            SwiftUI.Slider(value: configurationBinding(keyPath), in: range)
        }
    }
}

@MainActor
private struct HaloDropZoneStaticPreview: View {
    let configuration: HaloDropZoneConfiguration

    var body: some View {
        GeometryReader { proxy in
            let frames = HaloDropZoneLayoutResolver.frames(size: proxy.size, configuration: configuration)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(configuration.backgroundOpacity))
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(configuration.headerTitle).font(.headline)
                        Text(configuration.headerSubtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text("DROP CI").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                }
                .padding(12)

                ForEach(Array(configuration.zones.enumerated()), id: \.element.id) { index, zone in
                    if frames.indices.contains(index) {
                        let frame = frames[index]
                        VStack(spacing: 4) {
                            if configuration.showIcons {
                                Image(systemName: zone.symbol.isEmpty ? zone.action.symbol : zone.symbol)
                                    .foregroundStyle(zone.color.color)
                            }
                            Text(zone.title).font(.caption.bold()).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(zone.color.color.opacity(index == 0 ? 0.18 : 0.06), in: RoundedRectangle(cornerRadius: configuration.cornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: configuration.cornerRadius).stroke(zone.color.color.opacity(index == 0 ? 0.72 : 0.22)))
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
            .foregroundStyle(.white)
        }
    }
}

// MARK: - Global file-drag monitor

@MainActor
private final class HaloGlobalFileDragMonitor {
    static let shared = HaloGlobalFileDragMonitor()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pollTimer: Timer?
    private weak var activeTarget: (any HaloGlobalDropTarget)?
    private var activeItemCount = 0
    private var lastCompletedPasteboardChangeCount: Int?
    private var sawMouseDrag = false
    private var mouseDownAnchor: NSPoint?
    private var deferredFinishPending = false

    private init() {}

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        HaloDropZoneStudioWindowController.shared.installMenuItem()

        let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let type = event.type
            DispatchQueue.main.async { [weak self] in self?.handleMouseEvent(type) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            let type = event.type
            DispatchQueue.main.async { [weak self] in self?.handleMouseEvent(type) }
            return event
        }

        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pollDragSession() }
        }
        timer.tolerance = 0.01
        pollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func handleMouseEvent(_ type: NSEvent.EventType) {
        switch type {
        case .leftMouseDragged:
            sawMouseDrag = true
            inspectDragPasteboard()
            summonFinderFallbackIfNeeded()
        case .leftMouseUp:
            finishAfterDropOpportunity()
        default:
            break
        }
    }

    private func pollDragSession() {
        let leftButtonDown = (NSEvent.pressedMouseButtons & 1) != 0
        let point = NSEvent.mouseLocation

        guard leftButtonDown else {
            mouseDownAnchor = nil
            if activeTarget != nil || sawMouseDrag { finishAfterDropOpportunity() }
            return
        }

        deferredFinishPending = false
        if mouseDownAnchor == nil { mouseDownAnchor = point }
        if let anchor = mouseDownAnchor {
            let dx = point.x - anchor.x
            let dy = point.y - anchor.y
            if dx * dx + dy * dy >= 9 { sawMouseDrag = true }
        }

        inspectDragPasteboard()
        summonFinderFallbackIfNeeded()

        if activeTarget != nil {
            activateTarget(at: point, count: max(1, activeItemCount))
        }
    }

    private func summonFinderFallbackIfNeeded() {
        guard activeTarget == nil,
              sawMouseDrag,
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else { return }
        activeItemCount = max(1, dragPasteboardFileCount())
        activateTarget(at: NSEvent.mouseLocation, count: activeItemCount)
    }

    private func inspectDragPasteboard() {
        let pasteboard = NSPasteboard(name: .drag)
        let count = dragPasteboardFileCount(pasteboard)
        guard count > 0 else { return }
        if activeTarget == nil,
           let lastCompletedPasteboardChangeCount,
           pasteboard.changeCount == lastCompletedPasteboardChangeCount { return }
        activeItemCount = count
        activateTarget(at: NSEvent.mouseLocation, count: count)
    }

    private func dragPasteboardFileCount(_ pasteboard: NSPasteboard = NSPasteboard(name: .drag)) -> Int {
        pasteboard.pasteboardItems?.reduce(into: 0) { result, item in
            if item.availableType(from: [.fileURL]) != nil { result += 1 }
        } ?? 0
    }

    private func activateTarget(at point: NSPoint, count: Int) {
        guard let target = targetForDrag(at: point) else { return }
        if let activeTarget, activeTarget !== target {
            activeTarget.dragStateHandler?(false, 0)
            HaloEmbeddedDropZoneController.shared.dismiss()
        }
        activeTarget = target
        target.dragStateHandler?(true, max(1, count))
        HaloEmbeddedDropZoneController.shared.begin(target: target, itemCount: max(1, count))
    }

    private func targetForDrag(at point: NSPoint) -> (any HaloGlobalDropTarget)? {
        let panels = NSApp.windows.compactMap { $0 as? HaloPanel }
        if let panel = panels.first(where: { panel in
            guard let screen = panel.screen else { return false }
            return screen.frame.contains(point)
        }), let target = panel.contentView as? any HaloGlobalDropTarget {
            return target
        }
        return panels.compactMap { $0.contentView as? any HaloGlobalDropTarget }.first
    }

    private func finishAfterDropOpportunity() {
        guard !deferredFinishPending else { return }
        if HaloEmbeddedDropZoneController.shared.containsScreenPoint(NSEvent.mouseLocation) {
            deferredFinishPending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
                guard let self else { return }
                self.deferredFinishPending = false
                if HaloEmbeddedDropZoneController.shared.dropHandled {
                    self.resetSessionState()
                } else {
                    self.finishDrag()
                }
            }
        } else {
            finishDrag()
        }
    }

    private func finishDrag() {
        guard activeTarget != nil || sawMouseDrag else { return }
        activeTarget?.dragStateHandler?(false, 0)
        HaloEmbeddedDropZoneController.shared.cancelIfNeeded()
        resetSessionState()
    }

    private func resetSessionState() {
        activeTarget = nil
        activeItemCount = 0
        sawMouseDrag = false
        mouseDownAnchor = nil
        lastCompletedPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
    }
}

// MARK: - Display clock

/// Active animation only. AppKit tracks the view's display, including display moves.
@MainActor final class DisplayClock: NSObject {
    private var nativeLink: AnyObject?
    private var fallback: Timer?
    private var tick: ((CFTimeInterval) -> Void)?
    private var requestedRate = 0

    override init() {
        super.init()
        HaloGlobalFileDragMonitor.shared.start()
    }

    func start(view: NSView, tick: @escaping (CFTimeInterval) -> Void) {
        stop()
        self.tick = tick
        requestedRate = FrameRatePolicy.target(
            maximum: view.window?.screen?.maximumFramesPerSecond ?? 60,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
        if #available(macOS 14.0, *) {
            let link = view.displayLink(target: self, selector: #selector(displayTick(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: Float(min(60, requestedRate)),
                maximum: Float(requestedRate),
                preferred: Float(requestedRate)
            )
            nativeLink = link
            link.add(to: .main, forMode: .common)
        } else {
            let timer = Timer(timeInterval: 1 / Double(requestedRate), repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.tick?(CACurrentMediaTime()) }
            }
            timer.tolerance = 0
            fallback = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @available(macOS 14.0, *)
    @objc private func displayTick(_ link: CADisplayLink) {
        tick?(link.targetTimestamp)
    }

    func stop() {
        if #available(macOS 14.0, *), let link = nativeLink as? CADisplayLink {
            link.invalidate()
        }
        nativeLink = nil
        fallback?.invalidate()
        fallback = nil
        tick = nil
    }
}

struct RefreshTimeline<Content: View>: View {
    let active: Bool
    @ViewBuilder var content: (CFTimeInterval) -> Content
    @State private var time = CACurrentMediaTime()

    var body: some View {
        content(time)
            .background {
                RefreshPulse(active: active) { time = $0 }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

private struct RefreshPulse: NSViewRepresentable {
    let active: Bool
    let tick: (CFTimeInterval) -> Void

    final class PulseView: NSView {
        let clock = DisplayClock()
        var active = false
        var running = false
        var tick: ((CFTimeInterval) -> Void)?
        var screenObserver: NSObjectProtocol?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
            screenObserver = nil
            if let window {
                screenObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didChangeScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.restart() }
                }
            }
            restart()
        }

        override func viewDidChangeBackingProperties() {
            super.viewDidChangeBackingProperties()
            restart()
        }

        func restart() {
            clock.stop()
            running = false
            update()
        }

        func update() {
            let shouldRun = active && window != nil
            guard shouldRun != running else { return }
            running = shouldRun
            if shouldRun {
                clock.start(view: self) { [weak self] in self?.tick?($0) }
            } else {
                clock.stop()
            }
        }
    }

    func makeNSView(context: Context) -> PulseView { PulseView() }

    func updateNSView(_ view: PulseView, context: Context) {
        view.tick = tick
        view.active = active
        view.update()
    }

    static func dismantleNSView(_ view: PulseView, coordinator: ()) {
        view.clock.stop()
        view.tick = nil
        if let observer = view.screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        view.screenObserver = nil
    }
}
