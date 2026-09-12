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

enum HaloDropCIBackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case halo = "Halo Glow"
    case solid = "Solid"
    case gradient = "Gradient"
    case glass = "Glass"
    case transparent = "Transparent"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .halo: return "sparkles.rectangle.stack"
        case .solid: return "rectangle.fill"
        case .gradient: return "circle.lefthalf.filled"
        case .glass: return "drop.fill"
        case .transparent: return "square.dashed"
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
            acceptance = .all; subtitle = "Enter a new name after dropping"; parameter = ""
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
    // Optional for backward compatibility with HaloDropZones.v2 payloads.
    var backgroundStyle: HaloDropCIBackgroundStyle? = .halo
    var backgroundPrimaryColor: WidgetColor? = WidgetColor(red: 0.025, green: 0.035, blue: 0.060)
    var backgroundSecondaryColor: WidgetColor? = WidgetColor(red: 0.045, green: 0.105, blue: 0.180)
    var backgroundAccentStrength: Double? = 0.16
    var highlightStrength = 0.85
    var showIcons = true
    var showSubtitles = true
    var showActionBadges = true
    var headerTitle = "Drop into Halo"
    var headerSubtitle = "Choose what should happen to the dragged item"

    var resolvedBackgroundStyle: HaloDropCIBackgroundStyle { backgroundStyle ?? .halo }
    var resolvedBackgroundPrimaryColor: WidgetColor {
        backgroundPrimaryColor ?? WidgetColor(red: 0.025, green: 0.035, blue: 0.060)
    }
    var resolvedBackgroundSecondaryColor: WidgetColor {
        backgroundSecondaryColor ?? WidgetColor(red: 0.045, green: 0.105, blue: 0.180)
    }
    var resolvedBackgroundAccentStrength: Double { backgroundAccentStrength ?? 0.16 }

    mutating func normalize() {
        if zones.isEmpty { zones = [.preset(.shelf, index: 0)] }
        if zones.count > 8 { zones = Array(zones.prefix(8)) }
        boardPadding = min(28, max(0, boardPadding))
        zoneSpacing = min(24, max(2, zoneSpacing))
        cornerRadius = min(36, max(6, cornerRadius))
        backgroundOpacity = min(1, max(0, backgroundOpacity))
        if backgroundStyle == nil { backgroundStyle = .halo }
        if backgroundPrimaryColor == nil { backgroundPrimaryColor = WidgetColor(red: 0.025, green: 0.035, blue: 0.060) }
        if backgroundSecondaryColor == nil { backgroundSecondaryColor = WidgetColor(red: 0.045, green: 0.105, blue: 0.180) }
        backgroundAccentStrength = min(0.8, max(0, backgroundAccentStrength ?? 0.16))
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
        guard configuration.zones.count > 1, configuration.zones.indices.contains(index) else { return }
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

        let padding = max(8, CGFloat(configuration.boardPadding))
        let gap = max(2, CGFloat(configuration.zoneSpacing))
        let top = headerHeight + padding
        let availableWidth = max(1, size.width - padding * 2)
        let availableHeight = max(1, size.height - top - footerHeight - padding)
        let rect = CGRect(
            x: padding,
            y: top,
            width: availableWidth,
            height: availableHeight
        ).intersection(CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4))

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
                let requestedName = zone.parameter.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !requestedName.isEmpty else { return "Enter a new name." }
                try accepted.forEach { try rename($0, newName: requestedName) }
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

    private static func rename(_ url: URL, newName requestedName: String) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let ext = url.pathExtension
        var name = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        name = name.replacingOccurrences(of: "/", with: "-")
        name = name.replacingOccurrences(of: ":", with: "-")
        guard !name.isEmpty else { throw CocoaError(.fileWriteInvalidFileName) }
        if !ext.isEmpty && URL(fileURLWithPath: name).pathExtension.isEmpty {
            name += "." + ext
        }

        let directory = url.deletingLastPathComponent()
        var destination = directory.appendingPathComponent(name)
        if destination.standardizedFileURL == url.standardizedFileURL { return }
        if FileManager.default.fileExists(atPath: destination.path) {
            destination = uniqueURL(
                in: directory,
                stem: destination.deletingPathExtension().lastPathComponent,
                extension: destination.pathExtension
            )
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var moveError: Error?
        coordinator.coordinate(
            writingItemAt: url,
            options: .forMoving,
            writingItemAt: destination,
            options: [],
            error: &coordinationError
        ) { source, coordinatedDestination in
            do {
                try FileManager.default.moveItem(at: source, to: coordinatedDestination)
            } catch {
                moveError = error
            }
        }
        if let moveError { throw moveError }
        if let coordinationError { throw coordinationError }
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
    @Published var renameZoneID: UUID?
    @Published var renameURLs: [URL] = []
    @Published var renameText = ""

    var renameCommitHandler: ((String) -> Void)?
    var renameCancelHandler: (() -> Void)?

    func clearRename() {
        renameZoneID = nil
        renameURLs = []
        renameText = ""
        renameCommitHandler = nil
        renameCancelHandler = nil
    }
}

