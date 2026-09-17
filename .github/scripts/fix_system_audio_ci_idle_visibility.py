from pathlib import Path

path = Path("Halo/Services/Integrations.swift")
text = path.read_text()

old = '''    /// UI presentation lifetime is deliberately a little less brittle than raw playback state.
    /// System/Safari playback can momentarily report `isPlaying == false` while MediaRemote still
    /// owns a meaningful Now Playing session. Keeping that session present prevents Context Music
    /// and the closed-notch visualizer from disappearing and forcing a surface resize. Native
    /// Music/Spotify pauses remain immediate because they have a connected app.
    var hasNowPlayingPresentation: Bool {
        if isPlaying { return true }
        guard connectedApp == nil else { return false }
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedTitle.isEmpty,
              normalizedTitle != "connect a player",
              normalizedTitle != "nothing playing" else { return false }
        if normalizedTitle == "system audio" && normalizedArtist.contains("waiting for audio") { return false }
        return true
    }
'''

new = '''    /// Audio CI is visible only while playback is actually active. System/Safari already debounce
    /// short detector gaps by keeping `isPlaying` true for the fallback release window, so stale
    /// MediaRemote metadata must never keep the CI visible after system audio has genuinely stopped.
    var hasNowPlayingPresentation: Bool { isPlaying }
'''

if new in text:
    print("System Audio CI idle visibility fix already applied")
elif old in text:
    text = text.replace(old, new, 1)
    path.write_text(text)
    print("System Audio CI now requires active playback")
else:
    raise SystemExit("MediaService presentation contract changed; refusing an unsafe patch")
