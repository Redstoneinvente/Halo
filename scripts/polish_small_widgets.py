from pathlib import Path

PATH = Path("Halo/Views/VisualWorkspaceAdaptiveWidgets.swift")
text = PATH.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    text = text.replace(old, new, 1)


# Shared radial treatment used only by the smallest 1x1 widget family.
anchor = '''private struct AdaptiveSpectrumView: View {'''
insert = '''private struct AdaptiveMicroRing<Content: View>: View {
    let progress: Double?
    let accent: Color
    private let content: Content

    init(progress: Double?, accent: Color, @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let side = max(38, min(proxy.size.width, proxy.size.height))
            let lineWidth = max(3, min(5, side * 0.052))
            let resolvedProgress = min(1, max(0, progress ?? 0.16))
            ZStack {
                Circle()
                    .fill(accent.opacity(0.045))
                Circle()
                    .stroke(Color.primary.opacity(0.085), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: resolvedProgress)
                    .stroke(accent.opacity(progress == nil ? 0.58 : 0.98),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                content
                    .frame(maxWidth: side * 0.74, maxHeight: side * 0.74)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AdaptiveSpectrumView: View {'''
replace_once(anchor, insert, "insert AdaptiveMicroRing")

# Timer: replace bare time text with a compact progress dial and state glyph.
replace_once('''        case .micro:\n            primaryTime(remaining: remaining, elapsed: elapsed, progress: progress, scale: 1.0)''', '''        case .micro:\n            microTimer(remaining: remaining, elapsed: elapsed, progress: progress)''', "timer micro route")

anchor = '''    private func horizontalTimer(remaining: TimeInterval, elapsed: TimeInterval, progress: Double) -> some View {'''
insert = '''    private func microTimer(remaining: TimeInterval, elapsed: TimeInterval, progress: Double) -> some View {
        let value = context.settings.timerMode == .elapsed ? elapsed : remaining
        let text = formatDuration(value)
        let active = store.deadline != nil || store.pausedSeconds > 0 || store.finished
        let ringProgress = active ? progress : 0
        let symbol = store.finished ? "checkmark" : store.deadline != nil ? "timer" : store.pausedSeconds > 0 ? "pause.fill" : "play.fill"
        return AdaptiveMicroRing(progress: ringProgress, accent: style.accentColor.color) {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(style.accentColor.color)
                Text(store.finished ? "Done" : text)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)
                    .contentTransition(.numericText())
            }
            .padding(5)
        }
    }

    private func horizontalTimer(remaining: TimeInterval, elapsed: TimeInterval, progress: Double) -> some View {'''
replace_once(anchor, insert, "timer micro implementation")

# Audio: turn icon + percentage into a meaningful volume dial.
replace_once('''    private var micro: some View { VStack(spacing: 3) { Image(systemName: speakerSymbol).font(.system(size: 21, weight: .semibold)).foregroundStyle(style.accentColor.color); Text("\\(percent)%").font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit() } }''', '''    private var micro: some View {
        AdaptiveMicroRing(progress: min(1, max(0, Double(service.volume))), accent: style.accentColor.color) {
            VStack(spacing: 2) {
                Image(systemName: speakerSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(style.accentColor.color)
                Text("\\(percent)%")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }''', "audio micro")

# Clipboard: retain the copied information, but present it as a dense little information card.
old = '''    private var micro: some View {
        Group {
            if let entry = service.entries.first {
                VStack(spacing: 3) { Image(systemName: contentIcon(entry.text)).foregroundStyle(style.accentColor.color); Text(preview(entry.text, limit: min(28, context.settings.clipboardPreviewLength))).font(.system(size: 9, weight: .medium)).lineLimit(3).multilineTextAlignment(.center) }
            } else { empty(icon: "doc.on.clipboard", text: "Empty") }
        }
    }'''
new = '''    private var micro: some View {
        Group {
            if let entry = service.entries.first {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: contentIcon(entry.text))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(style.accentColor.color)
                        Text(contentIcon(entry.text) == "link" ? "LINK" : "TEXT")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 2)
                        Text("\\(service.entries.count)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(style.accentColor.color.opacity(0.12), in: Capsule())
                    }
                    Text(preview(entry.text, limit: min(42, context.settings.clipboardPreviewLength)))
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(7)
                .background(style.textColor.color.opacity(0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(alignment: .leading) {
                    Capsule().fill(style.accentColor.color.opacity(0.75)).frame(width: 2.5).padding(.vertical, 8)
                }
            } else { empty(icon: "doc.on.clipboard", text: "Empty") }
        }
    }'''
