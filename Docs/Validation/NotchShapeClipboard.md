# Notch contour and Clipboard sizing regression checks

Changes keep the surface contour on the animated viewport even when Default Layout or a CI has a larger intrinsic content size. Clipboard measures its expanded content at the final target width, includes the toggle strip, and scrolls when display bounds limit the height. Its closed preview uses measured text widths and reserves physical camera space. Transfer completion and Drop/Bluetooth teardown no longer unconditionally erase the incoming CI's geometry.

## Automated validation

- Swift parser: passed for SurfaceView.swift.
- Isolated macOS type-check of the actual Clipboard sizing and views: passed using stub monitor/state dependencies.
- Compact sizing assertions: passed for short, wide Latin, CJK, and emoji previews, with and without physical camera space.
- Full Xcode build: blocked during Sparkle dependency resolution by Swift package cache write permissions.
- Existing Swift package tests: blocked by missing app types in the package target (including SurfaceViewport, AppStore, and SurfaceState).

## Interactive checks still required

1. Open/close Default Layout repeatedly with both settings for retained closed content; verify curved edges throughout retract.
2. Repeat with Transfer Dashboard, Minimal, and Indicator presentations, including Reduce Motion and interrupted close/reopen.
3. Copy short text, wide text, CJK, emoji, images, and video; verify closed preview, type label, and countdown remain within the contour and outside the camera.
4. Open Clipboard with compact mode on/off, 1–6 preview lines, action rows, and history. Verify the footer and actions fit; use a constrained display to verify scrolling.
5. While Clipboard owns the surface, let Transfer stop. Switch from Drop/Bluetooth to Clipboard. Verify Clipboard retains its requested size.
6. Repeat open/close in Visual Workspace and with a custom contour to check shared-surface regressions.
