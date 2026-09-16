from pathlib import Path

integrations_path = Path("Halo/Services/Integrations.swift")
workspace_path = Path("Halo/Core/WorkspaceStore.swift")

integrations = integrations_path.read_text()
workspace = workspace_path.read_text()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f"{label}: already applied")
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    print(f"{label}: patched")
    return text.replace(old, new, 1)


# In Automatic mode, a paused/stopped Music or Spotify instance must not retain
# ownership of Halo's media surface. Otherwise System Audio (including Safari)
# cannot claim the surface even when browser audio is actually playing.
integrations = replace_once(
    integrations,
    '''                let snapshots = results.compactMap(\\.snapshot)\n                if let selected = PlayerSelection.choose(snapshots, current: self.connectedApp, preferred: app) {\n                    self.accept(selected)\n                } else if self.connectedApp != nil || self.isPlaying { self.disconnect() }\n''',
    '''                let snapshots = results.compactMap(\\.snapshot)\n                let selectableSnapshots = automatic ? snapshots.filter(\\.playing) : snapshots\n                if let selected = PlayerSelection.choose(selectableSnapshots, current: self.connectedApp, preferred: app) {\n                    self.accept(selected)\n                } else if self.connectedApp != nil || self.isPlaying { self.disconnect() }\n''',
    "release stopped rich media providers in automatic mode",
)

workspace = replace_once(
    workspace,
    '''import AppKit\nimport Combine\nimport UserNotifications\nimport Darwin\n''',
    '''import AppKit\nimport Combine\nimport UserNotifications\nimport CoreAudio\nimport Darwin\n''',
    "import CoreAudio",
)

