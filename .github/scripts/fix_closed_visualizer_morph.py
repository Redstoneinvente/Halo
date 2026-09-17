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

old_visualizer = '''            }.frame(maxWidth: options.width).frame(height: options.height)
'''
new_visualizer = '''            }
            // A max-width frame accepts the host's animated width proposal and deforms the
            // visualizer during notch/CI morphs. Give the Canvas a fixed render surface instead;
            // parent clipping is visually stable and preserves bar spacing/aspect.
            .frame(width: options.width, height: options.height)
            .fixedSize(horizontal: true, vertical: true)
'''

if old_visualizer not in text:
    raise SystemExit("PlaybackVisualizer frame contract changed; refusing blind patch")
text = text.replace(old_visualizer, new_visualizer, 1)

path.write_text(text)
print("Applied stable closed-notch visualizer geometry")
