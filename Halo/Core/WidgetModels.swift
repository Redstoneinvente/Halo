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
    var timeZone = "" // empty follows the system
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
    var width = 0.0 // zero fills available width
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
enum PlaybackAnimation: String, Codable, CaseIterable { case bars, wave, pulse }
struct ClosedNotchOptions: Codable, Equatable {
    var left: ClosedNotchItem = .clock
    var right: ClosedNotchItem = .visualizer
    var fontSize = 12.0
    var color = WidgetColor.white
    var animation: PlaybackAnimation = .bars
    var animate = true
    func validated() throws -> ClosedNotchOptions {
        guard fontSize.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        var v = self; v.fontSize = min(24, max(8, fontSize)); v.color = try color.validated(); return v
    }
}
