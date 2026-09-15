from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)

# -----------------------------------------------------------------------------
# Calendar source settings: avoid availability/exhaustiveness warnings while
# keeping macOS 14's full-access/write-only handling in the guarded checks.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/WidgetSettingsView.swift")
s = p.read_text()
# These are the two @unknown-default switches inside VisualCalendarSourceBrowser.
s = s.replace("        @unknown default:\n            break\n", "        default:\n            break\n", 1)
s = s.replace("        @unknown default:\n            return \"Calendar access is unavailable.\"\n", "        default:\n            return \"Calendar access is unavailable.\"\n", 1)
p.write_text(s)

# -----------------------------------------------------------------------------
# Adaptive model capabilities. Generic controls are shown only if the selected
# widget really consumes them, and only on footprints where they can matter.
# -----------------------------------------------------------------------------
p = Path("Halo/Core/WidgetModels.swift")
s = p.read_text()

s = replace_once(
    s,
    '''    var visualAdaptiveSupportsControlToggle: Bool {\n        switch self {\n        case .timer, .media, .audio, .clipboard, .launcher, .activities, .capture, .stopwatch: return true\n        default: return false\n        }\n    }''',
    '''    var visualAdaptiveSupportsControlToggle: Bool {\n        switch self {\n        case .timer, .media, .audio, .clipboard, .stopwatch: return true\n        default: return false\n        }\n    }\n\n    func visualAdaptiveMaximumItemsAffects(_ footprint: VisualWidgetFootprint) -> Bool {\n        guard visualAdaptiveSupportsMaximumItems else { return false }\n        switch self {\n        case .audio:\n            return footprint.area >= 6\n        case .shelf, .clipboard, .system, .launcher, .activities:\n            return footprint.area > 1\n        default:\n            return false\n        }\n    }\n\n    func visualAdaptiveControlToggleAffects(_ footprint: VisualWidgetFootprint) -> Bool {\n        guard visualAdaptiveSupportsControlToggle else { return false }\n        switch self {\n        case .timer, .clipboard, .stopwatch:\n            return footprint.area > 1\n        case .media, .audio:\n            return true\n        default:\n            return false\n        }\n    }''',
    "truthful generic adaptive control capabilities",
)

# The only legacy-style element priority controls that are wired through
# AdaptiveResolvedContext.shows are Timer and Media. Other widgets have their
# own dedicated controls, so do not surface fake per-element toggles for them.
s = replace_once(
    s,
    '''        default:\n            return no("This widget uses dedicated controls instead of legacy per-element toggles.")\n        }\n    }\n}\n\nstruct WidgetStyle: Codable, Equatable {''',
    '''        default:\n            return no("This widget uses dedicated controls instead of legacy per-element toggles.")\n        }\n    }\n}\n\nstruct WidgetStyle: Codable, Equatable {''',
    "keep adaptive availability contract stable",
)
p.write_text(s)

# -----------------------------------------------------------------------------
# Adaptive renderer: availability applies only to the element contract for
# Timer/Media. Widgets with dedicated controls must never be hidden by stale
# legacy element state. Also make existing controls actually affect output.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/VisualWorkspaceAdaptiveWidgets.swift")
s = p.read_text()

s = replace_once(
    s,
    '''    func shows(_ key: String) -> Bool {\n        guard module.visualAdaptiveElementAvailability(key, footprint: footprint).available else { return false }\n        if module.visualAdaptiveAlwaysInformation.contains(key) { return true }\n        guard information.contains(key) else { return false }\n        guard let descriptor = module.widgetElements.first(where: { $0.key == key }) else { return true }\n        return style.elementStyle(for: descriptor).visible\n    }''',
    '''    func shows(_ key: String) -> Bool {\n        let configurable = module.visualAdaptiveConfigurableElementKeys\n        // Dedicated adaptive widgets do not use the legacy element-style map.\n        // This prevents old/hidden settings from silently suppressing their UI.\n        guard !configurable.isEmpty else { return true }\n        guard configurable.contains(key) else { return true }\n        guard module.visualAdaptiveElementAvailability(key, footprint: footprint).available else { return false }\n        if module.visualAdaptiveAlwaysInformation.contains(key) { return true }\n        return information.contains(key)\n    }''',
    "adaptive shows only uses real element contract",
)

