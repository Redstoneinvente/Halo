from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: anchor {label!r} count={count}, expected 1")
    p.write_text(text.replace(old, new, 1))


p = "Halo/Core/WorkspaceStore.swift"

# Keep a playback-rate/time anchor with every MediaRemote snapshot. The cached snapshot can then
# report a current position instead of freezing the elapsed value for the cache lifetime.
replace_once(p,
'''private struct MediaRemoteNowPlayingSnapshot {
    let title: String
    let artist: String
    let album: String
    let playing: Bool
    let duration: Double?
    let elapsed: Double?
    let artworkData: Data?
    let artworkURL: String?
    let bundleIdentifier: String?
    let applicationName: String?
}
''',
'''private struct MediaRemoteNowPlayingSnapshot {
    let title: String
    let artist: String
    let album: String
    let playing: Bool
    let duration: Double?
    let elapsed: Double?
    let artworkData: Data?
    let artworkURL: String?
    let bundleIdentifier: String?
    let applicationName: String?
    let playbackRate: Double
    let sampledAt: Date

    var currentElapsed: Double? {
        guard let elapsed else { return nil }
        guard playing, playbackRate > 0 else { return elapsed }
        let advanced = elapsed + max(0, Date().timeIntervalSince(sampledAt)) * playbackRate
        if let duration, duration > 0 { return min(duration, advanced) }
        return advanced
    }
}
''', "timestamped MediaRemote snapshot")

# Track one-shot artwork enrichment separately from normal metadata polling.
replace_once(p,
'''    private var cachedAt = Date.distantPast
    private var oneShotInFlight = false
    private var pending: [((MediaRemoteNowPlayingSnapshot?) -> Void)] = []
''',
'''    private var cachedAt = Date.distantPast
    private var oneShotInFlight = false
    private var pending: [((MediaRemoteNowPlayingSnapshot?) -> Void)] = []
    private var artworkEnrichmentInFlight = false
    private var lastArtworkEnrichmentKey = ""
    private var lastArtworkEnrichmentAt = Date.distantPast
''', "artwork enrichment state")

# Streaming MediaRemote events sometimes arrive in stages. Preserve artwork from a previous event
# for the same track and opportunistically enrich an otherwise complete snapshot from legacy MR.
replace_once(p,
'''        controller.onTrackInfoReceived = { [weak self] info in
            guard let self else { return }
            if let snapshot = self.snapshot(from: info) {
                self.cached = snapshot
                self.cachedAt = Date()
            } else {
                self.cached = nil
                self.cachedAt = .distantPast
            }
        }
''',
'''        controller.onTrackInfoReceived = { [weak self] info in
            guard let self else { return }
            if let snapshot = self.snapshot(from: info) {
                let merged = self.mergingArtwork(into: snapshot, from: self.cached)
                self.cached = merged
                self.cachedAt = Date()
                self.enrichArtworkIfNeeded(merged)
            } else {
                self.cached = nil
                self.cachedAt = .distantPast
            }
        }
''', "merge streaming artwork")

replace_once(p,
'''        if let cached, Date().timeIntervalSince(cachedAt) < 15 {
            completion(cached)
            return
        }
''',
'''        if let cached, Date().timeIntervalSince(cachedAt) < 15 {
            enrichArtworkIfNeeded(cached)
            completion(cached)
            return
        }
''', "enrich cached snapshot")

replace_once(p,
'''            if let snapshot = self.snapshot(from: info) {
                self.cached = snapshot
                self.cachedAt = Date()
                callbacks.forEach { $0(snapshot) }
            } else {
''',
'''            if let snapshot = self.snapshot(from: info) {
                let merged = self.mergingArtwork(into: snapshot, from: self.cached)
                self.cached = merged
                self.cachedAt = Date()
                self.enrichArtworkIfNeeded(merged)
                callbacks.forEach { $0(merged) }
            } else {
''', "merge one-shot artwork")

