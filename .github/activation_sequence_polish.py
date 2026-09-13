from pathlib import Path

activation_path = Path('Halo/Views/ActivationSequence.swift')
activation = activation_path.read_text()

# Respect the hardware/software mute property as well as a zero scalar volume.
if 'import CoreAudio\n' not in activation:
    activation = activation.replace('import AVFoundation\n', 'import AVFoundation\nimport CoreAudio\n', 1)

sound_guard = '''            if settings.respectSystemVolume, let systemVolume, systemVolume <= 0.003 { return }'''
sound_guard_new = '''            if settings.respectSystemVolume {
                if Self.systemOutputIsMuted() { return }
                if let systemVolume, systemVolume <= 0.003 { return }
            }'''
if sound_guard in activation:
    activation = activation.replace(sound_guard, sound_guard_new, 1)

marker = '''    private func resolvedPreset(_ settings: ActivationSequenceSettings) -> ActivationPreset {'''
mute_helper = '''    private static func systemOutputIsMuted() -> Bool {
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

'''
if mute_helper.strip() not in activation:
    if marker not in activation: raise SystemExit('Coordinator preset marker missing')
    activation = activation.replace(marker, mute_helper + marker, 1)

# Reuse Halo's real contour renderer, including style-derived closed contours. This makes custom
# notch radii, simulated notch/scoop, pill, shelf/chamfer and user custom contours line up exactly
# with the surface the activation hands back to.
old_shape = '''    private var shape: ActivationSurfaceShape {
        let options = surfaceState.activationSurfaceOptions
        return ActivationSurfaceShape(kind: options.shape, topRadius: options.topRadius, bottomRadius: options.bottomRadius, shoulder: options.shoulder)
    }
'''
new_shape = '''    private var effectiveShape: SurfaceShapeKind {
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
'''
if old_shape in activation:
    activation = activation.replace(old_shape, new_shape, 1)
elif new_shape.strip() not in activation:
    raise SystemExit('Activation shape marker missing')

# Host wrapper: normal Halo remains mounted and fully hit-testable, but is visually hidden during
# the formation phase. It crossfades in against the same presentation timestamp, so the final
# activation frame and normal notch overlap instead of producing a one-frame disappearance/snap.
host_anchor = 'struct ActivationSequenceOverlay: View {'
host_code = '''struct ActivationSequenceSurfaceHost<Content: View>: View {
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

'''
if host_code.strip() not in activation:
    if host_anchor not in activation: raise SystemExit('Activation overlay anchor missing')
    activation = activation.replace(host_anchor, host_code + host_anchor, 1)

activation_path.write_text(activation)

# Replace the simple overlay stack with the crossfading host. The underlying SurfaceRouter remains
# the only interactive surface; ActivationSequenceOverlay remains non-hit-testing.
window_path = Path('Halo/NotchEngine/WindowManager.swift')
window = window_path.read_text()
old_root = '''                let root = ZStack {
                    HaloSurfaceRouter(viewport: host.state.viewport,
                                      store: store,
                                      state: host.state,
                                      workspace: store.workspace)
                    ActivationSequenceOverlay(displayID: id, surfaceState: host.state)
                }
                .environment(\\.haloScreenFrame, screen.frame)'''
new_root = '''                let root = ActivationSequenceSurfaceHost(displayID: id, surfaceState: host.state) {
                    HaloSurfaceRouter(viewport: host.state.viewport,
                                      store: store,
                                      state: host.state,
                                      workspace: store.workspace)
                }
                .environment(\\.haloScreenFrame, screen.frame)'''
if old_root in window:
    window = window.replace(old_root, new_root, 1)
elif new_root.strip() not in window:
    raise SystemExit('WindowManager activation root marker missing')
window_path.write_text(window)

print('Activation Sequence handoff/contour polish applied')
