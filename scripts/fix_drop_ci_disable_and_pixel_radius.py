from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


# --- Drop CI: make the AppKit drop destination itself respect the toggle. ---
window_path = Path("Halo/NotchEngine/WindowManager.swift")
window = window_path.read_text()

window = replace_once(
    window,
    '''final class HaloDropHostingView<Content: View>: NSHostingView<Content> {\n    var dragStateHandler: ((Bool, Int) -> Void)?\n    var dropHandler: (([URL]) -> Void)?\n\n    required init(rootView: Content) {''',
    '''final class HaloDropHostingView<Content: View>: NSHostingView<Content> {\n    var dragStateHandler: ((Bool, Int) -> Void)?\n    var dropHandler: (([URL]) -> Void)?\n    var dropEnabled: (() -> Bool)?\n\n    required init(rootView: Content) {''',
    "drop hosting properties",
)

window = replace_once(
    window,
    '''    @available(*, unavailable)\n    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }\n\n    private func fileURLCount(_ sender: NSDraggingInfo) -> Int {''',
    '''    @available(*, unavailable)\n    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }\n\n    private var acceptsFileDrop: Bool { dropEnabled?() ?? true }\n\n    private func rejectFileDrop() {\n        dragStateHandler?(false, 0)\n    }\n\n    private func fileURLCount(_ sender: NSDraggingInfo) -> Int {''',
    "drop enabled helper",
)

window = replace_once(
    window,
    '''    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {\n        let count = fileURLCount(sender)\n        guard count > 0 else { return [] }\n        dragStateHandler?(true, count)\n        return .copy\n    }\n\n    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {\n        let count = fileURLCount(sender)\n        guard count > 0 else { return [] }\n        dragStateHandler?(true, count)\n        return .copy\n    }''',
    '''    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {\n        guard acceptsFileDrop else { rejectFileDrop(); return [] }\n        let count = fileURLCount(sender)\n        guard count > 0 else { return [] }\n        dragStateHandler?(true, count)\n        return .copy\n    }\n\n    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {\n        guard acceptsFileDrop else { rejectFileDrop(); return [] }\n        let count = fileURLCount(sender)\n        guard count > 0 else { return [] }\n        dragStateHandler?(true, count)\n        return .copy\n    }''',
    "drop enter update gate",
)

window = replace_once(
    window,
    '''    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {\n        let urls = fileURLs(sender)\n        guard !urls.isEmpty else {\n            dragStateHandler?(false, 0)\n            return false\n        }\n        dropHandler?(urls)\n        return true\n    }''',
    '''    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {\n        guard acceptsFileDrop else { rejectFileDrop(); return false }\n        let urls = fileURLs(sender)\n        guard !urls.isEmpty else {\n            dragStateHandler?(false, 0)\n            return false\n        }\n        dropHandler?(urls)\n        return true\n    }''',
    "drop operation gate",
)

window = replace_once(
    window,
    '''                let view = HaloDropHostingView(rootView: root)\n                view.sizingOptions = []\n                view.dragStateHandler = { [weak host] active, count in''',
    '''                let view = HaloDropHostingView(rootView: root)\n                view.sizingOptions = []\n                view.dropEnabled = {\n                    let defaults = UserDefaults.standard\n                    return defaults.object(forKey: "HaloContextDropEnabled") == nil\n                        ? true : defaults.bool(forKey: "HaloContextDropEnabled")\n                }\n                view.dragStateHandler = { [weak host] active, count in''',
    "drop enabled closure",
)

window = replace_once(
    window,
    '''                view.dropHandler = { [weak self, weak host] urls in\n                    guard let self, let host else { return }\n                    host.state.completeFileDrop()\n                    self.store.addFiles(urls)\n                }''',
    '''                view.dropHandler = { [weak self, weak host] urls in\n                    guard let self, let host else { return }\n                    let defaults = UserDefaults.standard\n                    let ciEnabled = defaults.object(forKey: "HaloContextDropEnabled") == nil\n                        ? true : defaults.bool(forKey: "HaloContextDropEnabled")\n                    guard ciEnabled else {\n                        host.state.endFileDrop(collapseAfterDelay: true)\n                        return\n                    }\n                    host.state.completeFileDrop()\n                    self.store.addFiles(urls)\n                }''',
    "drop handler gate",
)

