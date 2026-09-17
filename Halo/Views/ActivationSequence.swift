import SwiftUI
import AppKit
import AVFoundation
import CoreAudio
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - Activation Sequence model

enum ActivationEvent: String, Codable, Equatable {
    case manualLaunch
    case loginLaunch
    case relaunchAfterQuit
    case wake
    case preview

    var title: String {
        switch self {
        case .manualLaunch: return "Manual launch"
        case .loginLaunch: return "Launch at login"
        case .relaunchAfterQuit: return "Relaunch after quit"
        case .wake: return "Wake"
        case .preview: return "Preview"
        }
    }
}

struct ActivationLaunchContext: Equatable {
    var event: ActivationEvent
    var macJustStarted: Bool
}

enum ActivationPreset: String, Codable, CaseIterable, Identifiable, Hashable {
    case haloReveal = "Halo Reveal"
    case powerOn = "Power On"
    case lightSweep = "Light Sweep"
    case softPulse = "Soft Pulse"
    case aperture = "Aperture"
    case liquid = "Liquid"
    case materialize = "Materialize"
    case digitalBoot = "Digital Boot"
    case neonIgnition = "Neon Ignition"
    case spark = "Spark"
    case ripple = "Ripple"
    case warpIn = "Warp In"
    case blackHole = "Black Hole"
    case minimalFade = "Minimal Fade"
    case none = "None"

    var id: String { rawValue }

    var category: String {
        switch self {
        case .minimalFade, .softPulse, .none: return "Minimal"
        case .haloReveal, .powerOn, .lightSweep, .aperture, .liquid: return "Elegant"
        case .digitalBoot, .neonIgnition, .spark, .warpIn: return "Futuristic"
        case .materialize, .ripple, .blackHole: return "Expressive"
        }
    }

    var defaultDuration: Double {
        switch self {
        case .minimalFade: return 0.34
        case .softPulse: return 0.55
        case .haloReveal: return 0.95
        case .powerOn: return 0.88
        case .lightSweep: return 0.72
        case .aperture: return 0.78
        case .liquid: return 0.82
        case .digitalBoot: return 0.72
        case .neonIgnition: return 0.82
        case .spark: return 0.62
        case .warpIn: return 0.72
        case .materialize: return 1.10
        case .ripple: return 0.86
        case .blackHole: return 1.22
        case .none: return 0.3
        }
    }
}

enum ActivationSound: String, Codable, CaseIterable, Identifiable {
    case off = "Off"
    case softChime = "Soft Chime"
    case glassTick = "Glass Tick"
    case digitalPing = "Digital Ping"
    case lowPulse = "Low Pulse"
    case softWhoosh = "Soft Whoosh"
    case energySweep = "Energy Sweep"
    case tinySpark = "Tiny Spark"
    case startupTone = "Startup Tone"
    case custom = "Custom Sound"
    var id: String { rawValue }
}

enum ActivationDisplayTarget: String, Codable, CaseIterable, Identifiable {
    case primaryOnly = "Primary Display Only"
    case allHaloDisplays = "All Halo Displays"
    case notchDisplayOnly = "Display With Notch Only"
    var id: String { rawValue }
}

enum ActivationColorSource: String, Codable, CaseIterable, Identifiable {
    case haloAccent = "Halo Accent"
    case systemAccent = "System Accent"
    case custom = "Custom"
    case gradient = "Gradient"
    case wallpaper = "Wallpaper-derived"
    case currentTheme = "Current Theme"
    var id: String { rawValue }
}

enum ActivationSweepDirection: String, Codable, CaseIterable, Identifiable {
    case leftToRight = "Left → Right"
    case rightToLeft = "Right → Left"
    case centerOut = "Center → Outward"
    case edgesIn = "Edges → Center"
    var id: String { rawValue }
}

enum ActivationMotionProfile: String, Codable, CaseIterable, Identifiable {
    case calm = "Calm"
    case fluid = "Fluid"
    case snappy = "Snappy"
    var id: String { rawValue }
}

struct ActivationRGBA: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    static let halo = ActivationRGBA(red: 0.34, green: 0.72, blue: 1.0)
    static let haloSecondary = ActivationRGBA(red: 0.72, green: 0.42, blue: 1.0)

    var color: Color { Color(red: red, green: green, blue: blue, opacity: alpha) }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    init(nsColor: NSColor) {
        let value = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        red = Double(value.redComponent)
        green = Double(value.greenComponent)
        blue = Double(value.blueComponent)
        alpha = Double(value.alphaComponent)
    }

    init(color: Color) {
        self.init(nsColor: NSColor(color))
    }

    func normalized() -> ActivationRGBA {
        ActivationRGBA(red: min(1, max(0, red)), green: min(1, max(0, green)), blue: min(1, max(0, blue)), alpha: min(1, max(0, alpha)))
    }
}

struct ActivationSequenceSettings: Codable, Equatable {
    var enabled = true

    var playManualLaunch = true
    var playLoginLaunch = true
    var playMacStartup = true
    var playRelaunchAfterQuit = true
    var playAfterWake = false

    var preset: ActivationPreset = .haloReveal
    var randomFavorite = false
    var favoritePresets: Set<ActivationPreset> = [.haloReveal, .powerOn, .lightSweep]

    var duration = 0.95
    var intensity = 0.72
    var motion: ActivationMotionProfile = .fluid
    var glowThickness = 2.0
    var scale = 1.035
    var overshoot = 0.045
    var bounce = 0.18
    var blur = 7.0
    var distortion = 0.20
    var trail = 0.46
    var particleCount = 38
    var particleSpeed = 1.0
    var particleSpread = 1.0
    var particleSize = 2.0
    var particleGlow = 0.62
    var sweepDirection: ActivationSweepDirection = .leftToRight

    var colorSource: ActivationColorSource = .currentTheme
    var customColor = ActivationRGBA.halo
    var gradientColor = ActivationRGBA.haloSecondary

    var sound: ActivationSound = .off
    var soundVolume = 0.32
    var soundCue = 0.48
    var respectSystemVolume = true
    var customSoundPath = ""

    var displayTarget: ActivationDisplayTarget = .notchDisplayOnly

    func normalized() -> ActivationSequenceSettings {
        var value = self
        value.duration = min(2.5, max(0.3, duration))
        value.intensity = min(1, max(0, intensity))
        value.glowThickness = min(8, max(0.5, glowThickness))
        value.scale = min(1.16, max(1.0, scale))
        value.overshoot = min(0.24, max(0, overshoot))
        value.bounce = min(1, max(0, bounce))
        value.blur = min(30, max(0, blur))
        value.distortion = min(1, max(0, distortion))
        value.trail = min(1, max(0, trail))
        value.particleCount = min(120, max(6, particleCount))
        value.particleSpeed = min(2.4, max(0.3, particleSpeed))
        value.particleSpread = min(2.2, max(0.2, particleSpread))
        value.particleSize = min(8, max(0.6, particleSize))
        value.particleGlow = min(1, max(0, particleGlow))
        value.customColor = customColor.normalized()
        value.gradientColor = gradientColor.normalized()
        value.soundVolume = min(1, max(0, soundVolume))
        value.soundCue = min(1, max(0, soundCue))
        value.favoritePresets.remove(.none)
        return value
    }

