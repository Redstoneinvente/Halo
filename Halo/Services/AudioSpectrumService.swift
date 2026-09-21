import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreGraphics
import Accelerate
import AudioToolbox
import AVFoundation
import ShazamKit

/// System-audio analyser used by the closed-notch reactive background.
/// ScreenCaptureKit supplies PCM audio and Accelerate converts it into normalized low/mid/high energy bands.
final class AudioSpectrumService: NSObject, AudioSpectrumProviding, SCStreamOutput, SCStreamDelegate, SHSessionDelegate, @unchecked Sendable {
    static let shared = AudioSpectrumService()

    private let sampleQueue = DispatchQueue(label: "Halo.AudioSpectrum.Samples", qos: .userInitiated)
    private let stateLock = NSLock()
    private var stream: SCStream?
    private var starting = false
    private var wanted = false
    private var activeOwners = Set<String>()
    private var blockedForCurrentActivation = false
    private var permissionRequestedThisRun = false
    private var idleStopTask: Task<Void, Never>?
    private var smoothed = AudioSpectrumSnapshot()

    private struct AdaptiveBandState {
        var floor: Double = 1
        var peak: Double = 0
        var previous: Double = 0
        var output: Double = 0
        var initialized = false
    }

    private var bassAdaptive = AdaptiveBandState()
    private var midsAdaptive = AdaptiveBandState()
    private var trebleAdaptive = AdaptiveBandState()
    private var overallAdaptive = AdaptiveBandState()

    private var recognitionSession: SHSession?
    private var recognitionCompletion: ((AudioRecognitionMatch?) -> Void)?
    private var recognitionDeadline = Date.distantPast
    private var recognitionSampleRate = 0.0

    func snapshot() -> AudioSpectrumSnapshot {
        stateLock.lock(); defer { stateLock.unlock() }
        return smoothed
    }

    func setActive(_ active: Bool) { setActive(active, owner: "legacy") }

