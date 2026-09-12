from pathlib import Path

# Fix atlas Y slicing.
p = Path('Halo/Views/CompanionSprite.swift')
s = p.read_text()
old = '''                    // The manifest is authored top-to-bottom, while CGImage crop rectangles use
                    // Core Graphics' bottom-origin image space. Convert the authored row explicitly.
                    // Using the fixed 200x200 manifest cell is also important: dividing by the PNG's
                    // total height makes a single export-padding pixel corrupt every row below it.
                    let y = image.height - authoredTop - cellHeight
                    let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
'''
new = '''                    // CGImage.cropping(to:) addresses raster rows from the first image-data row:
                    // (0, 0) is the first pixel of the first row. The manifest is authored top-to-bottom,
                    // so row N starts directly at N * cellHeight. Keep the exact 200x200 manifest cells.
                    let y = authoredTop
                    let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
'''
if old not in s:
    raise SystemExit('expected inverted atlas crop block not found')
s = s.replace(old, new, 1)
p.write_text(s)

# Move notch peeking outside the clipped EI surface and make reveal windows hug the hardware notch.
p = Path('Halo/Core/ExtensionContracts.swift')
s = p.read_text()

# Add router-level mapping helper before body.
anchor = '''    var body: some View {
        ZStack(alignment: .top) {
'''
helper = '''    private var physicalNotchPeekMotion: HaloCompanionMotion? {
        guard eiSettings.settings.mode == .pet, state.closedOcclusion != nil,
              let kind = engine.currentReaction?.kind else { return nil }
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
    raise SystemExit('router body anchor not found')
s = s.replace(anchor, helper + anchor, 1)

# Add router-level physical notch overlay after the clipped EIOpenSurface branch.
old_router = '''            if eiOwnsSurface {
                EIOpenSurface(surfaceState: state)
                    .background(EISurfaceBackdrop(mode: eiSettings.settings.mode,
                                                  preferences: EIOpenPreferencesStore.shared.value,
                                                  environment: engine.environment))
                    .clipShape(contour)
                    .overlay(contour.stroke(Color.white.opacity(0.11), lineWidth: 1))
                    .contentShape(contour)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    .zIndex(20)
            }
'''
new_router = '''            if eiOwnsSurface {
                EIOpenSurface(surfaceState: state)
                    .background(EISurfaceBackdrop(mode: eiSettings.settings.mode,
                                                  preferences: EIOpenPreferencesStore.shared.value,
                                                  environment: engine.environment))
                    .clipShape(contour)
                    .overlay(contour.stroke(Color.white.opacity(0.11), lineWidth: 1))
                    .contentShape(contour)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    .zIndex(20)

                // Physical-notch peeks must not be children of EIOpenSurface: that surface is clipped
                // to Halo's contour. Render the pet above the owned surface so only the real hardware
                // notch/reveal window occludes it, making it genuinely emerge from the camera housing.
                if let peekMotion = physicalNotchPeekMotion {
                    EIPhysicalNotchPetPeek(surfaceState: state, motion: peekMotion)
                        .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                        .zIndex(50)
                }
            }
'''
if old_router not in s:
    raise SystemExit('router EI block not found')
s = s.replace(old_router, new_router, 1)

# Stop drawing the physical peek inside the EI room. Hide the room pet while the router overlay is active.
old_pet = '''        case .pet:
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
new_pet = '''        case .pet:
            ZStack(alignment: .bottom) {
                EIHabitatDetails(preferences: preferences.value, environment: engine.environment)
                    .allowsHitTesting(false)

                // On a real notched display the active peek is rendered by HaloSurfaceRouter,
                // outside this clipped room. Keep the normal companion out of the way while peeking.
                if physicalNotchPeekMotion == nil || surfaceState.closedOcclusion == nil {
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
    raise SystemExit('embedded peek pet block not found')
s = s.replace(old_pet, new_pet, 1)

# Replace the physical notch view with geometry that exposes only a small reveal at the actual notch edge.
start = s.index('@MainActor\nprivate struct EIPhysicalNotchPetPeek: View {')
end = s.index('\n@MainActor\nstruct EIRoamingPetView: View {', start)
old_view = s[start:end]
new_view = r'''@MainActor
private struct EIPhysicalNotchPetPeek: View {
    @ObservedObject var surfaceState: SurfaceState
    let motion: HaloCompanionMotion
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    @ObservedObject private var settings = EISettingsStore.shared