    func allows(_ context: ActivationLaunchContext) -> Bool {
        guard enabled, preset != .none else { return false }
        if context.macJustStarted && playMacStartup { return true }
        switch context.event {
        case .manualLaunch: return playManualLaunch
        case .loginLaunch: return playLoginLaunch
        case .relaunchAfterQuit: return playRelaunchAfterQuit
        case .wake: return playAfterWake
        case .preview: return true
        }
    }
}

@MainActor
final class ActivationSequenceStore: ObservableObject {
    static let shared = ActivationSequenceStore()
    private let defaults: UserDefaults
    private let storageKey = "HaloActivationSequence.v1"

    @Published var settings: ActivationSequenceSettings {
        didSet { persist() }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(ActivationSequenceSettings.self, from: data) {
            settings = decoded.normalized()
        } else {
            settings = ActivationSequenceSettings()
        }
    }

    func update(_ body: (inout ActivationSequenceSettings) -> Void) {
        var next = settings
        body(&next)
        settings = next.normalized()
    }

    func selectPreset(_ preset: ActivationPreset) {
        update { value in
            value.preset = preset
            value.duration = preset.defaultDuration
            switch preset {
            case .minimalFade:
                value.intensity = 0.34; value.blur = 4; value.overshoot = 0; value.bounce = 0
            case .softPulse:
                value.intensity = 0.46; value.scale = 1.025; value.bounce = 0.12
            case .haloReveal:
                value.intensity = 0.72; value.glowThickness = 2; value.scale = 1.025
            case .powerOn:
                value.intensity = 0.68; value.glowThickness = 2.2; value.overshoot = 0.02
            case .lightSweep:
                value.intensity = 0.62; value.trail = 0.48
            case .aperture:
                value.intensity = 0.60; value.overshoot = 0.04
            case .liquid:
                value.intensity = 0.60; value.bounce = 0.22; value.overshoot = 0.035
            case .materialize:
                value.intensity = 0.66; value.particleCount = 42; value.particleSpread = 1.0; value.particleGlow = 0.58
            case .digitalBoot:
                value.intensity = 0.58; value.trail = 0.32
            case .neonIgnition:
                value.intensity = 0.68; value.glowThickness = 2.3
            case .spark:
                value.intensity = 0.70; value.trail = 0.58; value.particleGlow = 0.72
            case .ripple:
                value.intensity = 0.54; value.particleSpread = 1.15
            case .warpIn:
                value.intensity = 0.55; value.distortion = 0.26; value.overshoot = 0.04
            case .blackHole:
                value.intensity = 0.72; value.particleCount = 54; value.particleSpread = 1.25; value.distortion = 0.28
            case .none:
                break
            }
        }
    }

    func reset() { settings = ActivationSequenceSettings() }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings.normalized()) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

struct ActivationDisplayDescriptor {
    var id: String
    var screenFrame: CGRect
    var hasNotch: Bool
    var isMain: Bool
    var themeTint: Double
    var wallpaperURL: URL?
}

struct ActivationPresentation: Identifiable, Equatable {
    var id = UUID()
    var event: ActivationEvent
    var preset: ActivationPreset
    var settings: ActivationSequenceSettings
    var targetDisplayIDs: Set<String>
    var startDate: Date
    var primaryColor: ActivationRGBA
    var secondaryColor: ActivationRGBA
}

// MARK: - Sound

@MainActor
private final class ActivationSoundPlayer {
    private var player: AVAudioPlayer?
    private var builtins: [ActivationSound: Data] = [:]
    private var cachedCustomPath = ""
    private var cachedCustomData: Data?
    private var cachedCustomGain: Float = 1

    init() {
        for sound in ActivationSound.allCases where sound != .off && sound != .custom {
            builtins[sound] = Self.makeWAV(for: sound)
        }
    }

    func stop() { player?.stop(); player = nil }

    func prewarmCustom(path: String) {
        guard path != cachedCustomPath else { return }
        cachedCustomPath = path
        cachedCustomData = nil
        cachedCustomGain = 1
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        guard Self.validateCustom(url: url),
              let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
              data.count <= 8_000_000 else { return }
        cachedCustomData = data
        cachedCustomGain = Self.normalizedGain(url: url)
    }

    func play(sound: ActivationSound, volume: Double, customPath: String) {
        stop()
        guard sound != .off, volume > 0.001 else { return }
        do {
            let next: AVAudioPlayer
            if sound == .custom {
                prewarmCustom(path: customPath)
                guard let cachedCustomData else { return }
                next = try AVAudioPlayer(data: cachedCustomData)
                next.volume = min(1, Float(volume) * cachedCustomGain)
            } else {
                guard let data = builtins[sound] else { return }
                next = try AVAudioPlayer(data: data)
                next.volume = Float(min(1, volume))
            }
            next.prepareToPlay()
            next.play()
            player = next
        } catch {
            player = nil
        }
    }