# The adapter's currentElapsedTime is already extrapolated to the instant this snapshot is built.
# Remember that instant and the playback rate so future reads of the cached event remain live.
replace_once(p,
'''        let rawElapsed = payload.currentElapsedTime ?? payload.elapsedTimeMicros.map { $0 / 1_000_000 }
        let elapsed = rawElapsed.flatMap { value in value.isFinite && value >= 0 ? value : nil }
        let playing = payload.isPlaying ?? ((payload.playbackRate ?? 0) > 0.001)

        return MediaRemoteNowPlayingSnapshot(
            title: rawTitle,
            artist: payload.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            album: payload.album?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            playing: playing,
            duration: duration,
            elapsed: elapsed,
            artworkData: artworkData,
            artworkURL: nil,
            bundleIdentifier: payload.bundleIdentifier,
            applicationName: payload.applicationName
        )
''',
'''        let rawElapsed = payload.currentElapsedTime ?? payload.elapsedTimeMicros.map { $0 / 1_000_000 }
        let elapsed = rawElapsed.flatMap { value in value.isFinite && value >= 0 ? value : nil }
        let rawRate = payload.playbackRate
        let playing = payload.isPlaying ?? ((rawRate ?? 0) > 0.001)
        let playbackRate = rawRate.flatMap { $0.isFinite ? max(0, $0) : nil } ?? (playing ? 1.0 : 0.0)

        return MediaRemoteNowPlayingSnapshot(
            title: rawTitle,
            artist: payload.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            album: payload.album?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            playing: playing,
            duration: duration,
            elapsed: elapsed,
            artworkData: artworkData,
            artworkURL: nil,
            bundleIdentifier: payload.bundleIdentifier,
            applicationName: payload.applicationName,
            playbackRate: playbackRate,
            sampledAt: Date()
        )
''', "live cached playback anchor")

# Add same-track artwork merging and a throttled legacy-artwork enrichment pass. This deliberately
# never accepts legacy metadata for a different song, so a stale Music/Spotify session cannot paint
# Safari with the wrong cover.
replace_once(p,
'''    private func fetchLegacy(_ completion: @escaping (MediaRemoteNowPlayingSnapshot?) -> Void) {
''',
'''    private func normalizedTrackIdentity(_ snapshot: MediaRemoteNowPlayingSnapshot) -> String {
        [snapshot.title, snapshot.artist, snapshot.album]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "|")
    }

    private func sameTrack(_ lhs: MediaRemoteNowPlayingSnapshot, _ rhs: MediaRemoteNowPlayingSnapshot) -> Bool {
        normalizedTrackIdentity(lhs) == normalizedTrackIdentity(rhs)
    }

    private func mergingArtwork(into snapshot: MediaRemoteNowPlayingSnapshot,
                                from fallback: MediaRemoteNowPlayingSnapshot?) -> MediaRemoteNowPlayingSnapshot {
        guard let fallback, sameTrack(snapshot, fallback) else { return snapshot }
        return MediaRemoteNowPlayingSnapshot(
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            playing: snapshot.playing,
            duration: snapshot.duration,
            elapsed: snapshot.elapsed,
            artworkData: snapshot.artworkData ?? fallback.artworkData,
            artworkURL: snapshot.artworkURL ?? fallback.artworkURL,
            bundleIdentifier: snapshot.bundleIdentifier,
            applicationName: snapshot.applicationName,
            playbackRate: snapshot.playbackRate,
            sampledAt: snapshot.sampledAt
        )
    }

    private func enrichArtworkIfNeeded(_ snapshot: MediaRemoteNowPlayingSnapshot) {
        guard snapshot.artworkData == nil, snapshot.artworkURL == nil, legacyGetInfo != nil else { return }
        let key = normalizedTrackIdentity(snapshot)
        guard !key.isEmpty else { return }
        let now = Date()
        if artworkEnrichmentInFlight { return }
        if key == lastArtworkEnrichmentKey, now.timeIntervalSince(lastArtworkEnrichmentAt) < 4 { return }

        artworkEnrichmentInFlight = true
        lastArtworkEnrichmentKey = key
        lastArtworkEnrichmentAt = now
        fetchLegacy { [weak self] legacy in
            DispatchQueue.main.async {
                guard let self else { return }
                self.artworkEnrichmentInFlight = false
                guard let legacy, let current = self.cached, self.sameTrack(current, legacy) else { return }
                self.cached = self.mergingArtwork(into: current, from: legacy)
            }
        }
    }

    private func fetchLegacy(_ completion: @escaping (MediaRemoteNowPlayingSnapshot?) -> Void) {
''', "artwork enrichment helpers")

