from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADAPTIVE = ROOT / "Halo/Views/VisualWorkspaceAdaptiveWidgets.swift"
MODULES = ROOT / "Halo/Views/ModuleViews.swift"
SURFACE = ROOT / "Halo/Views/SurfaceView.swift"
DOC = ROOT / "Docs/WidgetCustomization.md"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


def struct_range(text: str, marker: str):
    start = text.index(marker)
    next_mark = text.find("\n// MARK:", start + len(marker))
    return start, len(text) if next_mark < 0 else next_mark


def replace_decl(text: str, struct_marker: str, signature: str, replacement: str) -> str:
    s, e = struct_range(text, struct_marker)
    pos = text.find(signature, s, e)
    if pos < 0:
        raise RuntimeError(f"Missing {signature!r} inside {struct_marker}")
    brace = text.find("{", pos, e)
    if brace < 0:
        raise RuntimeError(f"No body for {signature}")
    depth = 0
    i = brace
    in_string = False
    escape = False
    while i < len(text):
        c = text[i]
        if in_string:
            if escape:
                escape = False
            elif c == "\\":
                escape = True
            elif c == '"':
                in_string = False
        else:
            if c == '"':
                in_string = True
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return text[:pos] + replacement + text[i + 1:]
        i += 1
    raise RuntimeError(f"Unterminated body for {signature}")


# -----------------------------------------------------------------------------
# Shared 1x1 interaction language
# -----------------------------------------------------------------------------
text = ADAPTIVE.read_text()
helper_anchor = "private struct AdaptiveSpectrumView: View {"
if "struct HaloMicroInteractionModifier" not in text:
    helper = r'''
/// Shared interaction language for deliberate 1x1 widgets. A micro widget should remain
/// understandable without hover, while hover/press add polish and long-press exposes depth.
struct HaloMicroInteractionModifier<PopoverContent: View>: ViewModifier {
    let accent: Color
    let helpText: String
    let tapShowsPopover: Bool
    let onTap: () -> Void
    let popoverContent: () -> PopoverContent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var pressing = false
    @State private var suppressNextTap = false
    @State private var showingPopover = false

    func body(content: Content) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(pressing ? 0.965 : (hovering ? 1.012 : 1))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(pressing ? 0.095 : hovering ? 0.035 : 0))
                    .allowsHitTesting(false)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hovering)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: pressing)
            .onHover { hovering = $0 }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)
                    .onChanged { _ in pressing = true }
                    .onEnded { _ in
                        pressing = false
                        suppressNextTap = true
                        showingPopover = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { suppressNextTap = false }
                    }
            )
            .simultaneousGesture(TapGesture().onEnded {
                guard !suppressNextTap else { return }
                if tapShowsPopover { showingPopover = true } else { onTap() }
            })
            .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
                popoverContent().padding(12).frame(minWidth: 220)
            }
            .help(helpText)
    }
}

extension View {
    func haloMicroInteraction<PopoverContent: View>(
        accent: Color,
        help: String,
        tapShowsPopover: Bool = false,
        onTap: @escaping () -> Void,
        @ViewBuilder popover: @escaping () -> PopoverContent
    ) -> some View {
        modifier(HaloMicroInteractionModifier(accent: accent, helpText: help,
                                              tapShowsPopover: tapShowsPopover,
                                              onTap: onTap, popoverContent: popover))
    }
}

struct HaloMicroScrollCapture: NSViewRepresentable {
    let onScroll: (Double) -> Void
    final class View: NSView {
        var callback: ((Double) -> Void)?
        override func scrollWheel(with event: NSEvent) {
            callback?(event.scrollingDeltaY == 0 ? event.scrollingDeltaX : event.scrollingDeltaY)
        }
    }
    func makeNSView(context: Context) -> View { let view = View(); view.callback = onScroll; return view }
    func updateNSView(_ nsView: View, context: Context) { nsView.callback = onScroll }
}

'''
    text = replace_once(text, helper_anchor, helper + helper_anchor, "micro helper insertion")

