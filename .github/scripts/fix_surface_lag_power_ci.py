from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing block: {label}")
    return text.replace(old, new, 1)

# Window manager: stop reconciling the entire notch engine for unrelated defaults,
# keep power-event sizing independent from generic active width, and remove redundant
# CI safety space now that CI reports its real safe margins.
wm_path = Path("Halo/NotchEngine/WindowManager.swift")
wm = wm_path.read_text()

wm = replace_once(
    wm,
    '''    private var hosts: [String: Host] = [:]\n    private var subscriptions = Set<AnyCancellable>()\n''',
    '''    private var hosts: [String: Host] = [:]\n    private var subscriptions = Set<AnyCancellable>()\n    private var lastContextOffset = CGSize(\n        width: UserDefaults.standard.double(forKey: "HaloContextOffsetX"),\n        height: UserDefaults.standard.double(forKey: "HaloContextOffsetY")\n    )\n''',
    "context offset cache"
)

wm = replace_once(
    wm,
    '''        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)\n            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)\n            .sink { [weak self] _ in self?.reconcile() }\n            .store(in: &subscriptions)''',
    '''        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)\n            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)\n            .sink { [weak self] _ in\n                guard let self else { return }\n                let defaults = UserDefaults.standard\n                let next = CGSize(width: defaults.double(forKey: "HaloContextOffsetX"),\n                                  height: defaults.double(forKey: "HaloContextOffsetY"))\n                guard abs(next.width - self.lastContextOffset.width) >= 0.5 ||\n                      abs(next.height - self.lastContextOffset.height) >= 0.5 else { return }\n                self.lastContextOffset = next\n                self.reconcile()\n            }\n            .store(in: &subscriptions)''',
    "filtered user defaults reconcile"
)

wm = replace_once(
    wm,
    '''        var leftLive = sideHasLiveReason(item: items.left, decoration: options.leftDecoration)\n        var rightLive = sideHasLiveReason(item: items.right, decoration: options.rightDecoration)\n        if power?.side == .left { leftLive = true }\n        if power?.side == .right { rightLive = true }\n\n        let mediaSettings = options.mediaOptions ?? ClosedMediaOptions()''',
    '''        var leftLive = sideHasLiveReason(item: items.left, decoration: options.leftDecoration)\n        var rightLive = sideHasLiveReason(item: items.right, decoration: options.rightDecoration)\n\n        let mediaSettings = options.mediaOptions ?? ClosedMediaOptions()''',
    "do not mark power as generic expansion before media rules"
)

wm = replace_once(
    wm,
    '''        if adaptiveLyrics || constrainedMedia {\n            if items.left == .media {\n                leftLive = options.leftDecoration?.visibility == .playing && store.workspace.media.isPlaying\n            }\n            if items.right == .media {\n                rightLive = options.rightDecoration?.visibility == .playing && store.workspace.media.isPlaying\n            }\n        }\n\n        let attached = geometry.attachedToNotch''',
    '''        if adaptiveLyrics || constrainedMedia {\n            if items.left == .media {\n                leftLive = options.leftDecoration?.visibility == .playing && store.workspace.media.isPlaying\n            }\n            if items.right == .media {\n                rightLive = options.rightDecoration?.visibility == .playing && store.workspace.media.isPlaying\n            }\n        }\n        // Generic active-width expansion belongs to normal live content. Power events have\n        // their own explicit eventWidth and must not inherit the generic Active width as well.\n        let leftExpansionLive = leftLive\n        let rightExpansionLive = rightLive\n        if power?.side == .left { leftLive = true }\n        if power?.side == .right { rightLive = true }\n\n        let attached = geometry.attachedToNotch''',
    "separate power and generic expansion eligibility"
)

wm = replace_once(
    wm,
    '''                expansion: expansion.enabled ? expansion.width : 0,\n                leftLive: leftLive, rightLive: rightLive)''',
    '''                expansion: expansion.enabled ? expansion.width : 0,\n                leftLive: leftExpansionLive, rightLive: rightExpansionLive)''',
    "notch generic expansion eligibility"
)

wm = replace_once(
    wm,
    '''        } else {\n            var requested = baseWidth\n            if autoFit { requested = max(requested, sides.left + sides.right) }\n            if expansion.enabled && (leftLive || rightLive) { requested = max(requested, expansion.width) }\n            host.geometry?.activeCompactWidth = min(geometry.visible.width, requested)''',
    '''        } else {\n            var requested = baseWidth\n            if autoFit || power != nil { requested = max(requested, sides.left + sides.right) }\n            if expansion.enabled && (leftExpansionLive || rightExpansionLive) { requested = max(requested, expansion.width) }\n            host.geometry?.activeCompactWidth = min(geometry.visible.width, requested)''',
    "non-notch power width independence"
)

wm = replace_once(
    wm,
    '''        let contextHorizontalSafety: CGFloat = 56\n        let contextVerticalSafety: CGFloat = 64\n        let margin: CGFloat = 12\n        let minimumHeight = geometry.compactHeight + 112\n        let maxWidth = max(360, geometry.visible.width - margin * 2)\n        let width = min(maxWidth, max(360, requested.width + contextHorizontalSafety))\n        var height = max(minimumHeight, requested.height + contextVerticalSafety)''',
    '''        // Context views now report their complete content-safe size, including their\n        // own horizontal/top/bottom margins. Adding a second safety shell here produced\n        // visible dead space, especially below Music/Audio CI.\n        let margin: CGFloat = 12\n        let minimumHeight: CGFloat = 96\n        let maxWidth = max(360, geometry.visible.width - margin * 2)\n        let width = min(maxWidth, max(360, requested.width))\n        var height = max(minimumHeight, requested.height)''',
    "remove redundant context safety shell"
)

wm_path.write_text(wm)

# Audio CI: render artwork at the same size used by preferredSurfaceSize. The old
# proxy-relative caps made sizing reserve a larger artwork than it actually drew,
# leaving an empty band below the interface.
surface_path = Path("Halo/Views/SurfaceView.swift")
surface = surface_path.read_text()

surface = replace_once(
    surface,
    '''            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: min(options.artworkSize, max(48, proxy.size.height * 0.34))) }''',
    '''            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: options.artworkSize) }''',
    "hero artwork sizing"
)
surface = replace_once(
    surface,
    '''            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: min(options.artworkSize, max(52, proxy.size.height * 0.50))) }''',
    '''            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: options.artworkSize) }''',
    "split artwork sizing"
)
surface = replace_once(
    surface,
    '''            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: min(options.artworkSize, max(42, proxy.size.height * 0.24))) }''',
    '''            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: options.artworkSize) }''',
    "compact artwork sizing"
)
surface = replace_once(
    surface,
    '''            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: min(options.artworkSize, max(36, proxy.size.height * 0.20))) }''',
    '''            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: options.artworkSize) }''',
    "minimal artwork sizing"
)

surface_path.write_text(surface)

print("Fixed passive Surface lag, power-event expansion margins, and Audio CI dead space")
