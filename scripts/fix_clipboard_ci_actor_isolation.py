from pathlib import Path

path = Path("Halo/Views/SurfaceView.swift")
text = path.read_text()
old = "    static func closedPreferredWidth(monitor: ClipboardContextMonitor, physicalNotchWidth: CGFloat) -> CGFloat {"
new = "    @MainActor\n    static func closedPreferredWidth(monitor: ClipboardContextMonitor, physicalNotchWidth: CGFloat) -> CGFloat {"

if new in text:
    print("Clipboard CI sizing helper is already main-actor isolated")
elif old not in text:
    raise SystemExit("Could not find ClipboardCISizing.closedPreferredWidth")
else:
    path.write_text(text.replace(old, new, 1))
    print("Marked ClipboardCISizing.closedPreferredWidth as @MainActor")