# Legacy MediaRemote can expose artwork URLs/data that the streaming adapter occasionally omits.
# Give legacy snapshots the same playback anchor so they also remain internally consistent.
replace_once(p,
'''            let rate = firstDouble(["kMRMediaRemoteNowPlayingInfoPlaybackRate", "playbackRate"])
            let artworkData = firstData(["kMRMediaRemoteNowPlayingInfoArtworkData", "artworkData"])
            let artworkURL = firstHTTPSURL(["kMRMediaRemoteNowPlayingInfoArtworkURL", "artworkURL",
                                            "kMRMediaRemoteNowPlayingInfoArtworkIdentifier", "artworkIdentifier"])
            completion(MediaRemoteNowPlayingSnapshot(title: title, artist: artist, album: album,
                                                     playing: (rate ?? 0) > 0.001,
                                                     duration: duration, elapsed: elapsed,
                                                     artworkData: artworkData, artworkURL: artworkURL,
                                                     bundleIdentifier: nil, applicationName: nil))
''',
'''            let rate = firstDouble(["kMRMediaRemoteNowPlayingInfoPlaybackRate", "playbackRate"])
            let playbackRate = rate.flatMap { $0.isFinite ? max(0, $0) : nil } ?? 0
            let playing = playbackRate > 0.001
            let artworkData = firstData(["kMRMediaRemoteNowPlayingInfoArtworkData", "artworkData"])
            let artworkURL = firstHTTPSURL(["kMRMediaRemoteNowPlayingInfoArtworkURL", "artworkURL",
                                            "kMRMediaRemoteNowPlayingInfoArtworkIdentifier", "artworkIdentifier"])
            completion(MediaRemoteNowPlayingSnapshot(title: title, artist: artist, album: album,
                                                     playing: playing,
                                                     duration: duration, elapsed: elapsed,
                                                     artworkData: artworkData, artworkURL: artworkURL,
                                                     bundleIdentifier: nil, applicationName: nil,
                                                     playbackRate: playbackRate, sampledAt: Date()))
''', "legacy playback anchor")

# A MediaRemote callback is asynchronous relative to the normal audio tick. Re-use the tick's
# release-window logic here instead of allowing one quiet PCM/Safari detector sample to retract CI.
replace_once(p,
'''                let pcmAudible = self.isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutput)
                let safariLikely = safariOutput || (safariRunning && pcmAudible)
                let audibleNow = safariOutput || pcmAudible

                let sourceBundle = snapshot.bundleIdentifier?.lowercased() ?? ""
''',
'''                let pcmAudible = self.isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutput)
                let safariLikely = safariOutput || (safariRunning && pcmAudible)
                let audibleNow = safariOutput || pcmAudible
                let now = Date()
                if safariOutput { self.lastSafariOutput = now }
                if audibleNow || snapshot.playing { self.lastHeard = now }
                let safariRecentlyActive = now.timeIntervalSince(self.lastSafariOutput) < 2.0
                let releaseWindow = (safariRunning || safariRecentlyActive) ? 4.0 : 2.75
                let withinReleaseWindow = now.timeIntervalSince(self.lastHeard) < releaseWindow
                let shouldPresentPlaying = snapshot.playing || audibleNow || (self.ownsFallback && withinReleaseWindow)

                let sourceBundle = snapshot.bundleIdentifier?.lowercased() ?? ""
''', "callback playback hysteresis")

replace_once(p,
'''                guard snapshot.playing || !safariLikely || snapshotIsSafari else {
                    media.isPlaying = audibleNow
                    return
                }

                self.lastRemoteMetadata = Date()
''',
'''                guard snapshot.playing || !safariLikely || snapshotIsSafari else {
                    // Do not retract Audio CI from one detector dip. The normal refresh loop owns
                    // the transition to stopped after its release window has genuinely expired.
                    if shouldPresentPlaying { media.isPlaying = true }
                    return
                }

                self.lastRemoteMetadata = now
''', "prevent callback CI retraction")

replace_once(p,
'''                                          duration: snapshot.duration,
                                          position: snapshot.elapsed,
                                          playing: snapshot.playing || audibleNow,
                                          artworkData: snapshot.artworkData,
''',
'''                                          duration: snapshot.duration,
                                          position: snapshot.currentElapsed,
                                          playing: shouldPresentPlaying,
                                          artworkData: snapshot.artworkData,
''', "use live elapsed and stable playing state")

print("Applied Safari/system-audio media state stability hotfix")
