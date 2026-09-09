# Halo 0.2 — native macOS workspace

Open **Halo.xcodeproj**, select **Halo → My Mac**, choose your signing Team, and press **Command–R**. Requires macOS 13+ and Xcode 15+. There are no third-party app dependencies or required accounts.

This is a substantial implementation expansion, **not completion of every feature in the original product brief**. Source has passed structural and Swift grammar checks in Linux. It has **not been compiled, tested with the Apple SDK, or run on macOS**. Review Docs/ImplementationStatus.md before treating it as a release.

## Included

Latest update: closed-width handling fixed, eight contours, independent opening/closing transitions, closed-height controls, module drag ordering, profile renaming, shelf pins and Quick Look. See Docs/NotchCustomization.md for controls and regression coverage.

- Fourteen dashboard modules: clock, focus timer, shelf, media, audio, calendar, clipboard, system, launcher, live activities, Git status, notes, capture/OCR, stopwatch.
- Ten surface placement choices; per-display theme and optional profile-layout snapshots.
- Module enable/disable and ordering; eight preset profiles and custom profile snapshots.
- App/battery/charging/display-count/hour rules that switch profiles.
- Image, muted looping video, gradient, solid and glass backgrounds; blur, saturation and brightness.
- Theme v1 import and v2 layout/theme import/export. Imported themes cannot access foreign local asset paths.
- Apple Music/Spotify scripting controls, CoreAudio output selection/volume where supported, EventKit schedule.
- Opt-in memory-only text clipboard history, exclusions, search, copy and clear.
- Screenshot-region capture using macOS's capture tool; on-device Vision OCR.
- File references, drag in/out, open/reveal/share, retention and optional persistence.
- Declarative plugin commands with validation and per-invocation URL confirmation.
- Configurable global shortcut, launch at login, permission explanations.
- Xcode logic-test target, Swift package tests, release scripts and checklists.
- Weather/AI extension protocols and offline license signature verification, not connected services or enforced licensing.

## Run and test on a Mac

```sh
bash Scripts/validate.sh
```

This builds the app and runs Xcode logic tests, then runs the Swift package tests. For local unsigned compilation only:

```sh
xcodebuild -project Halo.xcodeproj -scheme Halo -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Use a properly signed build to evaluate privacy prompts and distribution behavior. **Command–U** runs the logic tests in Xcode. Tests exercise model/manifest/license logic, not AppKit integration.

Portable structure check:

```sh
python3 Scripts/check_structure.py
```

The optional tree-sitter Swift parser only checks grammar. It is not an SDK type checker and is not an app dependency.

## First launch

Settings opens on first launch. Enable modules under Modules and optional data access under Privacy. Default global shortcut: **Option–Command–Space**. Hover or click the top strip to expand. Right-click the surface for profiles. Pin to keep it open. Use the menu-bar icon for Settings or Quit.

Media access is requested by Connect / Refresh. Open the selected music player first. Refresh is explicit, not continuous Now Playing observation. Audio devices without writable master volume show an explanation.

Choose a display override in Displays; applying a profile there snapshots that display's modules/background separately. Global profile changes do not replace independent display snapshots. Detached panels retain their position through appearance edits; positions are not persisted across launches.

## Privacy and storage

This is a non-sandboxed direct-distribution target with hardened runtime enabled. Preferences, notes, profile settings, manifests, and optionally shelf paths are in UserDefaults. Clipboard history stays in RAM and clears on quit; it captures text only and is off by default. Clipboard exclusions are best-effort, not a guarantee against secrets.

Backgrounds and shelf items reference original files; moving them can break references. Shelf removal never deletes originals. Screenshots are saved only to a user-selected destination. OCR is on-device. No background analytics, network providers, weather requests, or AI uploads are configured.

Imported theme assets must be reselected locally. Plugin URLs are shown for confirmation before opening; Shortcuts may themselves perform actions configured by the user.

## Release

See Docs/ReleaseChecklist.md. Signing, notarization, production icon, update service, performance/accessibility QA, and outstanding brief features are not complete. No licensing gate is enabled; the signed-license verifier is isolated from the free core.

See Docs/Architecture.md and Docs/Plugins.md for extension contracts.