workspace = replace_once(
    workspace,
    '''private struct MediaRemoteNowPlayingSnapshot {\n''',
    '''@available(macOS 14.2, *)\nprivate enum SafariAudioProcessDetector {\n    private static let safariBundleID = "com.apple.Safari"\n    private static let safariWebContentBundleID = "com.apple.WebKit.WebContent"\n\n    static func isProducingOutput() -> Bool {\n        guard !NSRunningApplication.runningApplications(withBundleIdentifier: safariBundleID).isEmpty else { return false }\n\n        var listAddress = AudioObjectPropertyAddress(\n            mSelector: kAudioHardwarePropertyProcessObjectList,\n            mScope: kAudioObjectPropertyScopeGlobal,\n            mElement: kAudioObjectPropertyElementMain\n        )\n        let system = AudioObjectID(kAudioObjectSystemObject)\n        var byteCount: UInt32 = 0\n        guard AudioObjectGetPropertyDataSize(system, &listAddress, 0, nil, &byteCount) == noErr, byteCount > 0 else { return false }\n\n        var processObjects = [AudioObjectID](\n            repeating: kAudioObjectUnknown,\n            count: Int(byteCount) / MemoryLayout<AudioObjectID>.size\n        )\n        guard !processObjects.isEmpty,\n              AudioObjectGetPropertyData(system, &listAddress, 0, nil, &byteCount, &processObjects) == noErr else { return false }\n\n        for object in processObjects {\n            guard readUInt32(object, selector: kAudioProcessPropertyIsRunningOutput) != 0 else { continue }\n            let bundleID = readString(object, selector: kAudioProcessPropertyBundleID) ?? ""\n            let pid = readPID(object)\n            if belongsToSafari(pid: pid, bundleID: bundleID) { return true }\n        }\n        return false\n    }\n\n    private static func readUInt32(_ object: AudioObjectID, selector: AudioObjectPropertySelector) -> UInt32 {\n        var address = AudioObjectPropertyAddress(\n            mSelector: selector,\n            mScope: kAudioObjectPropertyScopeGlobal,\n            mElement: kAudioObjectPropertyElementMain\n        )\n        var value: UInt32 = 0\n        var size = UInt32(MemoryLayout<UInt32>.size)\n        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return 0 }\n        return value\n    }\n\n    private static func readPID(_ object: AudioObjectID) -> pid_t {\n        var address = AudioObjectPropertyAddress(\n            mSelector: kAudioProcessPropertyPID,\n            mScope: kAudioObjectPropertyScopeGlobal,\n            mElement: kAudioObjectPropertyElementMain\n        )\n        var value: pid_t = 0\n        var size = UInt32(MemoryLayout<pid_t>.size)\n        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return 0 }\n        return value\n    }\n\n    private static func readString(_ object: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {\n        var address = AudioObjectPropertyAddress(\n            mSelector: selector,\n            mScope: kAudioObjectPropertyScopeGlobal,\n            mElement: kAudioObjectPropertyElementMain\n        )\n        var value: CFString = "" as CFString\n        var size = UInt32(MemoryLayout<CFString>.size)\n        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }\n        let string = value as String\n        return string.isEmpty ? nil : string\n    }\n\n    private static func belongsToSafari(pid: pid_t, bundleID: String) -> Bool {\n        if bundleID == safariBundleID { return true }\n        guard bundleID == safariWebContentBundleID || bundleID.hasPrefix("com.apple.WebKit.") else { return false }\n\n        // Safari hands actual web media output to WebKit helper processes. Walk the normal\n        // parent chain first so we can attribute a helper to Safari without guessing.\n        var current = pid\n        var visited = Set<pid_t>()\n        for _ in 0..<8 {\n            guard current > 0, visited.insert(current).inserted else { break }\n            if NSRunningApplication(processIdentifier: current)?.bundleIdentifier == safariBundleID { return true }\n            guard let parent = parentPID(of: current), parent > 0, parent != current else { break }\n            current = parent\n        }\n\n        // WebKit helpers can be re-parented through launchd/XPC. If Safari itself is running,\n        // an active Apple WebKit WebContent output process is still a strong Safari signal.\n        return !NSRunningApplication.runningApplications(withBundleIdentifier: safariBundleID).isEmpty\n    }\n\n    private static func parentPID(of pid: pid_t) -> pid_t? {\n        var info = proc_bsdinfo()\n        let expected = Int32(MemoryLayout<proc_bsdinfo>.stride)\n        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, expected) == expected else { return nil }\n        return pid_t(info.pbi_ppid)\n    }\n}\n\nprivate struct MediaRemoteNowPlayingSnapshot {\n''',
    "add CoreAudio Safari output detector",
)

workspace = replace_once(
    workspace,
    '''    private var lastHeard = Date.distantPast\n    private var lastRemoteMetadata = Date.distantPast\n    private var remoteRequestInFlight = false\n''',
    '''    private var lastHeard = Date.distantPast\n    private var lastSafariOutput = Date.distantPast\n    private var lastRemoteMetadata = Date.distantPast\n    private var remoteRequestInFlight = false\n''',
    "track Safari output activity",
)

