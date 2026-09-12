from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing pattern: {label}")
    return text.replace(old, new, 1)

# -----------------------------------------------------------------------------
# WindowManager: native drag destination + stable drag expansion state
# -----------------------------------------------------------------------------
p = Path("Halo/NotchEngine/WindowManager.swift")
s = p.read_text()
s = replace_once(s,
'''    var collapseTask: Task<Void, Never>?
    var editingGeometry = false
    func hover(_ inside: Bool, enabled: Bool) {
        collapseTask?.cancel()
        guard enabled, !editingGeometry else { return }
        if inside { expanded = true }
        else if !pinned {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled, let self, !self.pinned, !self.editingGeometry else { return }
                self.expanded = false
            }
        }
    }
''',
'''    var collapseTask: Task<Void, Never>?
    var dropExitTask: Task<Void, Never>?
    var editingGeometry = false

    func beginFileDrop(count: Int) {
        dropExitTask?.cancel()
        collapseTask?.cancel()
        let nextCount = max(1, count)
        if dropItemCount != nextCount { dropItemCount = nextCount }
        if !dropTargeted { dropTargeted = true }
        if !expanded { expanded = true }
    }

    func endFileDrop(collapseAfterDelay: Bool = true) {
        dropExitTask?.cancel()
        dropExitTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled, let self else { return }
            self.dropTargeted = false
            self.dropItemCount = 0
            guard collapseAfterDelay, !self.pinned, !self.editingGeometry else { return }
            self.collapseTask?.cancel()
            self.collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 420_000_000)
                guard !Task.isCancelled, let self, !self.pinned, !self.editingGeometry, !self.dropTargeted else { return }
                self.expanded = false
            }
        }
    }

    func completeFileDrop() {
        dropExitTask?.cancel()
        dropTargeted = false
        dropItemCount = 0
        guard !pinned, !editingGeometry else { return }
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled, let self, !self.pinned, !self.editingGeometry, !self.dropTargeted else { return }
            self.expanded = false
        }
    }

    func hover(_ inside: Bool, enabled: Bool) {
        collapseTask?.cancel()
        guard enabled, !editingGeometry else { return }
        if dropTargeted {
            if inside && !expanded { expanded = true }
            return
        }
        if inside { expanded = true }
        else if !pinned {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled, let self, !self.pinned, !self.editingGeometry, !self.dropTargeted else { return }
                self.expanded = false
            }
        }
    }
''', "stable file drag state")

s = replace_once(s,
'''final class HaloPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
''',
'''final class HaloPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class HaloDropHostingView<Content: View>: NSHostingView<Content> {
    var dragStateHandler: ((Bool, Int) -> Void)?
    var dropHandler: (([URL]) -> Void)?

    override init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func fileURLCount(_ sender: NSDraggingInfo) -> Int {
        sender.draggingPasteboard.pasteboardItems?.reduce(into: 0) { count, item in
            if item.availableType(from: [.fileURL]) != nil { count += 1 }
        } ?? 0
    }

    private func fileURLs(_ sender: NSDraggingInfo) -> [URL] {
        let objects = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) ?? []
        return objects.compactMap { object in
            guard let url = object as? NSURL else { return nil }
            return url as URL
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let count = fileURLCount(sender)
        guard count > 0 else { return [] }
        dragStateHandler?(true, count)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let count = fileURLCount(sender)
        guard count > 0 else { return [] }
        dragStateHandler?(true, count)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dragStateHandler?(false, 0)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(sender)
        guard !urls.isEmpty else {
            dragStateHandler?(false, 0)
            return false
        }
        dropHandler?(urls)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        dragStateHandler?(false, 0)
    }
}
''', "native drop hosting view")

s = replace_once(s,
'''        func stop() {
            animator.cancel(); state.collapseTask?.cancel(); subscription?.cancel(); contextSizeSubscription?.cancel(); panel.close()
        }
''',
'''        func stop() {
            animator.cancel(); state.collapseTask?.cancel(); state.dropExitTask?.cancel()
            subscription?.cancel(); contextSizeSubscription?.cancel(); panel.close()
        }
''', "cancel drop task")

