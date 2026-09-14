from pathlib import Path

p = Path('Halo/Services/CaptureService.swift')
s = p.read_text()

old = '''enum TeleprompterPresentationStyle: String, Codable, CaseIterable, Identifiable {
    case floating = "Floating"
    case notchExpansion = "Notch Expansion"
    var id: String { rawValue }
}
'''
new = '''enum TeleprompterPresentationStyle: String, Codable, CaseIterable, Identifiable {
    case floating = "Floating"
    case notchExpansion = "Notch Expansion"
    case menuBarReplacement = "Menu Bar Replacement"
    var id: String { rawValue }
}

enum TeleprompterMenuBarLane: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case left = "Left of Notch"
    case right = "Right of Notch"
    case fullWidth = "Full Menu Bar"
    var id: String { rawValue }
}
'''
assert old in s, 'presentation enum anchor missing'
s = s.replace(old, new, 1)

old = '''    var customOffsetY = 0.0
    var screenEdgePadding = 18.0
    var notchExpansionAnimation = true
}'''
new = '''    var customOffsetY = 0.0
    var screenEdgePadding = 18.0
    var notchExpansionAnimation = true
    // Optional so profiles saved before Menu Bar Replacement continue decoding cleanly.
    var menuBarLane: TeleprompterMenuBarLane? = nil
    var menuBarFontSize: Double? = nil
    var menuBarTextInset: Double? = nil
}'''
assert old in s, 'appearance anchor missing'
s = s.replace(old, new, 1)

old = '''        panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = profile.appearance.presentationStyle == .floating
        panel.level = profile.appearance.presentationStyle == .notchExpansion ? .screenSaver : .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = profile.appearance.presentationStyle == .floating
        panel.sharingType = profile.appearance.hideFromCapture ? .none : .readOnly
        panel.contentView = NSHostingView(rootView: TeleprompterPromptView(runtime: runtime))
        promptPanel = panel
        position(panel, appearance: profile.appearance)
        panel.orderFrontRegardless()
'''
new = '''        panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = profile.appearance.presentationStyle == .floating
        // Notch Expansion and Menu Bar Replacement must sit above the system menu bar.
        panel.level = profile.appearance.presentationStyle == .floating ? .statusBar : .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = profile.appearance.presentationStyle == .floating
        panel.sharingType = profile.appearance.hideFromCapture ? .none : .readOnly
        promptPanel = panel
        position(panel, appearance: profile.appearance)
        let menuBarTextFrame = resolvedMenuBarTextFrame(for: panel, appearance: profile.appearance)
        panel.contentView = NSHostingView(rootView: TeleprompterPromptView(runtime: runtime, menuBarTextFrame: menuBarTextFrame))
        panel.orderFrontRegardless()
'''
assert old in s, 'show panel anchor missing'
s = s.replace(old, new, 1)

old = '''        let width = min(max(280, appearance.width), screen.frame.width - 20)
        let height = min(max(90, appearance.height), screen.frame.height - 20)

        if appearance.presentationStyle == .notchExpansion {
'''
new = '''        if appearance.presentationStyle == .menuBarReplacement {
            // Cover the entire system menu-bar strip. screenSaver level keeps this black
            // replacement surface above menu titles and menu-extra/status items.
            let reportedMenuBar = screen.frame.maxY - screen.visibleFrame.maxY
            let menuBarHeight = min(48, max(24, max(reportedMenuBar, screen.safeAreaInsets.top)))
            let target = NSRect(x: screen.frame.minX,
                                y: screen.frame.maxY - menuBarHeight,
                                width: screen.frame.width,
                                height: menuBarHeight)
            panel.setFrame(target, display: true)
            return
        }

        let width = min(max(280, appearance.width), screen.frame.width - 20)
        let height = min(max(90, appearance.height), screen.frame.height - 20)

        if appearance.presentationStyle == .notchExpansion {
'''
assert old in s, 'position anchor missing'
s = s.replace(old, new, 1)