    static func validateCustom(url: URL) -> Bool {
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return false }
        return player.duration > 0.02 && player.duration <= 3.0
    }

    private static func normalizedGain(url: URL) -> Float {
        guard let file = try? AVAudioFile(forReading: url) else { return 1 }
        let format = file.processingFormat
        let sampleRate = max(1, format.sampleRate)
        let maxFrames = min(file.length, AVAudioFramePosition(sampleRate * 3.0))
        guard maxFrames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(maxFrames)) else { return 1 }
        do { try file.read(into: buffer, frameCount: AVAudioFrameCount(maxFrames)) } catch { return 1 }
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 1 }
        var peak: Float = 0
        for channel in 0..<Int(format.channelCount) {
            let samples = channels[channel]
            for index in 0..<Int(buffer.frameLength) { peak = max(peak, abs(samples[index])) }
        }
        guard peak > 0.001 else { return 1 }
        return min(1.35, 0.72 / peak)
    }

    private static func makeWAV(for sound: ActivationSound) -> Data {
        let sampleRate = 44_100
        let duration: Double
        switch sound {
        case .glassTick, .tinySpark: duration = 0.15
        case .digitalPing: duration = 0.22
        case .lowPulse: duration = 0.28
        case .softWhoosh, .energySweep: duration = 0.34
        case .softChime, .startupTone: duration = 0.46
        default: duration = 0.22
        }
        let count = max(1, Int(Double(sampleRate) * duration))
        var pcm = [Int16](repeating: 0, count: count)
        var noise: UInt32 = 0x12345678
        for index in 0..<count {
            let t = Double(index) / Double(sampleRate)
            let x = Double(index) / Double(max(1, count - 1))
            let attack = min(1, x / 0.035)
            let release = min(1, max(0, (1 - x) / 0.28))
            let envelope = attack * release
            noise = 1664525 &* noise &+ 1013904223
            let white = (Double(noise & 0xFFFF) / 32767.5) - 1
            let signal: Double
            switch sound {
            case .softChime:
                signal = 0.55 * sin(2 * .pi * 660 * t) + 0.28 * sin(2 * .pi * 990 * t) + 0.14 * sin(2 * .pi * 1320 * t)
            case .glassTick:
                signal = 0.68 * sin(2 * .pi * 1760 * t) + 0.22 * sin(2 * .pi * 2310 * t)
            case .digitalPing:
                let frequency = x < 0.48 ? 1040.0 : 780.0
                signal = 0.76 * sin(2 * .pi * frequency * t) + 0.12 * sin(2 * .pi * frequency * 2 * t)
            case .lowPulse:
                signal = 0.74 * sin(2 * .pi * 112 * t) + 0.18 * sin(2 * .pi * 224 * t)
            case .softWhoosh:
                signal = white * (0.10 + 0.55 * sin(.pi * x)) + 0.10 * sin(2 * .pi * (180 + 260 * x) * t)
            case .energySweep:
                let frequency = 420 + 1180 * x
                signal = 0.55 * sin(2 * .pi * frequency * t) + 0.18 * sin(2 * .pi * frequency * 1.5 * t)
            case .tinySpark:
                signal = 0.38 * white + 0.55 * sin(2 * .pi * (1800 + 700 * x) * t)
            case .startupTone:
                signal = 0.46 * sin(2 * .pi * 440 * t) + 0.32 * sin(2 * .pi * 660 * t) + 0.16 * sin(2 * .pi * 880 * t)
            default:
                signal = 0
            }
            let value = max(-1, min(1, signal * envelope * 0.52))
            pcm[index] = Int16(value * Double(Int16.max))
        }

        var data = Data()
        func ascii(_ value: String) { data.append(value.data(using: .ascii) ?? Data()) }
        func le16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func le32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        let dataBytes = UInt32(pcm.count * MemoryLayout<Int16>.size)
        ascii("RIFF"); le32(36 + dataBytes); ascii("WAVE")
        ascii("fmt "); le32(16); le16(1); le16(1); le32(UInt32(sampleRate)); le32(UInt32(sampleRate * 2)); le16(2); le16(16)
        ascii("data"); le32(dataBytes)
        for sample in pcm { var s = sample.littleEndian; withUnsafeBytes(of: &s) { data.append(contentsOf: $0) } }
        return data
    }
}

// MARK: - Coordinator

@MainActor
final class ActivationSequenceCoordinator: ObservableObject {
    static let shared = ActivationSequenceCoordinator()

    @Published private(set) var presentation: ActivationPresentation?
    private let settingsStore = ActivationSequenceStore.shared
    private let soundPlayer = ActivationSoundPlayer()
    private var finishTask: Task<Void, Never>?
    private var soundTask: Task<Void, Never>?
    private var lastPlayDate = Date.distantPast
    private var wallpaperCache: [String: ActivationRGBA] = [:]

    private let quitBootKey = "HaloActivationLastQuitBoot.v1"
    private let loginBootKey = "HaloActivationLoginBoot.v1"

    private init() {
        soundPlayer.prewarmCustom(path: settingsStore.settings.customSoundPath)
    }

    func classifyStartup() -> ActivationLaunchContext {
        let defaults = UserDefaults.standard
        let boot = bootSessionID
        let uptime = ProcessInfo.processInfo.systemUptime
        let macJustStarted = uptime < 210

        if defaults.string(forKey: quitBootKey) == boot {
            defaults.removeObject(forKey: quitBootKey)
            return ActivationLaunchContext(event: .relaunchAfterQuit, macJustStarted: macJustStarted)
        }

        let loginEnabled = SMAppService.mainApp.status == .enabled
        if loginEnabled && defaults.string(forKey: loginBootKey) != boot && uptime < 900 {
            defaults.set(boot, forKey: loginBootKey)
            return ActivationLaunchContext(event: .loginLaunch, macJustStarted: macJustStarted)
        }
        return ActivationLaunchContext(event: .manualLaunch, macJustStarted: macJustStarted)
    }

    func markQuit() {
        UserDefaults.standard.set(bootSessionID, forKey: quitBootKey)
    }

    func shouldPlay(_ context: ActivationLaunchContext) -> Bool {
        settingsStore.settings.normalized().allows(context)
    }

    func prewarmCustomSound(path: String) { soundPlayer.prewarmCustom(path: path) }

    func previewSound() {
        let settings = settingsStore.settings.normalized()
        soundPlayer.play(sound: settings.sound, volume: settings.soundVolume, customPath: settings.customSoundPath)
    }

    func play(context: ActivationLaunchContext,
              displays: [ActivationDisplayDescriptor],
              systemVolume: Float32?) {
        let settings = settingsStore.settings.normalized()
        guard settings.allows(context), !displays.isEmpty else { return }
        begin(event: context.event, settings: settings, displays: displays, systemVolume: systemVolume)
    }

    func preview(displays: [ActivationDisplayDescriptor], systemVolume: Float32?) {
        var settings = settingsStore.settings.normalized()
        guard settings.enabled, settings.preset != .none, !displays.isEmpty else { return }
        settings.randomFavorite = false
        begin(event: .preview, settings: settings, displays: displays, systemVolume: systemVolume)
    }

    func cancelForInteraction() {
        guard presentation != nil else { return }
        finishTask?.cancel(); soundTask?.cancel(); soundPlayer.stop()
        withAnimation(.easeOut(duration: 0.11)) { presentation = nil }
    }