@MainActor
struct HaloDropCIBackgroundView: View {
    let configuration: HaloDropZoneConfiguration

    @ViewBuilder var body: some View {
        let primary = configuration.resolvedBackgroundPrimaryColor.color
        let secondary = configuration.resolvedBackgroundSecondaryColor.color
        let strength = configuration.resolvedBackgroundAccentStrength
        switch configuration.resolvedBackgroundStyle {
        case .halo:
            LinearGradient(
                colors: [primary, secondary.opacity(0.92), Color.accentColor.opacity(strength)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(configuration.backgroundOpacity)
        case .solid:
            primary.opacity(configuration.backgroundOpacity)
        case .gradient:
            LinearGradient(colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(configuration.backgroundOpacity)
        case .glass:
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(primary.opacity(strength * 0.55))
                .opacity(configuration.backgroundOpacity)
        case .transparent:
            Color.clear
        }
    }
}

@MainActor
private struct HaloDropZoneBoardView: View {
    @ObservedObject var settings: HaloDropZoneSettingsStore
    @ObservedObject var model: HaloDropZoneRuntimeModel
    @FocusState private var renameFieldFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let configuration = settings.configuration
            let frames = HaloDropZoneLayoutResolver.frames(size: proxy.size, configuration: configuration)
            let dense = configuration.zones.count >= 6 || proxy.size.height < 260

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())

                header(configuration: configuration)
                    .padding(.horizontal, max(14, configuration.boardPadding + 4))
                    .padding(.top, 11)

                ForEach(Array(configuration.zones.enumerated()), id: \.element.id) { index, zone in
                    if frames.indices.contains(index) {
                        let frame = frames[index]
                        zoneCard(
                            zone,
                            index: index,
                            active: model.hoveredZone == index,
                            configuration: configuration,
                            dense: dense
                        )
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: model.renameZoneID != nil ? "pencil" : (model.hoveredZone == nil ? "cursorarrow.motionlines" : "arrow.down.circle.fill"))
                        .font(.system(size: 8.5, weight: .semibold))
                    Text(model.renameZoneID != nil ? "Type a new name · Return to confirm · Esc to cancel" : (model.hoveredZone == nil ? "Move over an action" : "Release to run this action"))
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                }
                .foregroundStyle(model.renameZoneID != nil ? Color.white.opacity(0.72) : (model.hoveredZone == nil ? Color.white.opacity(0.36) : Color.white.opacity(0.70)))
                .position(x: proxy.size.width / 2, y: max(12, proxy.size.height - 11))
            }
            .foregroundStyle(.white)
        }
        .onChange(of: model.renameZoneID) { zoneID in
            guard zoneID != nil else {
                renameFieldFocused = false
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                renameFieldFocused = true
            }
        }
    }

    private func header(configuration: HaloDropZoneConfiguration) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.30), Color.accentColor.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(configuration.headerTitle.isEmpty ? "Drop into Halo" : configuration.headerTitle)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                Text(model.result ?? (configuration.headerSubtitle.isEmpty ? "Choose what happens next" : configuration.headerSubtitle))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(model.result == nil ? Color.white.opacity(0.45) : Color.green.opacity(0.90))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Image(systemName: model.itemCount == 1 ? "doc.fill" : "doc.on.doc.fill")
                Text(model.itemCount == 1 ? "1 item" : "\(model.itemCount) items")
            }
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.62))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.065), in: Capsule())
        }
    }

    private func zoneCard(
        _ zone: HaloDropZone,
        index: Int,
        active: Bool,
        configuration: HaloDropZoneConfiguration,
        dense: Bool
    ) -> some View {
        GeometryReader { proxy in
            let compact = dense || proxy.size.width < 130 || proxy.size.height < 86
            let accent = zone.color.color

            ZStack {
                RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(active ? 0.105 : 0.050))

                LinearGradient(
                    colors: [accent.opacity(active ? 0.24 : 0.075), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: compact ? 5 : 8) {
                    HStack(spacing: compact ? 7 : 9) {
                        if configuration.showIcons {
                            ZStack {
                                RoundedRectangle(cornerRadius: compact ? 9 : 11, style: .continuous)
                                    .fill(accent.opacity(active ? 0.27 : 0.13))
                                Image(systemName: zone.symbol.isEmpty ? zone.action.symbol : zone.symbol)
                                    .font(.system(size: compact ? 14 : 17, weight: .semibold))
                                    .foregroundStyle(active ? Color.white : accent)
                            }
                            .frame(width: compact ? 31 : 38, height: compact ? 31 : 38)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(zone.title.isEmpty ? zone.action.rawValue : zone.title)
                                .font(.system(size: compact ? 10 : 12.5, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                            if configuration.showSubtitles && !compact && !zone.subtitle.isEmpty {
                                Text(zone.subtitle)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.44))
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    if !compact {
                        Spacer(minLength: 0)
                        HStack(spacing: 6) {
                            if configuration.showActionBadges {
                                Label(zone.accepts.rawValue, systemImage: zone.accepts.symbol)
                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.42))
                            }
                            Spacer(minLength: 0)
                            if active {
                                Label("Release", systemImage: "arrow.down")
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(accent.opacity(0.90), in: Capsule())
                            } else if zone.action.isDestructive {
                                Label("Changes original", systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 7.6, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.orange.opacity(0.80))
                            } else {
                                Text(zone.action.rawValue)
                                    .font(.system(size: 7.8, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.26))
                                    .lineLimit(1)
                            }
                        }
                    } else if active {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                    }
                }
                .padding(compact ? 8 : 11)
                .opacity(model.renameZoneID == zone.id ? 0 : 1)
                .allowsHitTesting(model.renameZoneID != zone.id)

                if model.renameZoneID == zone.id {
                    renameEditor(zone: zone, accent: accent, compact: compact)
                        .padding(compact ? 8 : 11)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                    .stroke(active ? accent.opacity(configuration.highlightStrength) : Color.white.opacity(0.07), lineWidth: active ? 1.7 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))
            .shadow(color: active ? accent.opacity(0.18) : Color.clear, radius: active ? 10 : 0, y: 3)
            .animation(.easeOut(duration: 0.13), value: active)
        }
    }

    private func renameEditor(zone: HaloDropZone, accent: Color, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 9) {
            HStack(spacing: 7) {
                Image(systemName: "pencil")
                    .font(.system(size: compact ? 11 : 13, weight: .semibold))
                    .foregroundStyle(accent)
                Text(model.renameURLs.count > 1 ? "Rename \(model.renameURLs.count) items" : "Rename")
                    .font(.system(size: compact ? 10 : 12, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
                Button {
                    model.renameCancelHandler?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.48))
                }
                .buttonStyle(.plain)
                .help("Cancel rename")
            }

            HStack(spacing: 5) {
                TextField("New name", text: $model.renameText)
                    .textFieldStyle(.plain)
                    .font(.system(size: compact ? 10 : 12, weight: .medium, design: .rounded))
                    .focused($renameFieldFocused)
                    .onSubmit { model.renameCommitHandler?(model.renameText) }
                    .onExitCommand { model.renameCancelHandler?() }
                    .padding(.horizontal, compact ? 7 : 9)
                    .padding(.vertical, compact ? 5 : 7)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(accent.opacity(0.55), lineWidth: 1)
                    )

                if model.renameURLs.count == 1,
                   let ext = model.renameURLs.first?.pathExtension,
                   !ext.isEmpty {
                    Text(".\(ext)")
                        .font(.system(size: compact ? 8.5 : 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.42))
                }

                Button {
                    model.renameCommitHandler?(model.renameText)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: compact ? 15 : 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .disabled(model.renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Rename")
            }

            if !compact {
                Text(model.renameURLs.count > 1 ? "The same base name is applied and duplicates are numbered automatically." : "The current extension is preserved unless you type a different one.")
                    .font(.system(size: 7.8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.34))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        host.needsLayout = true
        host.layoutSubtreeIfNeeded()
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
        model.clearRename()
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
        if zone.action == .rename {
            beginInlineRename(zone: zone, urls: urls, target: target)
            return
        }

        let result = HaloDropZoneActionExecutor.perform(
            zone: zone,
            urls: urls,
            shelfHandler: originalDropHandler,
            closeHandler: { [weak target] in target?.dragStateHandler?(false, 0) }
        )
        completeDrop(result: result)
    }

    private func beginInlineRename(zone: HaloDropZone, urls: [URL], target: any HaloGlobalDropTarget) {
        let accepted = urls.filter { zone.accepts.accepts($0) }
        guard !accepted.isEmpty else {
            completeDrop(result: "Nothing matched this zone's \(zone.accepts.rawValue.lowercased()) filter.")
            return
        }

        dropHandled = true
        model.result = nil
        model.hoveredZone = nil
        model.renameURLs = accepted
        model.renameZoneID = zone.id
        model.renameText = accepted.first?.deletingPathExtension().lastPathComponent ?? ""

        let shelf = originalDropHandler
        model.renameCommitHandler = { [weak self, weak target] requestedName in
            guard let self else { return }
            let name = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                self.model.result = "Enter a new name"
                return
            }

            var runtimeZone = zone
            runtimeZone.parameter = name
            self.model.clearRename()
            let result = HaloDropZoneActionExecutor.perform(
                zone: runtimeZone,
                urls: accepted,
                shelfHandler: shelf,
                closeHandler: {}
            )
            target?.dragStateHandler?(false, 0)
            self.completeDrop(result: result)
        }
        model.renameCancelHandler = { [weak self, weak target] in
            guard let self else { return }
            self.model.clearRename()
            target?.dragStateHandler?(false, 0)
            self.completeDrop(result: "Rename cancelled")
        }

        if let window = targetView?.window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
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
            contentRect: CGRect(x: 0, y: 0, width: 1040, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Halo · Drop Zone Studio"
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 900, height: 620)
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private struct HaloDropZoneStudioView: View {
    var body: some View {
        HaloDropZoneSettingsEditor()
            .frame(minWidth: 900, minHeight: 620)
    }
}

private enum HaloDropStudioTemplate: String, CaseIterable, Identifiable {
    case essentials = "Essentials"
    case everyday = "Everyday"
    case creator = "Creator"
    case power = "Power User"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .essentials: return "sparkles"
        case .everyday: return "square.grid.2x2"
        case .creator: return "wand.and.stars"
        case .power: return "bolt.fill"
        }
    }
    var subtitle: String {
        switch self {
        case .essentials: return "Shelf + preview"
        case .everyday: return "Four useful actions"
        case .creator: return "Images and exports"
        case .power: return "Six utility actions"
        }
    }
    var actions: [HaloDropZoneAction] {
        switch self {
        case .essentials: return [.shelf, .quickLook]
        case .everyday: return [.shelf, .quickLook, .copyDownloads, .copyPath]
        case .creator: return [.quickLook, .convertPNG, .convertJPEG, .copyDownloads, .shelf]
        case .power: return [.shelf, .quickLook, .compress, .extract, .copyPath, .duplicate]
        }
    }
}

private enum HaloDropStudioLook: String, CaseIterable, Identifiable {
    case halo = "Halo"
    case glass = "Soft Glass"
    case minimal = "Minimal"
    case compact = "Compact"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .halo: return "circle.hexagongrid.fill"
        case .glass: return "drop.fill"
        case .minimal: return "minus.rectangle"
        case .compact: return "rectangle.compress.vertical"
        }
    }
}

