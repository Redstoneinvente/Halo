import XCTest
#if SWIFT_PACKAGE
@testable import HaloCore
#endif

final class HaloCoreTests: XCTestCase {
    func testReadableAlbumForegroundColorMeetsContrastOnDarkSurface() {
        let album = WidgetColor(red: 0.12, green: 0.18, blue: 0.24)
        let resolved = AlbumForegroundColorResolver.readable(album, against: .black)

        XCTAssertGreaterThanOrEqual(
            AlbumForegroundColorResolver.contrast(resolved, .black),
            AlbumForegroundColorResolver.minimumContrast - 0.001
        )
    }

    func testReadableAlbumForegroundColorMeetsContrastOnLightAlbumSurface() {
        let album = WidgetColor(red: 0.92, green: 0.78, blue: 0.34)
        let resolved = AlbumForegroundColorResolver.readable(album, against: album)

        XCTAssertGreaterThanOrEqual(
            AlbumForegroundColorResolver.contrast(resolved, album),
            AlbumForegroundColorResolver.minimumContrast - 0.001
        )
    }

    func testReadableAlbumForegroundColorSoftensAlreadyReadableSaturatedColor() {
        let album = WidgetColor(red: 0.82, green: 0.16, blue: 0.92)
        let resolved = AlbumForegroundColorResolver.readable(album, against: .black)

        XCTAssertNotEqual(resolved, album)
        XCTAssertGreaterThanOrEqual(
            AlbumForegroundColorResolver.contrast(resolved, .black),
            AlbumForegroundColorResolver.minimumContrast - 0.001
        )
    }

    func testReadableAlbumForegroundColorChecksWholeBackgroundPalette() {
        let album = WidgetColor(red: 0.22, green: 0.62, blue: 0.88)
        let backgrounds = [
            WidgetColor(red: 0.08, green: 0.18, blue: 0.30),
            WidgetColor(red: 0.18, green: 0.30, blue: 0.42),
            WidgetColor(red: 0.12, green: 0.24, blue: 0.20)
        ]
        let resolved = AlbumForegroundColorResolver.readable(album, against: backgrounds)

        XCTAssertGreaterThanOrEqual(
            AlbumForegroundColorResolver.worstContrast(resolved, against: backgrounds),
            AlbumForegroundColorResolver.minimumContrast - 0.001
        )
    }

    func testBluetoothDeviceSymbolsUseReportedClassForRenamedAccessories() {
        XCTAssertEqual(BluetoothDeviceVisual.symbol(name: "Pranav's device", classOfDevice: 0x0540), "keyboard")
        XCTAssertEqual(BluetoothDeviceVisual.symbol(name: "Pranav's device", classOfDevice: 0x0580), "computermouse")
        XCTAssertEqual(BluetoothDeviceVisual.symbol(name: "Pranav's device", classOfDevice: 0x0414), "hifispeaker.fill")
        XCTAssertEqual(BluetoothDeviceVisual.symbol(name: "Pranav's device", classOfDevice: 0x0508), "gamecontroller")
        XCTAssertEqual(BluetoothDeviceVisual.symbol(name: "AirPods Pro", classOfDevice: 0x0404), "airpodspro")
        XCTAssertEqual(BluetoothDeviceVisual.symbol(name: "Unknown", classOfDevice: 0), "wave.3.right")
    }

    func testBluetoothDisconnectActivityRetainsVisualAndDecodesLegacyActivities() throws {
        let visual = BluetoothDeviceVisual(symbol: "headphones", imageData: Data([1, 2, 3]))
        let event = BluetoothConnectionEvent(kind: .disconnected, deviceName: "Renamed headset", deviceVisual: visual)
        let activity = LiveActivity(bluetoothDeviceVisual: event.deviceVisual, title: event.title, detail: event.detail)
        let restored = try JSONDecoder().decode(LiveActivity.self, from: JSONEncoder().encode(activity))
        XCTAssertEqual(restored.bluetoothDeviceVisual, visual)
        XCTAssertEqual(event.symbol, "headphones")
        let power = BluetoothConnectionEvent(kind: .poweredOff, deviceName: nil)
        XCTAssertNil(power.deviceVisual)
        XCTAssertEqual(power.symbol, "wave.3.right.slash")

        // A pre-Live-Activities-v1 payload contains only the original fields.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(activity)) as? [String: Any])
        for key in [
            "bluetoothDeviceVisual", "externalID", "sourceBundleIdentifier", "sourceName",
            "kind", "state", "symbolName", "startedAt", "updatedAt", "expiresAt",
            "priority", "persistent", "actions"
        ] {
            json.removeValue(forKey: key)
        }
        let legacy = try JSONDecoder().decode(LiveActivity.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.bluetoothDeviceVisual)
        XCTAssertEqual(legacy.resolvedKind, .generic)
        XCTAssertEqual(legacy.resolvedState, .active)
        XCTAssertEqual(legacy.resolvedPriority, 50)
        XCTAssertEqual(legacy.resolvedSymbolName, "waveform.path")
    }