    var body: some View {
        GeometryReader { proxy in
            if let occlusion = surfaceState.closedOcclusion {
                let notchWidth = max(92, occlusion.width)
                let notchHeight = max(22, occlusion.height)
                let spriteSize = min(150, max(108, notchWidth * 0.72))
                let centerX = horizontalCenter(in: proxy.size, notchWidth: notchWidth, spriteSize: spriteSize)
                let centerY = verticalCenter(notchHeight: notchHeight, spriteSize: spriteSize)

                HaloCompanionSprite(kind: settings.settings.petKind,
                                    style: preferences.value.petVisual == .pixel ? .smooth : preferences.value.petVisual,
                                    size: spriteSize,
                                    primary: settings.settings.petPrimaryColor.color,
                                    accent: settings.settings.petAccentColor.color,
                                    motion: motion,
                                    facingRight: motion != .peekRight)
                    .position(x: centerX, y: centerY)
                    .mask {
                        revealMask(size: proxy.size,
                                   notchWidth: notchWidth,
                                   notchHeight: notchHeight,
                                   spriteSize: spriteSize)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func horizontalCenter(in size: CGSize, notchWidth: CGFloat, spriteSize: CGFloat) -> CGFloat {
        let notchLeft = size.width / 2 - notchWidth / 2
        let notchRight = size.width / 2 + notchWidth / 2
        switch motion {
        case .peekLeft:
            return notchLeft - spriteSize * 0.18
        case .peekRight:
            return notchRight + spriteSize * 0.18
        case .tail:
            return size.width / 2 + notchWidth * 0.18
        default:
            return size.width / 2
        }
    }

    private func verticalCenter(notchHeight: CGFloat, spriteSize: CGFloat) -> CGFloat {
        // Keep most of the body behind/above the notch edge. The reveal mask exposes only the part
        // that has actually cleared the physical camera housing, so the pet reads as peeking, not
        // standing inside Halo.
        switch motion {
        case .peekEyes: return notchHeight + spriteSize * 0.08
        case .peekEars: return notchHeight + spriteSize * 0.11
        case .peek: return notchHeight + spriteSize * 0.18
        case .paw: return notchHeight + spriteSize * 0.20
        case .tail: return notchHeight + spriteSize * 0.13
        case .peekLeft, .peekRight: return notchHeight + spriteSize * 0.10
        default: return notchHeight + spriteSize * 0.15
        }
    }

    @ViewBuilder
    private func revealMask(size: CGSize, notchWidth: CGFloat, notchHeight: CGFloat, spriteSize: CGFloat) -> some View {
        let notchLeft = size.width / 2 - notchWidth / 2
        let notchRight = size.width / 2 + notchWidth / 2
        switch motion {
        case .peekLeft:
            Rectangle()
                .frame(width: spriteSize * 0.62, height: spriteSize * 0.68)
                .position(x: notchLeft - spriteSize * 0.25,
                          y: notchHeight + spriteSize * 0.12)
        case .peekRight:
            Rectangle()
                .frame(width: spriteSize * 0.62, height: spriteSize * 0.68)
                .position(x: notchRight + spriteSize * 0.25,
                          y: notchHeight + spriteSize * 0.12)
        default:
            let revealHeight: CGFloat
            let revealWidth: CGFloat
            switch motion {
            case .peekEyes:
                revealHeight = spriteSize * 0.22
                revealWidth = min(notchWidth * 0.76, spriteSize * 0.82)
            case .peekEars:
                revealHeight = spriteSize * 0.28
                revealWidth = min(notchWidth * 0.82, spriteSize * 0.90)
            case .peek:
                revealHeight = spriteSize * 0.42
                revealWidth = min(notchWidth * 0.94, spriteSize)
            case .paw:
                revealHeight = spriteSize * 0.48
                revealWidth = min(notchWidth, spriteSize)
            case .tail:
                revealHeight = spriteSize * 0.34
                revealWidth = min(notchWidth * 0.84, spriteSize * 0.90)
            default:
                revealHeight = spriteSize * 0.38
                revealWidth = min(notchWidth * 0.90, spriteSize)
            }
            Rectangle()
                .frame(width: revealWidth, height: revealHeight)
                .position(x: size.width / 2,
                          y: notchHeight + revealHeight / 2)
        }
    }
}
'''
s = s[:start] + new_view + s[end:]
p.write_text(s)
print('Applied physical-notch pet peek architecture fix')
