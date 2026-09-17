from pathlib import Path

path = Path("Halo/Views/ClosedNotchView.swift")
text = path.read_text()

frozen_parent = '''    var body: some View {
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

live_parent = '''    var body: some View {
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

if frozen_parent in text:
    text = text.replace(frozen_parent, live_parent, 1)
elif live_parent not in text:
    raise SystemExit("ClosedNotchView parent layout contract changed; refusing blind rollback")

old_width = '        v.width = min(v.width, max(1, innerWidth - mediaSiblingFootprint))'
new_width = '        v.width = max(1, innerWidth - mediaSiblingFootprint)'
if old_width in text:
    text = text.replace(old_width, new_width, 1)
elif new_width not in text:
    raise SystemExit("Visualizer width contract changed; refusing blind patch")

path.write_text(text)
print("Restored live parent geometry and made closed visualizer consume the full available slot width")
