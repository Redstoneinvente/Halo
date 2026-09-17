from pathlib import Path

path = Path("Halo/Views/ClosedNotchView.swift")
text = path.read_text()

old_layout = '''    var body: some View {
        GeometryReader { proxy in
            let reservation = cameraReservation(width: proxy.size.width, height: proxy.size.height)
            if let hud = verticalHUD {
                verticalHUDContent(hud, size: proxy.size, reservation: reservation)
            } else {
                let leftWidth = reservation?.minX ?? proxy.size.width / 2
                let rightWidth = reservation.map { proxy.size.width - $0.maxX } ?? proxy.size.width / 2
                let items = resolvedItems
                HStack(spacing: 0) {
                    slot(items.left, decoration: options.leftDecoration, side: .left, width: leftWidth, height: proxy.size.height)
                    if let reservation { Color.clear.frame(width: reservation.width) }
                    slot(items.right, decoration: options.rightDecoration, side: .right, width: rightWidth, height: proxy.size.height)
                }.frame(height: proxy.size.height)
            }
        }
'''

new_layout = '''    var body: some View {
        GeometryReader { proxy in
            if let hud = verticalHUD {
                let reservation = cameraReservation(width: proxy.size.width, height: proxy.size.height)
                verticalHUDContent(hud, size: proxy.size, reservation: reservation)
            } else {
                // Closed-notch content must keep compact geometry while the host surface morphs.
                // The window animates through intermediate widths when a Context Island opens or
                // closes; laying the closed content out against those transient widths makes the
                // visualizer's bar spacing stretch/squash. Render at the stable compact width and
                // let the morphing parent clip it instead of relaying out its contents.
                let renderWidth = referenceWidth > 1 ? referenceWidth : proxy.size.width
                let reservation = cameraReservation(width: renderWidth, height: proxy.size.height)
                let leftWidth = reservation?.minX ?? renderWidth / 2
                let rightWidth = reservation.map { renderWidth - $0.maxX } ?? renderWidth / 2
                let items = resolvedItems
                HStack(spacing: 0) {
                    slot(items.left, decoration: options.leftDecoration, side: .left, width: leftWidth, height: proxy.size.height)
                    if let reservation { Color.clear.frame(width: reservation.width) }
                    slot(items.right, decoration: options.rightDecoration, side: .right, width: rightWidth, height: proxy.size.height)
                }
                .frame(width: renderWidth, height: proxy.size.height)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
'''

if old_layout not in text:
    raise SystemExit("ClosedNotchView body contract changed; refusing blind patch")
text = text.replace(old_layout, new_layout, 1)

old_colors = '''    private var animated: Bool { playing && enabled && !reduceMotion }; private var colors: [Color] { let extracted = options.dynamicColors ? palette.map(\\.color) : []; return extracted.isEmpty ? [fallback, fallback] : extracted.count == 1 ? [extracted[0], extracted[0]] : extracted }
'''
new_colors = '''    private var animated: Bool { playing && enabled && !reduceMotion }
    private var colors: [Color] {
        let extracted: [Color]
        if options.dynamicColors {
            extracted = palette.map(\\.color)
        } else {
            extracted = []
        }
        if extracted.isEmpty { return [fallback, fallback] }
        if extracted.count == 1 { return [extracted[0], extracted[0]] }
        return extracted
    }
'''
if old_colors not in text:
    raise SystemExit("PlaybackVisualizer color contract changed; refusing blind patch")
text = text.replace(old_colors, new_colors, 1)

old_visualizer = '''            }.frame(maxWidth: options.width).frame(height: options.height)
'''
new_visualizer = '''            }
            // Keep the Canvas at its configured width while the host surface animates. A fixed
            // width may be clipped by the morphing parent, but it is never re-proposed at a
            // narrower width, so bar spacing and aspect remain stable.
            .frame(width: options.width, height: options.height)
'''

if old_visualizer not in text:
    raise SystemExit("PlaybackVisualizer frame contract changed; refusing blind patch")
text = text.replace(old_visualizer, new_visualizer, 1)

path.write_text(text)
print("Applied stable closed-notch visualizer geometry")