    func testLiveActivityClassifierSeparatesMessagesCallsAndNotifications() {
        XCTAssertEqual(
            LiveActivityClassifier.kind(sourceName: "Messages", title: "Pranav", detail: "Are you free?"),
            .message
        )
        XCTAssertEqual(
            LiveActivityClassifier.kind(sourceName: "FaceTime", title: "Alex", detail: "Incoming"),
            .call
        )
        XCTAssertEqual(
            LiveActivityClassifier.kind(sourceName: "Microsoft Teams", title: "Incoming video call", detail: "Alex"),
            .call
        )
        XCTAssertEqual(
            LiveActivityClassifier.kind(sourceName: "Mail", title: "Build finished", detail: "New mail"),
            .notification
        )
    }

    func testLiveActivityActionFactoryDerivesContextActionsFromAXButtons() {
        let messageActions = LiveActivityActionFactory.actions(
            fromButtonLabels: ["Options", "Reply", "Mark as Read", "Close", "Reply"],
            kind: .message
        )

        XCTAssertEqual(messageActions.map(\.title), ["Reply", "Mark as Read", "Close"])
        XCTAssertEqual(messageActions[0].kind, .textReply)
        XCTAssertEqual(messageActions[0].role, .primary)
        XCTAssertEqual(messageActions[0].inputPlaceholder, "Reply…")
        XCTAssertEqual(messageActions[1].kind, .press)
        XCTAssertEqual(messageActions[1].role, .primary)
        XCTAssertEqual(messageActions[2].role, .destructive)

        let callActions = LiveActivityActionFactory.actions(
            fromButtonLabels: ["Accept", "Decline", "Mute"],
            kind: .call
        )
        XCTAssertEqual(callActions.map(\.role), [.primary, .destructive, .normal])
        XCTAssertEqual(callActions.map(\.symbolName), ["phone.fill", "phone.down.fill", "mic.slash.fill"])
    }

    func testLiveActivityActionsRoundTripWithoutBreakingLegacyPayloads() throws {
        let activity = LiveActivity(
            externalID: "system.notification.123",
            sourceName: "Messages",
            kind: .message,
            state: .active,
            title: "Alex",
            detail: "Hello",
            actions: [
                LiveActivityAction(
                    id: "system.ax.reply",
                    title: "Reply",
                    symbolName: "arrowshape.turn.up.left.fill",
                    kind: .textReply,
                    role: .primary,
                    targetLabel: "Reply",
                    inputPlaceholder: "Reply…"
                )
            ]
        )

        let restored = try JSONDecoder().decode(LiveActivity.self, from: JSONEncoder().encode(activity))
        XCTAssertEqual(restored.resolvedActions.count, 1)
        XCTAssertEqual(restored.resolvedActions.first?.kind, .textReply)
        XCTAssertEqual(restored.resolvedActions.first?.targetLabel, "Reply")
    }

    func testLiveActivitySelectionFiltersBeforeChoosingWinner() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let bluetooth = LiveActivity(
            kind: .bluetooth,
            state: .active,
            title: "Headphones connected",
            updatedAt: now,
            expiresAt: now.addingTimeInterval(10),
            priority: 99
        )
        let message = LiveActivity(
            kind: .message,
            state: .active,
            title: "New message",
            updatedAt: now.addingTimeInterval(1),
            expiresAt: now.addingTimeInterval(10),
            priority: 78
        )
        let expiredCall = LiveActivity(
            kind: .call,
            state: .ended,
            title: "Old call",
            updatedAt: now,
            expiresAt: now.addingTimeInterval(-1),
            priority: 100,
            persistent: false
        )