# Audio needs Media so its micro state can become artwork/playback while music is active.
text = replace_once(text,
    "case .audio:\n            VisualAdaptiveAudioView(service: workspace.audio)",
    "case .audio:\n            VisualAdaptiveAudioView(service: workspace.audio, media: workspace.media, mediaApp: workspace.settings.mediaApp)",
    "audio router")
text = replace_once(text,
    "@ObservedObject var service: AudioService\n\n    private var context:",
    "@ObservedObject var service: AudioService\n    @ObservedObject var media: MediaService\n    let mediaApp: String\n\n    private var context:",
    "audio dependencies")

# Timer: compact number, ring, click start/pause, long-press presets, scroll idle preset.
text = replace_once(text,
    "@ObservedObject var store: AppStore\n    @Namespace private var namespace",
    "@ObservedObject var store: AppStore\n    @Namespace private var namespace\n    @State private var microPresetMinutes = 5",
    "timer micro state")
timer_replacement = r'''private func microTimer(remaining: TimeInterval, elapsed: TimeInterval, progress: Double) -> some View {
        let value = context.settings.timerMode == .elapsed ? elapsed : remaining
        let text = microDuration(value)
        let active = store.deadline != nil || store.pausedSeconds > 0 || store.finished
        let ringProgress = active ? progress : 0
        let symbol = store.finished ? "checkmark" : store.deadline != nil ? "timer" : store.pausedSeconds > 0 ? "pause.fill" : "play.fill"
        return AdaptiveMicroRing(progress: ringProgress, accent: style.accentColor.color) {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(style.accentColor.color)
                Text(store.finished ? "Done" : (active ? text : "\(microPresetMinutes)m"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.56)
                    .contentTransition(.numericText())
            }.padding(5)
        }
        .haloMicroInteraction(accent: style.accentColor.color, help: "Timer · click to start/pause · hold for presets") {
            if store.finished { store.resetTimer() }
            else if store.deadline != nil || store.pausedSeconds > 0 { store.pauseResume() }
            else { store.startTimer(minutes: microPresetMinutes) }
        } popover: {
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Timer").font(.headline)
                HStack(spacing: 6) {
                    ForEach([1, 5, 10, 15, 30], id: \.self) { minutes in
                        Button("\(minutes)m") { microPresetMinutes = minutes; store.startTimer(minutes: minutes) }
                    }
                }
                if active { Button("Reset Timer") { store.resetTimer() } }
            }
        }
        .background(HaloMicroScrollCapture { delta in
            guard store.deadline == nil, store.pausedSeconds <= 0 else { return }
            microPresetMinutes = min(120, max(1, microPresetMinutes + (delta > 0 ? 1 : -1)))
        }.allowsHitTesting(true))
        .scaleEffect(store.finished && !reduceMotion ? 1.025 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.42).repeatCount(store.finished ? 2 : 1, autoreverses: true), value: store.finished)
    }

    private func microDuration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(Int(ceil(Double(seconds) / 60)))m" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h\(minutes)m"
    }'''
text = replace_decl(text, "struct VisualWorkspaceTimerView: View", "private func microTimer(remaining: TimeInterval, elapsed: TimeInterval, progress: Double) -> some View", timer_replacement)

