from pathlib import Path
import re
ROOT = Path('.')
def read(p): return (ROOT/p).read_text()
def write(p,s): (ROOT/p).write_text(s)

# -----------------------------------------------------------------------------
# Hardware brightness where IOKit exposes it; unsupported displays remain hidden.
# -----------------------------------------------------------------------------
p='Halo/Services/Integrations.swift'; s=read(p)
if 'import IOKit.graphics' not in s:
    s=s.replace('import IOKit.ps\n','import IOKit.ps\nimport IOKit.graphics\n',1)
old='''            let thermal = detailed ? Self.thermalDescription(ProcessInfo.processInfo.thermalState) : "Nominal"\n            let power = (battery, charging, onBattery)\n'''
new='''            let thermal = detailed ? Self.thermalDescription(ProcessInfo.processInfo.thermalState) : "Nominal"\n            let brightness = detailed ? Self.readBrightness() : nil\n            let power = (battery, charging, onBattery)\n'''
if old in s: s=s.replace(old,new,1)
old='''                self.networkUpPerSecond = rates.1\n                self.thermalState = thermal\n                Self.append(cpuPercent, to: &self.cpuHistory)\n'''
new='''                self.networkUpPerSecond = rates.1\n                self.thermalState = thermal\n                self.brightness = brightness\n                Self.append(cpuPercent, to: &self.cpuHistory)\n'''
if old in s: s=s.replace(old,new,1)
old='''    // Brightness remains hidden when the current display does not expose a safe software control.\n    func setBrightness(_ value: Double) { _ = value }\n'''
new=r'''    // IODisplay brightness is supported on compatible displays. Unsupported displays return nil,
    // so the lightweight Brightness element disappears rather than presenting a dead control.
    func setBrightness(_ value: Double) {
        let clamped = min(1, max(0, value))
        let service = CGDisplayIOServicePort(CGMainDisplayID())
        guard service != 0,
              IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, Float(clamped)) == kIOReturnSuccess else {
            brightness = nil
            return
        }
        brightness = clamped
    }

    private static func readBrightness() -> Double? {
        let service = CGDisplayIOServicePort(CGMainDisplayID())
        guard service != 0 else { return nil }
        var value: Float = 0
        guard IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &value) == kIOReturnSuccess else { return nil }
        return min(1, max(0, Double(value)))
    }
'''
if old in s: s=s.replace(old,new,1)
write(p,s)

# -----------------------------------------------------------------------------
# Useful default interactions for lightweight controls.
# -----------------------------------------------------------------------------
p='Halo/Core/WorkspaceModels.swift'; s=read(p)
old='''        value.element = element; value.priority = priority\n        value.sizing = OpenNotchSizing(mode: element == .spacer ? .fill : .fitContent,\n                                       minimumWidth: 20, preferredWidth: 110, maximumWidth: 500,\n                                       minimumHeight: 18, preferredHeight: 34, maximumHeight: 180)\n        return value\n'''
new='''        value.element = element; value.priority = priority\n        value.sizing = OpenNotchSizing(mode: element == .spacer ? .fill : .fitContent,\n                                       minimumWidth: 20, preferredWidth: 110, maximumWidth: 500,\n                                       minimumHeight: 18, preferredHeight: 34, maximumHeight: 180)\n        switch element {\n        case .volume: value.interactions.scroll = .adjustVolume\n        case .playbackProgress: value.interactions.scroll = .seekMedia\n        case .albumArt: value.interactions.doubleClick = .openPlayer\n        case .timer: value.interactions.singleClick = .toggleTimer\n        case .stopwatch: value.interactions.singleClick = .toggleStopwatch\n        default: break\n        }\n        return value\n'''
if old in s: s=s.replace(old,new,1)
write(p,s)

