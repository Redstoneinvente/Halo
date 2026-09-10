import Foundation
import ScreenCaptureKit
import CoreMedia
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
/// ScreenCaptureKit supplies PCM buffers; Accelerate reduces each buffer into low/mid/high energy bands.
final class AudioSpectrumService: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    static let shared = AudioSpectrumService()

    private let sampleQueue = DispatchQueue(label: "Halo.AudioSpectrum.Samples", qos: .userInitiated)
    private let stateLock = NSLock()
    private var stream: SCStream?
    private var starting = false
    private var wanted = false
    private var smoothed = AudioSpectrumSnapshot()

    func snapshot() -> AudioSpectrumSnapshot {
        stateLock.lock(); defer { stateLock.unlock() }
        return smoothed
    }

    func setActive(_ active: Bool) {
        stateLock.lock()
        wanted = active
        let shouldStart = active && stream == nil && !starting
        if shouldStart { starting = true }
        let current = stream
        stateLock.unlock()

        if shouldStart {
            Task { await startIfNeeded() }
        } else if !active, let current {
            Task {
                try? await current.stopCapture()
                stateLock.lock()
                if stream === current { stream = nil }
                smoothed = AudioSpectrumSnapshot()
                stateLock.unlock()
            }
        }
    }

    private func startIfNeeded() async {
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
        } catch {
            stateLock.lock()
            starting = false
            stream = nil
            smoothed.available = false
            stateLock.unlock()
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        stateLock.lock()
        if self.stream === stream { self.stream = nil }
        smoothed = AudioSpectrumSnapshot()
        let restart = wanted && !starting
        if restart { starting = true }
        stateLock.unlock()
        if restart { Task { await startIfNeeded() } }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, sampleBuffer.isValid,
              let format = sampleBuffer.formatDescription,
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(format) else { return }
        let asbd = asbdPointer.pointee
        guard asbd.mFormatID == kAudioFormatLinearPCM else { return }

        var blockBuffer: CMBlockBuffer?
        var bufferList = AudioBufferList(mNumberBuffers: 0, mBuffers: AudioBuffer())
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
        guard status == noErr else { return }

        let buffers = UnsafeMutableAudioBufferListPointer(&bufferList)
        guard let first = buffers.first, let data = first.mData else { return }
        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let channels = max(1, Int(asbd.mChannelsPerFrame))
        let interleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
        let bytesPerSample = max(1, Int(asbd.mBitsPerChannel / 8))
        let availableFrames = Int(first.mDataByteSize) / max(1, bytesPerSample * (interleaved ? channels : 1))
        let count = min(2048, availableFrames)
        guard count >= 128 else { return }

        var mono = [Float](repeating: 0, count: count)
        if isFloat && asbd.mBitsPerChannel == 32 {
            let samples = data.assumingMemoryBound(to: Float.self)
            if interleaved {
                for i in 0..<count {
                    var sum: Float = 0
                    for channel in 0..<channels { sum += samples[i * channels + channel] }
                    mono[i] = sum / Float(channels)
                }
            } else {
                for i in 0..<count { mono[i] = samples[i] }
            }
        } else if !isFloat && asbd.mBitsPerChannel == 16 {
            let samples = data.assumingMemoryBound(to: Int16.self)
            if interleaved {
                for i in 0..<count {
                    var sum: Float = 0
                    for channel in 0..<channels { sum += Float(samples[i * channels + channel]) / 32768 }
                    mono[i] = sum / Float(channels)
                }
            } else {
                for i in 0..<count { mono[i] = Float(samples[i]) / 32768 }
            }
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
        vDSP.multiply(samples, window, result: &samples)

        var real = [Float](repeating: 0, count: n / 2)
        var imag = [Float](repeating: 0, count: n / 2)
        var magnitudes = [Float](repeating: 0, count: n / 2)
        samples.withUnsafeBufferPointer { source in
            source.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) { complex in
                var split = DSPSplitComplex(realp: &real, imagp: &imag)
                vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(n / 2))
                guard let setup = vDSP_create_fftsetup(vDSP_Length(log2(Float(n))), FFTRadix(kFFTRadix2)) else { return }
                defer { vDSP_destroy_fftsetup(setup) }
                vDSP_fft_zrip(setup, &split, 1, vDSP_Length(log2(Float(n))), FFTDirection(FFT_FORWARD))
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