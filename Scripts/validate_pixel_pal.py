"""Compile the real Pixel Pal source with small service fixtures on macOS.

This isolates widget regressions when unrelated app/test-target errors block Xcode.
It complements, and never replaces, the full Halo build.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
models = (root / 'Halo/Core/WorkspaceModels.swift').read_text()
presets = models[models.index('enum OpenNotchGridSizePreset:'):models.index('struct OpenNotchGridPlacement:')]
helpers = models[models.index('// Shared by saved-layout validation,'):]
widget = (root / 'Halo/Views/PixelPetWidget.swift').read_text()
fixtures = r'''
@MainActor final class AppStore: ObservableObject {
    var finished = false
    var deadline: Date? = nil
    var pausedSeconds = 0
}
@MainActor final class MediaService: ObservableObject { var isPlaying = false }
@MainActor final class SystemService: ObservableObject { var battery: Int? = 80; var charging = false }
@MainActor final class WorkspaceStore: ObservableObject {
    let media = MediaService()
    let system = SystemService()
}
private struct SmokeColumns: EnvironmentKey { static let defaultValue: Int? = nil }
private struct SmokeRows: EnvironmentKey { static let defaultValue: Int? = nil }
extension EnvironmentValues {
    var openNotchGridColumnSpan: Int? {
        get { self[SmokeColumns.self] } set { self[SmokeColumns.self] = newValue }
    }
    var openNotchGridRowSpan: Int? {
        get { self[SmokeRows.self] } set { self[SmokeRows.self] = newValue }
    }
}
@main struct PixelPalSmoke {
    @MainActor static func main() throws {
        precondition(OpenNotchGridSizePreset.allCases.filter(HaloPixelPalLayout.supports).count == 4)
        for side in 1...4 { precondition(HaloPixelPalLayout.squareSide(columns: side, rows: side) == side) }
        precondition(HaloPixelPalLayout.squareSide(columns: 3, rows: 1) == 2)
        for side in [18.0, 37, 58, 95, 137, 211, 317] {
            for scale in [1.0, 2.0] {
                let geometry = HaloPixelPalDisplayGeometry(size: CGSize(width: side, height: side), scale: scale, fill: 1)
                precondition(side - geometry.led(x: 23, y: 23).maxX <= 1 / scale)
                for y in 0..<24 { for x in 0..<24 {
                    let r = geometry.led(x: x, y: y)
                    precondition(r.minX >= 0 && r.minY >= 0 && r.maxX <= side && r.maxY <= side)
                    for edge in [r.minX, r.minY, r.maxX, r.maxY] {
                        precondition(abs(edge * scale - (edge * scale).rounded()) < 0.00001)
                    }
                } }
            }
        }
        for t in stride(from: 0.0, through: 3, by: 0.05) {
            precondition(HaloPixelPalAnimationTiming.bounce(elapsed: t, intensity: 1, reduceMotion: true) == 0)
            precondition(HaloPixelPalAnimationTiming.bounce(elapsed: t, intensity: 0, reduceMotion: false) == 0)
        }
        precondition(HaloPixelPalAnimationTiming.bounce(elapsed: 0.1, intensity: 1, reduceMotion: false) < 0)
        precondition(HaloPixelPalAnimationTiming.bounce(elapsed: 1.1, intensity: 1, reduceMotion: false) == 0)
        let legacy = try JSONDecoder().decode(HaloPixelPalPreferences.self, from: Data(#"{"showCheeks":false,"faceScale":0.91}"#.utf8))
        precondition(legacy.cheekStyle == .none && legacy.faceScale == 0.91)
        for faceStyle in HaloPixelPalFaceStyle.allCases {
            var renderedCheeks = Set<Data>()
            for cheekStyle in HaloPixelPalCheekStyle.allCases {
                var prefs = HaloPixelPalPreferences()
                prefs.faceStyle = faceStyle
                prefs.cheekStyle = cheekStyle
                prefs.accessoryMode = .off
                prefs.backgroundStyle = .black
                prefs.glowIntensity = 0
                let normalized = prefs.normalized()
                precondition(normalized.showCheeks == (cheekStyle != .none))
                let roundTrip = try JSONDecoder().decode(HaloPixelPalPreferences.self, from: JSONEncoder().encode(normalized))
                precondition(roundTrip.cheekStyle == cheekStyle)
                let renderer = ImageRenderer(content: HaloPixelPalFace(
                    expression: .neutral, contextualAccessory: nil, fx: .none, squareSize: 1,
                    preferences: roundTrip, date: Date(), reduceMotion: true
                ).frame(width: 48, height: 48))
                renderer.scale = 2
                guard let image = renderer.cgImage, let data = image.dataProvider?.data else {
                    fatalError("Could not render cheek regression image")
                }
                renderedCheeks.insert(data as Data)
            }
            precondition(renderedCheeks.count == 4, "Every cheek option must visibly differ for \(faceStyle)")
        }
        let suite = "PixelPalSmoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try JSONEncoder().encode(legacy), forKey: "HaloPixelPal.preferences.v3")
        let pal = HaloPixelPalStore(defaults: defaults)
        precondition(pal.preferences.cheekStyle == .none)
        precondition(defaults.data(forKey: "HaloPixelPal.preferences.v4") != nil)
        let app = AppStore(), workspace = WorkspaceStore()
        func context() -> HaloPixelPalContext {
            HaloPixelPalContext.resolve(store: app, media: workspace.media, system: workspace.system,
                                        pal: pal, hovering: true, date: Date())
        }
        app.finished = true
        precondition(context().expression == .shocked, "Hover must not override a timer alert")
        pal.doubleTapped()
        precondition(context().expression == .love, "Direct interaction takes priority")
        pal.reset()
        app.finished = false
        workspace.system.battery = 10
        precondition(context().expression == .worried, "Hover must not override low battery")
        pal.update(\.contextReactions, false)
        precondition(context().expression == .happy)
        pal.update(\.tapReaction, false)
        pal.tapped()
        precondition(pal.reaction == nil)
        for style in HaloPixelPalEyeStyle.allCases {
            for sprite in [HaloPixelPalSprites.openEye(style), HaloPixelPalSprites.closedEye(style), HaloPixelPalSprites.happyEye(style)] {
                precondition(sprite.width <= 24 && sprite.height <= 24)
                precondition(Set(sprite.rows.map(\.count)).count == 1)
                precondition(sprite.rows.joined().allSatisfy { $0 == "." || HaloPixelPalColorRole(rawValue: $0) != nil })
            }
        }
        print("PASS: native Pixel Pal SwiftUI compilation, square sizes, LED geometry, animation timing, preference migration, context priority and sprites")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='halo-pixel-pal-') as scratch:
    source = Path(scratch) / 'PixelPalSmoke.swift'
    binary = Path(scratch) / 'PixelPalSmoke'
    source.write_text('import Foundation\n' + presets + helpers + '\n' + widget + '\n' + fixtures)
    subprocess.run(['swiftc', '-swift-version', '5', '-parse-as-library', str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