# Audio: every visible inspector option must affect every representation where
# it is offered, including the 1x1 popover.
s = replace_once(
    s,
    '''                HStack { Image(systemName: speakerSymbol); Text("\\(percent)%").monospacedDigit(); Spacer(); Button("Mute") { service.toggleMute() }.disabled(!service.canSetVolume) }\n                if service.canSetVolume { volumeSlider }\n                if service.devices.count > 1 { outputPicker }\n                if media.connectedApp != nil { HStack { Button { media.perform("previous track", app: mediaApp) } label: { Image(systemName: "backward.fill") }; Button { media.perform("playpause", app: mediaApp) } label: { Image(systemName: "playpause.fill") }; Button { media.perform("next track", app: mediaApp) } label: { Image(systemName: "forward.fill") } } }''',
    '''                HStack {\n                    if context.settings.audioShowDeviceIcon { Image(systemName: speakerSymbol) }\n                    if context.settings.audioShowPercentage { Text("\\(percent)%").monospacedDigit() }\n                    Spacer()\n                    if context.settings.showControls { Button("Mute") { service.toggleMute() }.disabled(!service.canSetVolume) }\n                }\n                if context.settings.audioShowSlider && service.canSetVolume { volumeSlider }\n                if context.settings.audioShowOutputSelector && service.devices.count > 1 { outputPicker }\n                if context.settings.showControls && media.connectedApp != nil { HStack { Button { media.perform("previous track", app: mediaApp) } label: { Image(systemName: "backward.fill") }; Button { media.perform("playpause", app: mediaApp) } label: { Image(systemName: "playpause.fill") }; Button { media.perform("next track", app: mediaApp) } label: { Image(systemName: "forward.fill") } } }''',
    "audio micro popover respects settings",
)

s = replace_once(
    s,
    '''    private var compact: some View { HStack(spacing: 7) { Image(systemName: speakerSymbol).foregroundStyle(style.accentColor.color); Text("\\(percent)%").font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit(); Spacer(minLength: 2); if context.settings.showControls && service.canSetVolume { Button { service.toggleMute() } label: { Image(systemName: service.volume <= 0.001 ? "speaker.wave.2" : "speaker.slash") }.buttonStyle(.plain) } } }''',
    '''    private var compact: some View { HStack(spacing: 7) { if context.settings.audioShowDeviceIcon { Image(systemName: speakerSymbol).foregroundStyle(style.accentColor.color) }; if context.settings.audioShowPercentage { Text("\\(percent)%").font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit() }; Spacer(minLength: 2); if context.settings.showControls && service.canSetVolume { Button { service.toggleMute() } label: { Image(systemName: service.volume <= 0.001 ? "speaker.wave.2" : "speaker.slash") }.buttonStyle(.plain) } } }''',
    "audio compact settings",
)

s = replace_once(
    s,
    '''        VStack(spacing: context.spacing) {\n            Image(systemName: speakerSymbol).font(.system(size: 24, weight: .semibold)).foregroundStyle(style.accentColor.color)\n            Text("\\(percent)%").font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()\n            Text(selectedName).font(.caption).lineLimit(2).multilineTextAlignment(.center)''',
    '''        VStack(spacing: context.spacing) {\n            if context.settings.audioShowDeviceIcon { Image(systemName: speakerSymbol).font(.system(size: 24, weight: .semibold)).foregroundStyle(style.accentColor.color) }\n            if context.settings.audioShowPercentage { Text("\\(percent)%").font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit() }\n            Text(selectedName).font(.caption).lineLimit(2).multilineTextAlignment(.center)''',
    "audio vertical settings",
)

s = replace_once(
    s,
    '''            HStack { Label(selectedName, systemImage: speakerSymbol).lineLimit(1); Spacer(); Text("\\(percent)%").font(.title3.bold()).monospacedDigit() }''',
    '''            HStack {\n                if context.settings.audioShowDeviceIcon { Image(systemName: speakerSymbol).foregroundStyle(style.accentColor.color) }\n                Text(selectedName).lineLimit(1)\n                Spacer()\n                if context.settings.audioShowPercentage { Text("\\(percent)%").font(.title3.bold()).monospacedDigit() }\n            }''',
    "audio standard settings",
)