# -----------------------------------------------------------------------------
# Runtime: true animated GIFs, live app identity, and runtime drag only when configured.
# Expose opened renderer/background internally so settings can display the real live renderer.
# -----------------------------------------------------------------------------
p='Halo/Views/SurfaceView.swift'; s=read(p)
s=s.replace('private struct OpenNotchBackgroundView: View {','struct OpenNotchBackgroundView: View {',1)
s=s.replace('private struct OpenNotchWorkspaceView: View {','struct OpenNotchWorkspaceView: View {',1)
old='''        case .appIcon:\n            if let icon = NSWorkspace.shared.frontmostApplication?.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: item.style?.iconSize ?? 24, height: item.style?.iconSize ?? 24) }\n        case .appName: Text(NSWorkspace.shared.frontmostApplication?.localizedName ?? "")\n'''
new='''        case .appIcon:\n            TimelineView(.periodic(from: .now, by: 1)) { _ in\n                if let icon = NSWorkspace.shared.frontmostApplication?.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: item.style?.iconSize ?? 24, height: item.style?.iconSize ?? 24) }\n            }\n        case .appName:\n            TimelineView(.periodic(from: .now, by: 1)) { _ in Text(NSWorkspace.shared.frontmostApplication?.localizedName ?? "") }\n'''
if old in s: s=s.replace(old,new,1)
old='''        case .customImage, .customGIF:\n            if let image { Image(nsImage: image).resizable().scaledToFit() }\n            else { Image(systemName: "photo").foregroundStyle(.secondary).task { image = NSImage(contentsOfFile: item.customAssetPath) } }\n'''
new='''        case .customImage:\n            if let image { Image(nsImage: image).resizable().scaledToFit() }\n            else { Image(systemName: "photo").foregroundStyle(.secondary).task { image = NSImage(contentsOfFile: item.customAssetPath) } }\n        case .customGIF:\n            if FileManager.default.fileExists(atPath: item.customAssetPath) { OpenNotchGIFView(path: item.customAssetPath) }\n            else { Image(systemName: "photo.stack").foregroundStyle(.secondary) }\n'''
if old in s: s=s.replace(old,new,1)

interaction_start=s.index('private struct OpenNotchInteractionModifier: ViewModifier {')
interaction_end=s.index('\nprivate struct OpenNotchScrollCapture:',interaction_start)
interaction=r'''private struct OpenNotchInteractionModifier: ViewModifier {
    let item: OpenNotchItem
    @ObservedObject var store: AppStore
    @ViewBuilder func body(content: Content) -> some View {
        let base = content
            .onTapGesture(count: 2) { perform(item.interactions.doubleClick) }
            .simultaneousGesture(TapGesture(count: 1).onEnded {
                let modifiers = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
                perform(modifiers.isEmpty ? item.interactions.singleClick : item.interactions.modifierClick)
            })
            .contextMenu {
                if item.interactions.rightClick != .none { Button(item.interactions.rightClick.rawValue) { perform(item.interactions.rightClick) } }
            }
            .background {
                if item.interactions.scroll != .none { OpenNotchScrollCapture { perform(item.interactions.scroll, delta: $0) } }
            }
        if item.interactions.drag != .none {
            base.onDrag { perform(item.interactions.drag); return NSItemProvider(object: item.id.uuidString as NSString) }
        } else {
            base
        }
    }
    private func perform(_ action: OpenNotchInteractionAction, delta: Double = 0) {
        let workspace = store.workspace
        switch action {
        case .none: break
        case .togglePlayback: workspace.media.perform("playpause", app: workspace.settings.mediaApp)
        case .nextTrack: workspace.media.perform("next track", app: workspace.settings.mediaApp)
        case .previousTrack: workspace.media.perform("previous track", app: workspace.settings.mediaApp)
        case .openPlayer:
            if let id = workspace.media.connectedApp, let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first { app.activate(options: .activateIgnoringOtherApps) }
        case .adjustVolume:
            guard workspace.audio.canSetVolume else { return }
            workspace.audio.setVolume(min(1, max(0, workspace.audio.volume + Float(delta > 0 ? 0.04 : -0.04))))
        case .seekMedia:
            if workspace.media.duration > 0 { workspace.media.seek(to: min(workspace.media.duration, max(0, workspace.media.position + (delta > 0 ? 5 : -5)))) }
        case .toggleTimer:
            if store.deadline != nil || store.pausedSeconds > 0 { store.pauseResume() } else { store.startTimer(minutes: 25) }
        case .toggleStopwatch: workspace.toggleStopwatch()
        case .openSystemSettings:
            if let url = URL(string: "x-apple.systempreferences:") { NSWorkspace.shared.open(url) }
        }
    }
}

private struct OpenNotchGIFView: NSViewRepresentable {
    let path: String
    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        view.animates = true
        view.image = NSImage(contentsOfFile: path)
        return view
    }
    func updateNSView(_ nsView: NSImageView, context: Context) {
        if nsView.image?.name() != path { nsView.image = NSImage(contentsOfFile: path) }
        nsView.animates = true
    }
}
'''
s=s[:interaction_start]+interaction+s[interaction_end:]
write(p,s)

