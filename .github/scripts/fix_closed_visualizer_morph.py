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
                // Keep closed-notch content on its compact layout grid while the host window
                // morphs into or out of a Context Island. Using proxy.size.width here makes the
                // slot widths (and therefore visualizer bar spacing) follow every intermediate
                // animation frame, which visibly squashes/stretches the closed visualizer.
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
path.write_text(text)
print("Applied stable closed-notch parent geometry")