# Launcher: Show Favorites / Show Running Apps were exposed but not consistently
# consumed. Make them authoritative in every launcher footprint.
s = replace_once(
    s,
    '''        let favorites = favoriteApps\n        let primary = favorites.first\n        let running = workspace.runningApps.first''',
    '''        let favorites = favoriteApps\n        let primary = favorites.first\n        let running = context.settings.launcherShowRunningApps ? workspace.runningApps.first : nil''',
    "launcher micro running toggle",
)
s = replace_once(
    s,
    '''            ForEach(Array(favoriteApps.prefix(limit)), id: \\.bundle) { favoriteButton($0, compact: true) }\n            if favoriteApps.isEmpty { ForEach(Array(visibleApps.prefix(limit)), id: \\.processIdentifier) { runningButton($0, compact: true) } }''',
    '''            ForEach(Array(favoriteApps.prefix(limit)), id: \\.bundle) { favoriteButton($0, compact: true) }\n            if favoriteApps.isEmpty && context.settings.launcherShowRunningApps { ForEach(Array(visibleApps.prefix(limit)), id: \\.processIdentifier) { runningButton($0, compact: true) } }''',
    "launcher strip running toggle",
)
s = replace_once(
    s,
    '''        VStack(spacing: context.spacing * 0.7) {\n            ForEach(Array(visibleApps.prefix(limit)), id: \\.processIdentifier) { runningButton($0, compact: false) }\n            if visibleApps.isEmpty { Text("No running apps").font(.caption).foregroundStyle(.secondary) }''',
    '''        VStack(spacing: context.spacing * 0.7) {\n            if context.settings.launcherShowRunningApps { ForEach(Array(visibleApps.prefix(limit)), id: \\.processIdentifier) { runningButton($0, compact: false) } }\n            if !context.settings.launcherShowRunningApps || visibleApps.isEmpty { Text(context.settings.launcherShowRunningApps ? "No running apps" : "Running apps hidden").font(.caption).foregroundStyle(.secondary) }''',
    "launcher list running toggle",
)
s = replace_once(
    s,
    '''            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: context.spacing), count: min(context.settings.launcherColumns, max(2, context.columns))), spacing: context.spacing) { ForEach(Array(visibleApps.prefix(context.settings.maxItems)), id: \\.processIdentifier) { runningButton($0, compact: true) } }''',
    '''            if context.settings.launcherShowRunningApps { LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: context.spacing), count: min(context.settings.launcherColumns, max(2, context.columns))), spacing: context.spacing) { ForEach(Array(visibleApps.prefix(context.settings.maxItems)), id: \\.processIdentifier) { runningButton($0, compact: true) } } }''',
    "launcher standard running toggle",
)
s = replace_once(
    s,
    '''    private var favoriteApps: [FavoriteApp] {\n        context.settings.launcherFavoriteBundleIDs.compactMap { bundle in''',
    '''    private var favoriteApps: [FavoriteApp] {\n        guard context.settings.launcherShowFavorites else { return [] }\n        return context.settings.launcherFavoriteBundleIDs.compactMap { bundle in''',
    "launcher favorites toggle",
)

# Notes: the count toggle now also controls the micro word-count badge.
s = replace_once(
    s,
    '''                    Text("\\(words)w")\n                        .font(.system(size: 7, weight: .semibold, design: .rounded))\n                        .foregroundStyle(.secondary)''',
    '''                    if context.settings.notesShowCounts {\n                        Text("\\(words)w")\n                            .font(.system(size: 7, weight: .semibold, design: .rounded))\n                            .foregroundStyle(.secondary)\n                    }''',
    "notes micro count setting",
)

# Capture OCR visibility must also apply to the narrow vertical layout.
s = replace_once(
    s,
    '''    private var vertical: some View { VStack(spacing: context.spacing) { captureButton; ocrButton; if service.busy { ProgressView().controlSize(.small) }; if !service.recognizedText.isEmpty && context.rows >= 3 { Text(service.recognizedText).font(.caption2).lineLimit(4).frame(maxWidth: .infinity, alignment: .leading) } }.disabled(service.busy) }''',
    '''    private var vertical: some View { VStack(spacing: context.spacing) { captureButton; ocrButton; if service.busy { ProgressView().controlSize(.small) }; if context.settings.captureShowOCR && !service.recognizedText.isEmpty && context.rows >= 3 { Text(service.recognizedText).font(.caption2).lineLimit(4).frame(maxWidth: .infinity, alignment: .leading) } }.disabled(service.busy) }''',
    "capture vertical OCR setting",
)

p.write_text(s)

