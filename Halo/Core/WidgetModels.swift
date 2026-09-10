import Foundation

enum WidgetFontFamily: String, Codable, CaseIterable { case system, rounded, serif, monospaced, custom }
enum WidgetFontWeight: String, Codable, CaseIterable { case light, regular, medium, semibold, bold }
struct WidgetColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    static let white = WidgetColor(red: 1, green: 1, blue: 1)
    static let accent = WidgetColor(red: 0.4, green: 0.7, blue: 1)
    func validated() throws -> WidgetColor {
        guard [red, green, blue].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        return WidgetColor(red: min(1, max(0, red)), green: min(1, max(0, green)), blue: min(1, max(0, blue)))
    }
}
struct ClockOptions: Codable, Equatable {
    var twentyFourHour = false
    var showSeconds = false
    var showDate = true
    var timeZone = ""
}
struct WidgetStyle: Codable, Equatable {
    var fontFamily: WidgetFontFamily = .system
    var customFont = "Helvetica Neue"
    var weight: WidgetFontWeight = .regular
    var fontSize = 14.0
    var textColor = WidgetColor.white
    var accentColor = WidgetColor.accent
    var backgroundColor = WidgetColor.white
    var backgroundOpacity = 0.06
    var padding = 12.0
    var cornerRadius = 14.0
    var width = 0.0
    var minimumHeight = 0.0
    var showTitle = true
    var clock = ClockOptions()
    func validated() throws -> WidgetStyle {
        guard [fontSize, backgroundOpacity, padding, cornerRadius, width, minimumHeight].allSatisfy(\.isFinite),
              clock.timeZone.isEmpty || TimeZone(identifier: clock.timeZone) != nil else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.fontSize = min(48, max(10, fontSize)); v.padding = min(32, max(0, padding))
        v.cornerRadius = min(40, max(0, cornerRadius)); v.backgroundOpacity = min(1, max(0, backgroundOpacity))
        v.width = width <= 0 ? 0 : min(640, max(120, width))
        v.minimumHeight = min(400, max(0, minimumHeight))
        v.textColor = try textColor.validated(); v.accentColor = try accentColor.validated(); v.backgroundColor = try backgroundColor.validated()
        v.customFont = String(customFont.prefix(120))
        return v
    }
}
enum ClosedNotchItem: String, Codable, CaseIterable, Identifiable {
    case none, clock, date, timer, battery, media, visualizer, files, activity
    var id: String { rawValue }
}
enum PlaybackAnimation: String, Codable, CaseIterable { case bars, wave, pulse, waveform, ribbon, dots, rings, orbit, spectrum }
struct ClosedExpansionOptions: Codable, Equatable {
    var enabled = true
    var width = 400.0
}
struct VisualizerOptions: Codable, Equatable {
    var dynamicColors = false
    var speed = 1.0
    var intensity = 1.0
    var width = 64.0
    var height = 16.0
    func validated() throws -> VisualizerOptions {
        guard [speed, intensity, width, height].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.speed = min(2, max(0.25, speed)); v.intensity = min(1, max(0.1, intensity))
        v.width = min(160, max(32, width)); v.height = min(48, max(8, height))
        return v
    }
}

enum MediaTextMode: String, Codable, CaseIterable { case title, artist, titleArtist, lyrics }
enum MediaOverflowMode: String, Codable, CaseIterable { case truncate, scale, marquee }
enum MediaArtworkMode: String, Codable, CaseIterable { case none, cover, background, vinyl }
struct ClosedMediaOptions: Codable, Equatable {
    var textMode: MediaTextMode = .titleArtist
    var overflow: MediaOverflowMode = .truncate
    var lines = 1
    var onlineLyrics: Bool?
    var usesOnlineLyrics: Bool { onlineLyrics ?? true }
    // Legacy artwork fields retained so existing saved profiles decode.
    var artwork: MediaArtworkMode = .none
    var artworkSize = 28.0
    var marqueeSpeed = 28.0
    var vinylRPM = 8.0
    var backgroundOpacity = 0.32
    var showPlaybackIcon = true
    func validated() throws -> ClosedMediaOptions {
        guard [artworkSize, marqueeSpeed, vinylRPM, backgroundOpacity].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.lines = min(2, max(1, lines))
        v.artworkSize = min(72, max(14, artworkSize))
        v.marqueeSpeed = min(120, max(8, marqueeSpeed))
        v.vinylRPM = min(45, max(1, vinylRPM))
        v.backgroundOpacity = min(1, max(0, backgroundOpacity))
        return v
    }
}

