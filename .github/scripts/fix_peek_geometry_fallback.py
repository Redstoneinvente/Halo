from pathlib import Path

p = Path('Halo/Core/ExtensionContracts.swift')
s = p.read_text()

old = '''    private var physicalNotchPeekMotion: HaloCompanionMotion? {
        guard eiSettings.settings.mode == .pet, state.closedOcclusion != nil,
              let kind = engine.currentReaction?.kind else { return nil }
'''
new = '''    private var physicalNotchPeekMotion: HaloCompanionMotion? {
        guard eiSettings.settings.mode == .pet,
              let kind = engine.currentReaction?.kind else { return nil }
'''
if old not in s:
    raise SystemExit('router physicalNotchPeekMotion guard not found')
s = s.replace(old, new, 1)

old = '''                if physicalNotchPeekMotion == nil || surfaceState.closedOcclusion == nil {
                    EIPetAvatar(size: min(220, max(120, size.height * 0.58)), walking: false)
'''
new = '''                if physicalNotchPeekMotion == nil {
                    EIPetAvatar(size: min(220, max(120, size.height * 0.58)), walking: false)
'''
if old not in s:
    raise SystemExit('normal pet fallback condition not found')
s = s.replace(old, new, 1)

old = '''    var body: some View {
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
'''
new = '''    var body: some View {
        GeometryReader { proxy in
            let notch = resolvedNotchGeometry()
            let notchWidth = notch.width
            let notchHeight = notch.height
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
'''
if old not in s:
    raise SystemExit('physical notch view body not found')
s = s.replace(old, new, 1)

anchor = '''    private func horizontalCenter(in size: CGSize, notchWidth: CGFloat, spriteSize: CGFloat) -> CGFloat {
'''
helper = '''    private func resolvedNotchGeometry() -> CGSize {
        // `closedOcclusion` disappears while Halo is expanded, so it cannot gate pet peeks.
        // Prefer it when available because it is already expressed in Halo's surface geometry.
        if let occlusion = surfaceState.closedOcclusion, occlusion.width > 20, occlusion.height > 8 {
            return CGSize(width: max(92, occlusion.width), height: max(22, occlusion.height))
        }

        // Fall back to the actual NSScreen notch geometry. On a notched MacBook the two
        // auxiliary top areas border the camera housing; their gap is the physical notch width.
        let screens = [NSScreen.main].compactMap { $0 } + NSScreen.screens.filter { $0 !== NSScreen.main }
        if let screen = screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            let height = max(22, screen.safeAreaInsets.top)
            if let left = screen.auxiliaryTopLeftArea,
               let right = screen.auxiliaryTopRightArea,
               right.minX > left.maxX {
                return CGSize(width: max(92, right.minX - left.maxX), height: height)
            }
            return CGSize(width: 180, height: height)
        }

        // EI may be previewed on a non-notched/external display. Keep the debug preview anchored
        // to Halo's top centre instead of falling back to the room pet.
        return CGSize(width: 180, height: 32)
    }

'''
if anchor not in s:
    raise SystemExit('horizontalCenter anchor not found')
s = s.replace(anchor, helper + anchor, 1)

p.write_text(s)
print('Removed closedOcclusion gating and added persistent physical notch geometry fallback')
