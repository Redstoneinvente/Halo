import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreGraphics
import Accelerate
import AudioToolbox

struct AudioSpectrumSnapshot: Equatable {
    var bass: Double = 0
    var mids: Double = 0
    var treble: Double = 0
    var overall: Double = 0
    var available = false
}

/// Lightweight system-audio analyser used only while an audio-reactive closed-notch background is active.
/// ScreenCaptureKit supplies mono PCM buffers; Accelerate reduces each buffer into low/mid/high energy bands.
final class AudioSpectrumService: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    static let shared = AudioSpectrumService()

    private let sampleQueue = DispatchQueue(label: "Halo.AudioSpectrum.Samples", qos: .userInitiated)
    private let stateLock = NSLock()
    private var stream: SCStream?
    private var starting = false
    private var wanted = false
    private var blockedForCurrentActivation = false
    private var permissionRequestedThisRun = false
    private var idleStopTask: Task<Void, Never>?
    private var smoothed = AudioSpectrumSnapshot()

    func snapshot() -> AudioSpectrumSnapshot {
        stateLock.lock(); defer { stateLock.unlock() }
        return smoothed
    }

    func setActive(_ active: Bool) {
        stateLock.lock()
        wanted = active
        idleStopTask?.cancel()
        idleStopTask = nil

        let shouldStart = active && stream == nil && !starting && !blockedForCurrentActivation
        if shouldStart { starting = true }
        let current = stream
        stateLock.unlock()

        if shouldStart {
            Task { await startIfNeeded() }
        } else if !active, let current {
            // Closed-notch SwiftUI views can be recreated while lyrics resize or profiles update. Keep the
            // capture alive briefly so those transient lifecycle changes do not repeatedly tear down and
            // recreate ScreenCaptureKit, which can retrigger macOS capture-consent UI.
            let task = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled, let self else { return }
                await self.stopIfStillIdle(current)
            }
            stateLock.lock()
            idleStopTask = task
            stateLock.unlock()
        }
    }

    private func screenCaptureAccessAvailable() async -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }

        stateLock.lock()
        let shouldRequest = !permissionRequestedThisRun
        if shouldRequest { permissionRequestedThisRun = true }
        stateLock.unlock()

        // Never hammer the system permission dialog. If access is denied/not yet reflected, ask at most
        // once per Halo process. A later Settings change is detected by CGPreflightScreenCaptureAccess().
        guard shouldRequest else { return false }
        return await MainActor.run { CGRequestScreenCaptureAccess() }
    }

    private func startIfNeeded() async {
        guard await screenCaptureAccessAvailable() else {
            stateLock.lock()
            starting = false
            stream = nil
            blockedForCurrentActivation = true
            smoothed = AudioSpectrumSnapshot()
            stateLock.unlock()
            return
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { throw SpectrumError.noDisplay }
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = 2
            configuration.height = 2
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 2)
            configuration.queueDepth = 2
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = true
            configuration.sampleRate = 48_000
            // Frequency analysis does not need stereo. Mono keeps the callback layout deterministic and cheap.
            configuration.channelCount = 1

            let candidate = SCStream(filter: filter, configuration: configuration, delegate: self)
            try candidate.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)

            stateLock.lock()
            let stillWanted = wanted
            if stillWanted { stream = candidate }
            starting = false
            stateLock.unlock()

            guard stillWanted else { return }
            try await candidate.startCapture()

            stateLock.lock()
            blockedForCurrentActivation = false
            stateLock.unlock()
        } catch {
            stateLock.lock()
            starting = false
            stream = nil
            blockedForCurrentActivation = true
            smoothed = AudioSpectrumSnapshot()
            stateLock.unlock()
            // Do not automatically recreate SCShareableContent/SCStream after a failure. An immediate retry
            // loop can repeatedly invoke the macOS capture-consent path. The next genuine activation after an
            // idle stop (or app relaunch) may try again.
        }
    }

    private func stopIfStillIdle(_ current: SCStream) async {
        stateLock.lock()
        guard !wanted, stream === current else {
            if wanted { blockedForCurrentActivation = false }
            stateLock.unlock()
            return
        }
        stateLock.unlock()

        try? await current.stopCapture()

        stateLock.lock()
        if stream === current { stream = nil }
        smoothed = AudioSpectrumSnapshot()
        blockedForCurrentActivation = false
        idleStopTask = nil
        stateLock.unlock()
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        stateLock.lock()
        if self.stream === stream { self.stream = nil }
        smoothed = AudioSpectrumSnapshot()
        starting = false
        blockedForCurrentActivation = true
        stateLock.unlock()
        // Deliberately no immediate restart. ScreenCaptureKit failures must not become permission-prompt loops.
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, sampleBuffer.isValid,
              let format = sampleBuffer.formatDescription,
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(format) else { return }
        let asbd = asbdPointer.pointee
        guard asbd.mFormatID == kAudioFormatLinearPCM else { return }

        var blockBuffer: CMBlockBuffer?
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: 0, mData: nil)
        )
        var needed = 0
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &needed,
            bufferListOut: &bufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr,
              bufferList.mNumberBuffers > 0,
              let data = bufferList.mBuffers.mData else { return }

        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let bytesPerSample = max(1, Int(asbd.mBitsPerChannel / 8))
        let count = min(2048, Int(bufferList.mBuffers.mDataByteSize) / bytesPerSample)
        guard count >= 128 else { return }

        var mono = [Float](repeating: 0, count: count)
        if isFloat && asbd.mBitsPerChannel == 32 {
            let samples = data.assumingMemoryBound(to: Float.self)
            for i in 0..<count { mono[i] = samples[i] }
        } else if !isFloat && asbd.mBitsPerChannel == 16 {
            let samples = data.assumingMemoryBound(to: Int16.self)
            for i in 0..<count { mono[i] = Float(samples[i]) / 32768 }
        } else { return }

        analyse(mono, sampleRate: max(8_000, Double(asbd.mSampleRate)))
    }

    private func analyse(_ input: [Float], sampleRate: Double) {
        let n = 1024
        guard input.count >= 128 else { return }
        var samples = [Float](repeating: 0, count: n)
        let copyCount = min(n, input.count)
        samples.replaceSubrange(0..<copyCount, with: input.prefix(copyCount))

        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(n))

        var real = [Float](repeating: 0, count: n / 2)
        var imag = [Float](repeating: 0, count: n / 2)
        var magnitudes = [Float](repeating: 0, count: n / 2)
        let log2n = vDSP_Length(log2(Float(n)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return }
        defer { vDSP_destroy_fftsetup(setup) }

        windowed.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            base.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) { complex in
                var split = DSPSplitComplex(realp: &real, imagp: &imag)
                vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(n / 2))
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(n / 2))
            }
        }

        let hzPerBin = sampleRate / Double(n)
        func band(_ low: Double, _ high: Double) -> Double {
            let lower = max(1, Int(low / hzPerBin))
            let upper = min(magnitudes.count - 1, Int(high / hzPerBin))
            guard upper >= lower else { return 0 }
            let slice = magnitudes[lower...upper]
            let mean = slice.reduce(0, +) / Float(slice.count)
            return min(1, max(0, log10(1 + Double(mean) * 180) / 2.4))
        }
        let bass = band(45, 220)
        let mids = band(220, 2_500)
        let treble = band(2_500, 12_000)
        let overall = min(1, max(0, bass * 0.42 + mids * 0.38 + treble * 0.20))

        stateLock.lock()
        let attack = 0.42
        let release = 0.16
        func smooth(_ old: Double, _ new: Double) -> Double {
            let factor = new > old ? attack : release
            return old + (new - old) * factor
        }
        smoothed.bass = smooth(smoothed.bass, bass)
        smoothed.mids = smooth(smoothed.mids, mids)
        smoothed.treble = smooth(smoothed.treble, treble)
        smoothed.overall = smooth(smoothed.overall, overall)
        smoothed.available = true
        stateLock.unlock()
    }

    private enum SpectrumError: Error { case noDisplay }
}