@MainActor
struct HaloDropZoneSettingsEditor: View {
    @ObservedObject private var store = HaloDropZoneSettingsStore.shared
    @State private var selectedZoneID: UUID?
    @State private var showAdvancedAppearance = false
    @State private var showAdvancedZone = false

    var body: some View {
        VStack(spacing: 0) {
            studioHeader
            Divider()

            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        quickSetup
                        livePreview
                        zoneStrip
                        layoutAndLook
                        if showAdvancedAppearance { advancedAppearance }
                    }
                    .padding(20)
                }
                .frame(minWidth: 540)

                Divider()

                ScrollView {
                    zoneInspector
                        .padding(18)
                }
                .frame(width: 330)
                .background(Color.primary.opacity(0.018))
            }
        }
        .onAppear { ensureSelection() }
        .onChange(of: store.configuration.zones) { _ in ensureSelection() }
    }

    private var studioHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Drop Zone Studio")
                    .font(.title2.bold())
                Text("Make dragging files feel instant, obvious and yours.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(store.configuration.zones.count) zone\(store.configuration.zones.count == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06), in: Capsule())

            Button("Reset") { store.reset(); selectedZoneID = store.configuration.zones.first?.id }
            Button { store.addZone(); selectedZoneID = store.configuration.zones.last?.id } label: {
                Label("Add Zone", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.configuration.zones.count >= 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var quickSetup: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("Quick setup", subtitle: "Start from a useful layout, then change anything.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 9)], spacing: 9) {
                ForEach(HaloDropStudioTemplate.allCases) { preset in
                    Button { applyTemplate(preset) } label: {
                        HStack(spacing: 9) {
                            Image(systemName: preset.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(preset.rawValue).font(.callout.weight(.semibold))
                                Text(preset.subtitle).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                sectionTitle("Live preview", subtitle: "Click a zone to edit it.")
                Spacer()
                Picker("Zones", selection: zoneCountBinding) {
                    ForEach(1...8, id: \.self) { Text("\($0)").tag($0) }
                }
                .labelsHidden()
                .frame(width: 72)
            }

            HaloDropZoneInteractivePreview(
                configuration: store.configuration,
                selectedZoneID: selectedZoneID,
                onSelect: { selectedZoneID = $0 }
            )
            .frame(height: previewHeight)
        }
    }

    private var zoneStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("Zones", subtitle: "Select one to edit. Order controls its position in the layout.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(store.configuration.zones.enumerated()), id: \.element.id) { index, zone in
                        Button { selectedZoneID = zone.id } label: {
                            HStack(spacing: 7) {
                                Image(systemName: zone.symbol.isEmpty ? zone.action.symbol : zone.symbol)
                                    .foregroundStyle(zone.color.color)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(zone.title.isEmpty ? zone.action.rawValue : zone.title)
                                        .font(.caption.weight(.semibold)).lineLimit(1)
                                    Text("Zone \(index + 1)").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                (selectedZoneID == zone.id ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04)),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(selectedZoneID == zone.id ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var layoutAndLook: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Layout & style", subtitle: "Visual choices first; precision controls stay out of the way.")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 8)], spacing: 8) {
                ForEach(HaloDropZoneLayout.allCases) { layout in
                    Button { setConfiguration(\.layout, layout) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: layout.symbol).font(.system(size: 17, weight: .semibold))
                            Text(layout.rawValue).font(.caption2.weight(.semibold)).lineLimit(1)
                        }
                        .foregroundStyle(store.configuration.layout == layout ? Color.accentColor : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            store.configuration.layout == layout ? Color.accentColor.opacity(0.11) : Color.primary.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(store.configuration.layout == layout ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                ForEach(HaloDropStudioLook.allCases) { look in
                    Button { applyLook(look) } label: {
                        Label(look.rawValue, systemImage: look.symbol)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("CI background").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 7)], spacing: 7) {
                    ForEach(HaloDropCIBackgroundStyle.allCases) { style in
                        Button { backgroundStyleBinding.wrappedValue = style } label: {
                            Label(style.rawValue, systemImage: style.symbol)
                                .font(.caption2.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .foregroundStyle(store.configuration.resolvedBackgroundStyle == style ? Color.accentColor : Color.primary)
                                .background(
                                    store.configuration.resolvedBackgroundStyle == style ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.03),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if store.configuration.resolvedBackgroundStyle != .transparent {
                    HStack(spacing: 14) {
                        ColorPicker("Primary", selection: backgroundPrimaryBinding, supportsOpacity: false)
                        if store.configuration.resolvedBackgroundStyle == .gradient || store.configuration.resolvedBackgroundStyle == .halo {
                            ColorPicker("Secondary", selection: backgroundSecondaryBinding, supportsOpacity: false)
                        }
                    }
                    HStack(spacing: 10) {
                        Text("Opacity").font(.caption).foregroundStyle(.secondary)
                        Slider(value: configurationBinding(\.backgroundOpacity), in: 0.15...1)
                        Text(String(format: "%.0f%%", store.configuration.backgroundOpacity * 100))
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 34)
                    }
                    if store.configuration.resolvedBackgroundStyle == .halo || store.configuration.resolvedBackgroundStyle == .glass {
                        HStack(spacing: 10) {
                            Text("Tint").font(.caption).foregroundStyle(.secondary)
                            Slider(value: backgroundAccentBinding, in: 0...0.8)
                        }
                    }
                } else {
                    Text("Transparent uses the surface underneath the Drop CI.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(11)
            .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Button {
                withAnimation(.easeInOut(duration: 0.16)) { showAdvancedAppearance.toggle() }
            } label: {
                Label(showAdvancedAppearance ? "Hide advanced appearance" : "Advanced appearance", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
        }
    }

    private var advancedAppearance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            sectionTitle("Advanced appearance", subtitle: "Fine-tune the board after choosing a look.")
            HStack { valueSlider("Padding", \.boardPadding, 0...28); valueSlider("Spacing", \.zoneSpacing, 2...24) }
            valueSlider("Corner radius", \.cornerRadius, 6...36)
            valueSlider("Hover emphasis", \.highlightStrength, 0.15...1)
            HStack(spacing: 16) {
                Toggle("Icons", isOn: configurationBinding(\.showIcons))
                Toggle("Subtitles", isOn: configurationBinding(\.showSubtitles))
                Toggle("Type badges", isOn: configurationBinding(\.showActionBadges))
            }
            TextField("Header title", text: configurationBinding(\.headerTitle))
            TextField("Header instruction", text: configurationBinding(\.headerSubtitle))
        }
    }

    @ViewBuilder private var zoneInspector: some View {
        if let index = selectedZoneIndex {
            let zone = zoneBinding(index)
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(zone.wrappedValue.color.color.opacity(0.14))
                        Image(systemName: zone.wrappedValue.symbol.isEmpty ? zone.wrappedValue.action.symbol : zone.wrappedValue.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(zone.wrappedValue.color.color)
                    }
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Zone \(index + 1)").font(.caption).foregroundStyle(.secondary)
                        Text(zone.wrappedValue.title.isEmpty ? zone.wrappedValue.action.rawValue : zone.wrappedValue.title)
                            .font(.headline).lineLimit(1)
                    }
                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("What happens").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Action", selection: actionBinding(index)) {
                        ForEach(HaloDropZoneAction.allCases) { action in
                            Label(action.rawValue, systemImage: action.symbol).tag(action)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    Picker("Accept", selection: zone.accepts) {
                        ForEach(HaloDropZoneAcceptance.allCases) { type in
                            Label(type.rawValue, systemImage: type.symbol).tag(type)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Label").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("Title", text: zone.title)
                    TextField("Short description", text: zone.subtitle)
                    ColorPicker(
                        "Accent",
                        selection: Binding(
                            get: { zone.wrappedValue.color.color },
                            set: { color in var next = zone.wrappedValue; next.color = WidgetColor(color); zone.wrappedValue = next }
                        ),
                        supportsOpacity: false
                    )
                }

                if zone.wrappedValue.action == .rename {
                    Label("Drop an item here and this zone becomes a rename field. Type the new name, then press Return.", systemImage: "text.cursor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                } else if zone.wrappedValue.action == .copyFolder {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Destination").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        HStack {
                            Text(zone.wrappedValue.parameter.isEmpty ? "No folder chosen" : URL(fileURLWithPath: zone.wrappedValue.parameter).lastPathComponent)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            Spacer()
                            Button("Choose…") { chooseFolder(for: index) }
                        }
                    }
                }

                if zone.wrappedValue.action != .shelf {
                    Toggle("Also keep in File Shelf", isOn: zone.alsoAddToShelf)
                }

                if zone.wrappedValue.action.isDestructive {
                    Label("This action changes the original item.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { showAdvancedZone.toggle() }
                } label: {
                    Label(showAdvancedZone ? "Hide advanced" : "Advanced", systemImage: "gearshape")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)

                if showAdvancedZone {
                    TextField("SF Symbol", text: zone.symbol)
                }

                Divider()

                HStack(spacing: 7) {
                    Button { store.moveZone(from: index, by: -1) } label: { Image(systemName: "arrow.left") }
                        .disabled(index == 0)
                    Button { store.moveZone(from: index, by: 1) } label: { Image(systemName: "arrow.right") }
                        .disabled(index == store.configuration.zones.count - 1)
                    Button { duplicateZone(index) } label: { Image(systemName: "plus.square.on.square") }
                        .disabled(store.configuration.zones.count >= 8)
                    Spacer()
                    Button(role: .destructive) { removeSelectedZone(index) } label: { Image(systemName: "trash") }
                        .disabled(store.configuration.zones.count <= 1)
                }
                .buttonStyle(.bordered)
            }
        } else {
            VStack(spacing: 10) {
      Image(systemName: "square.dashed")
          .font(.system(size: 30, weight: .medium))
          .foregroundStyle(.secondary)
      Text("Select a zone")
          .font(.headline)
      Text("Choose a zone from the preview to edit it.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
  }
  .frame(maxWidth: .infinity, minHeight: 220)
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var selectedZoneIndex: Int? {
        guard let selectedZoneID else { return store.configuration.zones.indices.first }
        return store.configuration.zones.firstIndex(where: { $0.id == selectedZoneID }) ?? store.configuration.zones.indices.first
    }

    private var previewHeight: CGFloat {
        let count = store.configuration.zones.count
        let rows: Int
        switch store.configuration.layout {
        case .vertical: rows = min(count, 4)
        case .horizontal: rows = 1
        case .twoColumns: rows = Int(ceil(Double(count) / 2.0))
        case .threeColumns: rows = Int(ceil(Double(count) / 3.0))
        case .fourColumns: rows = Int(ceil(Double(count) / 4.0))
        case .spotlight: rows = count > 4 ? 2 : 1
        case .adaptive:
            let columns = count <= 2 ? count : count <= 4 ? 2 : count <= 6 ? 3 : 4
            rows = Int(ceil(Double(count) / Double(max(1, columns))))
        }
        return min(390, max(250, 170 + CGFloat(rows - 1) * 62))
    }

    private var zoneCountBinding: Binding<Int> {
        Binding(
            get: { store.configuration.zones.count },
            set: { requested in
                let count = min(8, max(1, requested))
                while store.configuration.zones.count < count { store.addZone() }
                while store.configuration.zones.count > count { store.removeZone(at: store.configuration.zones.count - 1) }
                ensureSelection()
            }
        )
    }

    private func applyTemplate(_ preset: HaloDropStudioTemplate) {
        var configuration = store.configuration
        configuration.zones = preset.actions.enumerated().map { HaloDropZone.preset($0.element, index: $0.offset) }
        configuration.layout = preset.actions.count <= 2 ? .horizontal : .adaptive
        configuration.normalize()
        store.configuration = configuration
        selectedZoneID = configuration.zones.first?.id
    }

    private func applyLook(_ look: HaloDropStudioLook) {
        var configuration = store.configuration
        switch look {
        case .halo:
            configuration.boardPadding = 10; configuration.zoneSpacing = 8; configuration.cornerRadius = 18
            configuration.backgroundStyle = .halo
            configuration.backgroundOpacity = 0.94; configuration.highlightStrength = 0.88
            configuration.showIcons = true; configuration.showSubtitles = true; configuration.showActionBadges = true
        case .glass:
            configuration.boardPadding = 13; configuration.zoneSpacing = 10; configuration.cornerRadius = 22
            configuration.backgroundStyle = .glass
            configuration.backgroundOpacity = 0.78; configuration.highlightStrength = 0.82
            configuration.showIcons = true; configuration.showSubtitles = true; configuration.showActionBadges = false
        case .minimal:
            configuration.boardPadding = 8; configuration.zoneSpacing = 6; configuration.cornerRadius = 14
            configuration.backgroundStyle = .solid
            configuration.backgroundOpacity = 0.97; configuration.highlightStrength = 0.72
            configuration.showIcons = true; configuration.showSubtitles = false; configuration.showActionBadges = false
        case .compact:
            configuration.boardPadding = 5; configuration.zoneSpacing = 5; configuration.cornerRadius = 12
            configuration.backgroundStyle = .halo
            configuration.backgroundOpacity = 0.95; configuration.highlightStrength = 1.0
            configuration.showIcons = true; configuration.showSubtitles = false; configuration.showActionBadges = true
        }
        configuration.normalize()
        store.configuration = configuration
    }

    private func actionBinding(_ index: Int) -> Binding<HaloDropZoneAction> {
        Binding(
            get: { store.configuration.zones[index].action },
            set: { action in
                guard store.configuration.zones.indices.contains(index) else { return }
                var configuration = store.configuration
                let old = configuration.zones[index]
                let preset = HaloDropZone.preset(action, index: index)
                configuration.zones[index].action = action
                if old.title.isEmpty || old.title == old.action.rawValue { configuration.zones[index].title = preset.title }
                if old.subtitle.isEmpty || old.subtitle == old.action.rawValue || old.subtitle == HaloDropZone.preset(old.action, index: index).subtitle {
                    configuration.zones[index].subtitle = preset.subtitle
                }
                if old.symbol.isEmpty || old.symbol == old.action.symbol { configuration.zones[index].symbol = action.symbol }
                if action != .copyFolder { configuration.zones[index].parameter = "" }
                configuration.normalize()
                store.configuration = configuration
            }
        )
    }

    private func setConfiguration<T>(_ keyPath: WritableKeyPath<HaloDropZoneConfiguration, T>, _ value: T) {
        var configuration = store.configuration
        configuration[keyPath: keyPath] = value
        configuration.normalize()
        store.configuration = configuration
    }

    private func configurationBinding<T>(_ keyPath: WritableKeyPath<HaloDropZoneConfiguration, T>) -> Binding<T> {
        Binding(
            get: { store.configuration[keyPath: keyPath] },
            set: { setConfiguration(keyPath, $0) }
        )
    }

    private var backgroundStyleBinding: Binding<HaloDropCIBackgroundStyle> {
        Binding(
            get: { store.configuration.resolvedBackgroundStyle },
            set: { style in var next = store.configuration; next.backgroundStyle = style; next.normalize(); store.configuration = next }
        )
    }

    private var backgroundPrimaryBinding: Binding<Color> {
        Binding(
            get: { store.configuration.resolvedBackgroundPrimaryColor.color },
            set: { color in var next = store.configuration; next.backgroundPrimaryColor = WidgetColor(color); next.normalize(); store.configuration = next }
        )
    }

    private var backgroundSecondaryBinding: Binding<Color> {
        Binding(
            get: { store.configuration.resolvedBackgroundSecondaryColor.color },
            set: { color in var next = store.configuration; next.backgroundSecondaryColor = WidgetColor(color); next.normalize(); store.configuration = next }
        )
    }

    private var backgroundAccentBinding: Binding<Double> {
        Binding(
            get: { store.configuration.resolvedBackgroundAccentStrength },
            set: { value in var next = store.configuration; next.backgroundAccentStrength = value; next.normalize(); store.configuration = next }
        )
    }

    private func zoneBinding(_ index: Int) -> Binding<HaloDropZone> {
        Binding(
            get: { store.configuration.zones[index] },
            set: { value in
                guard store.configuration.zones.indices.contains(index) else { return }
                var configuration = store.configuration
                configuration.zones[index] = value
                configuration.normalize()
                store.configuration = configuration
            }
        )
    }

    private func duplicateZone(_ index: Int) {
        guard store.configuration.zones.indices.contains(index), store.configuration.zones.count < 8 else { return }
        var configuration = store.configuration
        var copy = configuration.zones[index]
        copy.id = UUID()
        copy.title = copy.title.isEmpty ? copy.action.rawValue : copy.title + " Copy"
        configuration.zones.insert(copy, at: min(index + 1, configuration.zones.count))
        configuration.normalize()
        store.configuration = configuration
        selectedZoneID = copy.id
    }

    private func removeSelectedZone(_ index: Int) {
        guard store.configuration.zones.count > 1 else { return }
        store.removeZone(at: index)
        selectedZoneID = store.configuration.zones[min(index, store.configuration.zones.count - 1)].id
    }

    private func chooseFolder(for index: Int) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            var configuration = store.configuration
            configuration.zones[index].parameter = url.path
            store.configuration = configuration
        }
    }

    private func ensureSelection() {
        if let id = selectedZoneID, store.configuration.zones.contains(where: { $0.id == id }) { return }
        selectedZoneID = store.configuration.zones.first?.id
    }

    private func valueSlider(_ title: String, _ keyPath: WritableKeyPath<HaloDropZoneConfiguration, Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text(String(format: "%.1f", store.configuration[keyPath: keyPath]))
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: configurationBinding(keyPath), in: range)
        }
    }
}

@MainActor
private struct HaloDropZoneInteractivePreview: View {
    let configuration: HaloDropZoneConfiguration
    let selectedZoneID: UUID?
    let onSelect: (UUID) -> Void

    var body: some View {
        GeometryReader { proxy in
            let frames = HaloDropZoneLayoutResolver.frames(size: proxy.size, configuration: configuration)
            let dense = configuration.zones.count >= 6 || proxy.size.height < 270

            ZStack(alignment: .topLeading) {
                HaloDropCIBackgroundView(configuration: configuration)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                LinearGradient(colors: [Color.white.opacity(0.04), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.accentColor.opacity(0.15))
                        Image(systemName: "arrow.down.doc.fill").foregroundStyle(Color.accentColor)
                    }
                    .frame(width: 31, height: 31)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(configuration.headerTitle.isEmpty ? "Drop into Halo" : configuration.headerTitle)
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        Text(configuration.headerSubtitle.isEmpty ? "Choose what happens next" : configuration.headerSubtitle)
                            .font(.system(size: 8.5)).foregroundStyle(.white.opacity(0.42)).lineLimit(1)
                    }
                    Spacer()
                    Text("LIVE").font(.system(size: 7, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.30))
                }
                .padding(.horizontal, max(12, configuration.boardPadding + 2))
                .padding(.top, 11)

                ForEach(Array(configuration.zones.enumerated()), id: \.element.id) { index, zone in
                    if frames.indices.contains(index) {
                        let frame = frames[index]
                        Button { onSelect(zone.id) } label: {
                            previewCard(zone, selected: selectedZoneID == zone.id, dense: dense)
                        }
                        .buttonStyle(.plain)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08)))
            .foregroundStyle(.white)
        }
    }

    private func previewCard(_ zone: HaloDropZone, selected: Bool, dense: Bool) -> some View {
        GeometryReader { proxy in
            let compact = dense || proxy.size.width < 125 || proxy.size.height < 80
            let accent = zone.color.color
            VStack(alignment: .leading, spacing: compact ? 4 : 7) {
                HStack(spacing: 7) {
                    if configuration.showIcons {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(accent.opacity(selected ? 0.24 : 0.12))
                            Image(systemName: zone.symbol.isEmpty ? zone.action.symbol : zone.symbol)
                                .font(.system(size: compact ? 12 : 15, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        .frame(width: compact ? 28 : 34, height: compact ? 28 : 34)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(zone.title.isEmpty ? zone.action.rawValue : zone.title)
                            .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded)).lineLimit(1)
                        if configuration.showSubtitles && !compact && !zone.subtitle.isEmpty {
                            Text(zone.subtitle).font(.system(size: 8)).foregroundStyle(.white.opacity(0.40)).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                if !compact {
                    Spacer(minLength: 0)
                    HStack {
                        if configuration.showActionBadges {
                            Label(zone.accepts.rawValue, systemImage: zone.accepts.symbol)
                                .font(.system(size: 7.5, weight: .semibold)).foregroundStyle(.white.opacity(0.38))
                        }
                        Spacer()
                        if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent) }
                    }
                }
            }
            .padding(compact ? 7 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(selected ? 0.09 : 0.045), in: RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous).stroke(selected ? accent.opacity(0.78) : Color.white.opacity(0.07), lineWidth: selected ? 1.7 : 1))
            .shadow(color: selected ? accent.opacity(0.12) : Color.clear, radius: selected ? 8 : 0, y: 3)
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
    private var dragSessionBaselineChangeCount: Int?
    private var lastCompletedPasteboardChangeCount: Int?
    private var sawMouseDrag = false
    private var deferredFinishPending = false

    private init() {}

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        HaloDropZoneStudioWindowController.shared.installMenuItem()
        lastCompletedPasteboardChangeCount = NSPasteboard(name: .drag).changeCount

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
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
        case .leftMouseDown:
            beginPointerSession()
        case .leftMouseDragged:
            sawMouseDrag = true
            inspectDragPasteboard()
        case .leftMouseUp:
            finishAfterDropOpportunity()
        default:
            break
        }
    }

    private func beginPointerSession() {
        let pasteboard = NSPasteboard(name: .drag)
        dragSessionBaselineChangeCount = pasteboard.changeCount
        sawMouseDrag = false
        deferredFinishPending = false
    }

    private func pollDragSession() {
        let leftButtonDown = (NSEvent.pressedMouseButtons & 1) != 0
        guard leftButtonDown else {
            if activeTarget != nil || sawMouseDrag { finishAfterDropOpportunity() }
            return
        }

        deferredFinishPending = false
        if dragSessionBaselineChangeCount == nil {
            dragSessionBaselineChangeCount = NSPasteboard(name: .drag).changeCount
        }
        inspectDragPasteboard()

        if activeTarget != nil {
            activateTarget(at: NSEvent.mouseLocation, count: max(1, activeItemCount))
        }
    }

    private func inspectDragPasteboard() {
        let pasteboard = NSPasteboard(name: .drag)
        let count = dragPasteboardFileCount(pasteboard)
        guard count > 0 else { return }

        if activeTarget == nil {
            if let baseline = dragSessionBaselineChangeCount,
               pasteboard.changeCount == baseline { return }
            if dragSessionBaselineChangeCount == nil,
               let lastCompletedPasteboardChangeCount,
               pasteboard.changeCount == lastCompletedPasteboardChangeCount { return }
        }

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
        guard activeTarget != nil || sawMouseDrag else {
            resetSessionState()
            return
        }
        activeTarget?.dragStateHandler?(false, 0)
        HaloEmbeddedDropZoneController.shared.cancelIfNeeded()
        resetSessionState()
    }

    private func resetSessionState() {
        activeTarget = nil
        activeItemCount = 0
        sawMouseDrag = false
        dragSessionBaselineChangeCount = nil
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
