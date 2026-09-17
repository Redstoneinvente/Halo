from pathlib import Path

path = Path('Halo/Core/WorkspaceStore.swift')
text = path.read_text()

old_props = '''    private var recognitionInFlight = false
    private var lastRecognitionAttempt = Date.distantPast
'''
new_props = '''    private var recognitionInFlight = false
    private var lastRecognitionAttempt = Date.distantPast
    private var fastRefreshTask: Task<Void, Never>?
'''
if old_props not in text:
    raise SystemExit('SystemAudioMediaFallback properties changed')
text = text.replace(old_props, new_props, 1)

old_enabled = '''        self.enabled = enabled
        AudioSpectrumService.shared.setActive(enabled)
        if !enabled {
            AudioSpectrumService.shared.cancelRecognition()
            recognitionInFlight = false
            safariAudibleSince = nil
            clearIfOwned()
        }
'''
new_enabled = '''        self.enabled = enabled
        AudioSpectrumService.shared.setActive(enabled)
        if !enabled {
            fastRefreshTask?.cancel()
            fastRefreshTask = nil
            AudioSpectrumService.shared.cancelRecognition()
            recognitionInFlight = false
            safariAudibleSince = nil
            clearIfOwned()
        }
'''
if old_enabled not in text:
    raise SystemExit('setEnabled block changed')
text = text.replace(old_enabled, new_enabled, 1)

old_window = '''        let safariRecentlyActive = now.timeIntervalSince(lastSafariOutput) < 2.0
        let releaseWindow = (safariRunning || safariRecentlyActive) ? 4.0 : 2.75
'''
new_window = '''        let safariRecentlyActive = now.timeIntervalSince(lastSafariOutput) < 0.9
        let releaseWindow = (safariRunning || safariRecentlyActive) ? 1.25 : 0.85
'''
if text.count(old_window) != 1:
    raise SystemExit(f'Expected one main release-window block, found {text.count(old_window)}')
text = text.replace(old_window, new_window, 1)

old_async_window = '''                let safariRecentlyActive = now.timeIntervalSince(self.lastSafariOutput) < 2.0
                let releaseWindow = (safariRunning || safariRecentlyActive) ? 4.0 : 2.75
'''
new_async_window = '''                let safariRecentlyActive = now.timeIntervalSince(self.lastSafariOutput) < 0.9
                let releaseWindow = (safariRunning || safariRecentlyActive) ? 1.25 : 0.85
'''
if old_async_window not in text:
    raise SystemExit('MediaRemote release-window block changed')
text = text.replace(old_async_window, new_async_window, 1)

old_return = '''            requestRecognitionIfNeeded(media: media, safariLikely: safariLikely, audibleNow: audibleNow, now: now)
            return
        }
'''
new_return = '''            requestRecognitionIfNeeded(media: media, safariLikely: safariLikely, audibleNow: audibleNow, now: now)
            scheduleFastRefresh()
            return
        }
'''
if old_return not in text:
    raise SystemExit('systemAudioPlaying return block changed')
text = text.replace(old_return, new_return, 1)

old_stop = '''    func stop() {
        enabled = false
        AudioSpectrumService.shared.cancelRecognition()
'''
new_stop = '''    func stop() {
        enabled = false
        fastRefreshTask?.cancel()
        fastRefreshTask = nil
        AudioSpectrumService.shared.cancelRecognition()
'''
if old_stop not in text:
    raise SystemExit('stop block changed')
text = text.replace(old_stop, new_stop, 1)

anchor = '''    private func requestMediaRemoteMetadata() {
'''
helper = '''    private func scheduleFastRefresh() {
        guard enabled, ownsFallback else { return }
        fastRefreshTask?.cancel()
        fastRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, self.enabled, self.ownsFallback else { return }
                self.refresh()
            }
        }
    }

'''
if anchor not in text:
    raise SystemExit('requestMediaRemoteMetadata anchor changed')
text = text.replace(anchor, helper + anchor, 1)

path.write_text(text)
print('Tuned System Audio stop detection to ~1 second with targeted 350 ms liveness refreshes')