struct ClosedArtworkOptions: Codable, Equatable {
    var enabled = false
    var mode: MediaArtworkMode = .cover
    var side: ClosedNotchSideChoice = .automatic
    var size = 28.0
    var padding = 0.0
    var margin = 7.0
    var vinylRPM = 8.0
    var backgroundOpacity = 0.32
    func validated() throws -> ClosedArtworkOptions {
        guard [size, padding, margin, vinylRPM, backgroundOpacity].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        if v.mode == .none { v.enabled = false }
        v.size = min(72, max(14, size))
        v.padding = min(24, max(0, padding))
        v.margin = min(48, max(0, margin))
        v.vinylRPM = min(45, max(1, vinylRPM))
        v.backgroundOpacity = min(1, max(0, backgroundOpacity))
        return v
    }
}

enum ReactiveDriver: String, Codable, CaseIterable { case pulse, bass, mids, treble, spectrum }
struct ReactiveBackgroundOptions: Codable, Equatable {
    var enabled = false
    var driver: ReactiveDriver = .pulse
    var speed = 1.0
    var intensity = 0.5
    var brightness = 0.22
    var saturation = 0.15
    var scale = 0.015
    var hueShift = 0.0
    var blur = 0.0
    var grain = 0.0
    func validated() throws -> ReactiveBackgroundOptions {
        guard [speed, intensity, brightness, saturation, scale, hueShift, blur, grain].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.speed = min(3, max(0.2, speed)); v.intensity = min(1, max(0, intensity))
        v.brightness = min(0.8, max(0, brightness)); v.saturation = min(1, max(0, saturation))
        v.scale = min(0.12, max(0, scale)); v.hueShift = min(1, max(0, hueShift))
        v.blur = min(12, max(0, blur)); v.grain = min(0.6, max(0, grain))
        return v
    }
}

enum PowerReactionStyle: String, Codable, CaseIterable { case off, icon, percent, iconPercent, label }
enum ClosedNotchSideChoice: String, Codable, CaseIterable { case automatic, left, right }
struct PowerReactionOptions: Codable, Equatable {
    var enabled: Bool?
    var isEnabled: Bool { enabled ?? true }
    var lowThreshold = 20
    var side: ClosedNotchSideChoice = .automatic
    var charging: PowerReactionStyle = .iconPercent
    var low: PowerReactionStyle = .iconPercent
    var charged: PowerReactionStyle = .icon
    var expandForEvent = true
    var eventWidth = 96.0
    var color = WidgetColor.accent
    var dynamicColor: Bool?
    var usesDynamicColor: Bool { dynamicColor ?? false }
    var lowColor: WidgetColor?
    var midColor: WidgetColor?
    var highColor: WidgetColor?
    var resolvedLowColor: WidgetColor { lowColor ?? WidgetColor(red: 1.0, green: 0.22, blue: 0.18) }
    var resolvedMidColor: WidgetColor { midColor ?? WidgetColor(red: 1.0, green: 0.72, blue: 0.12) }
    var resolvedHighColor: WidgetColor { highColor ?? WidgetColor(red: 0.28, green: 0.92, blue: 0.42) }
    func validated() throws -> PowerReactionOptions {
        guard eventWidth.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.lowThreshold = min(50, max(5, lowThreshold))
        v.eventWidth = min(240, max(48, eventWidth))
        v.color = try color.validated()
        if lowColor != nil { v.lowColor = try resolvedLowColor.validated() }
        if midColor != nil { v.midColor = try resolvedMidColor.validated() }
        if highColor != nil { v.highColor = try resolvedHighColor.validated() }
        return v
    }
}