workspace = replace_once(
    workspace,
    '''    func refresh() {\n        guard enabled, let media else { return }\n\n        // Rich Apple Music / Spotify metadata wins in Automatic mode. MediaRemote is used only\n        // when Halo is on the System Audio path (or when no rich provider is actively playing).\n        if media.connectedApp != nil && media.isPlaying {\n            ownsFallback = false\n            return\n        }\n\n        requestMediaRemoteMetadata()\n\n        let audioSnapshot = AudioSpectrumService.shared.snapshot()\n        let audibleNow = audioSnapshot.available && audioSnapshot.overall > 0.045\n        if audibleNow { lastHeard = Date() }\n        let withinReleaseWindow = Date().timeIntervalSince(lastHeard) < 2.75\n        let remoteMetadataFresh = Date().timeIntervalSince(lastRemoteMetadata) < 5.0\n        let systemAudioPlaying = audibleNow || (ownsFallback && withinReleaseWindow)\n\n        if systemAudioPlaying {\n            if media.connectedApp == nil {\n                if !remoteMetadataFresh {\n                    media.title = "System Audio"\n                    media.artist = "Playing from your Mac"\n                }\n                media.isPlaying = true\n                media.error = nil\n                ownsFallback = true\n            }\n            return\n        }\n''',
    '''    func refresh() {\n        guard enabled, let media else { return }\n\n        // A genuinely playing rich provider still wins. Paused/stopped Apple Music or Spotify\n        // must not block Safari/system audio from claiming the surface.\n        if media.connectedApp != nil && media.isPlaying {\n            ownsFallback = false\n            return\n        }\n\n        let now = Date()\n        let safariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty\n        let safariOutputActive: Bool\n        if #available(macOS 14.2, *) {\n            safariOutputActive = SafariAudioProcessDetector.isProducingOutput()\n        } else {\n            safariOutputActive = false\n        }\n        if safariOutputActive { lastSafariOutput = now }\n\n        let audioSnapshot = AudioSpectrumService.shared.snapshot()\n        let pcmAudible = isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutputActive)\n        let audibleNow = safariOutputActive || pcmAudible\n        if audibleNow { lastHeard = now }\n\n        // If a stale paused rich provider is still attached, release it as soon as real system\n        // output is observed. This is the main failure mode when Safari plays while Music/Spotify\n        // happens to be open in the background.\n        if audibleNow, media.connectedApp != nil, !media.isPlaying { media.disconnect() }\n\n        requestMediaRemoteMetadata()\n\n        let safariRecentlyActive = now.timeIntervalSince(lastSafariOutput) < 2.0\n        let releaseWindow = (safariRunning || safariRecentlyActive) ? 4.0 : 2.75\n        let withinReleaseWindow = now.timeIntervalSince(lastHeard) < releaseWindow\n        let remoteMetadataFresh = now.timeIntervalSince(lastRemoteMetadata) < 5.0\n        let systemAudioPlaying = audibleNow || (ownsFallback && withinReleaseWindow)\n\n        if systemAudioPlaying {\n            if media.connectedApp == nil {\n                if !remoteMetadataFresh {\n                    if safariOutputActive || safariRecentlyActive {\n                        media.title = "Safari Audio"\n                        media.artist = "Playing from Safari"\n                    } else {\n                        media.title = "System Audio"\n                        media.artist = "Playing from your Mac"\n                    }\n                }\n                media.isPlaying = true\n                media.error = nil\n                ownsFallback = true\n            }\n            return\n        }\n''',
    "make system audio fallback Safari-aware",
)

workspace = replace_once(
    workspace,
    '''                let audibleNow = AudioSpectrumService.shared.snapshot().available && AudioSpectrumService.shared.snapshot().overall > 0.045\n                media.isPlaying = snapshot.playing || audibleNow\n''',
    '''                let audioSnapshot = AudioSpectrumService.shared.snapshot()\n                let safariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty\n                let audibleNow = self.isPCMAudible(audioSnapshot, safariHint: safariRunning)\n                media.isPlaying = snapshot.playing || audibleNow\n''',
    "use Safari-aware PCM threshold for MediaRemote",
)

workspace = replace_once(
    workspace,
    '''    private func clearIfOwned() {\n''',
    '''    private func isPCMAudible(_ snapshot: AudioSpectrumSnapshot, safariHint: Bool) -> Bool {\n        guard snapshot.available else { return false }\n        // Browser video, speech, and WebAudio can sit far below music-mastering levels. Mids are\n        // especially useful for quiet speech, so blend the bands instead of relying on RMS alone.\n        let signal = max(snapshot.overall, snapshot.mids * 0.82, snapshot.bass * 0.62, snapshot.treble * 0.68)\n        return signal > (safariHint ? 0.016 : 0.040)\n    }\n\n    private func clearIfOwned() {\n''',
    "add Safari-aware PCM audibility helper",
)

integrations_path.write_text(integrations)
workspace_path.write_text(workspace)
print("Safari audio detection reliability patch applied.")
