from pathlib import Path

root = Path('.')
store_path = root / 'Halo/Core/WorkspaceStore.swift'
project_path = root / 'Halo.xcodeproj/project.pbxproj'

store = store_path.read_text()
if 'import MediaRemoteAdapter' not in store:
    store = store.replace('import Darwin\n', 'import Darwin\nimport MediaRemoteAdapter\n', 1)

start = store.index('private struct MediaRemoteNowPlayingSnapshot')
end = store.index('\n@MainActor\nprivate final class SystemAudioMediaFallback', start)
replacement = r'''private struct MediaRemoteNowPlayingSnapshot {
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

/// Reads the actual macOS Now Playing session through MediaRemoteAdapter. Since macOS 15.4,
/// direct MediaRemote calls from normal third-party processes can be denied by mediaremoted;
/// the adapter runs the private framework inside Apple's entitled /usr/bin/perl process and
/// streams the same metadata Control Center sees, including Safari/WebKit title and artwork.
@MainActor
private final class MediaRemoteNowPlayingReader {
    static let shared = MediaRemoteNowPlayingReader()

    private typealias InfoCallback = @convention(block) (CFDictionary?) -> Void
    private typealias GetInfoFunction = @convention(c) (DispatchQueue, InfoCallback) -> Void

    private let controller = MediaController()
    private var cached: MediaRemoteNowPlayingSnapshot?
    private var cachedAt = Date.distantPast
    private var oneShotInFlight = false
    private var pending: [((MediaRemoteNowPlayingSnapshot?) -> Void)] = []

    // Legacy direct reader remains only as a fallback for older systems or adapter failures.
    private let legacyHandle: UnsafeMutableRawPointer?
    private let legacyGetInfo: GetInfoFunction?

    private init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        legacyHandle = handle
        if let handle, let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            legacyGetInfo = unsafeBitCast(symbol, to: GetInfoFunction.self)
        } else {
            legacyGetInfo = nil
        }

        controller.onTrackInfoReceived = { [weak self] info in
            guard let self else { return }
            if let snapshot = self.snapshot(from: info) {
                self.cached = snapshot
                self.cachedAt = Date()
            } else {
                self.cached = nil
                self.cachedAt = .distantPast
            }
        }
        controller.onListenerTerminated = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                self?.controller.startListening()
            }
        }
        controller.startListening()
    }

    deinit {
        controller.stopListening()
        if let legacyHandle { dlclose(legacyHandle) }
    }

    func fetch(_ completion: @escaping (MediaRemoteNowPlayingSnapshot?) -> Void) {
        // The streaming adapter is the authoritative source. Reuse its latest event so Halo does
        // not spawn a helper process on every media poll.
        if let cached, Date().timeIntervalSince(cachedAt) < 15 {
            completion(cached)
            return
        }

        pending.append(completion)
        guard !oneShotInFlight else { return }
        oneShotInFlight = true
        controller.getTrackInfo { [weak self] info in
            guard let self else { return }
            self.oneShotInFlight = false
            let callbacks = self.pending
            self.pending.removeAll()

            if let snapshot = self.snapshot(from: info) {
                self.cached = snapshot
                self.cachedAt = Date()
                callbacks.forEach { $0(snapshot) }
            } else {
                self.fetchLegacy { snapshot in
                    callbacks.forEach { $0(snapshot) }
                }
            }
        }
    }

    private func snapshot(from info: TrackInfo?) -> MediaRemoteNowPlayingSnapshot? {
        guard let payload = info?.payload,
              let rawTitle = payload.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTitle.isEmpty else { return nil }

        let artworkData = payload.artworkDataBase64.flatMap(Data.init(base64Encoded:))
        let duration = payload.durationMicros.flatMap { value -> Double? in
            let seconds = value / 1_000_000
            return seconds.isFinite && seconds > 0 ? seconds : nil
        }
        let rawElapsed = payload.currentElapsedTime ?? payload.elapsedTimeMicros.map { $0 / 1_000_000 }
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
    }

    private func fetchLegacy(_ completion: @escaping (MediaRemoteNowPlayingSnapshot?) -> Void) {
        guard let legacyGetInfo else { completion(nil); return }
        let callback: InfoCallback = { dictionary in
            guard let dictionary else { completion(nil); return }
            let info = dictionary as NSDictionary

            func firstString(_ keys: [String]) -> String? {
                for key in keys {
                    if let value = info[key] as? String,
                       !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
                }
                return nil
            }
            func firstDouble(_ keys: [String]) -> Double? {
                for key in keys {
                    if let value = info[key] as? NSNumber { return value.doubleValue }
                    if let value = info[key] as? Double { return value }
                }
                return nil
            }
            func firstData(_ keys: [String]) -> Data? {
                for key in keys {
                    if let value = info[key] as? Data, !value.isEmpty { return value }
                    if let value = info[key] as? NSData, value.length > 0 { return value as Data }
                }
                return nil
            }
            func firstHTTPSURL(_ keys: [String]) -> String? {
                for key in keys {
                    let raw: String?
                    if let value = info[key] as? URL { raw = value.absoluteString }
                    else if let value = info[key] as? NSURL { raw = value.absoluteString }
                    else { raw = info[key] as? String }
                    if let raw, URL(string: raw)?.scheme == "https" { return raw }
                }
                return nil
            }

            guard let title = firstString(["kMRMediaRemoteNowPlayingInfoTitle", "title"]) else {
                completion(nil)
                return
            }
            let artist = firstString(["kMRMediaRemoteNowPlayingInfoArtist", "artist"]) ?? ""
            let album = firstString(["kMRMediaRemoteNowPlayingInfoAlbum", "album"]) ?? ""
            let duration = firstDouble(["kMRMediaRemoteNowPlayingInfoDuration", "duration"])
            let elapsed = firstDouble(["kMRMediaRemoteNowPlayingInfoElapsedTime", "elapsedTime"])
            let rate = firstDouble(["kMRMediaRemoteNowPlayingInfoPlaybackRate", "playbackRate"])
            let artworkData = firstData(["kMRMediaRemoteNowPlayingInfoArtworkData", "artworkData"])
            let artworkURL = firstHTTPSURL(["kMRMediaRemoteNowPlayingInfoArtworkURL", "artworkURL",
                                            "kMRMediaRemoteNowPlayingInfoArtworkIdentifier", "artworkIdentifier"])
            completion(MediaRemoteNowPlayingSnapshot(title: title, artist: artist, album: album,
                                                     playing: (rate ?? 0) > 0.001,
                                                     duration: duration, elapsed: elapsed,
                                                     artworkData: artworkData, artworkURL: artworkURL,
                                                     bundleIdentifier: nil, applicationName: nil))
        }
        legacyGetInfo(DispatchQueue.global(qos: .utility), callback)
    }
}
'''
store = store[:start] + replacement + store[end:]