    private func begin(event: ActivationEvent,
                       settings: ActivationSequenceSettings,
                       displays: [ActivationDisplayDescriptor],
                       systemVolume: Float32?) {
        if Date().timeIntervalSince(lastPlayDate) < 0.18 { return }
        lastPlayDate = Date()
        finishTask?.cancel(); soundTask?.cancel(); soundPlayer.stop()

        let targetIDs = resolveTargets(settings.displayTarget, displays: displays)
        guard !targetIDs.isEmpty else { return }
        let targetDescriptor = displays.first { targetIDs.contains($0.id) } ?? displays[0]
        let preset = resolvedPreset(settings)
        guard preset != .none else { return }
        let colors = resolveColors(settings: settings, display: targetDescriptor)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let duration = reduceMotion ? min(0.52, settings.duration) : settings.duration
        var snapshot = settings
        snapshot.duration = duration
        snapshot.preset = preset
        let token = UUID()
        presentation = ActivationPresentation(id: token, event: event, preset: preset, settings: snapshot,
                                              targetDisplayIDs: targetIDs,
                                              startDate: Date().addingTimeInterval(0.035),
                                              primaryColor: colors.0, secondaryColor: colors.1)

        let cueDelay = 0.035 + duration * settings.soundCue
        soundTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, cueDelay) * 1_000_000_000))
            guard !Task.isCancelled, let self, self.presentation?.id == token else { return }
            if settings.respectSystemVolume {
                if Self.systemOutputIsMuted() { return }
                if let systemVolume, systemVolume <= 0.003 { return }
            }
            self.soundPlayer.play(sound: settings.sound, volume: settings.soundVolume, customPath: settings.customSoundPath)
        }

        finishTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((duration + 0.10) * 1_000_000_000))
            guard !Task.isCancelled, let self, self.presentation?.id == token else { return }
            self.presentation = nil
        }
    }

    private static func systemOutputIsMuted() -> Bool {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, 0, nil, &size, &device) == noErr,
              device != 0 else { return false }
        var muted: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &muteAddress),
              AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &muted) == noErr else { return false }
        return muted != 0
    }

    private func resolvedPreset(_ settings: ActivationSequenceSettings) -> ActivationPreset {
        guard settings.randomFavorite else { return settings.preset }
        let choices = settings.favoritePresets.filter { $0 != .none }
        return choices.randomElement() ?? settings.preset
    }

    private func resolveTargets(_ target: ActivationDisplayTarget,
                                displays: [ActivationDisplayDescriptor]) -> Set<String> {
        switch target {
        case .allHaloDisplays:
            return Set(displays.map(\.id))
        case .primaryOnly:
            return Set([(displays.first(where: \.isMain) ?? displays[0]).id])
        case .notchDisplayOnly:
            let chosen = displays.first(where: { $0.isMain && $0.hasNotch }) ?? displays.first(where: \.hasNotch) ?? displays.first(where: \.isMain) ?? displays[0]
            return Set([chosen.id])
        }
    }

    private func resolveColors(settings: ActivationSequenceSettings,
                               display: ActivationDisplayDescriptor) -> (ActivationRGBA, ActivationRGBA) {
        switch settings.colorSource {
        case .custom:
            return (settings.customColor, settings.customColor)
        case .gradient:
            return (settings.customColor, settings.gradientColor)
        case .systemAccent:
            let accent = ActivationRGBA(nsColor: .controlAccentColor)
            return (accent, accent)
        case .haloAccent:
            return (.halo, .haloSecondary)
        case .currentTheme:
            let hue = min(1, max(0, display.themeTint))
            let primary = ActivationRGBA(nsColor: NSColor(calibratedHue: hue, saturation: 0.68, brightness: 1, alpha: 1))
            let secondary = ActivationRGBA(nsColor: NSColor(calibratedHue: (hue + 0.10).truncatingRemainder(dividingBy: 1), saturation: 0.52, brightness: 1, alpha: 1))
            return (primary, secondary)
        case .wallpaper:
            if let url = display.wallpaperURL {
                let key = url.path
                if let cached = wallpaperCache[key] { return (cached, cached) }
                if let sampled = Self.averageWallpaperColor(url: url) {
                    wallpaperCache[key] = sampled
                    return (sampled, sampled)
                }
            }
            return (.halo, .haloSecondary)
        }
    }

    private static func averageWallpaperColor(url: URL) -> ActivationRGBA? {
        guard let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .low
        context.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return ActivationRGBA(red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255, blue: Double(pixel[2]) / 255)
    }

    private var bootSessionID: String {
        let start = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
        return String(Int(start / 30))
    }
}

// MARK: - Geometry-aware renderer

private struct ActivationSurfaceShape: Shape {
    var kind: SurfaceShapeKind
    var topRadius: Double
    var bottomRadius: Double
    var shoulder: Double

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        guard w > 1, h > 1 else { return Path(rect) }
        let top = min(CGFloat(topRadius), h / 2, w / 2)
        let bottom = min(CGFloat(bottomRadius), h / 2, w / 2)
        let s = min(CGFloat(shoulder), w * 0.22)
        switch kind {
        case .capsule:
            return Capsule().path(in: rect)
        case .squircle:
            return RoundedRectangle(cornerRadius: min(w, h) * 0.34, style: .continuous).path(in: rect)
        case .chamfer:
            var p = Path()
            let cut = min(max(4, bottom * 0.62), min(w, h) * 0.28)
            p.move(to: CGPoint(x: cut, y: 0)); p.addLine(to: CGPoint(x: w - cut, y: 0)); p.addLine(to: CGPoint(x: w, y: cut))
            p.addLine(to: CGPoint(x: w, y: h - cut)); p.addLine(to: CGPoint(x: w - cut, y: h)); p.addLine(to: CGPoint(x: cut, y: h)); p.addLine(to: CGPoint(x: 0, y: h - cut)); p.addLine(to: CGPoint(x: 0, y: cut)); p.closeSubpath(); return p
        case .tapered:
            var p = Path(); let inset = min(s, w * 0.16)
            p.move(to: CGPoint(x: top, y: 0)); p.addLine(to: CGPoint(x: w - top, y: 0))
            p.addQuadCurve(to: CGPoint(x: w - inset, y: top), control: CGPoint(x: w, y: 0))
            p.addLine(to: CGPoint(x: w, y: h - bottom)); p.addQuadCurve(to: CGPoint(x: w - bottom, y: h), control: CGPoint(x: w, y: h))
            p.addLine(to: CGPoint(x: bottom, y: h)); p.addQuadCurve(to: CGPoint(x: 0, y: h - bottom), control: CGPoint(x: 0, y: h))
            p.addLine(to: CGPoint(x: inset, y: top)); p.addQuadCurve(to: CGPoint(x: top, y: 0), control: CGPoint(x: 0, y: 0)); p.closeSubpath(); return p
        case .asymmetric:
            var p = Path();
            p.move(to: CGPoint(x: top, y: 0)); p.addLine(to: CGPoint(x: w - top * 0.55, y: 0));
            p.addQuadCurve(to: CGPoint(x: w, y: top * 0.55), control: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: h - bottom));
            p.addQuadCurve(to: CGPoint(x: w - bottom, y: h), control: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: bottom * 0.65, y: h));
            p.addQuadCurve(to: CGPoint(x: 0, y: h - bottom * 0.65), control: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: 0, y: top));
            p.addQuadCurve(to: CGPoint(x: top, y: 0), control: CGPoint(x: 0, y: 0)); p.closeSubpath(); return p
        case .notch, .scoop:
            var p = Path(); let shoulderDepth = kind == .scoop ? min(h * 0.48, s) : min(h * 0.28, s * 0.6)
            p.move(to: CGPoint(x: top, y: 0)); p.addLine(to: CGPoint(x: w - top, y: 0));
            p.addQuadCurve(to: CGPoint(x: w, y: top), control: CGPoint(x: w, y: 0));
            p.addLine(to: CGPoint(x: w, y: max(top, h - bottom - shoulderDepth)));
            p.addCurve(to: CGPoint(x: w - bottom - s, y: h), control1: CGPoint(x: w, y: h - bottom * 0.25), control2: CGPoint(x: w - bottom * 0.35, y: h));
            p.addLine(to: CGPoint(x: bottom + s, y: h));
            p.addCurve(to: CGPoint(x: 0, y: max(top, h - bottom - shoulderDepth)), control1: CGPoint(x: bottom * 0.35, y: h), control2: CGPoint(x: 0, y: h - bottom * 0.25));
            p.addLine(to: CGPoint(x: 0, y: top)); p.addQuadCurve(to: CGPoint(x: top, y: 0), control: CGPoint(x: 0, y: 0)); p.closeSubpath(); return p
        case .rounded:
            return RoundedRectangle(cornerRadius: max(top, bottom), style: .continuous).path(in: rect)
        }
    }
}

