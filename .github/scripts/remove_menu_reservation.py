from pathlib import Path

path = Path('Halo/App/HaloApp.swift')
s = path.read_text()

replacements = [
    ('    private var menuReservation: NSStatusItem?\n', ''),
    ('        NotificationCenter.default.addObserver(self, selector: #selector(haloPanelResized(_:)), name: NSWindow.didResizeNotification, object: nil)\n', ''),
    ('        NotificationCenter.default.addObserver(self, selector: #selector(haloPanelMoved(_:)), name: NSWindow.didMoveNotification, object: nil)\n', ''),
    ('        NotificationCenter.default.addObserver(self, selector: #selector(haloPanelGeometryChanged(_:)), name: Notification.Name("HaloPanelGeometryChanged"), object: nil)\n', ''),
    ('\n        menuReservation = NSStatusBar.system.statusItem(withLength: 0)\n        menuReservation?.button?.title = ""\n        menuReservation?.button?.image = nil\n        menuReservation?.button?.isEnabled = false\n        menuReservation?.button?.toolTip = "Halo menu-bar protection"\n        menuReservation?.isVisible = true\n', '\n'),
    ('        releaseMenuBarReservation()\n', ''),
]

for old, new in replacements:
    if old not in s:
        raise SystemExit(f'Expected block not found: {old[:80]!r}')
    s = s.replace(old, new, 1)

start = s.find('    @objc private func haloPanelResized(_ note: Notification) {')
end = s.find('    @objc private func toggle() { engine?.toggleAll() }')
if start == -1 or end == -1 or end <= start:
    raise SystemExit('Menu reservation method block not found')
s = s[:start] + s[end:]

path.write_text(s)
print('Removed invisible menu-bar reservation status item and resize tracking')
