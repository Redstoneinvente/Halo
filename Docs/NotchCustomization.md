# Notch sizing, contours and motion

## Closed width fix

Previously WindowManager replaced compactWidth with a hardware-derived width for physical notches and with 220 for simulated notches. Full menu-bar mode also ignored closed width. All placements now use the requested closed width with a 16 pt minimum, including physical-notch mode. The actual hardware camera cutout does not shrink; use a positive closed Y offset to move a tiny surface below it. Width is clamped to the available display area.

Appearance → Closed size controls width (16–640 pt) and height (16–100 pt). These are minimum selectable values, not a reset of existing preferences. A tiny closed surface shows a single indicator. Open width cannot be smaller than closed width. Full menu-bar and wide-shelf modes widen only when opened.

Size and offset sliders automatically preview the relevant state during dragging and temporarily suspend hover collapse. Appearance updates are dispatched on the main queue without debounce, allowing continuous updates during mouse tracking. Preview ends when the slider is released; the chosen state stays visible until the next interaction.

Position offsets have separate opened X/Y and closed X/Y controls, each from −1000 to +1000 pt. Positive X moves right and positive Y moves down. Offsets are saved in themes/profiles, work per display, and are not clamped back onto the screen. Reset offsets restores zero. Older settings decode with no offsets.

Settings now uses an explicit sidebar, search field and content heading inside the window content area. Forms scroll below the heading rather than underneath a navigation toolbar. The window enforces a minimum content size.

Displays → Customize closed size, shape and transitions creates an independent layout snapshot. Controls there apply to that display. Use Follow global modules and background to restore global appearance inheritance.

## Eight contours

Rounded rectangle, Capsule, Squircle, Soft notch, Shouldered notch, Cut corners, Tapered and Asymmetric corners. Shoulder depth applies to shouldered/cut/tapered shapes; asymmetric shapes have separate top/bottom radii. The preview, visible background, border and hit-test contour use the same Shape implementation. Placement and shape are independent.

## Six transitions

Choose opening and closing independently: Resize, Spring, Fade and resize, Scale, Slide, Instant. Duration ranges from 0.1 to 1.2 seconds. Spring damping controls overshoot. Timing presets change easing for non-spring motion. Reduce Motion, disabled animations, and the None timing preset bypass animation entirely.

Animation advances using monotonic time and a timer only during motion. Retargeting starts from the displayed frame. Final geometry is assigned exactly, avoiding accumulated drift. The renderer receives an explicit frame, so SwiftUI content cannot impose a larger closed width. Existing panels and SwiftUI view trees survive settings changes; detached positions survive appearance changes during the current session.

## Other additions

- Module rows support process-local drag reorder; arrows remain available.
- Profile renaming preserves its ID and linked automation rules.
- Shelf pins prevent expiry, and timestamps/pins persist when shelf persistence is enabled.
- Quick Look and file-type/size labels are available from each shelf row.
- Global toggle now opens or closes all displays together, even if their initial states differ.

## Validation

Regression tests cover requested versus minimum width, simulated/menu-bar sizing, compact height, expanded width, negative display origins, edge placement, decoding older Appearance JSON, new settings round trips, motion endpoints, and module order integrity. They are included in both the Xcode logic-test target and Swift package.

Run bash Scripts/validate.sh on macOS. Then test width sliders while collapsed/expanded, each contour, both transition directions, rapid hover reversal, display hotplug, Reduce Motion, independent display settings, and shelf relaunch/expiry. Linux structural/grammar checks do not establish macOS runtime correctness.
