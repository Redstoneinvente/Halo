from pathlib import Path

p = Path('Halo/Views/SurfaceView.swift')
s = p.read_text()

repls = {
'''            let baseWidth: Double
''': '''            let baseWidth: CGFloat
''',
'''            let extraThickness = max(0, indicatorThickness - 3)
            return CGSize(width: baseWidth, height: max(96, 70 + (hasMeta ? 26 : 8) + extraThickness))
''': '''            let extraThickness = CGFloat(max(0, indicatorThickness - 3))
            return CGSize(width: baseWidth, height: max(CGFloat(96), CGFloat(70 + (hasMeta ? 26 : 8)) + extraThickness))
''',
'''            var width = 205.0
            if showDirection { width += 105 }
            width += Double(primaryStats) * 105
            if showElapsed { width += 62 }
            return CGSize(width: min(600, max(260, width)), height: 96)
''': '''            var width: CGFloat = 205
            if showDirection { width += 105 }
            width += CGFloat(primaryStats) * 105
            if showElapsed { width += 62 }
            return CGSize(width: min(600, max(260, width)), height: 96)
''',
'''            var width = compact ? 300.0 : 330.0
            if stats > 0 { width += Double(stats) * (compact ? 76 : 88) }
            if !showDirection && !showElapsed && stats == 0 { width = 280 }
            width = min(720, max(280, width))

            var height = compact ? 78.0 : 86.0
''': '''            var width: CGFloat = compact ? 300 : 330
            if stats > 0 { width += CGFloat(stats) * (compact ? 76 : 88) }
            if !showDirection && !showElapsed && stats == 0 { width = 280 }
            width = min(720, max(280, width))

            var height: CGFloat = compact ? 78 : 86
'''
}
for old, new in repls.items():
    if old not in s:
        raise SystemExit(f'missing sizing fragment: {old[:70]}')
    s = s.replace(old, new, 1)

old = '''            if !expanded {
                state.contextPreferredSize = nil
                retroGameRequested = false
            }
'''
new = '''            if !expanded {
                state.contextPreferredSize = nil
                if transferContextActive {
                    // Preserve the content-driven open target while Transfer remains active,
                    // so the next hover/click opens directly to the correct size.
                    DispatchQueue.main.async {
                        guard transferContextActive, !state.expanded else { return }
                        state.contextMinimumExpandedWidth = TransferCISizing.minimumExpandedWidth(physicalNotchWidth: state.physicalNotchWidth)
                        state.contextPreferredCompactWidth = TransferCISizing.closedPreferredWidth(physicalNotchWidth: state.physicalNotchWidth)
                        state.contextPreferredSize = TransferCISizing.openPreferredSize()
                    }
                }
                retroGameRequested = false
            }
'''
if old not in s:
    raise SystemExit('expanded collapse block not found')
s = s.replace(old, new, 1)

p.write_text(s)
print('Finalized Transfer CI sizing types and reopen sizing.')
