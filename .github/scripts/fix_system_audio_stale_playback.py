from pathlib import Path

path = Path('Halo/Core/WorkspaceStore.swift')
text = path.read_text()

old = '''                let now = Date()
                if safariOutput { self.lastSafariOutput = now }
                if audibleNow || snapshot.playing { self.lastHeard = now }
                let safariRecentlyActive = now.timeIntervalSince(self.lastSafariOutput) < 0.9
                let releaseWindow = (safariRunning || safariRecentlyActive) ? 1.25 : 0.85
                let withinReleaseWindow = now.timeIntervalSince(self.lastHeard) < releaseWindow
                let shouldPresentPlaying = snapshot.playing || audibleNow || (self.ownsFallback && withinReleaseWindow)
'''
new = '''                let now = Date()
                if safariOutput { self.lastSafariOutput = now }
                // MediaRemote snapshots may be cached for many seconds. Never let a stale
                // `playing = true` sample keep pushing lastHeard forward after output stopped.
                // Actual PCM/process output owns the release timer; MediaRemote can only seed
                // presentation briefly when its playback sample itself is fresh.
                if audibleNow { self.lastHeard = now }
                let remotePlaybackFresh = snapshot.playing && now.timeIntervalSince(snapshot.sampledAt) < 1.0
                let safariRecentlyActive = now.timeIntervalSince(self.lastSafariOutput) < 0.9
                let releaseWindow = (safariRunning || safariRecentlyActive) ? 1.25 : 0.85
                let withinReleaseWindow = now.timeIntervalSince(self.lastHeard) < releaseWindow
                let shouldPresentPlaying = remotePlaybackFresh || audibleNow || (self.ownsFallback && withinReleaseWindow)
'''
if old not in text:
    raise SystemExit('Expected MediaRemote playback block not found')
text = text.replace(old, new, 1)
path.write_text(text)
print('Stopped cached MediaRemote playing state from extending System Audio CI lifetime')