# -----------------------------------------------------------------------------
# Inspector footprint applicability. Hide module controls that cannot affect the
# selected footprint; keep only meaningful controls visible.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/WidgetSettingsView.swift")
s = p.read_text()

s = s.replace('if module.visualAdaptiveSupportsMaximumItems {', 'if module.visualAdaptiveMaximumItemsAffects(footprint) {')
s = s.replace('if module.visualAdaptiveSupportsControlToggle {', 'if module.visualAdaptiveControlToggleAffects(footprint) {')

# Timer controls: 1x1 has a purpose-built micro representation, so do not show
# style/typography-like controls that it cannot consume.
s = replace_once(
    s,
    '''            Section("Timer") {\n                Picker("Timer style", selection: adaptive.timerStyle) { ForEach(VisualTimerStyle.allCases) { Text($0.rawValue).tag($0) } }\n                Picker("Timer mode", selection: adaptive.timerMode) { ForEach(VisualTimerMode.allCases) { Text($0.rawValue).tag($0) } }\n                TextField("Timer name", text: adaptive.timerName)\n                Toggle("Show seconds", isOn: adaptive.timerShowSeconds)\n                PreciseSlider(title: "Progress thickness", value: adaptive.timerProgressThickness, range: 1...14, step: 1, suffix: "pt")\n            }''',
    '''            Section("Timer") {\n                if footprint.area > 1 { Picker("Timer style", selection: adaptive.timerStyle) { ForEach(VisualTimerStyle.allCases) { Text($0.rawValue).tag($0) } } }\n                Picker("Timer mode", selection: adaptive.timerMode) { ForEach(VisualTimerMode.allCases) { Text($0.rawValue).tag($0) } }\n                if footprint.area > 2 { TextField("Timer name", text: adaptive.timerName) }\n                if footprint.area > 1 { Toggle("Show seconds", isOn: adaptive.timerShowSeconds) }\n                if module.visualAdaptiveElementAvailability("progress", footprint: footprint).available { PreciseSlider(title: "Progress thickness", value: adaptive.timerProgressThickness, range: 1...14, step: 1, suffix: "pt") }\n            }''',
    "timer footprint controls",
)

# Media progress style is irrelevant if this footprint cannot render progress.
s = replace_once(
    s,
    '''                Toggle("Use artwork colors", isOn: adaptive.mediaUseArtworkColors)\n                Picker("Progress", selection: adaptive.mediaProgressStyle) { ForEach(VisualAdaptiveProgressStyle.allCases) { Text($0.rawValue).tag($0) } }''',
    '''                Toggle("Use artwork colors", isOn: adaptive.mediaUseArtworkColors)\n                if module.visualAdaptiveElementAvailability("progress", footprint: footprint).available { Picker("Progress", selection: adaptive.mediaProgressStyle) { ForEach(VisualAdaptiveProgressStyle.allCases) { Text($0.rawValue).tag($0) } } }''',
    "media progress control applicability",
)

# Audio quick levels only exist in large layouts. Other options are wired into
# the micro popover and compact/standard representations by the renderer patch.
s = replace_once(
    s,
    '''                Toggle("Show output selector", isOn: adaptive.audioShowOutputSelector)\n                Toggle("Quick volume levels", isOn: adaptive.audioShowQuickLevels)''',
    '''                Toggle("Show output selector", isOn: adaptive.audioShowOutputSelector)\n                if footprint.area >= 6 { Toggle("Quick volume levels", isOn: adaptive.audioShowQuickLevels) }''',
    "audio quick-level applicability",
)

# Clipboard: 1x1 deliberately shows object/type rather than prose. Search begins
# at medium layouts; the other row controls begin once rows can exist.
s = replace_once(
    s,
    '''            Section("Clipboard") {\n                PreciseSlider(title: "Preview length", value: Binding(get: { Double(adaptive.wrappedValue.clipboardPreviewLength) }, set: { adaptive.wrappedValue.clipboardPreviewLength = Int($0) }), range: 20...500, step: 10, suffix: " chars")\n                Toggle("Search", isOn: adaptive.clipboardShowSearch)\n                Toggle("Timestamps", isOn: adaptive.clipboardShowTimestamp)\n                Picker("Row style", selection: adaptive.clipboardRowStyle) { ForEach(VisualAdaptiveClipboardRowStyle.allCases) { Text($0.rawValue).tag($0) } }\n            }''',
    '''            Section("Clipboard") {\n                if footprint.area > 1 {\n                    PreciseSlider(title: "Preview length", value: Binding(get: { Double(adaptive.wrappedValue.clipboardPreviewLength) }, set: { adaptive.wrappedValue.clipboardPreviewLength = Int($0) }), range: 20...500, step: 10, suffix: " chars")\n                    Toggle("Timestamps", isOn: adaptive.clipboardShowTimestamp)\n                    Picker("Row style", selection: adaptive.clipboardRowStyle) { ForEach(VisualAdaptiveClipboardRowStyle.allCases) { Text($0.rawValue).tag($0) } }\n                }\n                if footprint.area >= 4 { Toggle("Search", isOn: adaptive.clipboardShowSearch) }\n            }''',
    "clipboard footprint controls",
)

