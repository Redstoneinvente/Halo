from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"missing anchor {label} in {path}")
    if text.count(old) != 1:
        raise SystemExit(f"anchor {label} count={text.count(old)} in {path}")
    p.write_text(text.replace(old, new, 1))

# AudioSpectrumService: feed already-captured system PCM into ShazamKit on demand.
p = "Halo/Services/AudioSpectrumService.swift"
replace_once(p,
'''import Accelerate
import AudioToolbox
''',
'''import Accelerate
import AudioToolbox
import AVFoundation
import ShazamKit
''', "audio imports")

replace_once(p,
'''struct AudioSpectrumSnapshot: Equatable {
    var bass: Double = 0
    var mids: Double = 0
    var treble: Double = 0
    var overall: Double = 0
    var available = false
}
''',
'''struct AudioSpectrumSnapshot: Equatable {
    var bass: Double = 0
    var mids: Double = 0
    var treble: Double = 0
    var overall: Double = 0
    var available = false
}

struct AudioRecognitionMatch: Equatable {
    let title: String
    let artist: String
    let artworkURL: URL?
    let isrc: String?
}
''', "recognition model")

replace_once(p,
'''final class AudioSpectrumService: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
''',
'''final class AudioSpectrumService: NSObject, SCStreamOutput, SCStreamDelegate, SHSessionDelegate, @unchecked Sendable {
''', "shazam delegate conformance")

replace_once(p,
'''    private var idleStopTask: Task<Void, Never>?
    private var smoothed = AudioSpectrumSnapshot()
''',
'''    private var idleStopTask: Task<Void, Never>?
    private var smoothed = AudioSpectrumSnapshot()
    private var recognitionSession: SHSession?
    private var recognitionCompletion: ((AudioRecognitionMatch?) -> Void)?
    private var recognitionDeadline = Date.distantPast
    private var recognitionSampleRate = 0.0
''', "recognition state")

replace_once(p,
'''    private func screenCaptureAccessAvailable() async -> Bool {
''',
'''    func recognizeCurrentAudio(timeout: TimeInterval = 8, completion: @escaping (AudioRecognitionMatch?) -> Void) {
        stateLock.lock()
        guard recognitionSession == nil else {
            stateLock.unlock()
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let session = SHSession()
        recognitionSession = session
        recognitionCompletion = completion
        recognitionDeadline = Date().addingTimeInterval(max(3, min(15, timeout)))
        recognitionSampleRate = 0
        stateLock.unlock()

        session.delegate = self
        sampleQueue.asyncAfter(deadline: .now() + max(3, min(15, timeout))) { [weak self, weak session] in
            guard let self, let session else { return }
            self.finishRecognition(nil, session: session)
        }
    }

    func cancelRecognition() {
        finishRecognition(nil, session: nil)
    }

    private func screenCaptureAccessAvailable() async -> Bool {
''', "recognition entrypoint")

replace_once(p,
'''        analyse(mono, sampleRate: max(8_000, Double(asbd.mSampleRate)))
''',
'''        let sampleRate = max(8_000, Double(asbd.mSampleRate))
        feedRecognition(mono, sampleRate: sampleRate)
        analyse(mono, sampleRate: sampleRate)
''', "feed recognition")