    func setActive(_ active: Bool, owner: String) {
        stateLock.lock()
        let ownerChanged: Bool
        if active {
            ownerChanged = activeOwners.insert(owner).inserted
        } else {
            ownerChanged = activeOwners.remove(owner) != nil
        }
        wanted = !activeOwners.isEmpty
        let nowWanted = wanted

        // A failed/denied capture is blocked only for the current ownership generation.
        // A genuinely new consumer, or a complete deactivate/reactivate cycle, gets one clean retry.
        if !nowWanted || (active && ownerChanged) {
            blockedForCurrentActivation = false
        }

        idleStopTask?.cancel()
        idleStopTask = nil

        let shouldStart = nowWanted && stream == nil && !starting && !blockedForCurrentActivation
        if shouldStart { starting = true }
        let current = stream
        stateLock.unlock()

        if shouldStart {
            Task { await startIfNeeded() }
        } else if !nowWanted, let current {
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

    func recognizeCurrentAudio(timeout: TimeInterval = 8, completion: @escaping (AudioRecognitionMatch?) -> Void) {
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
        if CGPreflightScreenCaptureAccess() { return true }

        stateLock.lock()
        let shouldRequest = !permissionRequestedThisRun
        if shouldRequest { permissionRequestedThisRun = true }
        stateLock.unlock()

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
            resetAdaptiveBandsLocked()
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
            configuration.queueDepth = 3
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = true
            configuration.sampleRate = 48_000
            configuration.channelCount = 2

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
            resetAdaptiveBandsLocked()
            stateLock.unlock()
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
        resetAdaptiveBandsLocked()
        blockedForCurrentActivation = false
        idleStopTask = nil
        stateLock.unlock()
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        stateLock.lock()
        if self.stream === stream { self.stream = nil }
        smoothed = AudioSpectrumSnapshot()
        resetAdaptiveBandsLocked()
        starting = false
        blockedForCurrentActivation = true
        stateLock.unlock()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio,
              sampleBuffer.isValid,
              let format = sampleBuffer.formatDescription,
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(format) else { return }

        let asbd = asbdPointer.pointee
        guard asbd.mFormatID == kAudioFormatLinearPCM else { return }

        var needed = 0
        var blockBuffer: CMBlockBuffer?
        let sizingStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &needed,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard sizingStatus == noErr || needed > 0 else { return }

        let byteCount = max(needed, MemoryLayout<AudioBufferList>.size)
        let raw = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &needed,
            bufferListOut: list,
            bufferListSize: byteCount,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return }

        let buffers = UnsafeMutableAudioBufferListPointer(list)
        guard !buffers.isEmpty else { return }

        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let isInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
        let bytesPerSample = max(1, Int(asbd.mBitsPerChannel / 8))
        let channelCount = max(1, Int(asbd.mChannelsPerFrame))
        var mono = [Float]()

        if isInterleaved, let first = buffers.first, let data = first.mData {
            let scalarCount = Int(first.mDataByteSize) / bytesPerSample
            let frameCount = min(4096, scalarCount / channelCount)
            guard frameCount >= 128 else { return }
            mono = [Float](repeating: 0, count: frameCount)

            if isFloat && asbd.mBitsPerChannel == 32 {
                let samples = data.assumingMemoryBound(to: Float.self)
                for frame in 0..<frameCount {
                    var sum: Float = 0
                    for channel in 0..<channelCount { sum += samples[frame * channelCount + channel] }
                    mono[frame] = sum / Float(channelCount)
                }
            } else if !isFloat && asbd.mBitsPerChannel == 16 {
                let samples = data.assumingMemoryBound(to: Int16.self)
                for frame in 0..<frameCount {
                    var sum: Float = 0
                    for channel in 0..<channelCount { sum += Float(samples[frame * channelCount + channel]) / 32768 }
                    mono[frame] = sum / Float(channelCount)
                }
            } else { return }
        } else {
            let validBuffers = buffers.filter { $0.mData != nil && $0.mDataByteSize >= UInt32(bytesPerSample * 128) }
            guard !validBuffers.isEmpty else { return }
            let frameCount = min(4096, validBuffers.map { Int($0.mDataByteSize) / bytesPerSample }.min() ?? 0)
            guard frameCount >= 128 else { return }
            mono = [Float](repeating: 0, count: frameCount)

            for buffer in validBuffers {
                guard let data = buffer.mData else { continue }
                if isFloat && asbd.mBitsPerChannel == 32 {
                    let samples = data.assumingMemoryBound(to: Float.self)
                    for i in 0..<frameCount { mono[i] += samples[i] / Float(validBuffers.count) }
                } else if !isFloat && asbd.mBitsPerChannel == 16 {
                    let samples = data.assumingMemoryBound(to: Int16.self)
                    for i in 0..<frameCount { mono[i] += (Float(samples[i]) / 32768) / Float(validBuffers.count) }
                } else { return }
            }
        }

        let sampleRate = max(8_000, Double(asbd.mSampleRate))
        feedRecognition(mono, sampleRate: sampleRate)
        analyse(mono, sampleRate: sampleRate)
    }

    private func resetAdaptiveBandsLocked() {
        bassAdaptive = AdaptiveBandState()
        midsAdaptive = AdaptiveBandState()
        trebleAdaptive = AdaptiveBandState()
        overallAdaptive = AdaptiveBandState()
    }

    private static func adaptiveEnvelope(_ value: Double, state: inout AdaptiveBandState) -> Double {
        let x = min(1, max(0, value))

        if !state.initialized {
            state.floor = x
            state.peak = min(1, x + 0.10)
            state.previous = x
            state.output = 0
            state.initialized = true
            return 0
        }

        // The floor should follow genuine quiet sections fairly quickly but only creep upward
        // during loud passages. Peak does the inverse: catch attacks quickly, decay slowly.
        let floorRate = x < state.floor ? 0.20 : 0.006
        let peakRate = x > state.peak ? 0.42 : 0.018
        state.floor += (x - state.floor) * floorRate
        state.peak += (x - state.peak) * peakRate

        if state.peak < state.floor + 0.07 {
            state.peak = min(1, state.floor + 0.07)
        }

        let dynamicRange = max(0.07, state.peak - state.floor)
        let level = min(1, max(0, (x - state.floor) / dynamicRange))

        // Positive band-energy changes are musical attacks (kick, snare, vocal consonants, hats).
        // Blend them with the adaptive level so sustained notes remain present but transients pop.
        let onset = min(1, max(0, x - state.previous) * 8.0)
        state.previous = x
        let target = min(1, level * 0.74 + onset * 0.48)

        let response = target > state.output ? 0.72 : 0.24
        state.output += (target - state.output) * response
        return min(1, max(0, state.output))
    }

    private func analyse(_ input: [Float], sampleRate: Double) {
        let n = 2048
        guard input.count >= 128 else { return }

        var samples = [Float](repeating: 0, count: n)
        let copyCount = min(n, input.count)
        samples.replaceSubrange(0..<copyCount, with: input.prefix(copyCount))

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(copyCount))

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
                real.withUnsafeMutableBufferPointer { realBuffer in
                    imag.withUnsafeMutableBufferPointer { imagBuffer in
                        guard let realBase = realBuffer.baseAddress, let imagBase = imagBuffer.baseAddress else { return }
                        var split = DSPSplitComplex(realp: realBase, imagp: imagBase)
                        vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(n / 2))
                        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                        vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(n / 2))
                    }
                }
            }
        }

        func normalizedDB(_ amplitude: Double, floor: Double = -68, ceiling: Double = -10) -> Double {
            let db = 20 * log10(max(0.0000001, amplitude))
            return min(1, max(0, (db - floor) / (ceiling - floor)))
        }

        let hzPerBin = sampleRate / Double(n)
        func band(_ low: Double, _ high: Double) -> Double {
            let lower = max(1, Int(low / hzPerBin))
            let upper = min(magnitudes.count - 1, Int(high / hzPerBin))
            guard upper >= lower else { return 0 }
            var meanPower: Float = 0
            magnitudes.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                vDSP_meanv(base.advanced(by: lower), 1, &meanPower, vDSP_Length(upper - lower + 1))
            }
            let amplitude = sqrt(max(0, Double(meanPower))) * 2 / Double(n)
            return normalizedDB(amplitude, floor: -74, ceiling: -18)
        }

        let bass = band(45, 220)
        let mids = band(220, 2_500)
        let treble = band(2_500, min(18_000, sampleRate * 0.45))
        let overall = normalizedDB(Double(rms), floor: -58, ceiling: -8)

        stateLock.lock()
        let attack = 0.58
        let release = 0.22
        func smooth(_ old: Double, _ new: Double) -> Double {
            let factor = new > old ? attack : release
            return old + (new - old) * factor
        }
        smoothed.bass = smooth(smoothed.bass, bass)
        smoothed.mids = smooth(smoothed.mids, mids)
        smoothed.treble = smooth(smoothed.treble, treble)
        smoothed.overall = smooth(smoothed.overall, overall)

        let reactiveBass = Self.adaptiveEnvelope(bass, state: &bassAdaptive)
        let reactiveMids = Self.adaptiveEnvelope(mids, state: &midsAdaptive)
        let reactiveTreble = Self.adaptiveEnvelope(treble, state: &trebleAdaptive)
        let reactiveOverall = Self.adaptiveEnvelope(overall, state: &overallAdaptive)
        smoothed.reactiveBass = reactiveBass
        smoothed.reactiveMids = reactiveMids
        smoothed.reactiveTreble = reactiveTreble
        smoothed.reactiveOverall = reactiveOverall

        // Keep liveness raw. A smoothed release here can take several seconds to decay and is
        // appropriate for animation, not for deciding whether Audio CI should still exist.
        smoothed.liveness = max(overall, mids * 0.82, bass * 0.62, treble * 0.68)
        smoothed.available = rms > 0.00001
        stateLock.unlock()
    }

    private func feedRecognition(_ input: [Float], sampleRate: Double) {
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
