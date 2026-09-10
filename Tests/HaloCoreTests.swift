import XCTest
#if SWIFT_PACKAGE
@testable import HaloCore
#endif

final class HaloCoreTests: XCTestCase {
    func testMediaWidthChangesDoNotResizeOppositeWing() {
        for leftLive in [false, true] {
            for rightLive in [false, true] {
                let initial = ClosedWingSizing.extents(base: 206, camera: 190, left: 80, right: 90, expansion: 400, leftLive: leftLive, rightLive: rightLive)
                let longLeft = ClosedWingSizing.extents(base: 206, camera: 190, left: 320, right: 90, expansion: 400, leftLive: leftLive, rightLive: rightLive)
                let longRight = ClosedWingSizing.extents(base: 206, camera: 190, left: 80, right: 320, expansion: 400, leftLive: leftLive, rightLive: rightLive)
                XCTAssertEqual(initial.right, longLeft.right)
                XCTAssertEqual(initial.left, longRight.left)
                XCTAssertGreaterThan(longLeft.left, initial.left)
                XCTAssertGreaterThan(longRight.right, initial.right)
            }
        }
    }

    func testProfilePresentationMetadataRoundTripsAndOldProfilesDecode() throws {
        var profile = Profile(name: "Evening")
        profile.icon = "moon"; profile.description = "Quiet workspace"
        profile.layout.horizontalWidgets = true; profile.layout.horizontalPages = true; profile.layout.horizontalHeight = 240
        let data = try JSONEncoder().encode(profile)
        let saved = try JSONDecoder().decode(Profile.self, from: data)
        XCTAssertEqual(saved.icon, "moon"); XCTAssertEqual(saved.description, "Quiet workspace")
        XCTAssertEqual(saved.layout.horizontalPages, true); XCTAssertEqual(saved.layout.horizontalHeight, 240)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        old.removeValue(forKey: "icon"); old.removeValue(forKey: "description")
        var layout = try XCTUnwrap(old["layout"] as? [String: Any])
        for key in ["horizontalWidgets", "horizontalPages", "horizontalHeight"] { layout.removeValue(forKey: key) }
        old["layout"] = layout
        let restored = try JSONDecoder().decode(Profile.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(restored.icon); XCTAssertNil(restored.layout.horizontalWidgets)
    }
    func testSurfaceStylesHaveDistinctPlacementAndWidth() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        var geometry = SurfaceGeometry(screen: screen, visible: CGRect(x: 0, y: 0, width: 1440, height: 875), safeAreaTop: 0, physicalNotchWidth: 0, style: .pill, appearance: Appearance(), expandedWidth: 420)
        let pill = geometry.frame(expanded: false)
        geometry.style = .island
        XCTAssertNotEqual(pill.maxY, geometry.frame(expanded: false).maxY)
        geometry.style = .simulated
        XCTAssertEqual(geometry.frame(expanded: false).maxY, screen.maxY)
        geometry.style = .shelf
        XCTAssertGreaterThan(geometry.frame(expanded: false).width, pill.width)
        geometry.style = .menuBar
        XCTAssertEqual(geometry.frame(expanded: false).width, 1416)
        geometry.style = .detached
        XCTAssertEqual(geometry.frame(expanded: false).midY, geometry.visible.midY)
    }

