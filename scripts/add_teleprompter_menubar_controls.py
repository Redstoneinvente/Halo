from pathlib import Path

path = Path('Halo/Services/CaptureService.swift')
text = path.read_text()

old = '''    private var menuBarPrompt: some View {
        GeometryReader { proxy in
            let fallback = CGRect(x: 14, y: 0, width: max(40, proxy.size.width - 28), height: proxy.size.height)
            let lane = menuBarTextFrame ?? fallback
            ZStack(alignment: .bottomLeading) {
                // Deliberately opaque: this is a replacement surface, not a translucent HUD.
                Color.black

                Group {
                    if let countdown = runtime.countdown {
                        Text("\\(countdown)")
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
'''

new = '''    private var menuBarPrompt: some View {
        GeometryReader { proxy in
            let fallback = CGRect(x: 14, y: 0, width: max(40, proxy.size.width - 28), height: proxy.size.height)
            let requestedLane = menuBarTextFrame ?? fallback
            let controlsWidth = appearance.showControls ? min(216, max(184, proxy.size.width * 0.16)) : 0
            let controlsOnLeft = requestedLane.midX >= proxy.size.width / 2
            let controlsRect = appearance.showControls
                ? CGRect(x: controlsOnLeft ? 8 : proxy.size.width - controlsWidth - 8,
                         y: 0,
                         width: controlsWidth,
                         height: proxy.size.height)
                : nil
            let lane = readableMenuBarLane(requestedLane, canvasWidth: proxy.size.width, controlsRect: controlsRect)

            ZStack(alignment: .bottomLeading) {
                // Deliberately opaque: this is a replacement surface, not a translucent HUD.
                Color.black

                Group {
                    if let countdown = runtime.countdown {
                        Text("\\(countdown)")
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

                if appearance.showControls, let controlsRect {
                    menuBarControls
                        .frame(width: controlsRect.width, height: proxy.size.height)
                        .position(x: controlsRect.midX, y: proxy.size.height / 2)
                        // Keep icons readable even when the teleprompter text itself is mirrored.
                        .scaleEffect(x: appearance.mirrorHorizontally ? -1 : 1, y: 1)
                }

                if appearance.showProgress && runtime.countdown == nil {
                    Capsule()
                        .fill(.white.opacity(hover ? 0.72 : 0.42))
                        .frame(width: max(2, proxy.size.width * runtime.progress), height: 1.25)
                        .animation(.easeOut(duration: 0.18), value: runtime.progress)
                }
            }
        }
    }

    private func readableMenuBarLane(_ requested: CGRect, canvasWidth: CGFloat, controlsRect: CGRect?) -> CGRect {
        guard let controlsRect, requested.intersects(controlsRect) else { return requested }
        let gap: CGFloat = 10
        var lane = requested

        if controlsRect.midX <= requested.midX {
            let nextMinX = min(requested.maxX - 40, controlsRect.maxX + gap)
            lane.origin.x = nextMinX
            lane.size.width = max(40, requested.maxX - nextMinX)
        } else {
            let nextMaxX = max(requested.minX + 40, controlsRect.minX - gap)
            lane.size.width = max(40, nextMaxX - requested.minX)
        }

        lane.origin.x = max(0, min(canvasWidth - lane.width, lane.origin.x))
        return lane
    }

    private var menuBarControls: some View {
        HStack(spacing: 2) {
            menuBarControlButton("backward.end.fill", help: "Previous") { runtime.previousChunk() }
            menuBarControlButton(runtime.playing ? "pause.fill" : "play.fill",
                                 help: runtime.playing ? "Pause" : "Play",
                                 emphasized: true) { runtime.toggle() }
            menuBarControlButton("forward.end.fill", help: "Next") { runtime.nextChunk() }

            menuBarControlDivider

            menuBarControlButton("minus", help: "Slower") { runtime.adjustWPM(-5) }
            Text("\\(Int(runtime.profile.behavior.wordsPerMinute))")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(hover ? 0.72 : 0.46))
                .frame(minWidth: 27)
                .help("Words per minute")
            menuBarControlButton("plus", help: "Faster") { runtime.adjustWPM(5) }

            menuBarControlDivider

            menuBarControlButton("gearshape", help: "Teleprompter Settings") {
                TeleprompterCoordinator.shared.showSettings()
            }
            menuBarControlButton("xmark", help: "Close Teleprompter") {
                TeleprompterCoordinator.shared.hidePrompt()
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2.5)
        .background(
            Capsule(style: .continuous)
                .fill(.white.opacity(hover ? 0.085 : 0.032))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(.white.opacity(hover ? 0.13 : 0.05), lineWidth: 0.5)
        )
        .opacity(hover ? 0.98 : 0.52)
        .animation(.easeOut(duration: 0.16), value: hover)
    }

    private var menuBarControlDivider: some View {
        Rectangle()
            .fill(.white.opacity(hover ? 0.14 : 0.07))
            .frame(width: 0.5, height: 12)
            .padding(.horizontal, 2)
    }

    private func menuBarControlButton(_ symbol: String,
                                      help: String,
                                      emphasized: Bool = false,
                                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: emphasized ? 9.5 : 8.5, weight: .semibold))
                .frame(width: emphasized ? 20 : 18, height: 18)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(emphasized ? (hover ? 0.11 : 0.055) : 0))
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(hover ? 0.90 : 0.58))
        .help(help)
    }
'''

if old not in text:
    raise SystemExit('menuBarPrompt anchor not found')
text = text.replace(old, new, 1)

old_settings = '''                Text("Halo places an opaque black panel over the entire system menu bar, hiding app menus and status items while the Teleprompter is active. Automatic avoids the physical camera notch by choosing the larger visible menu-bar wing. Esc closes the Teleprompter and restores normal menu-bar interaction.")
                    .font(.caption).foregroundStyle(.secondary)
'''
new_settings = '''                Toggle("Menu-bar controls", isOn: $profile.appearance.showControls)
                Text("Halo places an opaque black panel over the entire system menu bar, hiding app menus and status items while the Teleprompter is active. Automatic avoids the physical camera notch by choosing the larger visible menu-bar wing. Subtle playback, speed, settings, and close controls remain available in the replacement bar and brighten on hover.")
                    .font(.caption).foregroundStyle(.secondary)
'''
if old_settings not in text:
    raise SystemExit('menu bar settings anchor not found')
text = text.replace(old_settings, new_settings, 1)

path.write_text(text)
print('Patched Teleprompter menu bar controls')