replace_once(p,
'''    private enum SpectrumError: Error { case noDisplay }
}
''',
'''    private func feedRecognition(_ input: [Float], sampleRate: Double) {
        stateLock.lock()
        guard let session = recognitionSession, Date() < recognitionDeadline else {
            let expired = recognitionSession
            stateLock.unlock()
            if let expired { finishRecognition(nil, session: expired) }
            return
        }
        if recognitionSampleRate == 0 { recognitionSampleRate = sampleRate }
        let expectedRate = recognitionSampleRate
        stateLock.unlock()

        // ShazamKit requires one stable audio format for a streaming session.
        guard abs(expectedRate - sampleRate) < 1,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: sampleRate,
                                         channels: 1,
                                         interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(input.count)),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(input.count)
        for index in input.indices { channel[index] = input[index] }
        session.matchStreamingBuffer(buffer, at: nil)
    }

    func session(_ session: SHSession, didFind match: SHMatch) {
        guard let item = match.mediaItems.first,
              let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            finishRecognition(nil, session: session)
            return
        }
        let result = AudioRecognitionMatch(
            title: title,
            artist: item.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            artworkURL: item.artworkURL,
            isrc: item.isrc
        )
        finishRecognition(result, session: session)
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        // A streaming session can report an early no-match and succeed after more audio arrives.
        // Only abort immediately on an actual catalog/transport error; otherwise let the timeout run.
        if error != nil { finishRecognition(nil, session: session) }
    }

    private func finishRecognition(_ result: AudioRecognitionMatch?, session: SHSession?) {
        stateLock.lock()
        guard let current = recognitionSession, session == nil || current === session else {
            stateLock.unlock()
            return
        }
        let completion = recognitionCompletion
        recognitionSession = nil
        recognitionCompletion = nil
        recognitionDeadline = .distantPast
        recognitionSampleRate = 0
        current.delegate = nil
        stateLock.unlock()
        if let completion { DispatchQueue.main.async { completion(result) } }
    }

    private enum SpectrumError: Error { case noDisplay }
}
''', "recognition implementation")

# MediaService: preserve system/Safari ownership and accept external metadata/artwork.
p = "Halo/Services/Integrations.swift"
replace_once(p,
'''    private var trackID = ""
    private var artworkKey = ""
    private var artworkTask: Task<Void, Never>?
''',
'''    private var trackID = ""
    private var artworkKey = ""
    private var artworkTask: Task<Void, Never>?
    private var externalArtworkData: Data?
    private var externalArtworkURL: String?
''', "external artwork state")

replace_once(p,
'''        artworkTask?.cancel(); artworkKey = ""; artworkColors = []
        if enabled, let app = connectedApp { requestArtwork(app: app) }
''',
'''        artworkTask?.cancel(); artworkKey = ""; artworkColors = []
        if enabled, let app = connectedApp { requestArtwork(app: app) }
        else if enabled { requestExternalArtwork() }
''', "artwork enable external")

replace_once(p,
'''        artworkTask?.cancel(); artworkKey = ""; trackID = ""; artworkColors = []; artworkImage = nil
        album = ""; duration = 0; position = 0; shuffleSupported = false; shuffleEnabled = false; repeatSupported = false; repeatMode = ""
''',
'''        artworkTask?.cancel(); artworkKey = ""; trackID = ""; artworkColors = []; artworkImage = nil
        externalArtworkData = nil; externalArtworkURL = nil
        album = ""; duration = 0; position = 0; shuffleSupported = false; shuffleEnabled = false; repeatSupported = false; repeatMode = ""
''', "disconnect external")

replace_once(p,
'''        guard !candidates.isEmpty else {
            if isPlaying || connectedApp != nil { disconnect() }
            return
        }
''',
'''        guard !candidates.isEmpty else {
            // Automatic system/Safari audio is represented with connectedApp == nil. Do not let
            // the rich-player poll erase that source just because Music/Spotify are not running.
            if connectedApp != nil || (!automatic && isPlaying) { disconnect() }
            return
        }
''', "poll empty ownership")

replace_once(p,
'''                } else if self.connectedApp != nil || self.isPlaying { self.disconnect() }
''',
'''                } else if self.connectedApp != nil || (!automatic && self.isPlaying) { self.disconnect() }
''', "poll result ownership")

replace_once(p,
'''        if connectedApp != snapshot.app {
            artworkTask?.cancel(); artworkKey = ""; artworkColors = []
            connectedApp = snapshot.app
        }
''',
'''        if connectedApp != snapshot.app {
            artworkTask?.cancel(); artworkKey = ""; artworkColors = []; artworkImage = nil
            externalArtworkData = nil; externalArtworkURL = nil
            connectedApp = snapshot.app
        }
''', "rich source clears external")