    func testRefreshRatePolicyMatchesDisplayAndPowerMode() {
        XCTAssertEqual(FrameRatePolicy.target(maximum: 120, lowPower: false), 120)
        XCTAssertEqual(FrameRatePolicy.target(maximum: 60, lowPower: false), 60)
        XCTAssertEqual(FrameRatePolicy.target(maximum: 144, lowPower: false), 120)
        XCTAssertEqual(FrameRatePolicy.target(maximum: 120, lowPower: true), 60)
        XCTAssertEqual(FrameRatePolicy.target(maximum: 0, lowPower: false), 60)
    }
    func testClosedContentWidthReservesBothSidesOfOffsetCamera() {
        XCTAssertEqual(ClosedContentSizing.width(left: 60, right: 80), 160)
        XCTAssertEqual(ClosedContentSizing.width(left: 60, right: 80, camera: 190), 350)
        let width = ClosedContentSizing.width(left: 60, right: 80, camera: 190, cameraOffset: 25)
        XCTAssertEqual(width, 400)
        XCTAssertGreaterThanOrEqual((width - 190) / 2 + 25, 60)
        XCTAssertGreaterThanOrEqual((width - 190) / 2 - 25, 80)
    }
    func testClosedPaddingDefaultsAndValidation() throws {
        var options = ClosedNotchOptions()
        XCTAssertTrue(options.autoFitContent ?? true)
        XCTAssertEqual(options.contentPaddingX, 8); XCTAssertEqual(options.contentPaddingY, 2)
        options.horizontalPadding = 500; options.verticalPadding = -2
        let safe = try options.validated()
        XCTAssertEqual(safe.horizontalPadding, 24); XCTAssertEqual(safe.verticalPadding, 0)
        options.horizontalPadding = .infinity
        XCTAssertThrowsError(try options.validated())
    }
    func testSchedulesHandleWeekdaysOvernightAndEndBoundary() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
        }
        let overnight = DailyWindow(startMinute: 22 * 60, endMinute: 6 * 60, weekdays: [2])
        XCTAssertNotNil(overnight.occurrence(at: date(7, 22), calendar: calendar)) // Monday
        XCTAssertEqual(overnight.occurrence(at: date(8, 5, 59), calendar: calendar), calendar.startOfDay(for: date(7, 0)))
        XCTAssertNil(overnight.occurrence(at: date(8, 6), calendar: calendar))
        XCTAssertNil(overnight.occurrence(at: date(8, 22), calendar: calendar))
        let allDay = DailyWindow(startMinute: 0, endMinute: 0, weekdays: [2])
        XCTAssertNotNil(allDay.occurrence(at: date(7, 23, 59), calendar: calendar))
        XCTAssertNil(allDay.occurrence(at: date(8, 0), calendar: calendar))
    }
    func testBackgroundScheduleRestoresBaseAndUsesFirstMatch() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 12))!
        var base = Appearance(); base.background = .solid
        var first = TimedBackground(); first.kind = .glass
        var second = TimedBackground(); second.kind = .image; second.assetPath = "/chosen/photo.png"
        base.backgroundSchedule = [first, second]
        XCTAssertEqual(base.resolved(at: noon, calendar: calendar).background, .glass)
        XCTAssertEqual(base.resolved(at: noon.addingTimeInterval(8 * 3600), calendar: calendar).background, .solid)
        XCTAssertEqual(base.background, .solid)
    }
    func testPlayerSelectionFollowsPlayingAppAndAvoidsTieFlapping() {
        var music = PlayerSnapshot(app: "com.apple.Music")
        var spotify = PlayerSnapshot(app: "com.spotify.client", playing: true)
        XCTAssertEqual(PlayerSelection.choose([music, spotify], current: music.app, preferred: music.app)?.app, spotify.app)
        music.playing = true
        XCTAssertEqual(PlayerSelection.choose([music, spotify], current: spotify.app, preferred: music.app)?.app, spotify.app)
        spotify.playing = false
        XCTAssertEqual(PlayerSelection.choose([music, spotify], current: spotify.app, preferred: spotify.app)?.app, music.app)
        XCTAssertNil(PlayerSelection.choose([], current: nil, preferred: music.app))
    }
    func testDecorationVisibilityAndImportedPaths() throws {
        var decoration = SideDecoration(); decoration.visibility = .playing
        XCTAssertFalse(decoration.isVisible(playing: false)); XCTAssertTrue(decoration.isVisible(playing: true))
        decoration.visibility = .always
        XCTAssertTrue(decoration.isVisible(playing: false))
        decoration.kind = .image; decoration.assetPath = "/private/image.gif"
        let imported = try decoration.validatedForImport()
        XCTAssertEqual(imported.assetPath, ""); XCTAssertEqual(imported.visibility, .disabled)
    }
    func testPersonalizationRoundTripAndLegacySettings() throws {
        let defaults = try JSONDecoder().decode(WorkspaceSettings.self, from: JSONEncoder().encode(WorkspaceSettings()))
        XCTAssertNil(defaults.automaticMedia); XCTAssertNil(defaults.profileSchedules)
        XCTAssertTrue(defaults.automaticMedia ?? true)
        var layout = WorkspaceLayout()
        layout.appearance.grain = GrainOptions(enabled: true)
        layout.appearance.backgroundSchedule = [TimedBackground()]
        var options = ClosedNotchOptions()
        options.leftDecoration = SideDecoration(visibility: .always, symbol: "heart.fill")
        layout.closedNotch = options
        XCTAssertEqual(try JSONDecoder().decode(WorkspaceLayout.self, from: JSONEncoder().encode(layout)), layout)
    }
    func testVisualizerSettingsRoundTripAndLegacyDefaults() throws {
        let legacy = try JSONDecoder().decode(ClosedNotchOptions.self, from: JSONEncoder().encode(ClosedNotchOptions()))
        XCTAssertNil(legacy.visualizer)
        XCTAssertFalse((legacy.visualizer ?? VisualizerOptions()).dynamicColors)
        for animation in PlaybackAnimation.allCases {
            var options = ClosedNotchOptions()
            options.animation = animation
            options.visualizer = VisualizerOptions(dynamicColors: true, speed: 1.5, intensity: 0.8, width: 96, height: 24)
            let restored = try JSONDecoder().decode(ClosedNotchOptions.self, from: JSONEncoder().encode(options)).validated()
            XCTAssertEqual(restored, options)
        }
        var invalid = VisualizerOptions(); invalid.speed = .infinity
        XCTAssertThrowsError(try invalid.validated())
    }
    func testArtworkPaletteUsesDominantColorsAndRejectsEmptyArtwork() {
        let red = WidgetColor(red: 1, green: 0, blue: 0)
        let blue = WidgetColor(red: 0, green: 0, blue: 1)
        let colors = MusicPalette.colors(from: Array(repeating: red, count: 8) + [blue, blue, .white])
        XCTAssertEqual(colors, [red, blue])
        XCTAssertTrue(MusicPalette.colors(from: []).isEmpty)
        XCTAssertTrue(MusicPalette.colors(from: [.white, WidgetColor(red: 0, green: 0, blue: 0)]).isEmpty)
    }
    func testLiveWidthOnlyChangesClosedHorizontalGeometry() {
        var model = geometry(requested: 190)
        model.appearance.surface.offsets = SurfaceOffsets(closedX: 30, closedY: 10)
        let idle = model.frame(expanded: false)
        let dashboard = model.frame(expanded: true)
        model.activeCompactWidth = 500
        let live = model.frame(expanded: false)
        XCTAssertEqual(live.width, 500)
        XCTAssertEqual(live.height, idle.height)
        XCTAssertEqual(live.midX, idle.midX)
        XCTAssertEqual(live.maxY, idle.maxY)
        XCTAssertEqual(model.frame(expanded: true), dashboard)
        model.activeCompactWidth = nil
        XCTAssertEqual(model.frame(expanded: false), idle)
    }
    func testActiveWidthNeverShrinksConfiguredWidth() {
        var model = geometry(requested: 500)
        model.activeCompactWidth = 300
        XCTAssertEqual(model.compactWidth, 500)
    }
    func testOldLayoutsDecodeWithoutWidgetPreferences() throws {
        let original = WorkspaceLayout()
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkspaceLayout.self, from: encoded)
        XCTAssertNil(decoded.widgets)
        XCTAssertNil(decoded.closedNotch)
        XCTAssertEqual(decoded.widgetStyle(for: .clock).fontSize, 30)
    }
    func testWidgetPreferencesSurviveThemeRoundTrip() throws {
        var layout = WorkspaceLayout()
        var clock = WidgetStyle(); clock.fontFamily = .serif; clock.fontSize = 42
        clock.clock.twentyFourHour = true; clock.clock.timeZone = "Asia/Tokyo"
        layout.setWidgetStyle(clock, for: .clock)
        layout.closedNotch = ClosedNotchOptions(left: .battery, right: .visualizer)
        let archive = ThemeArchive(theme: Theme(), layout: layout)
        let decoded = try JSONDecoder().decode(ThemeArchive.self, from: JSONEncoder().encode(archive)).validated()
        XCTAssertEqual(decoded.layout.widgetStyle(for: .clock), clock)
        XCTAssertEqual(decoded.layout.closedNotch, layout.closedNotch)
        XCTAssertEqual(decoded.layout.widgetStyle(for: .notes).fontSize, 14)
    }
    func testWidgetImportValidation() throws {
        var style = WidgetStyle(); style.fontSize = 100; style.width = 900; style.backgroundOpacity = -2
        let safe = try style.validated()
        XCTAssertEqual(safe.fontSize, 48); XCTAssertEqual(safe.width, 640); XCTAssertEqual(safe.backgroundOpacity, 0)
        style.clock.timeZone = "Not/AZone"
        XCTAssertThrowsError(try style.validated())
        var closed = ClosedNotchOptions(); closed.fontSize = .infinity
        XCTAssertThrowsError(try closed.validated())
    }
    func testClosedCameraReservationTracksOffsets() {
        var model = geometry(requested: 400)
        XCTAssertEqual(model.closedCameraOcclusion?.minX, 110)
        XCTAssertEqual(model.closedCameraOcclusion?.width, 180)
        model.appearance.surface.offsets = SurfaceOffsets(closedX: 50, closedY: 0)
        XCTAssertEqual(model.closedCameraOcclusion?.minX, 60)
        model.appearance.surface.offsets?.closedY = 100
        XCTAssertNil(model.closedCameraOcclusion)
        XCTAssertNil(geometry(safeArea: 0).closedCameraOcclusion)
    }
    func testGlassTintNeverObscuresMaterial() {
        XCTAssertEqual(GlassRendering.tintOpacity(themeOpacity: 0.5), 0)
        XCTAssertLessThan(GlassRendering.tintOpacity(themeOpacity: 1), 0.2)
        XCTAssertTrue(GlassRendering.tintOpacity(themeOpacity: .nan).isFinite)
    }
    private func geometry(style: SurfaceStyle = .notch, safeArea: Double = 32, requested: Double = 400) -> SurfaceGeometry {
        var appearance = Appearance(); appearance.compactWidth = requested
        return SurfaceGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), visible: CGRect(x: 0, y: 40, width: 1512, height: 910),
                               safeAreaTop: safeArea, physicalNotchWidth: 180, style: style, appearance: appearance, expandedWidth: 420)
    }
    func testPhysicalNotchHonorsRequestedClosedWidth() {
        XCTAssertEqual(geometry(requested: 400).frame(expanded: false).width, 400)
        XCTAssertEqual(geometry(requested: 500).frame(expanded: false).width, 500)
    }
    func testAllPlacementsAllowSixteenPointClosedSize() {
        for style in SurfaceStyle.allCases {
            var model = geometry(style: style, requested: 16)
            model.appearance.surface.compactHeight = 16
            XCTAssertEqual(model.frame(expanded: false).size, CGSize(width: 16, height: 16))
        }
    }
    func testSimulatedNotchHasNoHardcodedWidth() {
        XCTAssertEqual(geometry(style: .simulated, requested: 370).frame(expanded: false).width, 370)
    }
    func testMenuBarOnlyUsesFullWidthWhenOpen() {
        let model = geometry(style: .menuBar, requested: 280)
        XCTAssertEqual(model.frame(expanded: false).width, 280)
        XCTAssertEqual(model.frame(expanded: true).width, 1488)
    }
    func testClosedHeightAndOpenWidthNeverShrinkUnexpectedly() {
        var model = geometry(requested: 600); model.appearance.surface.compactHeight = 72
        XCTAssertEqual(model.frame(expanded: false).height, 72)
        XCTAssertGreaterThanOrEqual(model.frame(expanded: true).width, model.frame(expanded: false).width)
    }
    func testFramesRespectNegativeScreenOriginsAndEdgeAnchors() {
        var model = geometry(style: .bottom)
        model.screen.origin.x = -1512; model.visible.origin.x = -1512
        for expanded in [false, true] {
            XCTAssertEqual(model.frame(expanded: expanded).minY, 48)
            XCTAssertTrue(model.visible.contains(model.frame(expanded: expanded)))
        }
        model.style = .right
        XCTAssertEqual(model.frame(expanded: false).maxX, model.visible.maxX - 8)
    }
    func testLegacyAppearanceDecodesWithoutResettingSettings() throws {
        let legacy = Data(#"{"compactWidth":301,"background":"solid","animation":"elastic"}"#.utf8)
        let appearance = try JSONDecoder().decode(Appearance.self, from: legacy)
        XCTAssertEqual(appearance.compactWidth, 301)
        XCTAssertEqual(appearance.background, .solid)
        XCTAssertEqual(appearance.surface, SurfaceOptions())
    }
    func testSurfaceOptionsRoundTripAndValidation() throws {
        var appearance = Appearance(); appearance.surface.shape = .scoop; appearance.surface.closing = .slide
        let decoded = try JSONDecoder().decode(Appearance.self, from: JSONEncoder().encode(appearance))
        XCTAssertEqual(decoded, appearance)
        var options = SurfaceOptions(); options.duration = 9; options.compactHeight = 0
        XCTAssertEqual(try options.validated().duration, 1.2)
        XCTAssertEqual(try options.validated().compactHeight, 16)
        options.damping = .infinity
        XCTAssertThrowsError(try options.validated())
    }
    func testTransitionEndpointsAndFiniteSamples() {
        for transition in SurfaceTransition.allCases {
            XCTAssertEqual(SurfaceMotion.progress(0, transition: transition, preset: .smooth, damping: 0.8), 0)
            XCTAssertEqual(SurfaceMotion.progress(1, transition: transition, preset: .smooth, damping: 0.8), 1)
            for step in 0...100 {
                let progress = SurfaceMotion.progress(Double(step) / 100, transition: transition, preset: .smooth, damping: 0.4)
                XCTAssertTrue(progress.isFinite); XCTAssertGreaterThanOrEqual(progress, 0); XCTAssertLessThan(progress, 1.4)
            }
        }
        XCTAssertGreaterThan(SurfaceMotion.progress(0.3, transition: .spring, preset: .smooth, damping: 0.4), 1)
    }
    func testModuleDragPreservesEveryModuleOnce() {
        var layout = WorkspaceLayout(); layout.move(.notes, before: .clock)
        XCTAssertEqual(layout.order.first, .notes)
        XCTAssertEqual(Set(layout.order), Set(ModuleID.allCases))
        XCTAssertEqual(layout.order.count, ModuleID.allCases.count)
        layout.move(.notes, before: .notes)
        XCTAssertEqual(layout.order.first, .notes)
    }
    func testOpenAndClosedOffsetsAreIndependentAndPositiveYMovesDown() {
        for style in SurfaceStyle.allCases {
            var model = geometry(style: style)
            let closed = model.frame(expanded: false), opened = model.frame(expanded: true)
            model.appearance.surface.offsets = SurfaceOffsets(openedX: 70, openedY: 45, closedX: -25, closedY: 12)
            XCTAssertEqual(model.frame(expanded: false).minX, closed.minX - 25)
            XCTAssertEqual(model.frame(expanded: false).minY, closed.minY - 12)
            XCTAssertEqual(model.frame(expanded: true).minX, opened.minX + 70)
            XCTAssertEqual(model.frame(expanded: true).minY, opened.minY - 45)
        }
    }
    func testOlderSurfaceOptionsDecodeWithZeroOffsets() throws {
        let data = try JSONEncoder().encode(SurfaceOptions())
        let decoded = try JSONDecoder().decode(SurfaceOptions.self, from: data)
        XCTAssertNil(decoded.offsets)
        var model = geometry(); model.appearance.surface = decoded
        XCTAssertEqual(model.offset(expanded: true), .zero)
        XCTAssertEqual(model.offset(expanded: false), .zero)
    }
    func testOffsetsValidateAndPersist() throws {
        var options = SurfaceOptions(); options.offsets = SurfaceOffsets(openedX: 1001, openedY: -1001, closedX: 16, closedY: -16)
        let validated = try options.validated()
        XCTAssertEqual(validated.offsets?.openedX, 1000)
        XCTAssertEqual(validated.offsets?.openedY, -1000)
        XCTAssertEqual(try JSONDecoder().decode(SurfaceOptions.self, from: JSONEncoder().encode(validated)), validated)
        options.offsets?.closedX = .infinity
        XCTAssertThrowsError(try options.validated())
    }
    func testThemeRoundTrip() throws {
        let theme = Theme()
        XCTAssertEqual(theme, try JSONDecoder().decode(Theme.self, from: JSONEncoder().encode(theme)))
    }
    func testThemeClampsDimensions() throws {
        var theme = Theme()
        theme.width = 5000
        theme.opacity = -1
        let validated = try theme.validated()
        XCTAssertEqual(validated.width, 640)
        XCTAssertEqual(validated.opacity, 0.5)
    }
    func testRejectUnknownVersion() {
        var theme = Theme()
        theme.version = 99
        XCTAssertThrowsError(try theme.validated())
    }
    func testRejectNonFiniteValues() {
        var theme = Theme()
        theme.width = .infinity
        XCTAssertThrowsError(try theme.validated())
    }
    func testGeometryClampsToScreen() {
        XCTAssertEqual(Geometry.width(screenWidth: 360, requested: 640), 336)
        XCTAssertEqual(Geometry.width(screenWidth: 1440, requested: 420), 420)
    }
    func testConfigurationRoundTrip() throws {
        var configuration = Configuration()
        configuration.allDisplays = true
        configuration.showShelf = false
        let decoded = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(configuration))
        XCTAssertTrue(decoded.allDisplays)
        XCTAssertFalse(decoded.showShelf)
    }
    func testModuleOrderDeduplicatesAndRestoresMissingModules() {
        var layout = WorkspaceLayout(); layout.order = [.timer, .timer, .clock]
        let result = layout.normalizedOrder()
        XCTAssertEqual(Array(result.prefix(2)), [.timer, .clock])
        XCTAssertEqual(Set(result), Set(ModuleID.allCases))
        XCTAssertEqual(result.count, ModuleID.allCases.count)
    }
    func testWorkspaceRoundTrip() throws {
        var settings = WorkspaceSettings(); settings.clipboardEnabled = true
        settings.layout.enabled = [.media, .calendar]
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(WorkspaceSettings.self, from: data)
        XCTAssertTrue(decoded.clipboardEnabled)
        XCTAssertEqual(decoded.layout.enabled, [.media, .calendar])
        XCTAssertEqual(decoded.profiles.count, 8)
    }
    func testClipboardIsOptIn() { XCTAssertFalse(WorkspaceSettings().clipboardEnabled) }
    func testAutomationBatteryRequiresRealReading() {
        let rule = AutomationRule(trigger: .batteryBelow, value: "20", profileID: UUID())
        XCTAssertFalse(rule.matches(app: "", battery: nil, charging: false, displays: 1, hour: 12))
        XCTAssertTrue(rule.matches(app: "", battery: 19, charging: false, displays: 1, hour: 12))
        XCTAssertFalse(rule.matches(app: "", battery: 20, charging: false, displays: 1, hour: 12))
    }
    func testDisabledAutomationDoesNotMatch() {
        let rule = AutomationRule(enabled: false, trigger: .activeApp, value: "Xcode", profileID: UUID())
        XCTAssertFalse(rule.matches(app: "Xcode", battery: nil, charging: false, displays: 1, hour: 1))
    }
    func testFuzzyCommandMatching() {
        XCTAssertTrue(CommandSearch.matches("stm25", in: "Start timer 25"))
        XCTAssertFalse(CommandSearch.matches("stop", in: "Start timer 25"))
        XCTAssertTrue(CommandSearch.matches("", in: "Safari"))
    }
    func testPluginRejectsExecutableAndFileURLs() {
        for url in ["file:///etc/passwd", "javascript:alert(1)", "http://example.com"] {
            let plugin = PluginManifest(version: 1, id: "test", name: "Test", permissions: ["openURL"], commands: [PluginCommand(id: "open", title: "Open", url: url)])
            XCTAssertThrowsError(try plugin.validated())
        }
    }
    func testPluginRejectsUndeclaredPermissionAndDuplicateCommands() {
        let command = PluginCommand(id: "one", title: "One", url: "https://example.com")
        XCTAssertThrowsError(try PluginManifest(version: 1, id: "test", name: "Test", permissions: [], commands: [command]).validated())
        XCTAssertThrowsError(try PluginManifest(version: 1, id: "test", name: "Test", permissions: ["openURL"], commands: [command, command]).validated())
    }
    func testPluginAcceptsHTTPS() throws {
        let plugin = PluginManifest(version: 1, id: "test", name: "Test", permissions: ["openURL"], commands: [PluginCommand(id: "open", title: "Open", url: "https://swift.org")])
        XCTAssertEqual(try plugin.validated().id, "test")
    }
    func testThemeArchiveRemovesForeignFilePaths() throws {
        var layout = WorkspaceLayout(); layout.appearance.assetPath = "/private/foreign.png"; layout.appearance.background = .image
        let archive = try ThemeArchive(theme: Theme(), layout: layout).validated()
        XCTAssertEqual(archive.layout.appearance.assetPath, "")
        XCTAssertEqual(archive.layout.appearance.background, .gradient)
    }
    func testThemeArchiveClampsEffects() throws {
        var layout = WorkspaceLayout(); layout.appearance.blur = 900; layout.appearance.expandedHeight = -1
        let archive = try ThemeArchive(theme: Theme(), layout: layout).validated()
        XCTAssertEqual(archive.layout.appearance.blur, 20)
        XCTAssertEqual(archive.layout.appearance.expandedHeight, 280)
    }
}