# Prefer exact Now Playing ownership from the adapter when deciding whether Safari metadata is stale.
old_guard = '''                // A paused MediaRemote entry is often stale Music/Spotify metadata. If Safari is
                // demonstrably making sound, do not paint that stale track over Safari; Shazam gets
                // a chance to resolve the audible track instead.
                guard snapshot.playing || !safariLikely else {
                    media.isPlaying = audibleNow
                    return
                }

                self.lastRemoteMetadata = Date()
                self.ownsFallback = true
                let displayArtist = !snapshot.artist.isEmpty ? snapshot.artist : (!snapshot.album.isEmpty ? snapshot.album : "System Audio")
                let sourceKey = [snapshot.title, snapshot.artist, snapshot.album]
'''
new_guard = '''                let sourceBundle = snapshot.bundleIdentifier?.lowercased() ?? ""
                let sourceName = snapshot.applicationName?.lowercased() ?? ""
                let snapshotIsSafari = sourceBundle == "com.apple.safari" || sourceBundle.contains("webkit") || sourceName.contains("safari")

                // The adapter tells us which app actually owns Now Playing. Only reject a paused
                // non-Safari item when Safari is demonstrably making sound; this prevents stale
                // Music/Spotify metadata from covering a live browser session.
                guard snapshot.playing || !safariLikely || snapshotIsSafari else {
                    media.isPlaying = audibleNow
                    return
                }

                self.lastRemoteMetadata = Date()
                self.ownsFallback = true
                let fallbackArtist = snapshotIsSafari ? "Playing from Safari" : (snapshot.applicationName ?? "System Audio")
                let displayArtist = !snapshot.artist.isEmpty ? snapshot.artist : (!snapshot.album.isEmpty ? snapshot.album : fallbackArtist)
                let sourceKey = [snapshot.bundleIdentifier ?? "", snapshot.title, snapshot.artist, snapshot.album]
'''
if old_guard not in store:
    raise SystemExit('expected stale metadata block not found')
