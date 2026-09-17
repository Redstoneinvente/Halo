from pathlib import Path
import textwrap

path = Path("Halo/Views/ClosedNotchView.swift")
text = path.read_text()

# Give the visualizer an exact outer width. The previous fix only removed the inner
# width cap, but the SwiftUI child itself retained its intrinsic width inside the HStack.
width_anchor = '''    private var visualizerOptions: VisualizerOptions {
        var v = options.visualizer ?? VisualizerOptions()
        v.width = Double.greatestFiniteMagnitude
        v.height = min(v.height, innerHeight)
        return v
    }
'''
width_block = width_anchor + '''    private var visualizerContentWidth: Double {
        max(1, innerWidth - mediaSiblingFootprint)
    }
'''
if 'private var visualizerContentWidth: Double' not in text:
    if width_anchor not in text:
        raise SystemExit("visualizerOptions contract changed; refusing blind patch")
    text = text.replace(width_anchor, width_block, 1)

old_case = '''        case .visualizer:
            if media.isPlaying { PlaybackVisualizer(kind: options.animation, playing: true, enabled: options.animate && !system.lowPower, options: visualizerOptions, palette: media.artworkColors, fallback: effectiveTextColor) }
'''
new_case = '''        case .visualizer:
            if media.isPlaying {
                PlaybackVisualizer(
                    kind: options.animation,
                    playing: true,
                    enabled: options.animate && !system.lowPower,
                    options: visualizerOptions,
                    palette: media.artworkColors,
                    fallback: effectiveTextColor
                )
                .frame(width: visualizerContentWidth, height: innerHeight)
                .layoutPriority(3)
            }
'''
if old_case in text:
    text = text.replace(old_case, new_case, 1)
elif new_case not in text:
    raise SystemExit("Closed visualizer case changed; refusing blind patch")

# PlaybackVisualizer's Canvas body is already very dense. Adding another generic SwiftUI
# wrapper pushed the compiler over its type-check limit. Move the imperative drawing work
# into a plain helper while preserving the exact renderer behavior.
struct_marker = 'struct PlaybackVisualizer: View {'
struct_start = text.find(struct_marker)
if struct_start < 0:
    raise SystemExit("PlaybackVisualizer not found")

simple_marker = 'private func drawVisualizer(in graphics: inout GraphicsContext, size: CGSize, time: Double)'
if simple_marker not in text[struct_start:]:
    body_start = text.find('    var body: some View {\n', struct_start)
    canvas_start_marker = '            Canvas { graphics, size in\n'
    canvas_start = text.find(canvas_start_marker, body_start)
    canvas_end_marker = '            }.frame(maxWidth: options.width).frame(height: options.height)\n'
    canvas_end = text.find(canvas_end_marker, canvas_start)
    body_end_marker = '        }.accessibilityLabel(playing ? "Music playing" : "Music paused")\n    }\n}'
    body_end = text.find(body_end_marker, canvas_end)
    if min(body_start, canvas_start, canvas_end, body_end) < 0:
        raise SystemExit("PlaybackVisualizer body contract changed; refusing blind refactor")

    drawing = text[canvas_start + len(canvas_start_marker):canvas_end]
    drawing = textwrap.indent(textwrap.dedent(drawing), '        ')
    replacement = '''    var body: some View {
        RefreshTimeline(active: animated) { timestamp in
            visualizerCanvas(at: timestamp)
        }
        .accessibilityLabel(playing ? "Music playing" : "Music paused")
    }

    private func visualizerCanvas(at timestamp: Double) -> some View {
        let time = animated ? timestamp * options.speed : 0
        return Canvas { graphics, size in
            drawVisualizer(in: &graphics, size: size, time: time)
        }
        .frame(maxWidth: options.width)
        .frame(height: options.height)
    }

    private func drawVisualizer(in graphics: inout GraphicsContext, size: CGSize, time: Double) {
''' + drawing + '''
    }
}'''
    text = text[:body_start] + replacement + text[body_end + len(body_end_marker):]

path.write_text(text)
print("Made closed visualizer consume exact remaining width and simplified Canvas type-checking")