# Audio: adaptive artwork when media is active, otherwise a volume gauge. Click is playback when
# media exists, otherwise mute; hold opens audio controls; scroll changes volume.
audio_replacement = r'''private var micro: some View {
        Group {
            if media.isPlaying, let artwork = media.artworkImage {
                ZStack {
                    Image(nsImage: artwork).resizable().scaledToFill()
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(style.accentColor.color.opacity(0.72), lineWidth: 2)
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12, weight: .bold))
                        .padding(7).background(.ultraThinMaterial, in: Circle())
                }.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                AdaptiveMicroRing(progress: min(1, max(0, Double(service.volume))), accent: style.accentColor.color) {
                    VStack(spacing: 2) {
                        Image(systemName: speakerSymbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(style.accentColor.color)
                        Text("\(percent)%").font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1)
                    }
                }
            }
        }
        .haloMicroInteraction(accent: style.accentColor.color, help: "Audio · click play/pause · scroll volume · hold for controls") {
            if media.connectedApp != nil || media.isPlaying { media.perform("playpause", app: mediaApp) }
            else if service.canSetVolume { service.toggleMute() }
        } popover: {
            VStack(alignment: .leading, spacing: 10) {
                Text(selectedName).font(.headline).lineLimit(1)
                HStack { Image(systemName: speakerSymbol); Text("\(percent)%").monospacedDigit(); Spacer(); Button("Mute") { service.toggleMute() }.disabled(!service.canSetVolume) }
                if service.canSetVolume { volumeSlider }
                if service.devices.count > 1 { outputPicker }
                if media.connectedApp != nil { HStack { Button { media.perform("previous track", app: mediaApp) } label: { Image(systemName: "backward.fill") }; Button { media.perform("playpause", app: mediaApp) } label: { Image(systemName: "playpause.fill") }; Button { media.perform("next track", app: mediaApp) } label: { Image(systemName: "forward.fill") } } }
            }
        }
        .background(HaloMicroScrollCapture { delta in
            guard service.canSetVolume else { return }
            service.setVolume(min(1, max(0, service.volume + Float(delta > 0 ? 0.04 : -0.04))))
        }.allowsHitTesting(true))
    }'''
text = replace_decl(text, "private struct VisualAdaptiveAudioView: View", "private var micro: some View", audio_replacement)

# Clipboard: the micro tile represents type/history, never the copied prose itself.
clipboard_replacement = r'''private var micro: some View {
        Group {
            if let entry = service.entries.first {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(style.accentColor.color.opacity(0.045)).offset(x: 5, y: 5).opacity(service.entries.count > 1 ? 1 : 0)
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(style.textColor.color.opacity(0.055)).offset(x: 2.5, y: 2.5).opacity(service.entries.count > 1 ? 1 : 0)
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(style.textColor.color.opacity(0.035))
                    VStack(spacing: 5) {
                        Image(systemName: contentIcon(entry.text)).font(.system(size: 22, weight: .semibold)).foregroundStyle(style.accentColor.color)
                        Text(contentKind(entry.text)).font(.system(size: 8, weight: .semibold, design: .rounded)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if service.entries.count > 1 {
                        Text("\(service.entries.count)").font(.system(size: 7, weight: .bold, design: .rounded)).padding(4).background(style.accentColor.color, in: Circle()).foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(5)
                    }
                }
                .padding(5)
                .haloMicroInteraction(accent: style.accentColor.color, help: "Clipboard · click for preview · hold for history", tapShowsPopover: true, onTap: {}) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Clipboard").font(.headline)
                        ForEach(Array(service.entries.prefix(6))) { item in
                            Button { service.copy(item) } label: {
                                HStack { Image(systemName: contentIcon(item.text)); Text(item.text).lineLimit(1); Spacer() }
                            }.buttonStyle(.plain)
                        }
                        Text("Clipboard history stays in memory and clears when Halo quits.").font(.caption2).foregroundStyle(.secondary)
                    }.frame(width: 280)
                }
            } else {
                VStack(spacing: 5) { Image(systemName: "doc.on.clipboard").font(.system(size: 22)); Text(enabled ? "EMPTY" : "OFF").font(.caption2).foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }'''
text = replace_decl(text, "private struct VisualAdaptiveClipboardView: View", "private var micro: some View", clipboard_replacement)

# System: keep one dominant live metric, let scroll rotate metrics, and hold exposes the selector.
text = replace_once(text,
    "private var orderedMetrics: [VisualSystemMetric] { context.settings.resolvedSystemMetrics }",
    "@State private var microMetricOffset = 0\n    private var orderedMetrics: [VisualSystemMetric] { context.settings.resolvedSystemMetrics }\n    private var microSelectedMetric: VisualSystemMetric { orderedMetrics.isEmpty ? context.settings.systemPrimaryMetric : orderedMetrics[abs(microMetricOffset) % orderedMetrics.count] }",
    "system micro state")
