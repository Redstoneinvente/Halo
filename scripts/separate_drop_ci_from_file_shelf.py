from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    path.write_text(text.replace(old, new, 1))


window = Path("Halo/NotchEngine/WindowManager.swift")
surface = Path("Halo/Views/SurfaceView.swift")
adaptive = Path("Halo/Views/VisualWorkspaceAdaptiveWidgets.swift")

replace_once(
    window,
    '''    var dragStateHandler: ((Bool, Int) -> Void)?
    var dropHandler: (([URL]) -> Void)?
    var dropEnabled: (() -> Bool)?

    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var acceptsFileDrop: Bool { dropEnabled?() ?? true }

    private func rejectFileDrop() {
''',
    '''    var dragStateHandler: ((Bool, Int) -> Void)?
    var dropHandler: (([URL]) -> Void)?
    var dropEnabled: (() -> Bool)? {
        didSet { refreshDropRegistration() }
    }
    private var dropCIRegistered = false

    required init(rootView: Content) {
        super.init(rootView: rootView)
        refreshDropRegistration()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var acceptsFileDrop: Bool { dropEnabled?() ?? true }

    /// Drop CI owns only the surface-wide drag destination. When disabled we unregister
    /// this hosting view entirely so descendant drop targets (notably File Shelf) remain usable.
    func refreshDropRegistration() {
        let shouldRegister = acceptsFileDrop
        guard shouldRegister != dropCIRegistered else { return }
        if shouldRegister {
            registerForDraggedTypes([.fileURL])
        } else {
            unregisterDraggedTypes()
        }
        dropCIRegistered = shouldRegister
        if !shouldRegister { rejectFileDrop() }
    }

    private func rejectFileDrop() {
''',
    "dynamic Drop CI registration",
)

replace_once(
    window,
    '''        var subscription: AnyCancellable?
        var contextSizeSubscription: AnyCancellable?
        var contextCompactSizeSubscription: AnyCancellable?
        var contextCompactHeightSubscription: AnyCancellable?
        init() {
''',
    '''        var subscription: AnyCancellable?
        var contextSizeSubscription: AnyCancellable?
        var contextCompactSizeSubscription: AnyCancellable?
        var contextCompactHeightSubscription: AnyCancellable?
        var refreshDropCIRegistration: (() -> Void)?
        init() {
''',
    "host Drop CI refresh hook",
)

replace_once(
    window,
    '''                if !dropEnabled {
                    self.hosts.values.forEach { host in
                        if host.state.dropTargeted {
                            host.state.endFileDrop(collapseAfterDelay: true)
                        }
                    }
                }
''',
    '''                self.hosts.values.forEach { host in
                    host.refreshDropCIRegistration?()
                    if !dropEnabled && host.state.dropTargeted {
                        host.state.endFileDrop(collapseAfterDelay: true)
                    }
                }
''',
    "runtime Drop CI toggle refresh",
)

replace_once(
    window,
    '''                view.dropEnabled = {
                    let defaults = UserDefaults.standard
                    return defaults.object(forKey: "HaloContextDropEnabled") == nil
                        ? true : defaults.bool(forKey: "HaloContextDropEnabled")
                }
                view.dragStateHandler = { [weak host] active, count in
''',
    '''                view.dropEnabled = {
                    let defaults = UserDefaults.standard
                    return defaults.object(forKey: "HaloContextDropEnabled") == nil
                        ? true : defaults.bool(forKey: "HaloContextDropEnabled")
                }
                host.refreshDropCIRegistration = { [weak view] in
                    view?.refreshDropRegistration()
                }
                view.dragStateHandler = { [weak host] active, count in
''',
    "wire Drop CI registration refresh",
)

replace_once(
    surface,
    '''        .onChange(of: state.dropTargeted) { active in
            if active {
                state.collapseTask?.cancel()
                state.expanded = true
            }
        }
''',
    '''        .onChange(of: state.dropTargeted) { active in
            if active && dropCIEnabled {
                state.collapseTask?.cancel()
                state.expanded = true
            }
        }
''',
    "gate Drop CI expansion",
)

replace_once(
    surface,
    '''    @ViewBuilder private var surfaceOverlayLayer: some View {
        contour.stroke(state.dropTargeted ? accent : .white.opacity(0.12), lineWidth: state.dropTargeted ? 1.6 : 1)
        if state.expanded && activeContext == nil && usesVisualWorkspace {
''',
    '''    @ViewBuilder private var surfaceOverlayLayer: some View {
        let dropOverlayActive = dropCIEnabled && state.dropTargeted
        contour.stroke(dropOverlayActive ? accent : .white.opacity(0.12), lineWidth: dropOverlayActive ? 1.6 : 1)
        if state.expanded && activeContext == nil && usesVisualWorkspace {
''',
    "gate Drop CI surface overlay",
)

replace_once(
    surface,
    '''            if options.showFooter && store.files.count > options.maxItems {
                WidgetElement(key: "footer") { Text("+\\(store.files.count - options.maxItems) more items") }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
''',
    '''            if options.showFooter && store.files.count > options.maxItems {
                WidgetElement(key: "footer") { Text("+\\(store.files.count - options.maxItems) more items") }
            }
        }
        .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\\.isFileURL)
            guard !files.isEmpty else { return false }
            store.addFiles(files)
            return true
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
''',
    "classic File Shelf local drop target",
)

replace_once(
    adaptive,
    '''        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: context.footprint)
    }

    private var microShelf: some View {
''',
    '''        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\\.isFileURL)
            guard !files.isEmpty else { return false }
            store.addFiles(files)
            return true
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: context.footprint)
    }

    private var microShelf: some View {
''',
    "adaptive File Shelf local drop target",
)

print("Separated Drop CI overlay handling from File Shelf local drops")
