# Halo Web Representation Export

Halo can export website-ready captures from the real running app rather than recreating the UI in HTML/CSS.

## One command

```bash
./Scripts/export-web-representation.sh
```

By default, assets are written to `WebRepresentation/`. Pass a custom output folder as the first argument.

```bash
./Scripts/export-web-representation.sh ~/Desktop/Halo-Web
```

The script builds Halo, launches a fresh instance, and passes:

```text
--export-web-representation <output-folder>
```

The running app exports deterministic captures from the same AppKit/SwiftUI surface used by Halo itself.

Current package:

```text
WebRepresentation/
├── closed.png
├── open.png
├── music.png
└── manifest.json
```

`manifest.json` includes the app/build version, image dimensions, backing scale, display ID, and whether each state is expanded.

## Website contract

The landing page should treat these assets as canonical. It may frame, position, crop, transition, or decorate them, but it should not redraw Halo's UI.

Future scenes can be added by extending `WindowManager.webRepresentationCaptureTargets()`. Keep those scenes deterministic and render through Halo's real surface tree.
