from pathlib import Path

p = Path('Halo/Core/ExtensionContracts.swift')
s = p.read_text()
old = '''        default:
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
'''
new = '''        default:
            let reveal = centralRevealSize(notchWidth: notchWidth, spriteSize: spriteSize)
            Rectangle()
                .frame(width: reveal.width, height: reveal.height)
                .position(x: size.width / 2,
                          y: notchHeight + reveal.height / 2)
'''
if old not in s:
    raise SystemExit('viewbuilder reveal block not found')
s = s.replace(old, new, 1)
anchor = '''    @ViewBuilder
    private func revealMask(size: CGSize, notchWidth: CGFloat, notchHeight: CGFloat, spriteSize: CGFloat) -> some View {
'''
helper = '''    private func centralRevealSize(notchWidth: CGFloat, spriteSize: CGFloat) -> CGSize {
        switch motion {
        case .peekEyes:
            return CGSize(width: min(notchWidth * 0.76, spriteSize * 0.82), height: spriteSize * 0.22)
        case .peekEars:
            return CGSize(width: min(notchWidth * 0.82, spriteSize * 0.90), height: spriteSize * 0.28)
        case .peek:
            return CGSize(width: min(notchWidth * 0.94, spriteSize), height: spriteSize * 0.42)
        case .paw:
            return CGSize(width: min(notchWidth, spriteSize), height: spriteSize * 0.48)
        case .tail:
            return CGSize(width: min(notchWidth * 0.84, spriteSize * 0.90), height: spriteSize * 0.34)
        default:
            return CGSize(width: min(notchWidth * 0.90, spriteSize), height: spriteSize * 0.38)
        }
    }

'''
if anchor not in s:
    raise SystemExit('revealMask anchor not found')
s = s.replace(anchor, helper + anchor, 1)
p.write_text(s)
print('Fixed SwiftUI ViewBuilder Void expression in physical pet reveal mask')