s = replace_once(s,
'''                let view = NSHostingView(rootView: root)
                view.sizingOptions = []
                host.panel.contentView = view
''',
'''                let view = HaloDropHostingView(rootView: root)
                view.sizingOptions = []
                view.dragStateHandler = { [weak host] active, count in
                    guard let host else { return }
                    let defaults = UserDefaults.standard
                    let ciEnabled = defaults.object(forKey: "HaloContextDropEnabled") == nil
                        ? true : defaults.bool(forKey: "HaloContextDropEnabled")
                    if active && ciEnabled {
                        host.state.beginFileDrop(count: count)
                    } else if host.state.dropTargeted {
                        host.state.endFileDrop(collapseAfterDelay: true)
                    }
                }
                view.dropHandler = { [weak self, weak host] urls in
                    guard let self, let host else { return }
                    host.state.completeFileDrop()
                    self.store.addFiles(urls)
                }
                host.panel.contentView = view
''', "install native drop handling")
p.write_text(s)

# -----------------------------------------------------------------------------
# SurfaceView: remove the SwiftUI drop delegate. Native host now owns drag entry.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/SurfaceView.swift")
s = p.read_text()
s = s.replace("import UniformTypeIdentifiers\n", "", 1)
s = replace_once(s,
'''        .onDrop(of: [UTType.fileURL.identifier], delegate: HaloFileDropDelegate(
            targeted: $state.dropTargeted,
            itemCount: $state.dropItemCount,
            perform: acceptFileDrop
        ))
    }

    private func acceptFileDrop(_ providers: [NSItemProvider]) {
        state.expanded = true
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in store.addFiles([url]) }
            }
        }
    }

    private func horizontalWidget(_ module: ModuleID) -> some View {
''',
'''    }

    private func horizontalWidget(_ module: ModuleID) -> some View {
''', "remove SwiftUI drop hook")
start = s.find("private struct HaloFileDropDelegate: DropDelegate {")
end = s.find("private struct DropContextView: View {", start)
if start == -1 or end == -1:
    raise SystemExit("missing pattern: HaloFileDropDelegate block")
s = s[:start] + s[end:]
p.write_text(s)

# -----------------------------------------------------------------------------
# WidgetViews: make alignment semantics + Clock icon control truthful.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/WidgetViews.swift")
s = p.read_text()
s = replace_once(s,
'''    var alignment: Alignment {
        switch self { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
''',
'''    var alignment: Alignment {
        switch self { case .leading: return .topLeading; case .center: return .top; case .trailing: return .topTrailing }
    }
''', "top-aligned widget alignment")
s = replace_once(s,
'''                if style.showTitle && !compact { Text("Clock").font(style.font(scale: 0.75)) }
''',
'''                if style.showTitle && !compact {
                    HStack(spacing: max(4, style.resolvedContent.spacing * 0.55)) {
                        Image(systemName: "clock")
                            .font(.system(size: style.resolvedContent.iconSize, weight: .semibold))
                            .foregroundStyle(style.accentColor.color)
                        Text("Clock").font(style.font(scale: 0.75))
                    }
                }
''', "clock header icon")
p.write_text(s)

# -----------------------------------------------------------------------------
# Opened widget renderers: remove hidden dependencies and make every exposed control effective.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/ModuleViews.swift")
s = p.read_text()
s = s.replace("if options.activitiesShowDetail && options.showSecondaryText && !activity.detail.isEmpty {", "if options.activitiesShowDetail && !activity.detail.isEmpty {", 1)
s = s.replace("if options.captureShowHelp && options.showSecondaryText {", "if options.captureShowHelp {", 1)
s = s.replace("if options.mediaShowSource && options.showSecondaryText, let source = service.connectedApp {", "if options.mediaShowSource, let source = service.connectedApp {", 1)
s = s.replace("if options.mediaShowArtist && options.showSecondaryText && !service.artist.isEmpty {", "if options.mediaShowArtist && !service.artist.isEmpty {", 1)
s = s.replace("if options.calendarShowTimes && options.showSecondaryText { Text(event.startDate, style: .time).font(style.font(scale: 0.85)).foregroundStyle(.secondary) }", "if options.calendarShowTimes { Text(event.startDate, style: .time).font(style.font(scale: 0.85)).foregroundStyle(.secondary) }", 1)

