from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: anchor {label!r} count={count}, expected 1")
    p.write_text(text.replace(old, new, 1))


# 1) Expose the already-running MediaRemote adapter as a module-local transport bridge.
p = "Halo/Core/WorkspaceStore.swift"
replace_once(
    p,
    '''    private func snapshot(from info: TrackInfo?) -> MediaRemoteNowPlayingSnapshot? {\n''',
    '''    @discardableResult\n    fileprivate func performTransportCommand(_ command: String) -> Bool {\n        switch command {\n        case "playpause":\n            controller.togglePlayPause()\n            if let current = cached {\n                let nextPlaying = !current.playing\n                cached = MediaRemoteNowPlayingSnapshot(\n                    title: current.title, artist: current.artist, album: current.album,\n                    playing: nextPlaying, duration: current.duration,\n                    elapsed: current.currentElapsed ?? current.elapsed,\n                    artworkData: current.artworkData, artworkURL: current.artworkURL,\n                    bundleIdentifier: current.bundleIdentifier, applicationName: current.applicationName,\n                    playbackRate: nextPlaying ? max(1, current.playbackRate) : 0, sampledAt: Date()\n                )\n                cachedAt = Date()\n            }\n        case "next track":\n            controller.nextTrack()\n        case "previous track":\n            controller.previousTrack()\n        default:\n            return false\n        }\n        return true\n    }\n\n    @discardableResult\n    fileprivate func seekTransport(to seconds: Double) -> Bool {\n        guard seconds.isFinite, seconds >= 0 else { return false }\n        let target: Double\n        if let duration = cached?.duration, duration > 0 { target = min(duration, seconds) }\n        else { target = seconds }\n        controller.setTime(seconds: target)\n        if let current = cached {\n            cached = MediaRemoteNowPlayingSnapshot(\n                title: current.title, artist: current.artist, album: current.album,\n                playing: current.playing, duration: current.duration, elapsed: target,\n                artworkData: current.artworkData, artworkURL: current.artworkURL,\n                bundleIdentifier: current.bundleIdentifier, applicationName: current.applicationName,\n                playbackRate: current.playbackRate, sampledAt: Date()\n            )\n            cachedAt = Date()\n        }\n        return true\n    }\n\n    private func snapshot(from info: TrackInfo?) -> MediaRemoteNowPlayingSnapshot? {\n''',
    "MediaRemote transport methods",
)

replace_once(
    p,
    '''}\n\n@MainActor\nprivate final class SystemAudioMediaFallback {\n''',
    '''}\n\n/// Shared command path for browser/system Now Playing sessions. Metadata and commands deliberately\n/// use the same MediaController so Safari/WebKit controls target the session shown by Control Center.\n@MainActor\nenum SystemMediaTransport {\n    @discardableResult\n    static func perform(_ command: String) -> Bool {\n        MediaRemoteNowPlayingReader.shared.performTransportCommand(command)\n    }\n\n    @discardableResult\n    static func seek(to seconds: Double) -> Bool {\n        MediaRemoteNowPlayingReader.shared.seekTransport(to: seconds)\n    }\n}\n\n@MainActor\nprivate final class SystemAudioMediaFallback {\n''',
    "SystemMediaTransport bridge",
)


# 2) Teach MediaService to select MediaRemote when connectedApp is nil, and let seek work
# whenever the Audio CI asks for it (not only when the legacy opened-detail flag happens to be on).
p = "Halo/Services/Integrations.swift"
replace_once(
    p,
    '''    func perform(_ command: String, app preferred: String) {\n''',
    '''    func performSystem(_ command: String) {\n        guard connectedApp == nil,\n              ["playpause", "next track", "previous track"].contains(command),\n              !busy else { return }\n        guard SystemMediaTransport.perform(command) else { return }\n        if error != nil { error = nil }\n    }\n\n    func perform(_ command: String, app preferred: String) {\n''',
    "system transport entrypoint",
)

replace_once(
    p,
    '''    func seek(to seconds: Double) {\n        guard openedDetailEnabled, let app = connectedApp, duration > 0 else { return }\n        let target = min(duration, max(0, seconds))\n        queue.async { [weak self] in\n            let source = """\n            if application id "\\(app)" is running then\n                tell application id "\\(app)" to set player position to \\(target)\n            end if\n            """\n            var failure: NSDictionary?\n            _ = NSAppleScript(source: source)?.executeAndReturnError(&failure)\n            Task { @MainActor in if failure == nil { self?.position = target } }\n        }\n    }\n''',
    '''    func seek(to seconds: Double) {\n        guard duration > 0, seconds.isFinite else { return }\n        let target = min(duration, max(0, seconds))\n\n        // System/Safari media has no AppleScript-connected app. Send the seek to the same\n        // MediaRemote session that supplied the Audio CI metadata. Optimistically anchor the\n        // local position so the 500 ms playback loop cannot snap the scrubber straight back.\n        if connectedApp == nil {\n            guard SystemMediaTransport.seek(to: target) else { return }\n            position = target\n            if error != nil { error = nil }\n            return\n        }\n\n        guard let app = connectedApp else { return }\n        position = target\n        queue.async { [weak self] in\n            let source = """\n            if application id "\\(app)" is running then\n                tell application id "\\(app)" to set player position to \\(target)\n            end if\n            """\n            var failure: NSDictionary?\n            _ = NSAppleScript(source: source)?.executeAndReturnError(&failure)\n            Task { @MainActor in\n                guard let self else { return }\n                if failure == nil { self.position = target }\n                else { self.error = failure?[NSAppleScript.errorMessage] as? String ?? "Unable to seek the current player." }\n            }\n        }\n    }\n''',
    "unified seek path",
)


# 3) Stop discarding system-media button clicks in Audio CI, and route scrubbing through MediaService.
p = "Halo/Views/SurfaceView.swift"
replace_once(
    p,
    '''                        Task {\n                            let result = await ContextMusicArtworkReader.seek(app: media.connectedApp, position: target)\n                            guard !Task.isCancelled, let result else { return }\n                            playbackPosition = result.position; playbackDuration = result.duration\n                        }\n''',
    '''                        media.seek(to: target)\n''',
    "Audio CI scrub dispatch",
)

replace_once(
    p,
    '''    private func control(_ symbol: String, action: String, label: String) -> some View {\n        Button { if let app = media.connectedApp { media.perform(action, app: app) } } label: { Image(systemName: symbol) }\n            .buttonStyle(.plain).accessibilityLabel(label)\n    }\n''',
    '''    private func control(_ symbol: String, action: String, label: String) -> some View {\n        Button {\n            if let app = media.connectedApp { media.perform(action, app: app) }\n            else { media.performSystem(action) }\n        } label: { Image(systemName: symbol) }\n            .buttonStyle(.plain).accessibilityLabel(label)\n    }\n''',
    "Audio CI transport dispatch",
)

print("Audio CI MediaRemote transport patch applied")
