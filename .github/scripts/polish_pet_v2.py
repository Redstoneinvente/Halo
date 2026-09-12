from pathlib import Path
import re

# --- CompanionSprite: exact manifest cell slicing + cleaner notch rendering ---
p = Path('Halo/Views/CompanionSprite.swift')
s = p.read_text()
old = '''            let rows = max(1, definitions.map(\\.row).max().map { $0 + 1 } ?? 1)
            let columns = max(1, manifest.columns)

            for definition in definitions {
                guard let animation = HaloPetAnimation(rawValue: definition.id) else { continue }
                var frames: [CGImage] = []
                frames.reserveCapacity(manifest.generatedKeyframesPerAnimation)
                for column in 0..<manifest.generatedKeyframesPerAnimation {
                    // Normalized cell boundaries keep slicing robust even if a future export is not
                    // exactly 200 px per cell. Atlas rows are authored top-to-bottom and CGImage
                    // cropping here uses the same top-left raster convention.
                    let nx0 = CGFloat(column) / CGFloat(columns)
                    let nx1 = CGFloat(column + 1) / CGFloat(columns)
                    let ny0 = CGFloat(definition.row) / CGFloat(rows)
                    let ny1 = CGFloat(definition.row + 1) / CGFloat(rows)
                    let x0 = Int((nx0 * CGFloat(image.width)).rounded(.down))
                    let x1 = Int((nx1 * CGFloat(image.width)).rounded(.down))
                    let y0 = Int((ny0 * CGFloat(image.height)).rounded(.down))
                    let y1 = Int((ny1 * CGFloat(image.height)).rounded(.down))
                    let rect = CGRect(x: x0, y: y0, width: max(1, x1 - x0), height: max(1, y1 - y0))
                    guard let frame = image.cropping(to: rect) else { return nil }
                    frames.append(frame)
                }
'''
new = '''            let columns = max(1, manifest.columns)
            let cellWidth = max(1, manifest.cellSize.width)
            let cellHeight = max(1, manifest.cellSize.height)
            let expectedWidth = columns * cellWidth
            guard image.width >= expectedWidth else { return nil }

            for definition in definitions {
                guard let animation = HaloPetAnimation(rawValue: definition.id) else { continue }
                let authoredTop = definition.row * cellHeight
                guard authoredTop >= 0, authoredTop + cellHeight <= image.height else { continue }

                var frames: [CGImage] = []
                frames.reserveCapacity(manifest.generatedKeyframesPerAnimation)
                for column in 0..<manifest.generatedKeyframesPerAnimation {
                    let x = column * cellWidth
                    guard x + cellWidth <= image.width else { break }

                    // The manifest is authored top-to-bottom, while CGImage crop rectangles use
                    // Core Graphics' bottom-origin image space. Convert the authored row explicitly.
                    // Using the fixed 200x200 manifest cell is also important: dividing by the PNG's
                    // total height makes a single export-padding pixel corrupt every row below it.
                    let y = image.height - authoredTop - cellHeight
                    let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                    guard let frame = image.cropping(to: rect) else { continue }
                    frames.append(frame)
                }
                guard !frames.isEmpty else { continue }
'''
if old not in s:
    raise SystemExit('atlas slicing block not found')
s = s.replace(old, new, 1)

old_sprite = '''    private func sprite(_ image: CGImage, animation: HaloPetAnimation, mirror: Bool) -> some View {
        Image(decorative: image, scale: 1, orientation: .up)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .scaleEffect(x: mirror ? -1 : 1, y: 1, anchor: .center)
            .mask(alignment: notchMaskAlignment(for: animation)) {
                Rectangle()
                    .frame(width: size, height: size * 0.92 * notchRevealAmount(for: animation))
            }
            .shadow(color: Color.black.opacity(shadowOpacity(for: animation)), radius: max(1, size * 0.014), y: max(1, size * 0.008))
    }

    private func notchMaskAlignment(for animation: HaloPetAnimation) -> Alignment {
        switch animation {
        case .peekFromLeft: return .leading
        case .peekFromRight: return .trailing
        default: return .bottom
        }
    }

    private func notchRevealAmount(for animation: HaloPetAnimation) -> CGFloat {
        // V2 notch sheets already encode the partial-body composition. Clipping remains here so the
        // sprite can sit against Halo's real notch boundary without drawing a fake ledge.
        switch animation {
        case .eyesPeekUp: return 0.34
        case .headPeekUp: return 0.52
        case .pawsOnLedge: return 0.72
        case .tailReveal: return 0.58
        default: return 1
        }
    }
'''
new_sprite = '''    private func sprite(_ image: CGImage, animation: HaloPetAnimation, mirror: Bool) -> some View {
        Image(decorative: image, scale: 1, orientation: .up)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .scaleEffect(x: mirror ? -1 : 1, y: 1, anchor: .center)
            // Notch interaction sheets already contain the authored body reveal. Do not crop them
            // a second time here: the real physical-notch host supplies the hardware occlusion mask.
            .shadow(color: Color.black.opacity(shadowOpacity(for: animation)), radius: max(1, size * 0.014), y: max(1, size * 0.008))
            .compositingGroup()
    }
'''
if old_sprite not in s:
    raise SystemExit('sprite notch mask block not found')
s = s.replace(old_sprite, new_sprite, 1)
p.write_text(s)