text = replace_once(text,
    "case .micro: microMetric(context.settings.systemPrimaryMetric)",
    "case .micro: microMetric(microSelectedMetric)",
    "system micro selection")
system_replacement = r'''private func microMetric(_ metric: VisualSystemMetric) -> some View {
        let value = metricValue(metric)
        return AdaptiveMicroRing(progress: value.percent.map { min(1, max(0, $0 / 100)) }, accent: metricColor(metric)) {
            VStack(spacing: 2) {
                Image(systemName: metric.symbol).font(.system(size: 10, weight: .semibold)).foregroundStyle(metricColor(metric))
                Text(value.value).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.62)
                Text(metric.shortTitle.uppercased()).font(.system(size: 6.5, weight: .bold, design: .rounded)).foregroundStyle(.secondary).lineLimit(1)
            }.padding(4)
        }
        .haloMicroInteraction(accent: metricColor(metric), help: "System · scroll metrics · hold for details", tapShowsPopover: true, onTap: {}) {
            VStack(alignment: .leading, spacing: 8) {
                Text("System").font(.headline)
                ForEach(orderedMetrics.prefix(8)) { item in
                    let itemValue = metricValue(item)
                    Button { if let index = orderedMetrics.firstIndex(of: item) { microMetricOffset = index } } label: {
                        HStack { Image(systemName: item.symbol).frame(width: 18); Text(item.title); Spacer(); Text(itemValue.value).monospacedDigit().foregroundStyle(.secondary) }
                    }.buttonStyle(.plain)
                }
            }.frame(width: 250)
        }
        .background(HaloMicroScrollCapture { delta in
            guard !orderedMetrics.isEmpty else { return }
            microMetricOffset = (microMetricOffset + (delta > 0 ? 1 : -1) + orderedMetrics.count) % orderedMetrics.count
        }.allowsHitTesting(true))
    }'''
text = replace_decl(text, "private struct VisualAdaptiveSystemView: View", "private func microMetric(_ metric: VisualSystemMetric) -> some View", system_replacement)

# Launcher: never cram four tappable icons into 1x1. Use one dominant app/group portal.
launcher_replacement = r'''@ViewBuilder private var micro: some View {
        let favorites = favoriteApps
        let primary = favorites.first
        let running = workspace.runningApps.first
        ZStack {
            if favorites.count > 1 {
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(style.accentColor.color.opacity(0.12)).frame(width: 52, height: 52).offset(x: 7, y: 6)
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(style.textColor.color.opacity(0.08)).frame(width: 52, height: 52).offset(x: 3, y: 3)
            }
            Group {
                if let primary {
                    Button { NSWorkspace.shared.open(primary.url) } label: { Image(nsImage: primary.icon).resizable().scaledToFit().padding(9) }.buttonStyle(.plain)
                } else if let running {
                    Button { running.activate(options: .activateIgnoringOtherApps) } label: { appIcon(running, size: min(50, context.settings.launcherIconSize + 12)).padding(7) }.buttonStyle(.plain)
                } else {
                    Image(systemName: "app.dashed").font(.system(size: 26, weight: .medium)).foregroundStyle(style.accentColor.color)
                }
            }
            .frame(width: 58, height: 58)
            .background(style.textColor.color.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if favorites.count > 1 {
                Text("\(favorites.count)").font(.system(size: 7, weight: .bold, design: .rounded)).padding(4).background(style.accentColor.color, in: Circle()).foregroundStyle(.white).offset(x: 25, y: -25)
            }
        }
        .haloMicroInteraction(accent: style.accentColor.color, help: "Launcher · click app · hold for group", onTap: {
            if let primary { NSWorkspace.shared.open(primary.url) } else { running?.activate(options: .activateIgnoringOtherApps) }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Launcher").font(.headline)
                ForEach(favorites.prefix(8), id: \.bundle) { app in
                    Button { NSWorkspace.shared.open(app.url) } label: { HStack { Image(nsImage: app.icon).resizable().frame(width: 22, height: 22); Text(app.name); Spacer() } }.buttonStyle(.plain)
                }
                if favorites.isEmpty { Text("No favorite apps configured.").font(.caption).foregroundStyle(.secondary) }
            }.frame(width: 230)
        }
    }'''