replace_once(p,
'''    func perform(_ command: String, app preferred: String) {
''',
'''    func acceptExternalMedia(title newTitle: String,
                             artist newArtist: String,
                             album newAlbum: String? = nil,
                             duration newDuration: Double? = nil,
                             position newPosition: Double? = nil,
                             playing: Bool,
                             artworkData: Data? = nil,
                             artworkURL: String? = nil,
                             sourceKey: String) {
        guard connectedApp == nil else { return }
        let canonicalKey = "external:" + sourceKey
        let trackChanged = trackID != canonicalKey
        if trackChanged {
            trackID = canonicalKey
            album = ""; duration = 0; position = 0
            artworkTask?.cancel(); artworkKey = ""; artworkColors = []; artworkImage = nil
            externalArtworkData = nil; externalArtworkURL = nil
        }
        if !newTitle.isEmpty, title != newTitle { title = newTitle }
        if artist != newArtist { artist = newArtist }
        if let newAlbum, !newAlbum.isEmpty { album = newAlbum }
        if let newDuration, newDuration.isFinite, newDuration > 0 { duration = newDuration }
        if let newPosition, newPosition.isFinite, newPosition >= 0 {
            position = duration > 0 ? min(duration, newPosition) : newPosition
        }
        if isPlaying != playing { isPlaying = playing }
        if let artworkData, !artworkData.isEmpty { externalArtworkData = artworkData }
        if let artworkURL, URL(string: artworkURL)?.scheme == "https" { externalArtworkURL = artworkURL }
        if error != nil { error = nil }
        requestExternalArtwork()
    }

    func perform(_ command: String, app preferred: String) {
''', "accept external media")

replace_once(p,
'''    private func requestArtwork(app: String) {
''',
'''    private func requestExternalArtwork() {
        guard artworkEnabled, connectedApp == nil else { return }
        let fingerprint = externalArtworkData.map { data in
            String(data.count) + ":" + data.prefix(18).base64EncodedString()
        } ?? ""
        let key = "external-art:" + trackID + ":" + fingerprint + ":" + (externalArtworkURL ?? "")
        guard (externalArtworkData != nil || externalArtworkURL != nil), key != artworkKey else { return }
        artworkTask?.cancel(); artworkKey = key
        let bytes = externalArtworkData
        let urlString = externalArtworkURL
        artworkTask = Task { [weak self] in
            async let colorsValue = ArtworkReader.palette(data: bytes, urlString: urlString)
            async let imageValue = ArtworkReader.image(data: bytes, urlString: urlString)
            let (colors, image) = await (colorsValue, imageValue)
            guard !Task.isCancelled, let self, self.artworkEnabled, self.connectedApp == nil,
                  self.artworkKey == key else { return }
            self.artworkColors = colors
            self.artworkImage = image
        }
    }

    private func requestArtwork(app: String) {
''', "external artwork loader")

# WorkspaceStore: request artwork whenever context music displays it; read MediaRemote artwork;
# use ShazamKit only after Safari has been audibly unresolved for a couple seconds.
p = "Halo/Core/WorkspaceStore.swift"
replace_once(p,
'''            let contextNeedsPalette = context?.enabled == true && (
                context?.usesSongTextColors == true ||
                context?.usesSongControlColors == true ||
                context?.usesSongVisualizerColors == true ||
                context?.usesSongBackgroundColors == true ||
                context?.background == .gradient
            )
''',
'''            let contextNeedsArtwork = context?.enabled == true && (
                context?.showArtwork == true || context?.usesArtworkBackground == true
            )
            let contextNeedsPalette = context?.enabled == true && (
                context?.usesSongTextColors == true ||
                context?.usesSongControlColors == true ||
                context?.usesSongVisualizerColors == true ||
                context?.usesSongBackgroundColors == true ||
                context?.background == .gradient
            )
''', "context artwork preference")