# -----------------------------------------------------------------------------
# Explicit Compact/Regular/Expanded content behavior for remaining major modules.
# -----------------------------------------------------------------------------
p='Halo/Views/ModuleViews.swift'; s=read(p)
if '@Environment(\\.openNotchPresentation) private var presentation' not in s.split('struct IntegrationModuleView: View {',1)[1].split('var body:',1)[0]:
    s=s.replace('struct IntegrationModuleView: View {\n    @Environment(\\.widgetStyle) private var style\n','struct IntegrationModuleView: View {\n    @Environment(\\.widgetStyle) private var style\n    @Environment(\\.openNotchPresentation) private var presentation\n',1)
# Activities: compact count only; regular list without full metadata; expanded everything.
s=s.replace('''        case .activities:\n            WidgetElement(key: "summary") {\n''','''        case .activities:\n            WidgetElement(key: "summary", defaultPriority: .high) {\n''',1)
s=s.replace('''            if workspace.activities.isEmpty, options.showStatus {\n''','''            if workspace.activities.isEmpty, options.showStatus, presentation != .compact {\n''',1)
s=s.replace('''            WidgetElement(key: "items") {\n                VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {\n                    ForEach(Array(workspace.activities.prefix(options.maxItems))) { activity in\n''','''            if presentation != .compact { WidgetElement(key: "items") {\n                VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {\n                    ForEach(Array(workspace.activities.prefix(presentation == .expanded ? options.maxItems : min(3, options.maxItems)))) { activity in\n''',1)
s=s.replace('''                                if options.activitiesShowDetail && !activity.detail.isEmpty { Text(activity.detail).foregroundStyle(.secondary) }\n                                if options.showProgress, let progress = activity.progress { ProgressView(value: progress) }\n''','''                                if presentation == .expanded && options.activitiesShowDetail && !activity.detail.isEmpty { Text(activity.detail).foregroundStyle(.secondary) }\n                                if presentation != .compact && options.showProgress, let progress = activity.progress { ProgressView(value: progress) }\n''',1)
# Close conditional just before notes case.
s=s.replace('''                }\n            }\n        case .notes:\n''','''                }\n            } }\n        case .notes:\n''',1)
# Notes compact = stats, regular = editor, expanded = stats/editor/actions.
s=s.replace('''        case .notes:\n            WidgetElement(key: "stats") {\n''','''        case .notes:\n            if presentation != .regular { WidgetElement(key: "stats", defaultPriority: .low) {\n''',1)
s=s.replace('''                HStack { Label("\\(words) words", systemImage: "text.word.spacing"); Spacer(); Text("\\(workspace.settings.notes.count) chars") }\n            }\n            WidgetElement(key: "editor") {\n''','''                HStack { Label("\\(words) words", systemImage: "text.word.spacing"); Spacer(); Text("\\(workspace.settings.notes.count) chars") }\n            } }\n            if presentation != .compact { WidgetElement(key: "editor", defaultPriority: .high) {\n''',1)
s=s.replace('''                TextEditor(text: $workspace.settings.notes).frame(height: options.notesHeight).accessibilityLabel("Quick note")\n            }\n            WidgetElement(key: "actions", defaultVisible: false) {\n''','''                TextEditor(text: $workspace.settings.notes).frame(height: presentation == .expanded ? max(options.notesHeight, 160) : options.notesHeight).accessibilityLabel("Quick note")\n            } }\n            if presentation == .expanded { WidgetElement(key: "actions", defaultVisible: false, defaultPriority: .low) {\n''',1)
s=s.replace('''                    Button("Clear") { workspace.settings.notes = "" }.disabled(workspace.settings.notes.isEmpty)\n                }\n            }\n        case .capture:\n''','''                    Button("Clear") { workspace.settings.notes = "" }.disabled(workspace.settings.notes.isEmpty)\n                }\n            } }\n        case .capture:\n''',1)
# Stopwatch compact = time only; regular/expanded add state and controls.
s=s.replace('''        case .stopwatch:\n            WidgetElement(key: "state") {\n''','''        case .stopwatch:\n            if presentation != .compact { WidgetElement(key: "state", defaultPriority: .low) {\n''',1)
s=s.replace('''                      systemImage: workspace.stopwatchStart == nil ? "pause.circle" : "play.circle.fill")\n            }\n            WidgetElement(key: "time") {\n''','''                      systemImage: workspace.stopwatchStart == nil ? "pause.circle" : "play.circle.fill")\n            } }\n            WidgetElement(key: "time", defaultPriority: .alwaysVisible) {\n''',1)
s=s.replace('''            if options.showControls {\n                WidgetElement(key: "controls") {\n''','''            if options.showControls && presentation != .compact {\n                WidgetElement(key: "controls", defaultPriority: .high) {\n''',1)
write(p,s)

