from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"{label}: expected source contract not found")
    return text.replace(old, new, 1)

# 1) Give views a presentation-level state that survives short external/Safari
# playback detector dips while meaningful Now Playing metadata is still owned.
path = Path("Halo/Services/Integrations.swift")
text = path.read_text()
old = '''    @Published private(set) var connectedApp: String?\n    private var detecting = false\n'''
new = '''    @Published private(set) var connectedApp: String?\n\n    /// UI presentation lifetime is deliberately a little less brittle than raw playback state.\n    /// System/Safari playback can momentarily report `isPlaying == false` while MediaRemote still\n    /// owns a meaningful Now Playing session. Keeping that session present prevents Context Music\n    /// and the closed-notch visualizer from disappearing and forcing a surface resize. Native\n    /// Music/Spotify pauses remain immediate because they have a connected app.\n    var hasNowPlayingPresentation: Bool {\n        if isPlaying { return true }\n        guard connectedApp == nil else { return false }\n        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()\n        let normalizedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()\n        guard !normalizedTitle.isEmpty,\n              normalizedTitle != "connect a player",\n              normalizedTitle != "nothing playing" else { return false }\n        if normalizedTitle == "system audio" && normalizedArtist.contains("waiting for audio") { return false }\n        return true\n    }\n\n    private var detecting = false\n'''
text = replace_once(text, old, new, "MediaService presentation state")
path.write_text(text)

# 2) Keep the Music CI candidate alive for the same presentation lifetime, so a transient
# raw false does not destroy ContextMusicView and clear contextPreferredSize.
path = Path("Halo/Views/SurfaceView.swift")
text = path.read_text()
old = '''        if contextOptions.enabled && workspace.media.isPlaying { candidates.append((.music, contextMusicPriority, 2)) }\n'''
new = '''        if contextOptions.enabled && workspace.media.hasNowPlayingPresentation { candidates.append((.music, contextMusicPriority, 2)) }\n'''
text = replace_once(text, old, new, "Music CI candidate")

old = '''            PlaybackVisualizer(kind: options.resolvedVisualizerStyle, playing: media.isPlaying, enabled: true,\n'''
new = '''            PlaybackVisualizer(kind: options.resolvedVisualizerStyle, playing: media.hasNowPlayingPresentation, enabled: true,\n'''
text = replace_once(text, old, new, "Context music visualizer presentation")
path.write_text(text)

# 3) Closed notch: do not give away the media slot or remove its visualizer on the same
# transient false. Also undo the previous oversized exact-width experiment; that could move
# centered visualizer styles away from the camera edge instead of fixing the lifecycle bug.
path = Path("Halo/Views/ClosedNotchView.swift")
text = path.read_text()
text = text.replace('''        let rightAvailable = right == .none || ((right == .media || right == .visualizer) && !workspace.media.isPlaying)\n        let leftAvailable = left == .none || ((left == .media || left == .visualizer) && !workspace.media.isPlaying)\n''', '''        let rightAvailable = right == .none || ((right == .media || right == .visualizer) && !workspace.media.hasNowPlayingPresentation)\n        let leftAvailable = left == .none || ((left == .media || left == .visualizer) && !workspace.media.hasNowPlayingPresentation)\n''', 1)
text = text.replace('''        if isMusicItem { return media.isPlaying }\n''', '''        if isMusicItem { return media.hasNowPlayingPresentation }\n''', 1)
text = text.replace('''        guard media.isPlaying, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return nil }\n''', '''        guard media.hasNowPlayingPresentation, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return nil }\n''', 1)
text = text.replace('''            let rightFree = options.right == .none || ((options.right == .media || options.right == .visualizer) && !media.isPlaying)\n            let leftFree = options.left == .none || ((options.left == .media || options.left == .visualizer) && !media.isPlaying)\n''', '''            let rightFree = options.right == .none || ((options.right == .media || options.right == .visualizer) && !media.hasNowPlayingPresentation)\n            let leftFree = options.left == .none || ((options.left == .media || options.left == .visualizer) && !media.hasNowPlayingPresentation)\n''', 1)

old_visualizer_options = '''    private var visualizerOptions: VisualizerOptions {\n        var v = options.visualizer ?? VisualizerOptions()\n        v.width = Double.greatestFiniteMagnitude\n        v.height = min(v.height, innerHeight)\n        return v\n    }\n    private var visualizerContentWidth: Double {\n        max(1, innerWidth - mediaSiblingFootprint)\n    }\n'''
new_visualizer_options = '''    private var visualizerOptions: VisualizerOptions {\n        var v = options.visualizer ?? VisualizerOptions()\n        v.height = min(v.height, innerHeight)\n        return v\n    }\n'''
text = replace_once(text, old_visualizer_options, new_visualizer_options, "Closed visualizer sizing rollback")

old_media_case = '''        case .media:\n            if media.isPlaying {\n                ClosedMediaView(media: media, options: closedMediaOptions, fontSize: textSize, availableWidth: closedMediaWidth, lowPower: system.lowPower)\n                    .frame(width: closedMediaWidth)\n                    .layoutPriority(1)\n            }\n        case .visualizer:\n            if media.isPlaying {\n                PlaybackVisualizer(\n                    kind: options.animation,\n                    playing: true,\n                    enabled: options.animate && !system.lowPower,\n                    options: visualizerOptions,\n                    palette: media.artworkColors,\n                    fallback: effectiveTextColor\n                )\n                .frame(width: visualizerContentWidth, height: innerHeight)\n                .layoutPriority(3)\n            }\n'''
new_media_case = '''        case .media:\n            if media.hasNowPlayingPresentation {\n                ClosedMediaView(media: media, options: closedMediaOptions, fontSize: textSize, availableWidth: closedMediaWidth, lowPower: system.lowPower)\n                    .frame(width: closedMediaWidth)\n                    .layoutPriority(1)\n            }\n        case .visualizer:\n            if media.hasNowPlayingPresentation {\n                PlaybackVisualizer(\n                    kind: options.animation,\n                    playing: true,\n                    enabled: options.animate && !system.lowPower,\n                    options: visualizerOptions,\n                    palette: media.artworkColors,\n                    fallback: effectiveTextColor\n                )\n            }\n'''
text = replace_once(text, old_media_case, new_media_case, "Closed media/visualizer lifetime")

required = [
    'workspace.media.hasNowPlayingPresentation',
    'if isMusicItem { return media.hasNowPlayingPresentation }',
    'if media.hasNowPlayingPresentation {',
]
missing = [marker for marker in required if marker not in text]
if missing:
    raise SystemExit(f"Closed notch presentation markers missing: {missing}")
if 'visualizerContentWidth' in text or 'v.width = Double.greatestFiniteMagnitude' in text:
    raise SystemExit("Old oversized visualizer allocation still present")
path.write_text(text)

print("Stabilized Music CI/closed visualizer presentation lifetime and removed oversized visualizer allocation")