# System had three inspector controls that the renderer never consumed. Remove
# them instead of keeping placebo switches. Graph controls only appear where the
# dashboard renderer can actually show a graph.
s = replace_once(
    s,
    '''                Toggle("Graphs on large layouts", isOn: adaptive.systemShowGraphs)\n                if adaptive.wrappedValue.systemShowGraphs { Picker("Graph type", selection: adaptive.systemGraphType) { ForEach(VisualSystemGraphType.allCases) { Text($0.rawValue).tag($0) } } }\n                Toggle("Battery ring", isOn: adaptive.systemBatteryRing)\n                Toggle("Metric labels", isOn: adaptive.systemShowLabels)\n                Toggle("Compact numbers", isOn: adaptive.systemCompactNumbers)''',
    '''                if footprint.area >= 6 {\n                    Toggle("Graphs", isOn: adaptive.systemShowGraphs)\n                    if adaptive.wrappedValue.systemShowGraphs { Picker("Graph type", selection: adaptive.systemGraphType) { ForEach(VisualSystemGraphType.allCases) { Text($0.rawValue).tag($0) } } }\n                }''',
    "remove dead system controls",
)

# Launcher: search/columns only exist in grid layouts; dashboard quick actions
# only exist on 6x3+; labels do not exist in the 1x1 portal.
s = replace_once(
    s,
    '''                Toggle("Show search", isOn: adaptive.launcherShowSearch)\n                Toggle("Show labels", isOn: adaptive.launcherShowLabels)\n                Toggle("Show running apps", isOn: adaptive.launcherShowRunningApps)\n                Toggle("Show favorites", isOn: adaptive.launcherShowFavorites)\n                Toggle("Downloads shortcut", isOn: adaptive.launcherShowDownloads)\n                Toggle("Timer actions", isOn: adaptive.launcherShowTimerActions)\n                Stepper("Columns: \\(adaptive.wrappedValue.launcherColumns)", value: adaptive.launcherColumns, in: 1...8)''',
    '''                if footprint.area >= 4 { Toggle("Show search", isOn: adaptive.launcherShowSearch) }\n                if footprint.area > 1 { Toggle("Show labels", isOn: adaptive.launcherShowLabels) }\n                Toggle("Show running apps", isOn: adaptive.launcherShowRunningApps)\n                Toggle("Show favorites", isOn: adaptive.launcherShowFavorites)\n                if footprint.columns >= 6 && footprint.rows >= 3 {\n                    Toggle("Downloads shortcut", isOn: adaptive.launcherShowDownloads)\n                    Toggle("Timer actions", isOn: adaptive.launcherShowTimerActions)\n                }\n                if footprint.area >= 4 { Stepper("Columns: \\(adaptive.wrappedValue.launcherColumns)", value: adaptive.launcherColumns, in: 1...8) }''',
    "launcher footprint controls",
)

# Activities: details need a real list; timestamps are rich-layout-only.
s = replace_once(
    s,
    '''            Section("Activities") {\n                Toggle("Details", isOn: adaptive.activitiesShowDetails)\n                Toggle("Progress", isOn: adaptive.activitiesShowProgress)\n                Toggle("Relative timestamps", isOn: adaptive.activitiesShowTimestamps)\n            }''',
    '''            Section("Activities") {\n                if footprint.area > 2 { Toggle("Details", isOn: adaptive.activitiesShowDetails) }\n                Toggle("Progress", isOn: adaptive.activitiesShowProgress)\n                if footprint.area >= 6 { Toggle("Relative timestamps", isOn: adaptive.activitiesShowTimestamps) }\n            }''',
    "activities footprint controls",
)