replace_once(p,
'''            return contextNeedsPalette || hudNeedsPalette ||
''',
'''            return contextNeedsArtwork || contextNeedsPalette || hudNeedsPalette ||
''', "context artwork return")

replace_once(p,
'''private struct MediaRemoteNowPlayingSnapshot {
    let title: String
    let artist: String
    let album: String
    let playing: Bool
    let duration: Double?
    let elapsed: Double?
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
}
''', "remote artwork model")

replace_once(p,
'''            func firstDouble(_ keys: [String]) -> Double? {
                for key in keys {
                    if let value = info[key] as? NSNumber { return value.doubleValue }
                    if let value = info[key] as? Double { return value }
                }
                return nil
            }

            guard let title = firstString(["kMRMediaRemoteNowPlayingInfoTitle", "title"]) else {
''',
'''            func firstDouble(_ keys: [String]) -> Double? {
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
''', "remote artwork helpers")

replace_once(p,
'''            let rate = firstDouble(["kMRMediaRemoteNowPlayingInfoPlaybackRate", "playbackRate"])
            completion(MediaRemoteNowPlayingSnapshot(title: title, artist: artist, album: album,
                                                     playing: (rate ?? 0) > 0.001,
                                                     duration: duration, elapsed: elapsed))
''',
'''            let rate = firstDouble(["kMRMediaRemoteNowPlayingInfoPlaybackRate", "playbackRate"])
            let artworkData = firstData(["kMRMediaRemoteNowPlayingInfoArtworkData", "artworkData"])
            let artworkURL = firstHTTPSURL(["kMRMediaRemoteNowPlayingInfoArtworkURL", "artworkURL",
                                            "kMRMediaRemoteNowPlayingInfoArtworkIdentifier", "artworkIdentifier"])
            completion(MediaRemoteNowPlayingSnapshot(title: title, artist: artist, album: album,
                                                     playing: (rate ?? 0) > 0.001,
                                                     duration: duration, elapsed: elapsed,
                                                     artworkData: artworkData, artworkURL: artworkURL))
''', "remote artwork extraction")

replace_once(p,
'''    private var lastRemoteMetadata = Date.distantPast
    private var remoteRequestInFlight = false
''',
'''    private var lastRemoteMetadata = Date.distantPast
    private var remoteRequestInFlight = false
    private var safariAudibleSince: Date?
    private var recognitionInFlight = false
    private var lastRecognitionAttempt = Date.distantPast
''', "fallback recognition state")

replace_once(p,
'''        AudioSpectrumService.shared.setActive(enabled)
        if !enabled { clearIfOwned() }
''',
'''        AudioSpectrumService.shared.setActive(enabled)
        if !enabled {
            AudioSpectrumService.shared.cancelRecognition()
            recognitionInFlight = false
            safariAudibleSince = nil
            clearIfOwned()
        }
''', "cancel recognition disable")

replace_once(p,
'''        if safariOutputActive { lastSafariOutput = now }

        let audioSnapshot = AudioSpectrumService.shared.snapshot()
        let pcmAudible = isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutputActive)
        let audibleNow = safariOutputActive || pcmAudible
        if audibleNow { lastHeard = now }
''',
'''        if safariOutputActive { lastSafariOutput = now }

        let audioSnapshot = AudioSpectrumService.shared.snapshot()
        let pcmAudible = isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutputActive)
        let audibleNow = safariOutputActive || pcmAudible
        let safariLikely = safariOutputActive || (safariRunning && pcmAudible)
        if audibleNow { lastHeard = now }
        if safariLikely && audibleNow {
            if safariAudibleSince == nil { safariAudibleSince = now }
        } else if now.timeIntervalSince(lastHeard) > 4.5 {
            safariAudibleSince = nil
        }
''', "safari audible timing")

replace_once(p,
'''                media.isPlaying = true
                media.error = nil
                ownsFallback = true
            }
            return
''',
'''                media.isPlaying = true
                media.error = nil
                ownsFallback = true
            }
            requestRecognitionIfNeeded(media: media, safariLikely: safariLikely, audibleNow: audibleNow, now: now)
            return
''', "trigger recognition")