        XCTAssertEqual(
            LiveActivitySelection.primary(in: [bluetooth, message, expiredCall], now: now)?.resolvedKind,
            .bluetooth
        )
        XCTAssertEqual(
            LiveActivitySelection.primary(in: [bluetooth, message, expiredCall], now: now, excluding: [.bluetooth])?.resolvedKind,
            .message
        )
    }

    func testLiveActivityMetadataRoundTripsAndClampsPriority() throws {
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let activity = LiveActivity(
            externalID: "call.123",
            sourceBundleIdentifier: "com.apple.FaceTime",
            sourceName: "FaceTime",
            kind: .call,
            state: .incoming,
            symbolName: nil,
            title: "Incoming Call",
            detail: "FaceTime",
            progress: nil,
            startedAt: started,
            updatedAt: started.addingTimeInterval(2),
            expiresAt: nil,
            priority: 140,
            persistent: true,
            created: started
        )
        let restored = try JSONDecoder().decode(LiveActivity.self, from: JSONEncoder().encode(activity))
        XCTAssertEqual(restored.externalID, "call.123")
        XCTAssertEqual(restored.sourceBundleIdentifier, "com.apple.FaceTime")
        XCTAssertEqual(restored.resolvedKind, .call)
        XCTAssertEqual(restored.resolvedState, .incoming)
        XCTAssertEqual(restored.resolvedPriority, 100)
        XCTAssertEqual(restored.resolvedSymbolName, "phone.fill")
        XCTAssertTrue(restored.isPersistent)
        XCTAssertEqual(restored.startedAt, started)
    }

    func testPixelPalVisualWorkspacePresetUsesFourByFourHeroAndRightStack() throws {
        let layout = try OpenNotchLayout.made(.pixelPal).validated()
        XCTAssertEqual(layout.preset, .pixelPal)
        XCTAssertEqual(layout.resolvedGridColumns, 8)
        XCTAssertEqual(layout.resolvedGridRows, 4)
        XCTAssertEqual(layout.resolvedGridItems.count, 3)

        let pet = try XCTUnwrap(layout.resolvedGridItems.first(where: { $0.module == .pet }))
        XCTAssertEqual(pet.gridPlacement?.column, 0)
        XCTAssertEqual(pet.gridPlacement?.row, 0)
        XCTAssertEqual(pet.gridPlacement?.columnSpan, 4)
        XCTAssertEqual(pet.gridPlacement?.rowSpan, 4)

        let clock = try XCTUnwrap(layout.resolvedGridItems.first(where: { $0.module == .clock }))
        XCTAssertEqual(clock.gridPlacement?.column, 4)
        XCTAssertEqual(clock.gridPlacement?.row, 0)
        XCTAssertEqual(clock.gridPlacement?.columnSpan, 4)
        XCTAssertEqual(clock.gridPlacement?.rowSpan, 2)

        let media = try XCTUnwrap(layout.resolvedGridItems.first(where: { $0.module == .media }))
        XCTAssertEqual(media.gridPlacement?.column, 4)
        XCTAssertEqual(media.gridPlacement?.row, 2)
        XCTAssertEqual(media.gridPlacement?.columnSpan, 4)
        XCTAssertEqual(media.gridPlacement?.rowSpan, 2)
    }

    func testPixelPalSquareSizesSurviveValidationAndPersistence() throws {
        for side in 1...4 {
            var pet = OpenNotchItem.moduleItem(.pet)
            pet.gridPlacement = .init(column: 0, row: 0, columnSpan: side, rowSpan: side)
            let restored = try JSONDecoder().decode(OpenNotchItem.self, from: JSONEncoder().encode(pet)).validated()
            XCTAssertEqual(restored.gridPlacement?.columnSpan, side)
            XCTAssertEqual(restored.gridPlacement?.rowSpan, side)
            var layout = OpenNotchLayout()
            layout.gridColumns = 4
            layout.gridItems = [restored]
            layout.normalizeGridItems()
            XCTAssertEqual(layout.gridItems?.first?.gridPlacement?.columnSpan, side)
            XCTAssertEqual(layout.gridItems?.first?.gridPlacement?.rowSpan, side)
        }
        XCTAssertEqual(OpenNotchGridSizePreset.allCases.filter(HaloPixelPalLayout.supports),
                       [.oneByOne, .twoByTwo, .threeByThree, .fourByFour])
    }

    func testPixelPalLegacyRectangleAndNarrowWorkspaceNormalization() throws {
        var pet = OpenNotchItem.moduleItem(.pet)
        pet.gridPlacement = .init(column: 7, row: 3, columnSpan: 3, rowSpan: 1)
        let normalized = try pet.validated()
        XCTAssertEqual(normalized.gridPlacement?.columnSpan, 2)
        XCTAssertEqual(normalized.gridPlacement?.rowSpan, 2)
        XCTAssertEqual(normalized.gridPlacement?.column, 5)
        XCTAssertEqual(normalized.gridPlacement?.row, 2)
        var layout = OpenNotchLayout()
        layout.gridColumns = 2
        pet.gridPlacement = .init(columnSpan: 4, rowSpan: 4)
        layout.gridItems = [pet]
        layout.normalizeGridItems()
        XCTAssertEqual(layout.resolvedGridColumns, 2)
        XCTAssertEqual(layout.gridItems?.first?.gridPlacement?.columnSpan, 2)
        XCTAssertEqual(layout.gridItems?.first?.gridPlacement?.rowSpan, 2)
    }

    func testPixelPalLEDsFillAvailableSquareAndStayOnBackingPixels() {
        for side in [18.0, 37, 58, 95, 137, 211, 317] {
            for scale in [1.0, 2.0] {
                let geometry = HaloPixelPalDisplayGeometry(size: CGSize(width: side, height: side), scale: scale, fill: 1)
                let last = geometry.led(x: 23, y: 23)
                XCTAssertLessThanOrEqual(side - last.maxX, 1 / scale)
                for y in 0..<24 {
                    for x in 0..<24 {
                        let rect = geometry.led(x: x, y: y)
                        XCTAssertGreaterThanOrEqual(rect.minX, 0)
                        XCTAssertGreaterThanOrEqual(rect.minY, 0)
                        XCTAssertLessThanOrEqual(rect.maxX, side)
                        XCTAssertLessThanOrEqual(rect.maxY, side)
                        for edge in [rect.minX, rect.minY, rect.maxX, rect.maxY] {
                            XCTAssertEqual(edge * scale, (edge * scale).rounded(), accuracy: 0.00001)
                        }
                    }
                }
            }
        }
    }

    func testPixelPalPixelSpacingStaysCrispAndShrinksLEDs() {
        for scale in [1.0, 2.0] {
            let packed = HaloPixelPalDisplayGeometry(size: CGSize(width: 240, height: 240), scale: scale, fill: 1, spacing: 0)
            let defaultGap = HaloPixelPalDisplayGeometry(size: CGSize(width: 240, height: 240), scale: scale, fill: 1, spacing: 1)
            let wideGap = HaloPixelPalDisplayGeometry(size: CGSize(width: 240, height: 240), scale: scale, fill: 1, spacing: 3)

            let packedLED = packed.led(x: 12, y: 12)
            let defaultLED = defaultGap.led(x: 12, y: 12)
            let wideLED = wideGap.led(x: 12, y: 12)

            XCTAssertGreaterThan(packedLED.width, defaultLED.width)
            XCTAssertGreaterThan(defaultLED.width, wideLED.width)
            XCTAssertEqual(packedLED.minX, defaultLED.minX)
            XCTAssertEqual(defaultLED.minX, wideLED.minX)

            for rect in [packedLED, defaultLED, wideLED] {
                for edge in [rect.minX, rect.minY, rect.maxX, rect.maxY] {
                    XCTAssertEqual(edge * scale, (edge * scale).rounded(), accuracy: 0.00001)
                }
            }
        }

        let tiny = HaloPixelPalDisplayGeometry(size: CGSize(width: 18, height: 18), scale: 2, fill: 1, spacing: 3)
        XCTAssertGreaterThan(tiny.led(x: 12, y: 12).width, 0)
        XCTAssertGreaterThan(tiny.led(x: 12, y: 12).height, 0)
    }

    func testPixelPalReactionSettlesAndRespectsReducedMotion() {
        for t in stride(from: 0.0, through: 3, by: 0.05) {
            XCTAssertEqual(HaloPixelPalAnimationTiming.bounce(elapsed: t, intensity: 1, reduceMotion: true), 0)
            XCTAssertEqual(HaloPixelPalAnimationTiming.bounce(elapsed: t, intensity: 0, reduceMotion: false), 0)
        }
        XCTAssertLessThan(HaloPixelPalAnimationTiming.bounce(elapsed: 0.1, intensity: 1, reduceMotion: false), 0)
        XCTAssertEqual(HaloPixelPalAnimationTiming.bounce(elapsed: 0, intensity: 1, reduceMotion: false), 0)
        XCTAssertEqual(HaloPixelPalAnimationTiming.bounce(elapsed: 1.1, intensity: 1, reduceMotion: false), 0)
    }

    func testPixelPalLEDShapeRawValuesStayStableForPersistence() {
        XCTAssertEqual(
            HaloPixelPalLEDShape.allCases.map(\.rawValue),
            ["Square", "Circle", "Triangle", "Diamond", "Star", "Hexagon", "Cross"]
        )
    }

    func testPixelPalCloseGateSkipsCIControlledSurface() {
        XCTAssertTrue(
            HaloPixelPalCloseGatePolicy.shouldDelayCollapse(
                layoutContainsPixelPal: true,
                activeCIIdentifier: nil
            )
        )
        XCTAssertFalse(
            HaloPixelPalCloseGatePolicy.shouldDelayCollapse(
                layoutContainsPixelPal: true,
                activeCIIdentifier: "builtin.music"
            )
        )
        XCTAssertFalse(
            HaloPixelPalCloseGatePolicy.shouldDelayCollapse(
                layoutContainsPixelPal: true,
                activeCIIdentifier: "com.example.partner-ci"
            )
        )
        XCTAssertFalse(
            HaloPixelPalCloseGatePolicy.shouldDelayCollapse(
                layoutContainsPixelPal: false,
                activeCIIdentifier: nil
            )
        )
    }

    func testPixelPalPowerTransitionTiming() {
        XCTAssertEqual(
            HaloPixelPalPowerAnimationTiming.duration(style: .scanline, direction: .up, speed: 1),
            0.48,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            HaloPixelPalPowerAnimationTiming.duration(style: .cascade, direction: .down, speed: 2),
            0.44 / 1.75,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            HaloPixelPalPowerAnimationTiming.duration(style: .none, direction: .up, speed: 1),
            0,
            accuracy: 0.0001
        )
        XCTAssertGreaterThan(
            HaloPixelPalPowerAnimationTiming.closeGateDelay(style: .sparkle, speed: 1),
            HaloPixelPalPowerAnimationTiming.duration(style: .sparkle, direction: .down, speed: 1)
        )

        XCTAssertEqual(HaloPixelPalPowerAnimationTiming.fallbackBootDelay(surfaceDuration: 0.3), 0.4, accuracy: 0.0001)
        XCTAssertEqual(HaloPixelPalPowerAnimationTiming.fallbackBootDelay(surfaceDuration: 0), 0.18, accuracy: 0.0001)
        XCTAssertEqual(HaloPixelPalPowerAnimationTiming.fallbackBootDelay(surfaceDuration: 5), 1.35, accuracy: 0.0001)

        XCTAssertEqual(HaloPixelPalPowerAnimationTiming.progress(elapsed: -1, duration: 0.4), 0)
        XCTAssertEqual(HaloPixelPalPowerAnimationTiming.progress(elapsed: 0.2, duration: 0.4), 0.5, accuracy: 0.0001)
        XCTAssertEqual(HaloPixelPalPowerAnimationTiming.progress(elapsed: 1, duration: 0.4), 1)
        XCTAssertEqual(HaloPixelPalPowerAnimationTiming.smoothstep(0), 0)
        XCTAssertEqual(HaloPixelPalPowerAnimationTiming.smoothstep(1), 1)
        XCTAssertGreaterThan(HaloPixelPalPowerAnimationTiming.smoothstep(0.75), 0.75)
    }

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

    func testGlassOptionsClampAndRenderingCurvesStayFinite() {
        var options = GlassOptions()
        options.clarity = 4
        options.frost = -2
        options.lightAbsorption = 3
        options.refraction = 4
        options.chromaticShift = .infinity
        options.tintAmount = 4
        options.highlight = -1
        options.edgeDepth = 7

        let normalized = options.normalized()
        // A non-finite optical parameter fails closed to the complete default material.
        XCTAssertEqual(normalized, GlassOptions())

        options = GlassOptions()
        options.clarity = 2
        options.frost = -1
        options.lightAbsorption = 2
        options.refraction = 2
        options.chromaticShift = 2
        options.tintAmount = 2
        options.highlight = 2
        options.edgeDepth = 2
        let clamped = options.normalized()
        XCTAssertEqual(clamped.clarity, 1)
        XCTAssertEqual(clamped.frost, 0)
        XCTAssertEqual(clamped.lightAbsorption, 1)
        XCTAssertEqual(clamped.refraction, 1)
        XCTAssertEqual(clamped.chromaticShift, 1)
        XCTAssertEqual(clamped.tintAmount, 0.5)
        XCTAssertEqual(clamped.highlight, 1)
        XCTAssertEqual(clamped.edgeDepth, 1)

        XCTAssertGreaterThan(GlassRendering.materialOpacity(clarity: 0), GlassRendering.materialOpacity(clarity: 1))
        XCTAssertEqual(GlassRendering.absorptionOpacity(0), 0)
        XCTAssertLessThanOrEqual(GlassRendering.absorptionOpacity(1), 0.78)
        XCTAssertTrue(GlassRendering.materialOpacity(clarity: .nan).isFinite)
        XCTAssertTrue(GlassRendering.chromaticOpacity(.nan).isFinite)
    }

    func testVisualWorkspaceLegacyGlassBlurMigratesToFrost() {
        var fallback = Appearance()
        fallback.background = .glass
        fallback.glass.frost = 0.1

        var override = OpenNotchAppearance()
        override.background = .glass
        override.blur = 24

        let resolved = override.baseAppearance(fallback)
        XCTAssertEqual(resolved.glass.frost, 0.8, accuracy: 0.0001)

        override.glass = GlassOptions(
            clarity: 0.9,
            frost: 0.25,
            lightAbsorption: 0.2,
            refraction: 0.4,
            chromaticShift: 0.1,
            tint: .white,
            tintAmount: 0.05,
            highlight: 0.1,
            edgeDepth: 0.1
        )
        XCTAssertEqual(override.baseAppearance(fallback).glass.frost, 0.25, accuracy: 0.0001)
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
        XCTAssertEqual(appearance.glass, GlassOptions())
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
        configuration.hoverOpenDelay = 0.4
        configuration.hoverCloseDelay = 0.8
        let decoded = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(configuration))
        XCTAssertTrue(decoded.allDisplays)
        XCTAssertFalse(decoded.showShelf)
        XCTAssertEqual(decoded.resolvedHoverOpenDelay, 0.4)
        XCTAssertEqual(decoded.resolvedHoverCloseDelay, 0.8)
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

    func testCustomCIBindingResolverIsDeterministic() {
        let template = "Now playing {{ media.title }} by {{ media.artist }}"
        XCTAssertEqual(HaloCIBindingResolver.keys(in: template), ["media.title", "media.artist"])
        XCTAssertEqual(HaloCIBindingResolver.resolve(template, data: ["media.title": "Halo", "media.artist": "Redstone"]), "Now playing Halo by Redstone")
        XCTAssertEqual(HaloCIBindingResolver.resolve("{{ media.album }}", data: [:]), "")
    }

    func testCustomCITriggerPermissionAndMatching() {
        let document = HaloCITriggerDocument(match: "all", triggers: [
            HaloCITrigger(type: "mediaPlaying", value: nil, number: nil, bool: true, startMinute: nil, endMinute: nil),
            HaloCITrigger(type: "batteryAbove", value: nil, number: 20, bool: nil, startMinute: nil, endMinute: nil)
        ])
        let snapshot = HaloCITriggerSnapshot(mediaIsPlaying: true, activeApplicationBundleID: "com.apple.Music", batteryLevel: 80, charging: false, minuteOfDay: 700)
        XCTAssertFalse(HaloCITriggerEvaluator.matches(document, snapshot: snapshot, grantedPermissions: []))
        XCTAssertTrue(HaloCITriggerEvaluator.matches(document, snapshot: snapshot, grantedPermissions: ["Media.ReadState"]))
    }

    func testCustomCIValidatorAcceptsMinimalPackage() throws {
        let root = try makeCustomCIPackage(
            manifest: customCIManifestJSON(),
            interface: #"{"expanded":{"type":"VStack","children":[{"type":"Text","text":"Hello Halo"}]}}"#
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertTrue(report.isValid, report.issues.map(\.message).joined(separator: " | "))
        XCTAssertEqual(report.package?.manifest.id, "com.redstoneinvente.tests.hello")
    }

    func testCustomCIValidatorRejectsExecutableContent() throws {
        let root = try makeCustomCIPackage(manifest: customCIManifestJSON(), interface: #"{"expanded":{"type":"Text","text":"Safe"}}"#)
        defer { try? FileManager.default.removeItem(at: root) }
        let scripts = root.appendingPathComponent("scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
        try "print(\'nope\')".write(to: scripts.appendingPathComponent("main.py"), atomically: true, encoding: .utf8)
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.issues.contains { $0.message.contains("Executable/script") })
    }

    func testCustomCIValidatorRejectsUndeclaredProtectedBinding() throws {
        let root = try makeCustomCIPackage(
            manifest: customCIManifestJSON(),
            interface: #"{"expanded":{"type":"Text","text":"{{ media.title }}"}}"#
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.issues.contains { $0.message.contains("Media.ReadState") })
    }

    func testCustomCIValidatorAcceptsDeclaredPermissionActionAndTrigger() throws {
        let manifest = customCIManifestJSON(permissions: ["Media.ReadState", "Media.Control"])
        let root = try makeCustomCIPackage(
            manifest: manifest,
            interface: #"{"expanded":{"type":"VStack","children":[{"type":"Text","text":"{{ media.title }}"},{"type":"Button","text":"Play","accessibilityLabel":"Play or pause media","action":{"id":"media.playPause"}}]}}"#,
            triggers: #"{"match":"any","triggers":[{"type":"mediaPlaying","bool":true}]}"#
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertTrue(report.isValid, report.issues.map(\.message).joined(separator: " | "))
    }

    func testCustomCIValidatorRejectsUnknownComponentsAndTraversal() throws {
        let root = try makeCustomCIPackage(
            manifest: customCIManifestJSON(),
            interface: #"{"expanded":{"type":"RawSwiftUIView","source":"asset:../secret.png"}}"#
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.issues.contains { $0.message.contains("Unsupported component") })
    }

    func testCustomCIValidatorRejectsUnsupportedSchemaAndSDK() throws {
        let bad = #"{"schemaVersion":2,"sdkVersion":"9.9","id":"com.redstoneinvente.tests.hello","name":"Hello CI","author":"Tests","version":"1.0.0","minimumHaloVersion":"1.0.0","entryInterface":"interface.json","description":"","permissions":[],"capabilities":[],"supportedSurfaces":["notch"],"supportedStates":["expanded"]}"#
        let root = try makeCustomCIPackage(manifest: bad, interface: #"{"expanded":{"type":"Text","text":"Hello"}}"#)
        defer { try? FileManager.default.removeItem(at: root) }
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.issues.contains { $0.path.contains("schemaVersion") })
        XCTAssertTrue(report.issues.contains { $0.path.contains("sdkVersion") })
    }

    func testClosedNotchLayoutMetricsEnforceOuterEdgeSafetyMargin() {
        var options = ClosedNotchOptions()
        options.horizontalPadding = 0
        options.sideMargin = 0
        options.outerMargin = 0
        let metrics = ClosedNotchLayoutMetrics(options: options, height: 40)

        XCTAssertEqual(options.contentOuterMargin, 17, accuracy: 0.001)
        XCTAssertEqual(metrics.normalCameraInset, 0, accuracy: 0.001)
        XCTAssertEqual(metrics.outerInset, 17, accuracy: 0.001)
        XCTAssertGreaterThan(metrics.renderingAllowance, 0)
    }

    func testClosedNotchPowerInheritsCanonicalCameraInsetUntilOverridden() {
        var options = ClosedNotchOptions()
        options.horizontalPadding = 10
        options.sideMargin = 6
        let metrics = ClosedNotchLayoutMetrics(options: options, height: 40)

        var power = PowerReactionOptions()
        XCTAssertEqual(metrics.cameraInset(power: power), metrics.normalCameraInset, accuracy: 0.001)

        power.notchMargin = 3
        XCTAssertEqual(metrics.cameraInset(power: power), 3, accuracy: 0.001)
    }

    func testClosedNotchResolverUsesSameVisibleMediaRuleForActivityPlacement() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var options = ClosedNotchOptions()
        options.left = .none
        options.right = .media

        let activity = LiveActivity(
            kind: .message,
            state: .active,
            title: "Message",
            updatedAt: now,
            expiresAt: now.addingTimeInterval(20),
            priority: 80,
            persistent: false,
            created: now
        )

        let visibleMedia = ClosedNotchContentResolver.resolve(
            options: options,
            activities: [activity],
            mediaVisible: true,
            preferences: ClosedNotchActivityPreferences(),
            now: now
        )
        XCTAssertEqual(visibleMedia.left, .activity)
        XCTAssertEqual(visibleMedia.right, .media)
        XCTAssertEqual(visibleMedia.activity?.id, activity.id)

        let hiddenMedia = ClosedNotchContentResolver.resolve(
            options: options,
            activities: [activity],
            mediaVisible: false,
            preferences: ClosedNotchActivityPreferences(),
            now: now
        )
        XCTAssertEqual(hiddenMedia.left, .none)
        XCTAssertEqual(hiddenMedia.right, .activity)
    }

    func testClosedNotchResolverRespectsAutoPresentAndBluetoothSidePreferences() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var options = ClosedNotchOptions()
        options.left = .clock
        options.right = .none

        let bluetooth = LiveActivity(
            kind: .bluetooth,
            state: .active,
            title: "Bluetooth connected",
            detail: "Headphones",
            updatedAt: now,
            expiresAt: now.addingTimeInterval(10),
            priority: 90,
            persistent: false,
            created: now
        )

        var preferences = ClosedNotchActivityPreferences()
        preferences.bluetoothPreferredSide = "Left"
        let left = ClosedNotchContentResolver.resolve(
            options: options,
            activities: [bluetooth],
            mediaVisible: false,
            preferences: preferences,
            now: now
        )
        XCTAssertEqual(left.left, .activity)
        XCTAssertEqual(left.right, .none)

        preferences.autoPresent = false
        let disabled = ClosedNotchContentResolver.resolve(
            options: options,
            activities: [bluetooth],
            mediaVisible: false,
            preferences: preferences,
            now: now
        )
        XCTAssertEqual(disabled.left, .clock)
        XCTAssertEqual(disabled.right, .none)
        XCTAssertEqual(disabled.activity?.id, bluetooth.id)
    }

    func testClosedNotchResolverFiltersDisabledBluetoothAndSchedulesRealExpiry() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let bluetooth = LiveActivity(
            kind: .bluetooth,
            state: .active,
            title: "Bluetooth connected",
            updatedAt: now,
            expiresAt: now.addingTimeInterval(4),
            priority: 90,
            persistent: false,
            created: now
        )
        let message = LiveActivity(
            kind: .message,
            state: .active,
            title: "Message",
            updatedAt: now,
            expiresAt: now.addingTimeInterval(9),
            priority: 70,
            persistent: false,
            created: now
        )

        var preferences = ClosedNotchActivityPreferences()
        preferences.bluetoothConnected = false
        XCTAssertEqual(
            ClosedNotchContentResolver.primaryActivity(
                in: [bluetooth, message],
                preferences: preferences,
                now: now
            )?.id,
            message.id
        )
        XCTAssertEqual(
            ClosedNotchContentResolver.nextExpiry(
                in: [bluetooth, message],
                preferences: preferences,
                now: now
            ),
            message.expiresAt
        )
    }

    private func customCIManifestJSON(permissions: [String] = []) -> String {
        let permissionJSON = permissions.map { "\"\($0)\"" }.joined(separator: ",")
        return """
        {"schemaVersion":1,"sdkVersion":"0.1","id":"com.redstoneinvente.tests.hello","name":"Hello CI","author":"Tests","version":"1.0.0","minimumHaloVersion":"1.0.0","entryInterface":"interface.json","description":"Test package","permissions":[\(permissionJSON)],"capabilities":[],"supportedSurfaces":["notch"],"supportedStates":["closed","expanded"]}
        """
    }

    private func makeCustomCIPackage(manifest: String, interface: String, triggers: String? = nil) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("haloCI")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try manifest.write(to: root.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        try interface.write(to: root.appendingPathComponent("interface.json"), atomically: true, encoding: .utf8)
        if let triggers { try triggers.write(to: root.appendingPathComponent("triggers.json"), atomically: true, encoding: .utf8) }
        return root
    }
}