private struct ActivationParticleLayer: View {
    var progress: Double
    var settings: ActivationSequenceSettings
    var color: Color
    var inward: Bool
    var blackHole: Bool = false

    var body: some View {
        Canvas { context, size in
            let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            let count = lowPower ? max(6, settings.particleCount / 2) : settings.particleCount
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let spread = max(size.width, size.height) * 0.58 * settings.particleSpread
            for index in 0..<count {
                let seed = Double(index + 1)
                let angle = (seed * 2.399963229728653).truncatingRemainder(dividingBy: .pi * 2)
                let radial = 0.34 + (sin(seed * 7.13) + 1) * 0.33
                let start = CGPoint(x: center.x + cos(angle) * spread * radial,
                                    y: center.y + sin(angle) * spread * radial * 0.42)
                let edgeRadiusX = max(4, size.width / 2 - 5)
                let edgeRadiusY = max(4, size.height / 2 - 4)
                let target = CGPoint(x: center.x + cos(angle) * edgeRadiusX,
                                     y: center.y + sin(angle) * edgeRadiusY)
                let paced = min(1, max(0, progress * settings.particleSpeed))
                let t = inward ? paced : (1 - paced)
                let destination = blackHole ? center : target
                let x = start.x + (destination.x - start.x) * t
                let y = start.y + (destination.y - start.y) * t
                let life = sin(.pi * progress)
                let radius = max(0.5, settings.particleSize * (0.55 + 0.6 * radial))
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(life * settings.particleGlow)))
            }
        }
        .blur(radius: settings.particleGlow * 1.2)
        .allowsHitTesting(false)
    }
}

struct ActivationSequenceSurfaceHost<Content: View>: View {
    let displayID: String
    @ObservedObject var surfaceState: SurfaceState
    let content: Content
    @ObservedObject private var coordinator = ActivationSequenceCoordinator.shared

    init(displayID: String, surfaceState: SurfaceState, @ViewBuilder content: () -> Content) {
        self.displayID = displayID
        self.surfaceState = surfaceState
        self.content = content()
    }

    var body: some View {
        Group {
            if let presentation = coordinator.presentation,
               presentation.targetDisplayIDs.contains(displayID) {
                let interval = ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0 / 30.0 : 1.0 / 60.0
                TimelineView(.animation(minimumInterval: interval, paused: false)) { timeline in
                    let duration = max(0.01, presentation.settings.duration)
                    let raw = timeline.date.timeIntervalSince(presentation.startDate) / duration
                    let progress = motionProgress(raw, profile: presentation.settings.motion)
                    ZStack {
                        // Opacity does not disable hit testing. The user's first interaction still
                        // reaches the real Halo surface and WindowManager cancels the flourish.
                        content.opacity(normalOpacity(for: presentation.preset, progress: progress))
                        ActivationSequenceOverlay(displayID: displayID, surfaceState: surfaceState)
                    }
                }
            } else {
                content
            }
        }
    }

    private func normalOpacity(for preset: ActivationPreset, progress: Double) -> Double {
        switch preset {
        case .minimalFade:
            return smoothstep(progress)
        case .materialize, .aperture, .liquid, .warpIn, .blackHole:
            return smoothstep((progress - 0.54) / 0.46)
        case .digitalBoot:
            return smoothstep((progress - 0.62) / 0.38)
        case .none:
            return 1
        default:
            return smoothstep((progress - 0.68) / 0.32)
        }
    }

    private func motionProgress(_ value: Double, profile: ActivationMotionProfile) -> Double {
        let x = min(1, max(0, value))
        switch profile {
        case .calm: return x * x * x * (x * (x * 6 - 15) + 10)
        case .fluid: return x * x * (3 - 2 * x)
        case .snappy: return min(1, 1 - pow(1 - x, 3))
        }
    }

    private func smoothstep(_ value: Double) -> Double {
        let x = min(1, max(0, value))
        return x * x * (3 - 2 * x)
    }
}