replace_once(p,
'''    func stop() {
        enabled = false
        AudioSpectrumService.shared.setActive(false)
        clearIfOwned()
    }
''',
'''    func stop() {
        enabled = false
        AudioSpectrumService.shared.cancelRecognition()
        recognitionInFlight = false
        safariAudibleSince = nil
        AudioSpectrumService.shared.setActive(false)
        clearIfOwned()
    }
''', "stop recognition")

old_remote = '''                self.lastRemoteMetadata = Date()
                self.ownsFallback = true
                media.title = snapshot.title
                if !snapshot.artist.isEmpty {
                    media.artist = snapshot.artist
                } else if !snapshot.album.isEmpty {
                    media.artist = snapshot.album
                } else {
                    media.artist = "System Audio"
                }
                let audioSnapshot = AudioSpectrumService.shared.snapshot()
                let safariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
                let audibleNow = self.isPCMAudible(audioSnapshot, safariHint: safariRunning)
                media.isPlaying = snapshot.playing || audibleNow
                media.error = nil
'''
new_remote = '''                let audioSnapshot = AudioSpectrumService.shared.snapshot()
                let safariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
                let safariOutput: Bool
                if #available(macOS 14.2, *) { safariOutput = SafariAudioProcessDetector.isProducingOutput() }
                else { safariOutput = false }
                let pcmAudible = self.isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutput)
                let safariLikely = safariOutput || (safariRunning && pcmAudible)
                let audibleNow = safariOutput || pcmAudible

                // A paused MediaRemote entry is often stale Music/Spotify metadata. If Safari is
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
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .joined(separator: "|")
                media.acceptExternalMedia(title: snapshot.title,
                                          artist: displayArtist,
                                          album: snapshot.album,
                                          duration: snapshot.duration,
                                          position: snapshot.elapsed,
                                          playing: snapshot.playing || audibleNow,
                                          artworkData: snapshot.artworkData,
                                          artworkURL: snapshot.artworkURL,
                                          sourceKey: sourceKey)
'''
replace_once(p, old_remote, new_remote, "accept remote metadata")

replace_once(p,
'''    private func isPCMAudible(_ snapshot: AudioSpectrumSnapshot, safariHint: Bool) -> Bool {
''',
'''    private func requestRecognitionIfNeeded(media: MediaService, safariLikely: Bool, audibleNow: Bool, now: Date) {
        guard safariLikely, audibleNow, !recognitionInFlight,
              let since = safariAudibleSince, now.timeIntervalSince(since) >= 2.4,
              now.timeIntervalSince(lastRecognitionAttempt) >= 15 else { return }

        let generic = isGenericExternalMetadata(title: media.title, artist: media.artist)
        guard generic || media.artworkImage == nil else { return }

        recognitionInFlight = true
        lastRecognitionAttempt = now
        AudioSpectrumService.shared.recognizeCurrentAudio(timeout: 8) { [weak self] match in
            Task { @MainActor in
                guard let self else { return }
                self.recognitionInFlight = false
                guard self.enabled, let media = self.media, let match else { return }

                let keepExistingMetadata = !self.isGenericExternalMetadata(title: media.title, artist: media.artist)
                let title = keepExistingMetadata ? media.title : match.title
                let artist = keepExistingMetadata ? media.artist : match.artist
                let sourceKey = [title, artist, media.album]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .joined(separator: "|")
                media.acceptExternalMedia(title: title,
                                          artist: artist,
                                          album: media.album,
                                          duration: media.duration > 0 ? media.duration : nil,
                                          position: media.position >= 0 ? media.position : nil,
                                          playing: media.isPlaying,
                                          artworkURL: match.artworkURL?.absoluteString,
                                          sourceKey: sourceKey)
            }
        }
    }

    private func isGenericExternalMetadata(title: String, artist: String) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let artist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return title.isEmpty || title == "system audio" || title == "safari audio" || title == "connect a player" ||
            artist.isEmpty || artist == "system audio" || artist == "playing from safari" || artist == "playing from your mac"
    }

    private func isPCMAudible(_ snapshot: AudioSpectrumSnapshot, safariHint: Bool) -> Bool {
''', "recognition arbitration")