replace_once(old, new, "clipboard micro")

# System: primary metric gets a gauge rather than two loose lines of text.
replace_once('''            case .micro: metricCard(context.settings.systemPrimaryMetric, prominent: true)''', '''            case .micro: microMetric(context.settings.systemPrimaryMetric)''', "system micro route")
anchor = '''    private var horizontal: some View {'''
# This anchor occurs several times; scope it to the System section by replacing a longer unique fragment.
old = '''    private var horizontal: some View {
        HStack(spacing: max(5, context.spacing)) {
            ForEach(Array(orderedMetrics.prefix(min(context.settings.maxItems, context.columns >= 7 ? 5 : max(2, context.columns))))) { metric in metricCard(metric, prominent: false) }
        }
    }'''
new = '''    private func microMetric(_ metric: VisualSystemMetric) -> some View {
        let value = metricValue(metric)
        return AdaptiveMicroRing(progress: value.percent.map { min(1, max(0, $0 / 100)) }, accent: metricColor(metric)) {
            VStack(spacing: 2) {
                Image(systemName: metric.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(metricColor(metric))
                Text(value.text)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)
                Text(metric.shortTitle.uppercased())
                    .font(.system(size: 6.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var horizontal: some View {
        HStack(spacing: max(5, context.spacing)) {
            ForEach(Array(orderedMetrics.prefix(min(context.settings.maxItems, context.columns >= 7 ? 5 : max(2, context.columns))))) { metric in metricCard(metric, prominent: false) }
        }
    }'''
replace_once(old, new, "system micro implementation")

# Launcher: a 1x1 widget can still be a useful mini launcher. Show up to four app icons.
old = '''    @ViewBuilder private var micro: some View {
        if let favorite = favoriteApps.first { favoriteButton(favorite, compact: true) }
        else if let app = visibleApps.first { runningButton(app, compact: true) }
        else { VStack(spacing: 3) { Image(systemName: "square.grid.2x2").font(.system(size: 25)).foregroundStyle(style.accentColor.color); Text("Apps").font(.caption2) } }
    }'''
new = '''    @ViewBuilder private var micro: some View {
        let favorites = Array(favoriteApps.prefix(4))
        if !favorites.isEmpty {
            LazyVGrid(columns: microColumns, spacing: 5) {
                ForEach(favorites, id: \\.bundle) { microFavoriteButton($0) }
            }
            .padding(3)
        } else {
            let apps = Array(visibleApps.prefix(4))
            if !apps.isEmpty {
                LazyVGrid(columns: microColumns, spacing: 5) {
                    ForEach(apps, id: \\.processIdentifier) { microRunningButton($0) }
                }
                .padding(3)
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(style.accentColor.color)
                    Text("Apps").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var microColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)]
    }

    private func microFavoriteButton(_ app: FavoriteApp) -> some View {
        Button { NSWorkspace.shared.open(app.url) } label: {
            Image(nsImage: app.icon)
                .resizable().scaledToFit()
                .frame(width: min(28, context.settings.launcherIconSize), height: min(28, context.settings.launcherIconSize))
                .frame(maxWidth: .infinity, minHeight: 31)
                .background(style.textColor.color.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(app.name)
    }

    private func microRunningButton(_ app: NSRunningApplication) -> some View {
        Button { app.activate(options: .activateIgnoringOtherApps) } label: {
            appIcon(app, size: min(28, context.settings.launcherIconSize))
                .frame(maxWidth: .infinity, minHeight: 31)
                .background(style.textColor.color.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(app.localizedName ?? "App")
    }'''
replace_once(old, new, "launcher micro")

# Activities: use the first activity's progress as a live ring and keep the count/state legible.
replace_once('''    private var micro: some View { VStack(spacing: 2) { Text("\\(workspace.activities.count)").font(.system(size: 27, weight: .bold, design: .rounded)).monospacedDigit(); Text("Active").font(.caption2).foregroundStyle(.secondary) } }''', '''    private var micro: some View {
        let first = activities.first
        return AdaptiveMicroRing(progress: first?.progress, accent: style.accentColor.color) {
            VStack(spacing: 1) {
                Image(systemName: workspace.activities.isEmpty ? "checkmark" : "waveform.path")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(style.accentColor.color)
                Text("\\(workspace.activities.count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(workspace.activities.isEmpty ? "QUIET" : "LIVE")
                    .font(.system(size: 6.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }''', "activities micro")