# --- ExtensionContracts: route peek reactions to the physical notch ---
p = Path('Halo/Core/ExtensionContracts.swift')
s = p.read_text()
old_pet = '''        case .pet:
            ZStack(alignment: .bottom) {
                EIHabitatDetails(preferences: preferences.value, environment: engine.environment)
                    .allowsHitTesting(false)
                EIPetAvatar(size: min(220, max(120, size.height * 0.58)), walking: false)
                    .offset(y: -max(8, size.height * 0.055))
                    .onTapGesture { engine.interact(.petPat) }
                petActions.padding(.bottom, 13)
            }
'''
new_pet = '''        case .pet:
            ZStack(alignment: .bottom) {
                EIHabitatDetails(preferences: preferences.value, environment: engine.environment)
                    .allowsHitTesting(false)

                if let peekMotion = physicalNotchPeekMotion {
                    EIPhysicalNotchPetPeek(surfaceState: surfaceState, motion: peekMotion)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                        .zIndex(12)
                } else {
                    EIPetAvatar(size: min(220, max(120, size.height * 0.58)), walking: false)
                        .offset(y: -max(8, size.height * 0.055))
                        .onTapGesture { engine.interact(.petPat) }
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
                petActions.padding(.bottom, 13)
            }
            .animation(.easeInOut(duration: 0.20), value: physicalNotchPeekMotion != nil)
'''
if old_pet not in s:
    raise SystemExit('pet content block not found')
s = s.replace(old_pet, new_pet, 1)

anchor = '''    private var title: String {
'''
helper = '''    private var physicalNotchPeekMotion: HaloCompanionMotion? {
        guard let kind = engine.currentReaction?.kind else { return nil }
        switch kind {
        case .petPeekEyes: return .peekEyes
        case .petPeekEars: return .peekEars
        case .petPeekUnder: return .peek
        case .petPeekLeft: return .peekLeft
        case .petPeekRight: return .peekRight
        case .petPawFirst: return .paw
        case .petTailFirst: return .tail
        default: return nil
        }
    }

'''
if anchor not in s:
    raise SystemExit('title anchor not found')
s = s.replace(anchor, helper + anchor, 1)

roam_anchor = '''@MainActor
struct EIRoamingPetView: View {
'''
physical_view = r'''@MainActor
private struct EIPhysicalNotchPetPeek: View {
    @ObservedObject var surfaceState: SurfaceState
    let motion: HaloCompanionMotion
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    @ObservedObject private var settings = EISettingsStore.shared

    var body: some View {
        GeometryReader { proxy in
            let hardwareWidth = resolvedNotchWidth(in: proxy.size)
            let hardwareHeight = resolvedNotchHeight()
            let spriteSize = min(164, max(112, hardwareWidth * 0.82))
            let center = CGPoint(x: horizontalCenter(in: proxy.size, notchWidth: hardwareWidth, spriteSize: spriteSize),
                                 y: verticalCenter(notchHeight: hardwareHeight, spriteSize: spriteSize))

            HaloCompanionSprite(kind: settings.settings.petKind,
                                style: preferences.value.petVisual == .pixel ? .smooth : preferences.value.petVisual,
                                size: spriteSize,
                                primary: settings.settings.petPrimaryColor.color,
                                accent: settings.settings.petAccentColor.color,
                                motion: motion,
                                facingRight: motion != .peekRight)
                .position(center)
                .mask {
                    physicalNotchVisibilityMask(size: proxy.size,
                                                notchWidth: hardwareWidth,
                                                notchHeight: hardwareHeight)
                }
                .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func resolvedNotchWidth(in size: CGSize) -> CGFloat {
        if let occlusion = surfaceState.closedOcclusion, occlusion.width > 20 {
            return min(size.width * 0.72, max(90, occlusion.width))
        }
        return min(210, max(140, size.width * 0.34))
    }

    private func resolvedNotchHeight() -> CGFloat {
        if let occlusion = surfaceState.closedOcclusion, occlusion.height > 8 {
            return min(54, max(22, occlusion.height))
        }
        return 32
    }

    private func horizontalCenter(in size: CGSize, notchWidth: CGFloat, spriteSize: CGFloat) -> CGFloat {
        switch motion {
        case .peekLeft:
            return size.width / 2 - notchWidth / 2 - spriteSize * 0.20
        case .peekRight:
            return size.width / 2 + notchWidth / 2 + spriteSize * 0.20
        case .tail:
            return size.width / 2 + notchWidth * 0.22
        default:
            return size.width / 2
        }
    }

    private func verticalCenter(notchHeight: CGFloat, spriteSize: CGFloat) -> CGFloat {
        switch motion {
        case .peekLeft, .peekRight:
            return max(notchHeight * 0.70, spriteSize * 0.25)
        case .peekEyes:
            return notchHeight + spriteSize * 0.20
        case .peekEars:
            return notchHeight + spriteSize * 0.24
        case .paw:
            return notchHeight + spriteSize * 0.30
        case .tail:
            return notchHeight + spriteSize * 0.18
        default:
            return notchHeight + spriteSize * 0.28
        }
    }

    /// Visible pixels are the actual screen around the camera housing. The central top rectangle is
    /// removed from the mask, so the pet can genuinely travel behind the MacBook's physical notch.
    @ViewBuilder
    private func physicalNotchVisibilityMask(size: CGSize, notchWidth: CGFloat, notchHeight: CGFloat) -> some View {
        let sideWidth = max(0, (size.width - notchWidth) / 2)
        ZStack(alignment: .topLeading) {
            Rectangle()
                .frame(width: size.width, height: max(0, size.height - notchHeight))
                .offset(y: notchHeight)
            Rectangle().frame(width: sideWidth, height: notchHeight)
            Rectangle()
                .frame(width: sideWidth, height: notchHeight)
                .offset(x: sideWidth + notchWidth)
        }
    }
}

'''
if roam_anchor not in s:
    raise SystemExit('roaming pet anchor not found')
s = s.replace(roam_anchor, physical_view + roam_anchor, 1)
p.write_text(s)
print('Applied pet V2 atlas slicing and physical-notch polish')
