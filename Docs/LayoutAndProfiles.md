# Layout and profile update

- Appearance → Horizontal widget layout now offers Scroll or Pages. Pages show one widget at a time with Previous/Next controls. Each widget can still scroll vertically. Horizontal dashboard height defaults to 260 pt (plus the header), independently of the vertical layout, and is adjustable from 200–500 pt.
- Surface styles use distinctive default contours and placement. Floating pill has a capsule closed state and larger screen gap; Dynamic island sits closer to the menu bar; Wide shelf uses a wider cut-corner surface; Menu-bar surface spans the display; Simulated notch attaches to the top edge; Detached panel sits in the screen center. Expanded pill/island surfaces use rounded corners to keep content readable. Choose a custom contour to override these defaults.
- Profiles support cards/list presentation, icons, names, descriptions, independent module/appearance/widget editing, and schedule/rule summaries. Saving edits does not manually apply the profile; Apply does. Scheduled profiles take effect according to the existing schedule engine.
- AppIcon.icns contains seven PNG representations from 16 through 1024 pixels, extracted from the supplied logo, and is linked in both app build configurations.

## Mac validation

Run the Xcode test target, including the added legacy-profile decoding and surface-geometry cases. Check horizontal scroll and page modes with zero, one and many widgets; test tall file shelves, switching layouts, profile editing/cancel/save, and overnight/paused schedules. Inspect all surface styles on notched and external displays, including custom contours and offsets. Confirm Finder shows the icon after rebuilding. Profile on a 120 Hz display with Low Power Mode off; no change to the display-link policy was made here.

Portable project-reference and Swift grammar checks pass. Xcode compilation, visual checks and frame-rate measurement require macOS and were not run in this environment.