window = replace_once(
    window,
    '''                let defaults = UserDefaults.standard\n                let next = CGSize(width: defaults.double(forKey: "HaloContextOffsetX"),\n                                  height: defaults.double(forKey: "HaloContextOffsetY"))\n                guard abs(next.width - self.lastContextOffset.width) >= 0.5 ||''',
    '''                let defaults = UserDefaults.standard\n                let dropEnabled = defaults.object(forKey: "HaloContextDropEnabled") == nil\n                    ? true : defaults.bool(forKey: "HaloContextDropEnabled")\n                if !dropEnabled {\n                    self.hosts.values.forEach { host in\n                        if host.state.dropTargeted {\n                            host.state.endFileDrop(collapseAfterDelay: true)\n                        }\n                    }\n                }\n                let next = CGSize(width: defaults.double(forKey: "HaloContextOffsetX"),\n                                  height: defaults.double(forKey: "HaloContextOffsetY"))\n                guard abs(next.width - self.lastContextOffset.width) >= 0.5 ||''',
    "disable active drop immediately",
)

window_path.write_text(window)


# --- Pixel Pet: overlay pixels follow the configured LED radius. ---
pet_path = Path("Halo/Views/PixelPetWidget.swift")
pet = pet_path.read_text()

pet = replace_once(
    pet,
    '''                var path = Path()\n                path.addRect(rect)\n                let outer = x == 0 || x == 4 || y == 0 || y == 4\n                context.fill(path, with: .color(value == "d" ? chip : (outer ? edge : dough)))''',
    '''                let radius = min(rect.width, rect.height) * preferences.pixelCornerRadius\n                let outer = x == 0 || x == 4 || y == 0 || y == 4\n                context.fill(\n                    Path(roundedRect: rect, cornerRadius: radius),\n                    with: .color(value == "d" ? chip : (outer ? edge : dough)),\n                    style: FillStyle(antialiased: preferences.pixelCornerRadius > 0.001)\n                )''',
    "cookie badge LED radius",
)

pet = replace_once(
    pet,
    '''        let seamColor = Color.black.opacity(0.42)\n\n        func paintRect(_ rect: CGRect, _ color: Color) {\n            var path = Path()\n            path.addRect(rect)\n            context.fill(path, with: .color(color))\n        }''',
    '''        let seamColor = Color.black.opacity(0.42)\n        let ledUnit = max(1.0, min(size.width, size.height) / CGFloat(logicalGrid))\n\n        func paintRect(_ rect: CGRect, _ color: Color) {\n            let radius = min(min(rect.width, rect.height) * 0.5, ledUnit * preferences.pixelCornerRadius)\n            context.fill(\n                Path(roundedRect: rect, cornerRadius: radius),\n                with: .color(color),\n                style: FillStyle(antialiased: preferences.pixelCornerRadius > 0.001)\n            )\n        }''',
    "fury door LED radius",
)

pet = replace_once(
    pet,
    '''        func paintCookiePixel(_ rect: CGRect, _ color: Color) {\n            var path = Path()\n            path.addRect(rect)\n            context.fill(path, with: .color(color))\n        }''',
    '''        func paintCookiePixel(_ rect: CGRect, _ color: Color) {\n            let radius = min(rect.width, rect.height) * preferences.pixelCornerRadius\n            context.fill(\n                Path(roundedRect: rect, cornerRadius: radius),\n                with: .color(color),\n                style: FillStyle(antialiased: preferences.pixelCornerRadius > 0.001)\n            )\n        }''',
    "fury cookie LED radius",
)

pet_path.write_text(pet)

print("Patched Drop CI disable behavior and Pixel Pet overlay LED radius")