anchor = '''        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func installInputMonitors() {
'''
insert = '''        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func resolvedMenuBarTextFrame(for panel: NSPanel, appearance: TeleprompterAppearance) -> CGRect? {
        guard appearance.presentationStyle == .menuBarReplacement,
              let screen = panel.screen ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) else { return nil }

        let inset = CGFloat(max(6, appearance.menuBarTextInset ?? 12))
        let localFull = CGRect(x: inset, y: 0,
                               width: max(40, panel.frame.width - inset * 2),
                               height: panel.frame.height)
        let lane = appearance.menuBarLane ?? .automatic

        guard let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea,
              rightArea.minX > leftArea.maxX else {
            switch lane {
            case .left:
                return CGRect(x: inset, y: 0, width: max(40, panel.frame.width * 0.5 - inset * 2), height: panel.frame.height)
            case .right:
                let half = panel.frame.width * 0.5
                return CGRect(x: half + inset, y: 0, width: max(40, half - inset * 2), height: panel.frame.height)
            case .automatic, .fullWidth:
                return localFull
            }
        }

        func local(_ area: CGRect) -> CGRect {
            let x = area.minX - panel.frame.minX + inset
            return CGRect(x: x, y: 0,
                          width: max(40, area.width - inset * 2),
                          height: panel.frame.height)
        }
        let left = local(leftArea)
        let right = local(rightArea)

        switch lane {
        case .left: return left
        case .right: return right
        case .fullWidth: return localFull
        case .automatic:
            // Keep text readable instead of allowing the camera/notch to punch a hole
            // through the middle of a sentence. Prefer whichever visible wing is wider.
            return left.width >= right.width ? left : right
        }
    }

    private func installInputMonitors() {
'''
assert anchor in s, 'menu bar frame insertion anchor missing'
s = s.replace(anchor, insert, 1)

start = s.index('struct TeleprompterPromptView: View {')
end = s.index('\nstruct TeleprompterSettingsView: View {', start)
old_view = s[start:end]
new_view = r'''struct TeleprompterPromptView: View {
    @ObservedObject var runtime: TeleprompterRuntime
    var menuBarTextFrame: CGRect? = nil
    @State private var hover = false
    private var appearance: TeleprompterAppearance { runtime.profile.appearance }
    private var weight: Font.Weight { appearance.fontWeight > 0.72 ? .bold : appearance.fontWeight > 0.52 ? .semibold : appearance.fontWeight > 0.32 ? .medium : .regular }

    var body: some View {
        Group {
            if appearance.presentationStyle == .menuBarReplacement {
                menuBarPrompt
            } else {
                standardPrompt
            }
        }
        .foregroundStyle(.white)
        .scaleEffect(x: appearance.mirrorHorizontally ? -1 : 1, y: 1)
        .onHover { hover = $0 }
        .contextMenu {
            Button(runtime.playing ? "Pause" : "Play") { runtime.toggle() }
            Button("Previous") { runtime.previousChunk() }
            Button("Next") { runtime.nextChunk() }
            Divider()
            Button("Teleprompter Settings…") { TeleprompterCoordinator.shared.showSettings() }
            Button("Close") { TeleprompterCoordinator.shared.hidePrompt() }
        }
    }

    private var standardPrompt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: appearance.presentationStyle == .notchExpansion ? max(8, appearance.cornerRadius) : appearance.cornerRadius, style: .continuous)
                .fill(.black.opacity(appearance.presentationStyle == .notchExpansion ? 1.0 : appearance.backgroundOpacity))
                .background {
                    if appearance.blurBackground {
                        TeleprompterVisualEffectBlur().clipShape(RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous))
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
            VStack(spacing: 9) {
                if let countdown = runtime.countdown {
                    Text("\(countdown)").font(.system(size: 58, weight: .bold, design: .rounded))
                } else {
                    promptContent
                    if appearance.showControls && hover { controls }
                    if appearance.showProgress {
                        ProgressView(value: runtime.progress).tint(.white.opacity(0.8)).scaleEffect(x: 1, y: 0.65)
                    }
                }
            }
            .padding(.horizontal, appearance.horizontalPadding)
            .padding(.vertical, 15)
        }
    }

    private var menuBarPrompt: some View {
        GeometryReader { proxy in
            let fallback = CGRect(x: 14, y: 0, width: max(40, proxy.size.width - 28), height: proxy.size.height)
            let lane = menuBarTextFrame ?? fallback
            ZStack(alignment: .bottomLeading) {
                // Deliberately opaque: this is a replacement surface, not a translucent HUD.
                Color.black

                Group {
                    if let countdown = runtime.countdown {
                        Text("\(countdown)")
                            .font(.system(size: min(20, menuBarFontSize + 3), weight: .bold, design: .rounded))
                    } else {
                        Text(menuBarText)
                            .font(.system(size: menuBarFontSize, weight: weight, design: .rounded))
                            .opacity(appearance.textOpacity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .truncationMode(.tail)
                    }
                }
                .frame(width: max(40, lane.width), height: proxy.size.height, alignment: .center)
                .position(x: min(proxy.size.width - 20, max(20, lane.midX)), y: proxy.size.height / 2)

                if appearance.showProgress && runtime.countdown == nil {
                    Capsule()
                        .fill(.white.opacity(0.82))
                        .frame(width: max(2, proxy.size.width * runtime.progress), height: 1.5)
                        .animation(.easeOut(duration: 0.18), value: runtime.progress)
                }
            }
        }
    }

    private var menuBarText: String {
        runtime.current
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var menuBarFontSize: CGFloat {
        CGFloat(min(22, max(9, appearance.menuBarFontSize ?? 13)))
    }

    @ViewBuilder private var promptContent: some View {
        switch runtime.profile.behavior.displayMode {
        case .singleLine:
            Text(runtime.current.replacingOccurrences(of: "\n", with: " ")).font(.system(size: appearance.fontSize, weight: weight, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
        case .cueCards:
            Text(runtime.current).font(.system(size: appearance.fontSize, weight: weight, design: .rounded)).multilineTextAlignment(.center).lineSpacing(appearance.lineSpacing).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .focus, .paragraphs:
            VStack(spacing: max(4, appearance.lineSpacing)) {
                if runtime.profile.behavior.displayMode == .paragraphs, let previous = runtime.previous { Text(previous).opacity(appearance.surroundingOpacity).font(.system(size: appearance.fontSize * 0.72)).lineLimit(2) }
                Text(runtime.current).font(.system(size: appearance.fontSize, weight: weight, design: .rounded)).opacity(appearance.textOpacity).multilineTextAlignment(.center).lineSpacing(appearance.lineSpacing)
                if let next = runtime.next { Text(next).opacity(appearance.surroundingOpacity).font(.system(size: appearance.fontSize * 0.72)).lineLimit(runtime.profile.behavior.displayMode == .focus ? 2 : 3) }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button { runtime.previousChunk() } label: { Image(systemName: "backward.end.fill") }
            Button { runtime.toggle() } label: { Image(systemName: runtime.playing ? "pause.fill" : "play.fill") }
            Button { runtime.nextChunk() } label: { Image(systemName: "forward.end.fill") }
            Divider().frame(height: 18)
            Button { runtime.adjustWPM(-5) } label: { Image(systemName: "minus") }
            Text("\(Int(runtime.profile.behavior.wordsPerMinute)) WPM").font(.caption.monospacedDigit()).frame(width: 76)
            Button { runtime.adjustWPM(5) } label: { Image(systemName: "plus") }
            Spacer(); Text("\(runtime.chunkIndex + 1)/\(runtime.chunks.count)").font(.caption2.monospacedDigit()).opacity(0.65)
            Button { TeleprompterCoordinator.shared.showSettings() } label: { Image(systemName: "gearshape") }
            Button { TeleprompterCoordinator.shared.hidePrompt() } label: { Image(systemName: "xmark") }
        }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
    }
}
'''
s = s[:start] + new_view + s[end:]

