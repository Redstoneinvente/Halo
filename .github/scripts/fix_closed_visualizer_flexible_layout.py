from pathlib import Path

path = Path("Halo/Views/ClosedNotchView.swift")
text = path.read_text()

old = '''        case .visualizer:
            if media.isPlaying { PlaybackVisualizer(kind: options.animation, playing: true, enabled: options.animate && !system.lowPower, options: visualizerOptions, palette: media.artworkColors, fallback: effectiveTextColor) }
'''
new = '''        case .visualizer:
            if media.isPlaying {
                PlaybackVisualizer(
                    kind: options.animation,
                    playing: true,
                    enabled: options.animate && !system.lowPower,
                    options: visualizerOptions,
                    palette: media.artworkColors,
                    fallback: effectiveTextColor
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: innerHeight,
                    alignment: side == .left ? .trailing : .leading
                )
                .layoutPriority(3)
            }
'''

if old not in text:
    if new in text:
        print("Flexible closed visualizer layout already present")
    else:
        raise SystemExit("Closed visualizer case changed; refusing blind patch")
else:
    text = text.replace(old, new, 1)
    path.write_text(text)
    print("Made the closed visualizer the flexible width consumer")