struct ActivationSequenceOverlay: View {
    let displayID: String
    @ObservedObject var surfaceState: SurfaceState
    @ObservedObject private var coordinator = ActivationSequenceCoordinator.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            if let presentation = coordinator.presentation,
               presentation.targetDisplayIDs.contains(displayID) {
                let interval = ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0 / 30.0 : 1.0 / 60.0
                TimelineView(.animation(minimumInterval: interval, paused: false)) { timeline in
                    let duration = max(0.01, presentation.settings.duration)
                    let raw = timeline.date.timeIntervalSince(presentation.startDate) / duration
                    let progress = motionProgress(raw, profile: presentation.settings.motion)
                    let endFade = 1 - smoothstep(min(1, max(0, (progress - 0.80) / 0.20)))
                    sequence(presentation: presentation, progress: progress, size: proxy.size)
                        .opacity(endFade)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var effectiveShape: SurfaceShapeKind {
        let options = surfaceState.activationSurfaceOptions
        guard options.useStyleContour ?? true else { return options.shape }
        switch surfaceState.theme.style {
        case .pill, .island: return .capsule
        case .simulated, .notch: return .scoop
        case .shelf: return .chamfer
        case .detached, .menuBar: return .rounded
        default: return options.shape
        }
    }

    private var shape: HaloContour {
        let options = surfaceState.activationSurfaceOptions
        let radius: CGFloat = (options.useStyleContour ?? true)
            ? (surfaceState.theme.style == .menuBar ? 4 : surfaceState.theme.style == .pill ? 40 : surfaceState.theme.cornerRadius)
            : surfaceState.theme.cornerRadius
        return HaloContour(kind: effectiveShape,
                           radius: radius,
                           topRadius: options.topRadius,
                           bottomRadius: options.bottomRadius,
                           shoulder: options.shoulder)
    }

    @ViewBuilder
    private func sequence(presentation: ActivationPresentation, progress: Double, size: CGSize) -> some View {
        let settings = presentation.settings
        let primary = presentation.primaryColor.color
        let secondary = presentation.secondaryColor.color
        if reduceMotion {
            reducedSequence(progress: progress, settings: settings, primary: primary)
        } else {
            switch presentation.preset {
            case .haloReveal: haloReveal(progress, settings, primary, secondary)
            case .powerOn: powerOn(progress, settings, primary, secondary, size)
            case .lightSweep: lightSweep(progress, settings, primary, secondary, size)
            case .softPulse: softPulse(progress, settings, primary)
            case .aperture: aperture(progress, settings, primary)
            case .liquid: liquid(progress, settings, primary, secondary)
            case .materialize: materialize(progress, settings, primary)
            case .digitalBoot: digitalBoot(progress, settings, primary, size)
            case .neonIgnition: neonIgnition(progress, settings, primary)
            case .spark: spark(progress, settings, primary, size)
            case .ripple: ripple(progress, settings, primary)
            case .warpIn: warpIn(progress, settings, primary)
            case .blackHole: blackHole(progress, settings, primary, size)
            case .minimalFade: minimalFade(progress, settings, primary)
            case .none: EmptyView()
            }
        }
    }

    private func reducedSequence(progress: Double, settings: ActivationSequenceSettings, primary: Color) -> some View {
        let pulse = sin(.pi * progress)
        return shape.stroke(primary.opacity((0.12 + 0.55 * pulse) * settings.intensity), lineWidth: settings.glowThickness)
            .shadow(color: primary.opacity(0.35 * settings.intensity * pulse), radius: 8)
    }

    private func haloReveal(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color, _ secondary: Color) -> some View {
        let reveal = smoothstep(min(1, p / 0.72))
        let pulse = sin(.pi * min(1, max(0, (p - 0.58) / 0.42)))
        return ZStack {
            shape.trim(from: 0, to: reveal).stroke(AngularGradient(colors: [primary, secondary, primary], center: .center), style: StrokeStyle(lineWidth: settings.glowThickness, lineCap: .round, lineJoin: .round))
                .shadow(color: primary.opacity(0.55 * settings.intensity), radius: 7 + 9 * settings.intensity)
            shape.stroke(primary.opacity(0.12 + 0.28 * pulse), lineWidth: settings.glowThickness * (1 + pulse * 0.55))
                .scaleEffect(1 + (settings.scale - 1) * pulse)
        }
    }

    private func powerOn(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color, _ secondary: Color, _ size: CGSize) -> some View {
        let ignition = smoothstep(min(1, p / 0.34))
        let outline = smoothstep(min(1, max(0, (p - 0.22) / 0.54)))
        return ZStack {
            Capsule().fill(LinearGradient(colors: [primary.opacity(0), primary, secondary, primary.opacity(0)], startPoint: .leading, endPoint: .trailing))
                .frame(width: max(2, size.width * ignition), height: max(1, settings.glowThickness * 0.9))
                .shadow(color: primary.opacity(0.65 * settings.intensity), radius: 8)
            shape.trim(from: 0, to: outline).stroke(primary.opacity(0.85 * settings.intensity), style: StrokeStyle(lineWidth: settings.glowThickness, lineCap: .round, lineJoin: .round))
                .shadow(color: primary.opacity(0.38 * settings.intensity), radius: 6)
        }
    }

    private func lightSweep(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color, _ secondary: Color, _ size: CGSize) -> some View {
        let band = max(18, size.width * (0.10 + settings.trail * 0.18))
        let x: Double
        switch settings.sweepDirection {
        case .leftToRight: x = -band + (size.width + band * 2) * p
        case .rightToLeft: x = size.width + band - (size.width + band * 2) * p
        case .centerOut: x = size.width / 2 + size.width * 0.48 * p
        case .edgesIn: x = size.width * 0.02 + size.width * 0.48 * p
        }
        return ZStack {
            shape.stroke(primary.opacity(0.14 * settings.intensity), lineWidth: settings.glowThickness)
            Rectangle().fill(LinearGradient(colors: [primary.opacity(0), primary.opacity(0.9), secondary.opacity(0.6), primary.opacity(0)], startPoint: .leading, endPoint: .trailing))
                .frame(width: band)
                .offset(x: x - size.width / 2)
                .blur(radius: 3 + settings.blur * 0.25)
                .mask(shape.fill(Color.white))
            if settings.sweepDirection == .centerOut || settings.sweepDirection == .edgesIn {
                Rectangle().fill(LinearGradient(colors: [primary.opacity(0), secondary.opacity(0.8), primary.opacity(0)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: band).offset(x: -(x - size.width / 2)).blur(radius: 3).mask(shape.fill(Color.white))
            }
        }
    }

    private func softPulse(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color) -> some View {
        let pulse = pow(sin(.pi * min(1, p)), 1.4)
        return shape.stroke(primary.opacity((0.12 + 0.55 * pulse) * settings.intensity), lineWidth: settings.glowThickness)
            .scaleEffect(1 + (settings.scale - 1) * pulse)
            .shadow(color: primary.opacity(0.42 * pulse * settings.intensity), radius: 5 + 10 * pulse)
    }

    private func aperture(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color) -> some View {
        let t = easedWithOvershoot(p, overshoot: settings.overshoot)
        return ZStack {
            shape.fill(Color.black.opacity(0.95 * (1 - p * 0.12))).scaleEffect(x: max(0.08, t), y: 1, anchor: .center)
            shape.stroke(primary.opacity(0.54 * settings.intensity * sin(.pi * p)), lineWidth: settings.glowThickness).scaleEffect(x: max(0.08, t), y: 1)
        }
    }

    private func liquid(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color, _ secondary: Color) -> some View {
        let spring = easedWithOvershoot(p, overshoot: settings.overshoot + settings.bounce * 0.035)
        let vertical = 0.62 + 0.38 * smoothstep(p)
        return shape.fill(LinearGradient(colors: [Color.black.opacity(0.98), primary.opacity(0.16 * settings.intensity), Color.black.opacity(0.98)], startPoint: .top, endPoint: .bottom))
            .overlay(shape.stroke(secondary.opacity(0.30 * sin(.pi * p) * settings.intensity), lineWidth: settings.glowThickness))
            .scaleEffect(x: max(0.12, spring), y: vertical)
            .blur(radius: max(0, settings.blur * (1 - p) * 0.22))
    }

    private func materialize(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color) -> some View {
        ZStack {
            ActivationParticleLayer(progress: smoothstep(p), settings: settings, color: primary, inward: true)
            shape.stroke(primary.opacity(0.5 * settings.intensity * smoothstep(p)), lineWidth: settings.glowThickness)
                .shadow(color: primary.opacity(0.35 * settings.intensity), radius: 7)
        }
    }

    private func digitalBoot(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color, _ size: CGSize) -> some View {
        let line = smoothstep(min(1, p / 0.48))
        let lock = smoothstep(min(1, max(0, (p - 0.36) / 0.50)))
        return ZStack {
            Capsule().fill(primary.opacity(0.88 * settings.intensity)).frame(width: size.width * line, height: max(1, settings.glowThickness * 0.65))
            HStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1).fill(primary.opacity((index.isMultiple(of: 3) ? 0.85 : 0.28) * settings.intensity * sin(.pi * p)))
                        .frame(width: max(3, size.width / 26), height: max(2, size.height * 0.10))
                }
            }.opacity(p > 0.18 && p < 0.72 ? 1 : 0)
            shape.stroke(primary.opacity(0.58 * lock * settings.intensity), lineWidth: settings.glowThickness)
        }
    }

    private func neonIgnition(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color) -> some View {
        let early = p < 0.35 ? (0.52 + 0.20 * sin(p * 42)) : 1.0
        let ramp = smoothstep(min(1, p / 0.58))
        return shape.stroke(primary.opacity(max(0.12, early) * ramp * settings.intensity), lineWidth: settings.glowThickness)
            .shadow(color: primary.opacity(0.58 * ramp * settings.intensity), radius: 5 + 10 * settings.intensity)
    }

    private func spark(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color, _ size: CGSize) -> some View {
        let angle = 2 * Double.pi * p - Double.pi / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let point = CGPoint(x: center.x + cos(angle) * max(2, size.width / 2 - 5), y: center.y + sin(angle) * max(2, size.height / 2 - 4))
        return ZStack {
            shape.stroke(primary.opacity(0.16 * settings.intensity), lineWidth: max(0.8, settings.glowThickness * 0.55))
            Circle().fill(primary).frame(width: 4 + settings.particleSize, height: 4 + settings.particleSize)
                .position(point)
                .shadow(color: primary.opacity(0.8 * settings.intensity), radius: 4 + settings.trail * 10)
        }
    }

    private func ripple(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let shifted = min(1, max(0, p * 1.35 - Double(index) * 0.16))
                shape.stroke(primary.opacity((1 - shifted) * 0.38 * settings.intensity), lineWidth: max(0.7, settings.glowThickness * 0.55))
                    .scaleEffect(1 + shifted * (0.08 + settings.particleSpread * 0.07))
            }
        }
    }

    private func warpIn(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color) -> some View {
        let x = easedWithOvershoot(p, overshoot: settings.overshoot)
        return shape.stroke(primary.opacity(0.5 * settings.intensity * sin(.pi * min(1, p * 1.15))), lineWidth: settings.glowThickness)
            .background(shape.fill(Color.black.opacity(0.90 * (1 - p * 0.20))))
            .scaleEffect(x: 0.42 + x * 0.58, y: 1 - settings.distortion * 0.16 * sin(.pi * p))
            .blur(radius: settings.blur * settings.distortion * (1 - p))
    }

    private func blackHole(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color, _ size: CGSize) -> some View {
        let grow = smoothstep(min(1, p / 0.72))
        return ZStack {
            ActivationParticleLayer(progress: grow, settings: settings, color: primary, inward: true, blackHole: true)
            Circle().fill(Color.black).frame(width: max(2, size.width * grow * 0.95), height: max(2, size.height * grow * 1.35))
                .shadow(color: primary.opacity(0.52 * settings.intensity * sin(.pi * p)), radius: 8 + 14 * settings.intensity)
            shape.stroke(primary.opacity(0.36 * settings.intensity * grow), lineWidth: settings.glowThickness)
        }
    }

    private func minimalFade(_ p: Double, _ settings: ActivationSequenceSettings, _ primary: Color) -> some View {
        let fade = sin(.pi * p)
        return shape.fill(primary.opacity(0.055 * settings.intensity * fade))
            .overlay(shape.stroke(primary.opacity(0.24 * settings.intensity * fade), lineWidth: max(0.7, settings.glowThickness * 0.55)))
            .blur(radius: settings.blur * 0.10 * (1 - p))
    }

    private func motionProgress(_ value: Double, profile: ActivationMotionProfile) -> Double {
        let x = min(1, max(0, value))
        switch profile {
        case .calm:
            return x * x * x * (x * (x * 6 - 15) + 10)
        case .fluid:
            return x * x * (3 - 2 * x)
        case .snappy:
            return min(1, 1 - pow(1 - x, 3))
        }
    }

    private func smoothstep(_ value: Double) -> Double {
        let x = min(1, max(0, value)); return x * x * (3 - 2 * x)
    }

    private func easedWithOvershoot(_ value: Double, overshoot: Double) -> Double {
        let x = min(1, max(0, value))
        if overshoot <= 0 { return smoothstep(x) }
        let s = 1.70158 + overshoot * 4.2
        let t = x - 1
        return max(0, min(1 + overshoot, 1 + (s + 1) * t * t * t + s * t * t))
    }
}

