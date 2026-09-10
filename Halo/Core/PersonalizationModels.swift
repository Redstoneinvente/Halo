import Foundation

struct DailyWindow: Codable, Equatable {
    var startMinute = 9 * 60
    var endMinute = 17 * 60
    var weekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7] // Calendar: Sunday = 1
    func occurrence(at date: Date, calendar: Calendar = .current) -> Date? {
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let start = min(1439, max(0, startMinute)), end = min(1439, max(0, endMinute))
        var day = calendar.startOfDay(for: date)
        if start < end {
            guard minute >= start && minute < end else { return nil }
        } else if start > end {
            if minute < end { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
            else if minute < start { return nil }
        }
        return weekdays.contains(calendar.component(.weekday, from: day)) ? day : nil
    }
}
struct ProfileSchedule: Codable, Identifiable, Equatable {
    var id = UUID()
    var enabled = true
    var window = DailyWindow()
    var profileID: UUID
}
struct GrainOptions: Codable, Equatable {
    var enabled = false
    var amount = 0.18
    var size = 1.0
    var warmth = 0.3
    func validated() throws -> GrainOptions {
        guard [amount, size, warmth].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.amount = min(0.6, max(0, amount)); v.size = min(3, max(0.5, size)); v.warmth = min(1, max(0, warmth))
        return v
    }
}
struct TimedBackground: Codable, Identifiable, Equatable {
    var id = UUID()
    var enabled = true
    var window = DailyWindow()
    var kind: BackgroundKind = .gradient
    var assetPath = ""
    var blur = 0.0
    var grain = GrainOptions()
}
extension Appearance {
    func resolved(at date: Date, calendar: Calendar = .current) -> Appearance {
        guard let entry = backgroundSchedule?.first(where: { $0.enabled && $0.window.occurrence(at: date, calendar: calendar) != nil }) else { return self }
        var result = self
        result.background = entry.kind; result.assetPath = entry.assetPath
        result.blur = entry.blur; result.grain = entry.grain
        return result
    }
}
enum DecorationVisibility: String, Codable, CaseIterable { case disabled, always, playing }
enum DecorationKind: String, Codable, CaseIterable { case symbol, image }
struct SideDecoration: Codable, Equatable {
    var visibility: DecorationVisibility = .disabled
    var kind: DecorationKind = .symbol
    var symbol = "sparkles"
    var assetPath = ""
    var size = 22.0
    var color = WidgetColor.white
    func isVisible(playing: Bool) -> Bool { visibility == .always || (visibility == .playing && playing) }
    func validatedForImport() throws -> SideDecoration {
        guard size.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        var v = self; v.size = min(64, max(12, size)); v.color = try color.validated()
        v.symbol = String(symbol.prefix(120)); v.assetPath = ""
        if kind == .image { v.visibility = .disabled }
        return v
    }
}

struct PlayerSnapshot: Equatable {
    var app: String
    var title = "Nothing playing"
    var artist = ""
    var playing = false
    var trackID = ""
}
enum PlayerSelection {
    static func choose(_ snapshots: [PlayerSnapshot], current: String?, preferred: String) -> PlayerSnapshot? {
        let playing = snapshots.filter(\.playing)
        let candidates = playing.isEmpty ? snapshots : playing
        return candidates.first { $0.app == current } ?? candidates.first { $0.app == preferred } ?? candidates.first
    }
}