# Add non-breaking bindings for new optional menu-bar appearance fields.
anchor = '''    private let sections = ["Script", "Appearance", "Playback", "Triggers", "Context"]

    var body: some View {
'''
insert = '''    private let sections = ["Script", "Appearance", "Playback", "Triggers", "Context"]

    private var menuBarLane: Binding<TeleprompterMenuBarLane> {
        Binding(get: { profile.appearance.menuBarLane ?? .automatic },
                set: { profile.appearance.menuBarLane = $0 })
    }
    private var menuBarFontSize: Binding<Double> {
        Binding(get: { profile.appearance.menuBarFontSize ?? 13 },
                set: { profile.appearance.menuBarFontSize = $0 })
    }
    private var menuBarTextInset: Binding<Double> {
        Binding(get: { profile.appearance.menuBarTextInset ?? 12 },
                set: { profile.appearance.menuBarTextInset = $0 })
    }

    var body: some View {
'''
assert anchor in s, 'profile editor binding anchor missing'
s = s.replace(anchor, insert, 1)

start = s.index('    private var appearanceEditor: some View {')
end = s.index('\n    private var playbackEditor: some View {', start)
old_editor = s[start:end]
new_editor = r'''    private var appearanceEditor: some View {
        Form {
            Picker("Presentation", selection: $profile.appearance.presentationStyle) {
                ForEach(TeleprompterPresentationStyle.allCases) { Text($0.rawValue).tag($0) }
            }

            if profile.appearance.presentationStyle == .floating {
                Picker("Placement", selection: $profile.appearance.placement) { ForEach(TeleprompterPlacement.allCases) { Text($0.rawValue).tag($0) } }
                if profile.appearance.placement == .custom {
                    LabeledContent("Horizontal offset") { Slider(value: $profile.appearance.customOffsetX, in: -900...900); Text("\(Int(profile.appearance.customOffsetX)) pt").frame(width: 70) }
                    LabeledContent("Vertical offset") { Slider(value: $profile.appearance.customOffsetY, in: -600...600); Text("\(Int(profile.appearance.customOffsetY)) pt").frame(width: 70) }
                }
                LabeledContent("Screen-edge padding") { Slider(value: $profile.appearance.screenEdgePadding, in: 0...80); Text("\(Int(profile.appearance.screenEdgePadding)) pt").frame(width: 70) }
            } else if profile.appearance.presentationStyle == .notchExpansion {
                Toggle("Animate from notch", isOn: $profile.appearance.notchExpansionAnimation)
                Text("Notch Expansion anchors the Teleprompter to the physical notch and expands outward from it like Halo's other Context Interfaces.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Picker("Text lane", selection: menuBarLane) {
                    ForEach(TeleprompterMenuBarLane.allCases) { Text($0.rawValue).tag($0) }
                }
                LabeledContent("Menu-bar font size") {
                    Slider(value: menuBarFontSize, in: 9...22, step: 1)
                    Text("\(Int(menuBarFontSize.wrappedValue)) pt").frame(width: 56)
                }
                LabeledContent("Text inset") {
                    Slider(value: menuBarTextInset, in: 6...40, step: 1)
                    Text("\(Int(menuBarTextInset.wrappedValue)) pt").frame(width: 56)
                }
                Text("Halo places an opaque black panel over the entire system menu bar, hiding app menus and status items while the Teleprompter is active. Automatic avoids the physical camera notch by choosing the larger visible menu-bar wing. Esc closes the Teleprompter and restores normal menu-bar interaction.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if profile.appearance.presentationStyle != .menuBarReplacement {
                Picker("Mode", selection: $profile.behavior.displayMode) { ForEach(TeleprompterDisplayMode.allCases) { Text($0.rawValue).tag($0) } }
                LabeledContent("Width") { Slider(value: $profile.appearance.width, in: 360...1100); Text("\(Int(profile.appearance.width)) pt").frame(width: 62) }
                LabeledContent("Height") { Slider(value: $profile.appearance.height, in: 100...520); Text("\(Int(profile.appearance.height)) pt").frame(width: 62) }
                LabeledContent("Eye-line offset") { Slider(value: $profile.appearance.eyeLineOffset, in: 0...120); Text("\(Int(profile.appearance.eyeLineOffset)) pt").frame(width: 62) }
                Toggle("Keep near camera / notch", isOn: $profile.appearance.keepNearCamera)
                LabeledContent("Font size") { Slider(value: $profile.appearance.fontSize, in: 14...72); Text("\(Int(profile.appearance.fontSize))").frame(width: 44) }
                LabeledContent("Weight") { Slider(value: $profile.appearance.fontWeight, in: 0...1) }
                LabeledContent("Line spacing") { Slider(value: $profile.appearance.lineSpacing, in: 0...30) }
                LabeledContent("Surrounding opacity") { Slider(value: $profile.appearance.surroundingOpacity, in: 0...0.8) }
                LabeledContent("Background opacity") { Slider(value: $profile.appearance.backgroundOpacity, in: 0.1...1) }
                LabeledContent("Corner radius") { Slider(value: $profile.appearance.cornerRadius, in: 0...40) }
                Toggle("Glass blur", isOn: $profile.appearance.blurBackground)
                Toggle("Show controls on hover", isOn: $profile.appearance.showControls)
            } else {
                LabeledContent("Text opacity") { Slider(value: $profile.appearance.textOpacity, in: 0.2...1) }
                Text("Menu Bar Replacement always renders the current chunk as one line so it stays inside the native menu-bar height. Use shorter blank-line-separated chunks for the best reading cadence.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Toggle("Hide from screen capture", isOn: $profile.appearance.hideFromCapture)
            Toggle("Mirror horizontally", isOn: $profile.appearance.mirrorHorizontally)
            Toggle("Show progress", isOn: $profile.appearance.showProgress)
        }.formStyle(.grouped)
    }
'''
s = s[:start] + new_editor + s[end:]

p.write_text(s)
print('Patched Teleprompter Menu Bar Replacement')
