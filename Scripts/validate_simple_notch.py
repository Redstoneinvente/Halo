"""Test actual Simple layout code and render actual cards with inert service fixtures.

Complements the full Xcode build; never starts personal media/calendar services.
Pixel Pal has its own renderer validation and is excluded from these snapshots.
Usage: python3 Scripts/validate_simple_notch.py [snapshot-directory] [populated]
"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
models = (root / 'Halo/Core/WorkspaceModels.swift').read_text()
models = models[:models.index('enum BackgroundKind:')]
views = (root / 'Halo/Views/SurfaceView.swift').read_text()
views = views[views.index('private struct SimpleNotchWidgetView:'):views.index('private struct SimpleClosedNotchView:')]
a = views.index('    private var pixelPal: some View {')
b = views.index('    private var compactMedia:', a)
views = views[:a] + '    private var pixelPal: some View { Color.clear }\n\n' + views[b:]
# ImageRenderer cannot render AppKit's drop-destination bridge. The interaction
# wrapper has no visual content; render the exact same shell without that bridge.
a = views.index('    @ViewBuilder\n    var body: some View {')
b = views.index('    private var shell:', a)
views = views[:a] + '    var body: some View { shell }\n\n' + views[b:]
tests = (root / 'Tests/HaloCoreTests.swift').read_text()
tests = tests[tests.index('final class SimpleNotchLayoutTests:'):]
fixtures = r'''
import SwiftUI
import AppKit
import EventKit
// Execute the same XCTest test bodies with fail-fast assertions in this CLI.
class XCTestCase {}
func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T) { precondition(lhs == rhs, "\(lhs) != \(rhs)") }
func XCTAssertEqual(_ lhs: Double, _ rhs: Double, accuracy: Double) { precondition(abs(lhs - rhs) <= accuracy) }
func XCTAssertGreaterThanOrEqual(_ lhs: Double, _ rhs: Double) { precondition(lhs >= rhs) }
func XCTAssertLessThanOrEqual(_ lhs: Double, _ rhs: Double) { precondition(lhs <= rhs) }
@MainActor final class AppStore: ObservableObject {
    var deadline: Date? = nil
    var pausedSeconds: TimeInterval = 0
    var finished = false
    var timerDurationSeconds: TimeInterval = 1500
    var files: [URL] = []
    func addFiles(_ files: [URL]) {}
    func chooseFiles() {}
    func startTimer(minutes: Int) {}
    func addTimer(minutes: Int) {}
    func pauseResume() {}
    func resetTimer() {}
}
@MainActor final class SurfaceState: ObservableObject { var expanded = true }
struct FixtureSettings { var mediaApp = "com.apple.Music" }
struct FixtureCalendar { var upcomingEvents: [EKEvent] = [] }
@MainActor final class FixtureMedia {
    var title = "A quiet afternoon"
    var artist = "Halo Sessions"
    var isPlaying = true
    var duration: Double = 240
    var position: Double = 84
    var connectedApp: String? = "com.apple.Music"
    var artworkImage: NSImage? = nil
    func perform(_ action: String, app: String) {}
}
@MainActor final class WorkspaceStore: ObservableObject {
    var settings = FixtureSettings()
    var calendar = FixtureCalendar()
    var media = FixtureMedia()
    var stopwatchStart: Date? = nil
    var stopwatchElapsed: TimeInterval = 125
    func toggleStopwatch() {}
}
@main struct SimpleValidation {
    @MainActor static func main() throws {
        if CommandLine.arguments.count > 1 {
            let directory = URL(fileURLWithPath: CommandLine.arguments[1])
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let store = AppStore()
            let workspace = WorkspaceStore()
            let state = SurfaceState()
            if CommandLine.arguments.count > 2 {
                store.deadline = Date().addingTimeInterval(735)
                store.files = (1...3).map { URL(fileURLWithPath: "/Example/Project research and reference notes \($0).pdf") }
                workspace.stopwatchStart = Date().addingTimeInterval(-10)
                workspace.media.title = "An intentionally long track title to check graceful truncation"
                workspace.media.artist = "A longer artist name with multiple collaborators"
                let event = EKEvent(eventStore: EKEventStore())
                event.title = "Design review and planning for the next release"
                event.startDate = Date().addingTimeInterval(1800)
                event.endDate = Date().addingTimeInterval(3600)
                workspace.calendar.upcomingEvents = [event]
            }
            for size in SimpleNotchSize.allCases {
                for style in SimpleNotchWidgetStyle.allCases {
                    let content = VStack(alignment: .leading, spacing: 16) {
                        Text("HALO  /  \(style.title.uppercased())  /  \(size.rawValue.uppercased())")
                            .font(.system(size: 12, weight: .medium)).tracking(2).foregroundStyle(.secondary)
                        ForEach(0..<2) { row in
                            HStack(spacing: 12) {
                                ForEach(row == 0 ? [ModuleID.clock, .media, .calendar] : [.timer, .stopwatch, .shelf]) { widget in
                                    SimpleNotchWidgetView(widget: widget, preset: style, sizePreset: size,
                                                          store: store, workspace: workspace, surfaceState: state)
                                        .frame(width: SimpleNotchMetrics.width(for: widget, size: size),
                                               height: SimpleNotchMetrics.height(for: widget, style: style, size: size))
                                }
                            }
                        }
                    }
                    .padding(28).background(Color.black).foregroundStyle(.white).environment(\.colorScheme, .dark)
                    let renderer = ImageRenderer(content: content)
                    renderer.scale = 2
                    guard let image = renderer.cgImage else { fatalError("Snapshot failed") }
                    let bitmap = NSBitmapImageRep(cgImage: image)
                    let png = bitmap.representation(using: .png, properties: [:])!
                    try png.write(to: directory.appendingPathComponent("\(style.title)-\(size.rawValue).png"))
                }
            }
        }
        let tests = SimpleNotchLayoutTests()
        tests.testEveryWidgetCombinationFitsWithoutLosingOrReorderingCards()
        tests.testSingleWidgetRetractsButAlwaysCoversHardware()
        tests.testMonthCalendarSetsRowHeightAndEmptySettingsStillShowClock()
        print("Passed: 4,572 widget combinations plus hardware floors, retraction and calendar checks.")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='halo-simple-') as tmp:
    source = Path(tmp) / 'SimpleValidation.swift'
    source.write_text(fixtures + '\n' + models + '\n' + views + '\n' + tests)
    binary = Path(tmp) / 'validate'
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary), *sys.argv[1:]], check=True)