text = replace_decl(text, "private struct VisualAdaptiveLauncherView: View", "@ViewBuilder private var micro: some View", launcher_replacement)

# Notes: 1x1 is a Quick Note control, not a prose viewer. Keep actual text in the hold/click popover.
old_note_text = '''            Text(trimmed.isEmpty ? context.settings.notesPlaceholder : trimmed)
                .font(style.font(scale: isMicro ? 0.70 : 0.86))
                .foregroundStyle(trimmed.isEmpty ? .secondary : .primary)
                .lineLimit(lines)
                .frame(maxWidth: .infinity, alignment: .leading)'''
new_note_text = '''            if isMicro {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<3, id: \\.self) { index in
                        Capsule().fill(index == 0 ? style.accentColor.color.opacity(0.55) : style.textColor.color.opacity(0.14))
                            .frame(width: index == 2 ? 28 : index == 1 ? 42 : 50, height: 3)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                Text(trimmed.isEmpty ? context.settings.notesPlaceholder : trimmed)
                    .font(style.font(scale: 0.86))
                    .foregroundStyle(trimmed.isEmpty ? .secondary : .primary)
                    .lineLimit(lines)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }'''
text = replace_once(text, old_note_text, new_note_text, "notes remove micro prose")
# Wrap the micro preview call itself so click/hold opens a focused quick editor popover.
text = replace_once(text,
    "case .micro: preview(lines: 3)",
    '''case .micro:
                preview(lines: 3)
                    .haloMicroInteraction(accent: style.accentColor.color, help: "Quick Note · click or hold to write", tapShowsPopover: true, onTap: {}) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Note").font(.headline)
                            TextEditor(text: note).frame(width: 300, height: 150)
                            HStack { Spacer(); Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(workspace.settings.notes, forType: .string) }.disabled(workspace.settings.notes.isEmpty) }
                        }
                    }''',
    "notes micro interaction")

# Capture: command/status surface, with supported Capture Region + OCR options in the hold menu.
text = replace_once(text,
    "case .micro: micro(region: true)",
    '''case .micro:
                micro(region: true)
                    .haloMicroInteraction(accent: style.accentColor.color, help: "Capture · click region · hold for capture tools") {
                        service.capture { store.addFiles([$0]) }
                    } popover: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Capture").font(.headline)
                            Button { service.capture { store.addFiles([$0]) } } label: { Label("Capture Region", systemImage: "viewfinder") }
                            Button { service.chooseImage() } label: { Label("OCR Image", systemImage: "text.viewfinder") }
                            if service.busy { ProgressView("Working…") }
                            if !service.recognizedText.isEmpty { Text(service.recognizedText).font(.caption).lineLimit(4).textSelection(.enabled) }
                        }.frame(width: 250)
                    }''',
    "capture micro interaction")

# Stopwatch: chronograph sweep + adaptive compact time, click start/pause, hold laps/reset.
stopwatch_replacement = r'''private func microStopwatch(elapsed: TimeInterval) -> some View {
        let sweep = min(1, max(0, elapsed.truncatingRemainder(dividingBy: 60) / 60))
        return AdaptiveMicroRing(progress: sweep, accent: style.accentColor.color) {
            VStack(spacing: 2) {
                Image(systemName: workspace.stopwatchStart == nil ? "pause.fill" : "stopwatch.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(style.accentColor.color)
                Text(microStopwatchTime(elapsed)).font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.58).contentTransition(.numericText())
            }.padding(5)
        }
        .haloMicroInteraction(accent: style.accentColor.color, help: "Stopwatch · click start/pause · hold for laps") {
            workspace.toggleStopwatch()
        } popover: {
            VStack(alignment: .leading, spacing: 9) {
                Text("Stopwatch").font(.headline)
                Text(formatTime(elapsed)).font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit()
                HStack {
                    Button(workspace.stopwatchStart == nil ? "Start" : "Pause") { workspace.toggleStopwatch() }
                    if workspace.stopwatchStart != nil { Button("Lap") { workspace.lapStopwatch() } }
                    Button("Reset") { workspace.resetStopwatch() }.disabled(elapsed < 0.01)
                }
                ForEach(Array(workspace.stopwatchLaps.suffix(4).enumerated()), id: \.offset) { index, lap in
                    HStack { Text("Lap \(workspace.stopwatchLaps.count - 3 + index)"); Spacer(); Text(formatTime(lap)).monospacedDigit() }.font(.caption)
                }
            }.frame(width: 250)
        }
    }

    private func microStopwatchTime(_ elapsed: TimeInterval) -> String {
        if elapsed < 60 { return String(format: "%.1f", elapsed) }
        let total = Int(elapsed)
        if total < 3600 { return String(format: "%d:%02d", total / 60, total % 60) }
        return String(format: "%d:%02d", total / 3600, (total / 60) % 60)
    }'''