s = replace_once(s,
'''            if options.showControls {
                HStack(spacing: options.spacing) {
                    Button { service.perform("previous track", app: app) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("Previous track")
                    Button { service.perform("playpause", app: app) } label: { Image(systemName: "playpause.fill") }.accessibilityLabel("Play or pause")
                    Button { service.perform("next track", app: app) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("Next track")
                    Spacer()
                    Button("Retry detection") { service.retryDetection(preferred: app) }
                }.disabled(service.busy)
            }
''',
'''            if options.showControls || options.showQuickActions {
                HStack(spacing: options.spacing) {
                    if options.showControls {
                        Button { service.perform("previous track", app: app) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("Previous track")
                        Button { service.perform("playpause", app: app) } label: { Image(systemName: "playpause.fill") }.accessibilityLabel("Play or pause")
                        Button { service.perform("next track", app: app) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("Next track")
                    }
                    if options.showQuickActions {
                        Spacer()
                        Button("Retry detection") { service.retryDetection(preferred: app) }
                    }
                }.disabled(service.busy)
            }
''', "media controls independent from retry")

s = replace_once(s,
'''                if options.showSearch { TextField("Search clipboard", text: $search) }
                ForEach(Array(service.entries.filter { search.isEmpty || $0.text.localizedCaseInsensitiveContains(search) }.prefix(options.maxItems))) { entry in
''',
'''                if options.showSearch { TextField("Search clipboard", text: $search) }
                let effectiveSearch = options.showSearch ? search : ""
                ForEach(Array(service.entries.filter { effectiveSearch.isEmpty || $0.text.localizedCaseInsensitiveContains(effectiveSearch) }.prefix(options.maxItems))) { entry in
''', "clipboard hidden search")

s = replace_once(s,
'''        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.showSearch { TextField("Search apps and commands", text: $query) }
            if options.launcherTimers {
                ForEach([5, 15, 25], id: \.self) { minutes in
                    if CommandSearch.matches(query, in: "Start timer \(minutes)") {
''',
'''        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.showSearch { TextField("Search apps and commands", text: $query) }
            let effectiveQuery = options.showSearch ? query : ""
            if options.launcherTimers {
                ForEach([5, 15, 25], id: \.self) { minutes in
                    if CommandSearch.matches(effectiveQuery, in: "Start timer \(minutes)") {
''', "launcher hidden search start")
s = s.replace('CommandSearch.matches(query, in: $0.localizedName ?? "")', 'CommandSearch.matches(effectiveQuery, in: $0.localizedName ?? "")', 1)
s = s.replace('CommandSearch.matches(query, in: $0.title)', 'CommandSearch.matches(effectiveQuery, in: $0.title)', 1)
p.write_text(s)

# -----------------------------------------------------------------------------
# Built-in opened widgets + settings truthfulness.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/SurfaceView.swift")
s = p.read_text()
s = s.replace('else if store.finished { Text("Session complete").foregroundStyle(.green) }', 'else if options.showSecondaryText && store.finished { Text("Session complete").foregroundStyle(.green) }', 1)
s = replace_once(s,
'''                        ForEach([options.timerPresetA, options.timerPresetB, options.timerPresetC], id: \.self) { minutes in
                            Button("\(minutes) min") { store.startTimer(minutes: minutes) }
                        }
''',
'''                        ForEach(Array([options.timerPresetA, options.timerPresetB, options.timerPresetC].enumerated()), id: \.offset) { _, minutes in
                            Button("\(minutes) min") { store.startTimer(minutes: minutes) }
                        }
''', "timer duplicate preset ids")
s = s.replace('showDetail: options.shelfShowDetails && options.showSecondaryText', 'showDetail: options.shelfShowDetails', 1)
p.write_text(s)

p = Path("Halo/Views/WidgetSettingsView.swift")
s = p.read_text()
s = replace_once(s,
'''            PreciseSlider(title: "Minimum height", value: style.minimumHeight, range: 0...400, step: 1, suffix: "pt")
            Divider()
''',
'''            if layout.horizontalWidgets ?? false {
                Text("Horizontal widgets use the dashboard's fixed horizontal height, so per-widget minimum height does not apply in this layout mode.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                PreciseSlider(title: "Minimum height", value: style.minimumHeight, range: 0...400, step: 1, suffix: "pt")
            }
            Divider()
''', "truthful minimum height")
s = replace_once(s,
'''                Toggle("Show playback controls", isOn: content.showControls)
                Toggle("Show errors / status", isOn: content.showStatus)
''',
'''                Toggle("Show playback controls", isOn: content.showControls)
                Toggle("Show Retry detection", isOn: content.showQuickActions)
                Toggle("Show errors / status", isOn: content.showStatus)
''', "media retry toggle")
p.write_text(s)

print("Drop CI native expansion + opened widget control audit applied")