// MARK: - Settings

@MainActor
struct ActivationSequenceSettingsPane: View {
    @ObservedObject private var store = ActivationSequenceStore.shared
    @State private var soundError: String?

    private var settings: ActivationSequenceSettings { store.settings }

    var body: some View {
        Section("Activation Sequence") {
            Toggle("Enable Activation Sequence", isOn: binding(\.enabled))
            Text("A one-time startup flourish for Halo itself. It does not replace the normal notch open/close animation.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Preview Activation") { NotificationCenter.default.post(name: .init("HaloPreviewActivationSequence"), object: nil) }
                    .buttonStyle(.borderedProminent)
                Button("Reset") { store.reset() }
                Spacer()
                if settings.randomFavorite { Label("Random Favorite", systemImage: "shuffle") }
            }
        }

        Section("Play When") {
            Toggle("Halo is launched manually", isOn: binding(\.playManualLaunch))
            Toggle("Halo launches at login", isOn: binding(\.playLoginLaunch))
            Toggle("Mac has just started", isOn: binding(\.playMacStartup))
            Toggle("Halo is reopened after being quit", isOn: binding(\.playRelaunchAfterQuit))
            Toggle("Play after wake", isOn: binding(\.playAfterWake))
            Text("Wake is intentionally off by default. Opening Settings, clicking the menu-bar item, opening the notch, changing displays, or normal widget/CI activity does not replay the sequence.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Animation") {
            Picker("Preset", selection: Binding(get: { settings.preset }, set: { store.selectPreset($0) })) {
                ForEach(ActivationPreset.allCases) { preset in Text("\(preset.category) · \(preset.rawValue)").tag(preset) }
            }
            HStack {
                Button {
                    store.update { value in
                        if value.favoritePresets.contains(value.preset) { value.favoritePresets.remove(value.preset) }
                        else if value.preset != .none { value.favoritePresets.insert(value.preset) }
                    }
                } label: {
                    Label(settings.favoritePresets.contains(settings.preset) ? "Favorited" : "Favorite", systemImage: settings.favoritePresets.contains(settings.preset) ? "star.fill" : "star")
                }
                Toggle("Random Favorite", isOn: binding(\.randomFavorite))
            }
            Picker("Motion", selection: binding(\.motion)) { ForEach(ActivationMotionProfile.allCases) { Text($0.rawValue).tag($0) } }
            presetControls
        }

        Section("Color") {
            Picker("Color source", selection: binding(\.colorSource)) { ForEach(ActivationColorSource.allCases) { Text($0.rawValue).tag($0) } }
            if settings.colorSource == .custom || settings.colorSource == .gradient {
                ColorPicker("Primary", selection: rgbaBinding(\.customColor), supportsOpacity: false)
            }
            if settings.colorSource == .gradient {
                ColorPicker("Secondary", selection: rgbaBinding(\.gradientColor), supportsOpacity: false)
            }
            Text("Current Theme is the default. Wallpaper-derived samples the active display wallpaper once and caches the result for the launch.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Sound") {
            Picker("Sound", selection: binding(\.sound)) { ForEach(ActivationSound.allCases) { Text($0.rawValue).tag($0) } }
            if settings.sound == .custom {
                HStack {
                    Button("Import Short Sound…") { importSound() }
                    if !settings.customSoundPath.isEmpty { Text(URL(fileURLWithPath: settings.customSoundPath).lastPathComponent).lineLimit(1).foregroundStyle(.secondary) }
                    Spacer()
                    Button("Clear") { store.update { $0.customSoundPath = ""; $0.sound = .off }; ActivationSequenceCoordinator.shared.prewarmCustomSound(path: "") }
                        .disabled(settings.customSoundPath.isEmpty)
                }
                if let soundError { Text(soundError).font(.caption).foregroundStyle(.orange) }
                Text("Custom sounds are limited to 3 seconds and 8 MB. Halo peak-normalizes them before playback.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Slider(value: binding(\.soundVolume), in: 0...1, step: 0.01) { Text("Sound volume") }
            Slider(value: binding(\.soundCue), in: 0...1, step: 0.01) { Text("Sound sync point") }
            Toggle("Respect System Volume", isOn: binding(\.respectSystemVolume))
            Button("Preview Sound") { ActivationSequenceCoordinator.shared.previewSound() }
                .disabled(settings.sound == .off || (settings.sound == .custom && settings.customSoundPath.isEmpty))
        }

        Section("Displays") {
            Picker("Play on", selection: binding(\.displayTarget)) {
                ForEach(ActivationDisplayTarget.allCases) { Text($0.rawValue).tag($0) }
            }
            Text("All-display playback uses one shared start timestamp so the sequence remains synchronized.")
                .font(.caption).foregroundStyle(.secondary)
        }

    }

    @ViewBuilder
    private var presetControls: some View {
        switch settings.preset {
        case .haloReveal:
            duration; intensity; slider("Glow thickness", \.glowThickness, 0.5...8, 0.1); slider("Pulse scale", \.scale, 1...1.16, 0.002)
        case .powerOn:
            duration; intensity; slider("Glow thickness", \.glowThickness, 0.5...8, 0.1); slider("Overshoot", \.overshoot, 0...0.24, 0.005)
        case .lightSweep:
            duration; intensity; Picker("Direction", selection: binding(\.sweepDirection)) { ForEach(ActivationSweepDirection.allCases) { Text($0.rawValue).tag($0) } }; slider("Trail", \.trail, 0...1, 0.01); slider("Blur", \.blur, 0...30, 0.5)
        case .softPulse:
            duration; intensity; slider("Pulse scale", \.scale, 1...1.16, 0.002); slider("Bounce", \.bounce, 0...1, 0.01)
        case .materialize:
            duration; intensity; intSlider("Particle count", \.particleCount, 6...120); slider("Spawn radius", \.particleSpread, 0.2...2.2, 0.02); slider("Particle size", \.particleSize, 0.6...8, 0.1); slider("Particle glow", \.particleGlow, 0...1, 0.01); slider("Convergence speed", \.particleSpeed, 0.3...2.4, 0.02)
        case .digitalBoot:
            duration; intensity; slider("Glow thickness", \.glowThickness, 0.5...8, 0.1); slider("Segment trail", \.trail, 0...1, 0.01)
        case .aperture:
            duration; intensity; slider("Overshoot", \.overshoot, 0...0.24, 0.005)
        case .liquid:
            duration; intensity; slider("Bounce", \.bounce, 0...1, 0.01); slider("Overshoot", \.overshoot, 0...0.24, 0.005); slider("Blur", \.blur, 0...30, 0.5)
        case .neonIgnition:
            duration; intensity; slider("Tube thickness", \.glowThickness, 0.5...8, 0.1)
        case .spark:
            duration; intensity; slider("Trail", \.trail, 0...1, 0.01); slider("Spark size", \.particleSize, 0.6...8, 0.1); slider("Glow", \.particleGlow, 0...1, 0.01)
        case .ripple:
            duration; intensity; slider("Ripple spread", \.particleSpread, 0.2...2.2, 0.02); slider("Stroke thickness", \.glowThickness, 0.5...8, 0.1)
        case .warpIn:
            duration; intensity; slider("Distortion", \.distortion, 0...1, 0.01); slider("Overshoot", \.overshoot, 0...0.24, 0.005); slider("Blur", \.blur, 0...30, 0.5)
        case .blackHole:
            duration; intensity; intSlider("Particle count", \.particleCount, 6...120); slider("Particle spread", \.particleSpread, 0.2...2.2, 0.02); slider("Distortion", \.distortion, 0...1, 0.01); slider("Particle glow", \.particleGlow, 0...1, 0.01)
        case .minimalFade:
            duration; intensity; slider("Blur", \.blur, 0...30, 0.5)
        case .none:
            Text("No activation animation will play.").foregroundStyle(.secondary)
        }
    }

    private var duration: some View { slider("Duration", \.duration, 0.3...2.5, 0.01) }
    private var intensity: some View { slider("Intensity", \.intensity, 0...1, 0.01) }

    private func slider(_ title: String, _ path: WritableKeyPath<ActivationSequenceSettings, Double>, _ range: ClosedRange<Double>, _ step: Double) -> some View {
        Slider(value: binding(path), in: range, step: step) { Text(title) }
    }

    private func intSlider(_ title: String, _ path: WritableKeyPath<ActivationSequenceSettings, Int>, _ range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(value: binding(path), in: range) { Text("\(settings[keyPath: path])").monospacedDigit() }
        }
    }

    private func binding<T>(_ path: WritableKeyPath<ActivationSequenceSettings, T>) -> Binding<T> {
        Binding(get: { store.settings[keyPath: path] }, set: { newValue in store.update { $0[keyPath: path] = newValue } })
    }

    private func rgbaBinding(_ path: WritableKeyPath<ActivationSequenceSettings, ActivationRGBA>) -> Binding<Color> {
        Binding(get: { store.settings[keyPath: path].color }, set: { newValue in store.update { $0[keyPath: path] = ActivationRGBA(color: newValue) } })
    }

    private func importSound() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber, size.intValue <= 8_000_000 else {
            soundError = "Choose an audio file smaller than 8 MB."
            return
        }
        guard ActivationSoundPlayer.validateCustom(url: url) else {
            soundError = "Choose a playable audio file between 0.02 and 3 seconds."
            return
        }
        soundError = nil
        store.update { value in value.customSoundPath = url.path; value.sound = .custom }
        ActivationSequenceCoordinator.shared.prewarmCustomSound(path: url.path)
    }
}