# Notes: 1x1 is an intentional capture/preview surface. Editor-only controls
# should not be shown until an editor can exist.
s = replace_once(
    s,
    '''            Section("Notes") {\n                Toggle("Word & character count", isOn: adaptive.notesShowCounts)\n                TextField("Empty-state placeholder", text: adaptive.notesPlaceholder)\n                PreciseSlider(title: "Line spacing", value: adaptive.notesLineSpacing, range: 0...18, step: 1, suffix: "pt")\n                PreciseSlider(title: "Editor padding", value: adaptive.notesEditorPadding, range: 0...24, step: 1, suffix: "pt")\n            }''',
    '''            Section("Notes") {\n                Toggle("Word & character count", isOn: adaptive.notesShowCounts)\n                if (footprint.columns == 1 && footprint.rows >= 2) || footprint.area >= 4 {\n                    TextField("Empty-state placeholder", text: adaptive.notesPlaceholder)\n                    PreciseSlider(title: "Line spacing", value: adaptive.notesLineSpacing, range: 0...18, step: 1, suffix: "pt")\n                    PreciseSlider(title: "Editor padding", value: adaptive.notesEditorPadding, range: 0...24, step: 1, suffix: "pt")\n                }\n            }''',
    "notes footprint controls",
)

# Capture: primary action is a 1x1 behavior; OCR output and recents require room.
s = replace_once(
    s,
    '''            Section("Capture") {\n                Picker("Primary action", selection: adaptive.capturePrimaryAction) { ForEach(VisualCapturePrimaryAction.allCases) { Text($0.rawValue).tag($0) } }\n                Toggle("Recent captures", isOn: adaptive.captureShowRecent)\n                Toggle("OCR result", isOn: adaptive.captureShowOCR)\n                PreciseSlider(title: "Thumbnail size", value: adaptive.captureThumbnailSize, range: 44...180, step: 2, suffix: "pt")\n            }''',
    '''            Section("Capture") {\n                if footprint.area == 1 { Picker("Primary action", selection: adaptive.capturePrimaryAction) { ForEach(VisualCapturePrimaryAction.allCases) { Text($0.rawValue).tag($0) } } }\n                if footprint.rows >= 2 || footprint.area >= 4 { Toggle("OCR result", isOn: adaptive.captureShowOCR) }\n                if footprint.area >= 6 {\n                    Toggle("Recent captures", isOn: adaptive.captureShowRecent)\n                    if adaptive.wrappedValue.captureShowRecent { PreciseSlider(title: "Thumbnail size", value: adaptive.captureThumbnailSize, range: 44...180, step: 2, suffix: "pt") }\n                }\n            }''',
    "capture footprint controls",
)

# Stopwatch scale does not affect the purpose-built 1x1 chronograph. Lap count
# only matters when lap lists can render.
s = replace_once(
    s,
    '''            Section("Stopwatch") {\n                Picker("Precision", selection: adaptive.stopwatchPrecision) { ForEach(VisualStopwatchPrecision.allCases) { Text($0.rawValue).tag($0) } }\n                Toggle("Show laps", isOn: adaptive.stopwatchShowLaps)\n                if adaptive.wrappedValue.stopwatchShowLaps { Stepper("Lap count: \\(adaptive.wrappedValue.stopwatchLapCount)", value: adaptive.stopwatchLapCount, in: 1...30) }\n                PreciseSlider(title: "Time scale", value: adaptive.stopwatchTimeScale, range: 0.6...2.4, step: 0.05, suffix: "×", decimals: 2)\n            }''',
    '''            Section("Stopwatch") {\n                Picker("Precision", selection: adaptive.stopwatchPrecision) { ForEach(VisualStopwatchPrecision.allCases) { Text($0.rawValue).tag($0) } }\n                if footprint.area > 1 {\n                    Toggle("Show laps", isOn: adaptive.stopwatchShowLaps)\n                    if adaptive.wrappedValue.stopwatchShowLaps && (footprint.rows >= 2 || footprint.area >= 4) { Stepper("Lap count: \\(adaptive.wrappedValue.stopwatchLapCount)", value: adaptive.stopwatchLapCount, in: 1...30) }\n                    PreciseSlider(title: "Time scale", value: adaptive.stopwatchTimeScale, range: 0.6...2.4, step: 0.05, suffix: "×", decimals: 2)\n                }\n            }''',
    "stopwatch footprint controls",
)

p.write_text(s)

print("Repaired Calendar/widget polish applicability")