text = replace_decl(text, "private struct VisualAdaptiveStopwatchView: View", "private func microStopwatch(elapsed: TimeInterval) -> some View", stopwatch_replacement)

ADAPTIVE.write_text(text)

# -----------------------------------------------------------------------------
# Calendar 1x1: date first, imminent-event countdown when useful, no event-name cramming.
# -----------------------------------------------------------------------------
modules = MODULES.read_text()
today_tile = r'''private var todayTile: some View {
        let next = filteredToday.first { $0.endDate > Date() }
        let minutesUntil = next.map { Int(ceil($0.startDate.timeIntervalSinceNow / 60)) }
        let imminent = minutesUntil.map { $0 >= 0 && $0 <= 60 } ?? false
        return Group {
            if imminent, let minutesUntil {
                VStack(spacing: 3) {
                    Image(systemName: "calendar.badge.clock").font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                    Text("\(minutesUntil)m").font(dateFont(30)).monospacedDigit().minimumScaleFactor(0.65)
                    Text("NEXT").font(dateFont(7)).foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 1) {
                    Text(Date(), format: .dateTime.weekday(.abbreviated).locale(.autoupdatingCurrent)).font(dateFont(9)).textCase(.uppercase).foregroundStyle(.secondary)
                    todayHeroNumber
                    if !filteredToday.isEmpty { Circle().fill(accent).frame(width: 4, height: 4).padding(.top, 3) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .haloMicroInteraction(accent: accent, help: imminent ? "Next event in \(minutesUntil ?? 0) minutes" : "Calendar · click for today · hold for agenda", tapShowsPopover: true, onTap: {}) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day()).font(.headline)
                if filteredToday.isEmpty { Text("No more events today").foregroundStyle(.secondary) }
                ForEach(filteredToday.prefix(5), id: \.eventIdentifier) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title).lineLimit(1)
                        Text(event.startDate, style: .time).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.frame(width: 280)
        }
    }'''
modules = replace_decl(modules, "struct VisualWorkspaceCalendarView: View", "private var todayTile: some View", today_tile)
MODULES.write_text(modules)

# -----------------------------------------------------------------------------
# File Shelf 1x1: portal/top item, no filename crammed into the tile.
# -----------------------------------------------------------------------------
surface = SURFACE.read_text()
surface = replace_once(surface,
    "case .shelf: shelf",
    "case .shelf:\n            if gridColumnSpan == 1, gridRowSpan == 1 { microShelf } else { shelf }",
    "shelf micro route")