# -----------------------------------------------------------------------------
# Real live preview in the editor + file picker for image/GIF elements.
# -----------------------------------------------------------------------------
p='Halo/Views/WorkspaceSettingsView.swift'; s=read(p)
s=s.replace('case "Widgets": WidgetSettingsView(layout: $workspace.settings.layout)','case "Widgets": WidgetSettingsView(layout: $workspace.settings.layout, store: store)',1)
write(p,s)

p='Halo/Views/WidgetSettingsView.swift'; s=read(p)
s=s.replace('struct WidgetSettingsView: View {\n    @Binding var layout: WorkspaceLayout\n','struct WidgetSettingsView: View {\n    @Binding var layout: WorkspaceLayout\n    @ObservedObject var store: AppStore\n',1)
s=s.replace('OpenedNotchWorkspaceEditor(layout: $layout)','OpenedNotchWorkspaceEditor(layout: $layout, store: store)',1)
s=s.replace('''private struct OpenedNotchWorkspaceEditor: View {\n    @Binding var layout: WorkspaceLayout\n''','''private struct OpenedNotchWorkspaceEditor: View {\n    @Binding var layout: WorkspaceLayout\n    @ObservedObject var store: AppStore\n''',1)
s=s.replace('''    @State private var backgroundMode = false\n\n    private var opened: OpenNotchLayout { layout.resolvedOpenNotchLayout }\n''','''    @State private var backgroundMode = false\n    @State private var livePreview = false\n    @State private var livePage = 0\n\n    private var opened: OpenNotchLayout { layout.resolvedOpenNotchLayout }\n''',1)
s=s.replace('''            Button { backgroundMode = true; selectedItem = nil; selectedGroup = nil; selectedRegion = nil } label: { Image(systemName: "paintbrush") }.help("Opened surface appearance")\n            Spacer()\n''','''            Button { backgroundMode = true; selectedItem = nil; selectedGroup = nil; selectedRegion = nil } label: { Image(systemName: "paintbrush") }.help("Opened surface appearance")\n            Picker("Preview", selection: $livePreview) { Text("Layout").tag(false); Text("Live").tag(true) }.pickerStyle(.segmented).frame(width: 130)\n            Spacer()\n''',1)
old_preview='''    private var preview: some View {\n        VStack(spacing: 10) {\n            HStack {\n                VStack(alignment: .leading, spacing: 2) { Text("Opened Notch").font(.headline); Text(opened.preset.rawValue).font(.caption).foregroundStyle(.secondary) }\n                Spacer(); Text("Drag items between regions · drag corner to resize").font(.caption).foregroundStyle(.secondary)\n            }\n            RoundedRectangle(cornerRadius: 28, style: .continuous)\n                .fill(Color.black.opacity(0.92))\n                .overlay {\n                    VStack(spacing: 8) {\n                        editorRow([.topLeft, .topCenter, .topRight])\n                        editorRow([.middleLeft, .middleCenter, .middleRight])\n                        editorRow([.bottomLeft, .bottomCenter, .bottomRight])\n                    }.padding(14)\n                }\n                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))\n                .frame(width: 610, height: 470)\n                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.84), value: opened)\n        }\n    }\n'''
new_preview='''    @ViewBuilder private var preview: some View {\n        VStack(spacing: 10) {\n            HStack {\n                VStack(alignment: .leading, spacing: 2) { Text("Opened Notch").font(.headline); Text(opened.preset.rawValue).font(.caption).foregroundStyle(.secondary) }\n                Spacer(); Text(livePreview ? "Live opened-notch renderer" : "Drag items between regions · drag corner to resize").font(.caption).foregroundStyle(.secondary)\n            }\n            if livePreview {\n                ZStack {\n                    OpenNotchBackgroundView(options: opened.appearance, fallback: layout.appearance, theme: store.configuration.theme, system: store.workspace.system)\n                    OpenNotchWorkspaceView(layout: layout, store: store, mode: layout.resolvedOpenNotchContentMode, page: $livePage)\n                        .padding(.horizontal, layout.resolvedOpenHorizontalPadding)\n                        .padding(.vertical, layout.resolvedOpenVerticalPadding)\n                }\n                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))\n                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))\n                .frame(width: 610, height: 470)\n            } else {\n                RoundedRectangle(cornerRadius: 28, style: .continuous)\n                    .fill(Color.black.opacity(0.92))\n                    .overlay {\n                        VStack(spacing: 8) {\n                            editorRow([.topLeft, .topCenter, .topRight])\n                            editorRow([.middleLeft, .middleCenter, .middleRight])\n                            editorRow([.bottomLeft, .bottomCenter, .bottomRight])\n                        }.padding(14)\n                    }\n                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))\n                    .frame(width: 610, height: 470)\n            }\n        }\n        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.84), value: opened)\n    }\n'''
if old_preview in s: s=s.replace(old_preview,new_preview,1)
s=s.replace('''        if item.element == .customImage || item.element == .customGIF { Section("Content") { TextField("Image / GIF path", text: binding.customAssetPath) } }\n''','''        if item.element == .customImage || item.element == .customGIF {\n            Section("Content") {\n                TextField("Image / GIF path", text: binding.customAssetPath)\n                Button("Choose File…") { chooseAsset(for: item.id, gifOnly: item.element == .customGIF) }\n            }\n        }\n''',1)
# Add asset chooser before materialize helper.
anchor='''    private func materialize() { if layout.openNotch == nil { layout.materializeOpenNotchLayout() } }\n'''
chooser='''    private func chooseAsset(for itemID: UUID, gifOnly: Bool) {\n        let panel = NSOpenPanel()\n        panel.allowsMultipleSelection = false\n        panel.canChooseDirectories = false\n        panel.allowedContentTypes = gifOnly ? [.gif] : [.image]\n        if panel.runModal() == .OK, let url = panel.url { mutateItem(itemID) { $0.customAssetPath = url.path } }\n    }\n\n'''
if chooser.strip() not in s: s=s.replace(anchor,chooser+anchor,1)
write(p,s)

print('Opened-notch final polish applied.')