# SurfaceView: consume MediaService external artwork and timing; existing LRCLIB lookup then works for Safari.
p = "Halo/Views/SurfaceView.swift"
replace_once(p,
'''    private var playbackKey: String { "\\(media.connectedApp ?? \"\")|\\(media.title)|\\(media.artist)|\\(media.isPlaying)" }
    private var lyricKey: String { playbackKey + "|lyrics|\\(options.showsLyrics)|\\(options.usesOnlineLyrics)" }
''',
'''    private var playbackKey: String { "\\(media.connectedApp ?? \"\")|\\(media.title)|\\(media.artist)|\\(media.isPlaying)|\\(Int(media.duration.rounded()))" }
    private var lyricKey: String { playbackKey + "|lyrics|\\(media.album)|\\(options.showsLyrics)|\\(options.usesOnlineLyrics)" }
''', "surface task keys")

replace_once(p,
'''    private var songColors: [Color] { media.artworkColors.map(\\.color) }
''',
'''    private var activeArtwork: NSImage? { media.artworkImage ?? artwork }
    private var songColors: [Color] { media.artworkColors.map(\\.color) }
''', "active external artwork")

replace_once(p,
'''            if options.usesArtworkBackground, let artwork {
                Image(nsImage: artwork)
''',
'''            if options.usesArtworkBackground, let activeArtwork {
                Image(nsImage: activeArtwork)
''', "background external artwork")

replace_once(p,
'''                    if let artwork { Image(nsImage: artwork).resizable().scaledToFill() }
''',
'''                    if let activeArtwork { Image(nsImage: activeArtwork).resizable().scaledToFill() }
''', "cover external artwork")

replace_once(p,
'''        VinylRecordView(artwork: artwork,
''',
'''        VinylRecordView(artwork: activeArtwork,
''', "vinyl external artwork")

replace_once(p,
'''    private func playbackLoop() async {
        playbackPosition = 0; playbackDuration = 0
        while !Task.isCancelled {
            if !isScrubbing, let sample = await MediaAssetReader.playbackTime(app: media.connectedApp) {
                playbackPosition = sample.position
                playbackDuration = sample.duration
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
''',
'''    private func playbackLoop() async {
        playbackPosition = media.position
        playbackDuration = media.duration
        while !Task.isCancelled {
            if !isScrubbing {
                if let sample = await MediaAssetReader.playbackTime(app: media.connectedApp) {
                    playbackPosition = sample.position
                    playbackDuration = sample.duration
                } else if media.duration > 0 {
                    playbackDuration = media.duration
                    // MediaRemote updates roughly on Halo's normal poll. Interpolate between those
                    // samples so synced Safari lyrics remain fluid rather than stepping every 2 s.
                    if abs(media.position - playbackPosition) > 1.35 {
                        playbackPosition = media.position
                    } else if media.isPlaying {
                        playbackPosition = min(playbackDuration, playbackPosition + 0.5)
                    } else {
                        playbackPosition = min(playbackDuration, max(0, media.position))
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
''', "external playback clock")

replace_once(p,
'''        if playbackDuration <= 0, let initial {
            playbackPosition = initial.position
            playbackDuration = initial.duration
        }
        let duration = playbackDuration > 0 ? playbackDuration : initial?.duration
''',
'''        if playbackDuration <= 0, let initial {
            playbackPosition = initial.position
            playbackDuration = initial.duration
        } else if playbackDuration <= 0, media.duration > 0 {
            playbackPosition = media.position
            playbackDuration = media.duration
        }
        let duration = playbackDuration > 0 ? playbackDuration : (initial?.duration ?? (media.duration > 0 ? media.duration : nil))
''', "external lyric duration")

print("Safari media enrichment patch applied")