# Insert microShelf immediately before the existing shelf implementation.
shelf_anchor = "    private var shelf: some View {"
if "private var microShelf: some View" not in surface:
    micro_shelf = r'''    private var microShelf: some View {
        Group {
            if let url = store.files.last {
                ZStack {
                    if store.files.count > 2 { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(style.accentColor.color.opacity(0.10)).frame(width: 52, height: 52).offset(x: 7, y: 6) }
                    if store.files.count > 1 { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(style.textColor.color.opacity(0.08)).frame(width: 52, height: 52).offset(x: 3, y: 3) }
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit().padding(12)
                        .frame(width: 58, height: 58).background(style.textColor.color.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    if store.files.count > 1 { Text("\(store.files.count)").font(.system(size: 7, weight: .bold, design: .rounded)).padding(4).background(style.accentColor.color, in: Circle()).foregroundStyle(.white).offset(x: 25, y: -25) }
                }
                .haloMicroInteraction(accent: style.accentColor.color, help: "File Shelf · click top file · hold to browse") {
                    NSWorkspace.shared.open(url)
                } popover: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("File Shelf").font(.headline); Spacer(); Button { store.chooseFiles() } label: { Image(systemName: "plus") } }
                        ForEach(Array(store.files.reversed().prefix(6)), id: \.self) { file in
                            Button { NSWorkspace.shared.open(file) } label: { HStack { Image(nsImage: NSWorkspace.shared.icon(forFile: file.path)).resizable().frame(width: 22, height: 22); Text(file.lastPathComponent).lineLimit(1); Spacer() } }.buttonStyle(.plain)
                        }
                    }.frame(width: 280)
                }
                .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url.path as NSString) }
            } else {
                Button { store.chooseFiles() } label: {
                    VStack(spacing: 5) { Image(systemName: "tray").font(.system(size: 24, weight: .semibold)); Text("ADD").font(.caption2).fontWeight(.bold) }
                        .foregroundStyle(style.accentColor.color).frame(maxWidth: .infinity, maxHeight: .infinity)
                }.buttonStyle(.plain).help("Add files to shelf")
            }
        }
    }

'''
    surface = replace_once(surface, shelf_anchor, micro_shelf + shelf_anchor, "micro shelf insertion")
SURFACE.write_text(surface)

# -----------------------------------------------------------------------------
# Document the shipped 1x1 contract so future widget work doesn't regress into shrunken layouts.
# -----------------------------------------------------------------------------
doc = DOC.read_text() if DOC.exists() else "# Widget Customization\n"
section = r'''

## 1×1 micro-widget design contract

A 1×1 widget is a specialised glanceable state, not a compressed version of a larger widget. It should normally present one dominant visual object — a number, icon, progress ring, artwork, waveform, file thumbnail, or date — and avoid multiple labelled controls.

Default interaction language:

- **Hover:** subtle visual lift/illumination and a helpful tooltip; hover must never be required to understand the tile.
- **Click:** the widget's single most obvious action. Timer and Stopwatch start/pause; Audio controls playback; File Shelf opens its top item; Capture starts the preferred supported capture flow.
- **Press and hold (~450 ms):** compresses the tile slightly and opens the widget's compact contextual popover.
- **Secondary click:** remains the configuration/context-menu path supplied by the workspace.
- **Scroll:** used only where it maps naturally, such as volume, Timer preset duration, or System metric rotation.
- **Drag:** used when the content itself is draggable, such as the top File Shelf item.
- **Double click:** do not make destructive or primary behavior depend on it.

Current deliberate micro presentations include: Timer countdown ring, File Shelf top-item portal, adaptive Audio artwork/volume, Calendar date/imminent-event countdown, Clipboard object-type/history card, single System metric gauge, single Launcher app/group portal, Quick Note capture surface, Capture command/status tile, and Stopwatch chronograph sweep.

Do not put readable note prose, event names, filenames, lap lists, several system metrics, or four tappable launcher icons inside 1×1. Those belong to larger footprints or the long-press popover.
'''
if "## 1×1 micro-widget design contract" not in doc:
    doc += section
DOC.write_text(doc)

# Guardrails: prove the intended design landed.
checks = {
    ADAPTIVE: ["HaloMicroInteractionModifier", "microDuration(_ interval", "tapShowsPopover: true", "microStopwatchTime", "favorites.count > 1"],
    MODULES: ["calendar.badge.clock", "Next event in"],
    SURFACE: ["private var microShelf", "gridColumnSpan == 1, gridRowSpan == 1"],
    DOC: ["1×1 micro-widget design contract"]
}
for path, markers in checks.items():
    content = path.read_text()
    for marker in markers:
        if marker not in content:
            raise RuntimeError(f"Missing marker {marker!r} in {path}")
print("Applied Halo deliberate 1x1 widget design")