# Notes: turn the tiny preview into a mini paper surface with a useful word-count badge.
replace_once('''    private func preview(lines: Int) -> some View { VStack(alignment: .leading, spacing: 4) { if context.family == .micro { Image(systemName: "note.text").foregroundStyle(style.accentColor.color) }; Text(trimmed.isEmpty ? context.settings.notesPlaceholder : trimmed).font(style.font(scale: context.family == .micro ? 0.72 : 0.86)).foregroundStyle(trimmed.isEmpty ? .secondary : .primary).lineLimit(lines).frame(maxWidth: .infinity, alignment: .leading) } }''', '''    private func preview(lines: Int) -> some View {
        let isMicro = context.family == .micro
        let words = workspace.settings.notes.split { $0.isWhitespace || $0.isNewline }.count
        return VStack(alignment: .leading, spacing: isMicro ? 4 : 4) {
            if isMicro {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(style.accentColor.color)
                    Text("NOTE")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    Text("\\(words)w")
                        .font(.system(size: 7, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Text(trimmed.isEmpty ? context.settings.notesPlaceholder : trimmed)
                .font(style.font(scale: isMicro ? 0.70 : 0.86))
                .foregroundStyle(trimmed.isEmpty ? .secondary : .primary)
                .lineLimit(lines)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(isMicro ? 7 : 0)
        .background {
            if isMicro {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(style.textColor.color.opacity(0.035))
            }
        }
        .overlay(alignment: .leading) {
            if isMicro {
                Capsule().fill(style.accentColor.color.opacity(0.72)).frame(width: 2.5).padding(.vertical, 8)
            }
        }
    }''', "notes micro")

# Capture: icon-only was visually empty. Keep it one-tap, but give the 1x1 state a focus-frame treatment and label.
old = '''    @ViewBuilder private func primaryAction(iconOnly: Bool) -> some View { if context.settings.capturePrimaryAction == .region { Button { capture() } label: { if iconOnly { Image(systemName: "viewfinder").font(.system(size: 25, weight: .semibold)) } else { Label("Capture", systemImage: "viewfinder") } }.buttonStyle(.plain) } else { Button { service.chooseImage() } label: { if iconOnly { Image(systemName: "text.viewfinder").font(.system(size: 25, weight: .semibold)) } else { Label("OCR", systemImage: "text.viewfinder") } }.buttonStyle(.plain) } }'''
new = '''    @ViewBuilder private func primaryAction(iconOnly: Bool) -> some View {
        let region = context.settings.capturePrimaryAction == .region
        Button { region ? capture() : service.chooseImage() } label: {
            if iconOnly {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(style.accentColor.color.opacity(0.055))
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(style.accentColor.color.opacity(0.42), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    VStack(spacing: 4) {
                        if service.busy {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: region ? "viewfinder" : "text.viewfinder")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(style.accentColor.color)
                        }
                        Text(region ? "CAPTURE" : "OCR")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(3)
            } else {
                Label(region ? "Capture" : "OCR", systemImage: region ? "viewfinder" : "text.viewfinder")
            }
        }
        .buttonStyle(.plain)
        .disabled(service.busy)
    }'''
replace_once(old, new, "capture micro")

# Stopwatch: show a 60-second sweep and running/paused state instead of a lone time string.
replace_once('''        case .micro: timeText(elapsed, scale: 1.0)''', '''        case .micro: microStopwatch(elapsed: elapsed)''', "stopwatch micro route")
anchor = '''    private func hero(elapsed: TimeInterval) -> some View {'''
insert = '''    private func microStopwatch(elapsed: TimeInterval) -> some View {
        let sweep = min(1, max(0, elapsed.truncatingRemainder(dividingBy: 60) / 60))
        return AdaptiveMicroRing(progress: sweep, accent: style.accentColor.color) {
            VStack(spacing: 2) {
                Image(systemName: workspace.stopwatchStart == nil ? "pause.fill" : "stopwatch.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(style.accentColor.color)
                timeText(elapsed, scale: 0.72)
            }
            .padding(5)
        }
    }

    private func hero(elapsed: TimeInterval) -> some View {'''
replace_once(anchor, insert, "stopwatch micro implementation")

PATH.write_text(text)
print("Polished micro widget layouts without changing larger widget families")