store = store.replace(old_guard, new_guard, 1)
store_path.write_text(store)

project = project_path.read_text()
if 'MediaRemoteAdapter in Frameworks' not in project:
    project = project.replace(
        'A11C0F1A0000000000000353 /* Sparkle in Frameworks */ = {isa = PBXBuildFile; productRef = A11C0F1A0000000000000354 /* Sparkle */; };',
        'A11C0F1A0000000000000353 /* Sparkle in Frameworks */ = {isa = PBXBuildFile; productRef = A11C0F1A0000000000000354 /* Sparkle */; };\n\t\tA11C0F1A0000000000000380 /* MediaRemoteAdapter in Frameworks */ = {isa = PBXBuildFile; productRef = A11C0F1A0000000000000381 /* MediaRemoteAdapter */; };',
        1,
    )
    project = project.replace(
        '\t\t\t\tA11C0F1A0000000000000353 /* Sparkle in Frameworks */,',
        '\t\t\t\tA11C0F1A0000000000000353 /* Sparkle in Frameworks */,\n\t\t\t\tA11C0F1A0000000000000380 /* MediaRemoteAdapter in Frameworks */,',
        1,
    )
    project = project.replace(
        '\t\t\t\tA11C0F1A0000000000000354 /* Sparkle */,\n\t\t\t);',
        '\t\t\t\tA11C0F1A0000000000000354 /* Sparkle */,\n\t\t\t\tA11C0F1A0000000000000381 /* MediaRemoteAdapter */,\n\t\t\t);',
        1,
    )
    project = project.replace(
        '\t\t\t\tA11C0F1A0000000000000355 /* XCRemoteSwiftPackageReference "Sparkle" */,\n\t\t\t);',
        '\t\t\t\tA11C0F1A0000000000000355 /* XCRemoteSwiftPackageReference "Sparkle" */,\n\t\t\t\tA11C0F1A0000000000000382 /* XCRemoteSwiftPackageReference "mediaremote-adapter" */,\n\t\t\t);',
        1,
    )
    project = project.replace(
        '\t\tA11C0F1A0000000000000355 /* XCRemoteSwiftPackageReference "Sparkle" */ = {\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = "https://github.com/sparkle-project/Sparkle";\n\t\t\trequirement = {\n\t\t\t\tkind = exactVersion;\n\t\t\t\tversion = 2.9.6;\n\t\t\t};\n\t\t};',
        '\t\tA11C0F1A0000000000000355 /* XCRemoteSwiftPackageReference "Sparkle" */ = {\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = "https://github.com/sparkle-project/Sparkle";\n\t\t\trequirement = {\n\t\t\t\tkind = exactVersion;\n\t\t\t\tversion = 2.9.6;\n\t\t\t};\n\t\t};\n\t\tA11C0F1A0000000000000382 /* XCRemoteSwiftPackageReference "mediaremote-adapter" */ = {\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = "https://github.com/ejbills/mediaremote-adapter.git";\n\t\t\trequirement = {\n\t\t\t\tkind = revision;\n\t\t\t\trevision = 5b6afde3f501a3da567e23bf7f23d562938a1809;\n\t\t\t};\n\t\t};',
        1,
    )
    project = project.replace(
        '\t\tA11C0F1A0000000000000354 /* Sparkle */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = A11C0F1A0000000000000355 /* XCRemoteSwiftPackageReference "Sparkle" */;\n\t\t\tproductName = Sparkle;\n\t\t};',
        '\t\tA11C0F1A0000000000000354 /* Sparkle */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = A11C0F1A0000000000000355 /* XCRemoteSwiftPackageReference "Sparkle" */;\n\t\t\tproductName = Sparkle;\n\t\t};\n\t\tA11C0F1A0000000000000381 /* MediaRemoteAdapter */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = A11C0F1A0000000000000382 /* XCRemoteSwiftPackageReference "mediaremote-adapter" */;\n\t\t\tproductName = MediaRemoteAdapter;\n\t\t};',
        1,
    )
project_path.write_text(project)

# Sanity contract.
assert 'import MediaRemoteAdapter' in store
assert 'private let controller = MediaController()' in store
assert 'artworkDataBase64.flatMap' in store
assert 'snapshotIsSafari' in store
assert 'MediaRemoteAdapter in Frameworks' in project
assert 'https://github.com/ejbills/mediaremote-adapter.git' in project
assert '5b6afde3f501a3da567e23bf7f23d562938a1809' in project
print('MediaRemote adapter patch applied')