struct ClosedNotchOptions: Codable, Equatable {
    var autoFitContent: Bool?
    var horizontalPadding: Double?
    var verticalPadding: Double?
    var sideMargin: Double?
    var outerMargin: Double?
    var albumTextColor: Bool?
    var albumBackgroundColor: Bool?
    var albumBackgroundFrequencyEffect: Bool?
    var mediaOptions: ClosedMediaOptions?
    var artworkOptions: ClosedArtworkOptions?
    var reactiveBackground: ReactiveBackgroundOptions?
    var powerReaction: PowerReactionOptions?
    var contentPaddingX: Double { min(24, max(0, horizontalPadding ?? 8)) }
    var contentPaddingY: Double { min(12, max(0, verticalPadding ?? 2)) }
    var contentSideMargin: Double { min(48, max(0, sideMargin ?? 4)) }
    var contentOuterMargin: Double { min(48, max(0, outerMargin ?? 4)) }
    var leftDecoration: SideDecoration?
    var rightDecoration: SideDecoration?
    var visualizer: VisualizerOptions?
    var expansion: ClosedExpansionOptions?
    var left: ClosedNotchItem = .clock
    var right: ClosedNotchItem = .visualizer
    var fontSize = 12.0
    var color = WidgetColor.white
    var animation: PlaybackAnimation = .bars
    var animate = true
    func validated() throws -> ClosedNotchOptions {
        guard fontSize.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        guard (horizontalPadding ?? 8).isFinite, (verticalPadding ?? 2).isFinite, (sideMargin ?? 4).isFinite, (outerMargin ?? 4).isFinite else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        if horizontalPadding != nil { v.horizontalPadding = contentPaddingX }
        if verticalPadding != nil { v.verticalPadding = contentPaddingY }
        if sideMargin != nil { v.sideMargin = contentSideMargin }
        if outerMargin != nil { v.outerMargin = contentOuterMargin }
        v.fontSize = min(24, max(8, fontSize)); v.color = try color.validated()
        v.leftDecoration = try leftDecoration?.validatedForImport()
        v.rightDecoration = try rightDecoration?.validatedForImport()
        v.visualizer = try visualizer?.validated()
        v.mediaOptions = try mediaOptions?.validated()
        v.artworkOptions = try artworkOptions?.validated()
        v.reactiveBackground = try reactiveBackground?.validated()
        v.powerReaction = try powerReaction?.validated()
        if var expansion {
            guard expansion.width.isFinite else { throw CocoaError(.fileReadCorruptFile) }
            expansion.width = min(640, max(120, expansion.width)); v.expansion = expansion
        }
        return v
    }
}

enum MusicPalette {
    static func colors(from samples: [WidgetColor]) -> [WidgetColor] {
        var bins: [Int: Int] = [:]
        for sample in samples {
            guard let c = try? sample.validated() else { continue }
            let high = max(c.red, max(c.green, c.blue))
            let low = min(c.red, min(c.green, c.blue))
            guard high > 0.12, low < 0.92 else { continue }
            let key = Int(c.red * 7) * 64 + Int(c.green * 7) * 8 + Int(c.blue * 7)
            bins[key, default: 0] += high - low > 0.15 ? 3 : 1
        }
        let ranked = bins.keys.sorted { bins[$0] == bins[$1] ? $0 < $1 : bins[$0]! > bins[$1]! }
        var result: [WidgetColor] = []
        for key in ranked {
            var c = WidgetColor(red: Double(key / 64) / 7, green: Double(key / 8 % 8) / 7, blue: Double(key % 8) / 7)
            let high = max(c.red, max(c.green, c.blue))
            let lift = max(0, 0.65 - high)
            c.red += lift; c.green += lift; c.blue += lift
            if result.allSatisfy({ abs($0.red - c.red) + abs($0.green - c.green) + abs($0.blue - c.blue) > 0.35 }) { result.append(c) }
            if result.count == 2 { break }
        }
        return result
    }
}
