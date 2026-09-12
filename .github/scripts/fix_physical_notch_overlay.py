from pathlib import Path

app = Path('Halo/Core/AppStore.swift')
ext = Path('Halo/Core/ExtensionContracts.swift')

s = app.read_text()

old = '''        EnvironmentalInterfaceEngine.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.deferRefresh(animatedRoaming: false) }
            .store(in: &bag)
'''
new = old + '''        HaloPetDebugState.shared.$forcedMotion.removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.deferRefresh(animatedRoaming: false) }
            .store(in: &bag)
'''
if old not in s:
    raise SystemExit('engine subscription anchor not found')
s = s.replace(old, new, 1)

old = '''    private func activePeekMotion() -> HaloCompanionMotion? {
        let settings = EISettingsStore.shared.settings
        let engine = EnvironmentalInterfaceEngine.shared
        guard settings.mode == .pet, engine.shouldRender,
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
new = '''    private func activePeekMotion() -> HaloCompanionMotion? {
        let settings = EISettingsStore.shared.settings
        let engine = EnvironmentalInterfaceEngine.shared
        guard settings.mode == .pet, engine.shouldRender else { return nil }

        if let forced = HaloPetDebugState.shared.forcedMotion {
            switch forced {
            case .peekEyes, .peekEars, .peek, .peekLeft, .peekRight, .paw, .tail:
                return forced
            default:
                break
            }
        }

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
if old not in s:
    raise SystemExit('activePeekMotion block not found')
s = s.replace(old, new, 1)

app.write_text(s)

s = ext.read_text()

old = '''    @ObservedObject private var settings = EISettingsStore.shared
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    @ObservedObject private var engine = EnvironmentalInterfaceEngine.shared
    @ObservedObject private var ui = EIOpenUI.shared
'''
new = '''    @ObservedObject private var settings = EISettingsStore.shared
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    @ObservedObject private var engine = EnvironmentalInterfaceEngine.shared
    @ObservedObject private var petDebug = HaloPetDebugState.shared
    @ObservedObject private var ui = EIOpenUI.shared
'''
if old not in s:
    raise SystemExit('EIOpenSurface observed objects anchor not found')
s = s.replace(old, new, 1)

old = '''    private var physicalNotchPeekMotion: HaloCompanionMotion? {
        guard NSScreen.screens.contains(where: { $0.safeAreaInsets.top > 0 }),
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
new = '''    private var physicalNotchPeekMotion: HaloCompanionMotion? {
        guard NSScreen.screens.contains(where: { $0.safeAreaInsets.top > 0 }) else { return nil }

        if let forced = petDebug.forcedMotion {
            switch forced {
            case .peekEyes, .peekEars, .peek, .peekLeft, .peekRight, .paw, .tail:
                return forced
            default:
                break
            }
        }

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
if old not in s:
    raise SystemExit('EIOpenSurface physical peek block not found')
s = s.replace(old, new, 1)

ext.write_text(s)
print('Routed debug-forced pet peek motions through the physical notch overlay')
