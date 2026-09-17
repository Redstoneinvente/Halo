from pathlib import Path

spectrum = Path('Halo/Services/AudioSpectrumService.swift')
text = spectrum.read_text()

old = '''struct AudioSpectrumSnapshot: Equatable {
    var bass: Double = 0
    var mids: Double = 0
    var treble: Double = 0
    var overall: Double = 0
    var available = false
}
'''
new = '''struct AudioSpectrumSnapshot: Equatable {
    var bass: Double = 0
    var mids: Double = 0
    var treble: Double = 0
    var overall: Double = 0
    // Unsmoothed instantaneous energy used for playback liveness. Visual bands deliberately
    // retain release smoothing, but stop detection must not inherit that decay tail.
    var liveness: Double = 0
    var available = false
}
'''
if old not in text:
    raise SystemExit('AudioSpectrumSnapshot layout changed')
text = text.replace(old, new, 1)

old = '''        smoothed.bass = smooth(smoothed.bass, bass)
        smoothed.mids = smooth(smoothed.mids, mids)
        smoothed.treble = smooth(smoothed.treble, treble)
        smoothed.overall = smooth(smoothed.overall, overall)
        smoothed.available = rms > 0.00001
'''
new = '''        smoothed.bass = smooth(smoothed.bass, bass)
        smoothed.mids = smooth(smoothed.mids, mids)
        smoothed.treble = smooth(smoothed.treble, treble)
        smoothed.overall = smooth(smoothed.overall, overall)
        // Keep liveness raw. A smoothed release here can take several seconds to decay and is
        // appropriate for animation, not for deciding whether Audio CI should still exist.
        smoothed.liveness = max(overall, mids * 0.82, bass * 0.62, treble * 0.68)
        smoothed.available = rms > 0.00001
'''
if old not in text:
    raise SystemExit('AudioSpectrum analyse tail changed')
text = text.replace(old, new, 1)
spectrum.write_text(text)

workspace = Path('Halo/Core/WorkspaceStore.swift')
text = workspace.read_text()

old = '''        if safariOutputActive { lastSafariOutput = now }

        let audioSnapshot = AudioSpectrumService.shared.snapshot()
        let pcmAudible = isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutputActive)
        let audibleNow = safariOutputActive || pcmAudible
        let safariLikely = safariOutputActive || (safariRunning && pcmAudible)
'''
new = '''        let audioSnapshot = AudioSpectrumService.shared.snapshot()
        let pcmAudible = isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutputActive)
        // CoreAudio's process-output flag means Safari/WebKit owns a running output stream; it
        // does NOT guarantee non-silent samples. Use it only to attribute PCM to Safari. Actual
        // liveness comes from captured PCM so a paused/silent WebKit stream cannot pin Audio CI.
        let audibleNow = pcmAudible
        let safariLikely = safariOutputActive || (safariRunning && pcmAudible)
        if safariOutputActive && pcmAudible { lastSafariOutput = now }
'''
if old not in text:
    raise SystemExit('Primary Safari liveness block changed')
text = text.replace(old, new, 1)

old = '''                let pcmAudible = self.isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutput)
                let safariLikely = safariOutput || (safariRunning && pcmAudible)
                let audibleNow = safariOutput || pcmAudible
                let now = Date()
                if safariOutput { self.lastSafariOutput = now }
'''
new = '''                let pcmAudible = self.isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutput)
                let safariLikely = safariOutput || (safariRunning && pcmAudible)
                let audibleNow = pcmAudible
                let now = Date()
                if safariOutput && pcmAudible { self.lastSafariOutput = now }
'''
if old not in text:
    raise SystemExit('Async Safari liveness block changed')
text = text.replace(old, new, 1)

old = '''        guard snapshot.available else { return false }
        // Browser video, speech, and WebAudio can sit far below music-mastering levels. Mids are
        // especially useful for quiet speech, so blend the bands instead of relying on RMS alone.
        let signal = max(snapshot.overall, snapshot.mids * 0.82, snapshot.bass * 0.62, snapshot.treble * 0.68)
        return signal > (safariHint ? 0.016 : 0.040)
'''
new = '''        guard snapshot.available else { return false }
        // Use instantaneous (unsmoothed) energy for liveness. The displayed spectrum keeps its
        // smooth release, but Audio CI must disappear as soon as real PCM falls silent.
        return snapshot.liveness > (safariHint ? 0.016 : 0.040)
'''
if old not in text:
    raise SystemExit('isPCMAudible block changed')
text = text.replace(old, new, 1)
workspace.write_text(text)

print('Separated visual spectrum smoothing from System Audio playback liveness')
