# Implementation status — 0.2

“Implemented” below means source is wired into the project, not macOS-tested. No Apple SDK compilation or runtime checks were possible in the build environment.

| Area | Present in this package | Remaining from the original brief |
| --- | --- | --- |
| Notch/windows | Safe-area measurement, ten placement choices, multi-display rebuild, pinned/open-state preservation, per-display theme/layout snapshots | Hardware validation, independent freeform positioning persistence, precise custom notch contours |
| Interaction | Hover, click toggle, context menu, pin, drag/drop, configurable modifier/key preset hotkey | Full gesture binding editor, wheel volume, swipe/long-press actions, arbitrary key recording |
| Modules | Fourteen selectable views, ordered layout, integration registry | Drag reorder, compact variants per module, priorities/minimum widths/per-module styling; original three views still hosted directly |
| Focus | Deadline timer, pause/resume/reset, completion activity/sound, authorized notification, stopwatch | Pomodoro cycles, task history, world clocks, reminders and productivity analytics |
| Shelf | File references, drag in/out, open, reveal, share, count limit, retention, opt-in restart persistence | Quick Look, pinning, file metadata/previews, controlled move/copy workflows, reliable bookmark tracking |
| Media | Apple Music/Spotify title/artist, play/pause, previous/next, explicit refresh | Artwork, progress/seek, shuffle/repeat, automatic updates, browser/universal media, lyrics/visualizer |
| Audio | Output enumeration/selection, supported master-volume control | Input selection, microphone mute, per-channel fallback, accessory battery |
| Calendar | Today's remaining events and recognized meeting links, optional EventKit access | Reminders, broader schedule navigation, richer countdown presentations |
| Clipboard | Optional bounded RAM text history, search/copy/remove, exclusions and sensitive markers | Images, rich text, files, pin/favorites, provenance guarantees |
| Capture | User-triggered region capture, save and shelf handoff, local OCR from chosen images | Screenshot-directory watcher, annotation, screen recording, automatic OCR handoff |
| System | Battery/charging/AC, installed RAM, free disk, uptime, low-power status | CPU/GPU usage, used memory/swap, network throughput, graphs, supported thermal metrics, alerts |
| Launcher | Running apps, choose app, Downloads, fuzzy timer/plugin commands | Indexed app catalog, favorites/recents persistence, full command-palette window |
| Developer | Read-only Git status in a selected folder | Build/run/test commands, server/Docker integrations, branch/commit widgets |
| Live activities | Internal model/API and timer completion list | External progress ingestion, compact prioritization, downloads/build/render tracking |
| Appearance | Image/video/solid/gradient/glass; muted loop/pause; blur/saturation/brightness; dimensions and timing presets | Shader graph/editor, broad effect stacks, audio reaction, artwork/wallpaper integration, true spring presets, typography/icon editor |
| Themes/profiles | v1 import; v2 theme/layout export/import; eight presets; custom save/duplicate/delete; display snapshots | Rename/editor polish, share UI, marketplace; portable bundled image/video assets |
| Automation | Five condition types, profile switching, edge triggering | App-open/close, audio/Focus/Wi-Fi triggers; generalized action UI, approved scripts/shortcuts |
| Plugins | Validated declarative URL commands, installation/revocation, per-run confirmation | Native module loading and secure process isolation, third-party trigger/activity providers |
| Weather and AI | Provider contracts only | Provider implementation, key management, disclosure/consent UX, feature views |
| Licensing | Offline signature/expiry verification with tests; no gates | Production public key, issuer, purchase/import UI, entitlement integration |
| Release | Hardened-runtime settings, permission descriptions, archive/export/notarize scripts, Xcode logic tests | Successful Mac build, integration tests, app icon, updater, signing/notarization execution, accessibility/performance QA, distribution policy review |

## Verification performed here

- Project IDs and references, every Swift source membership, test scheme, entitlement XML and example JSON.
- Swift grammar parsing for app and test sources.
- Shell script syntax checks and ZIP integrity checks at packaging time.

## Verification not performed

Xcode build, XCTest execution, SDK availability/type correctness, actual permissions, Spaces/fullscreen behavior, sleep/wake integration, multiple display hardware, energy/CPU/GPU profiling, signing/notarization, and Gatekeeper installation.

## Next engineering gates

1. Run Scripts/validate.sh on a Mac; resolve all compiler/API and test failures.
2. Run ReleaseChecklist.md's manual matrix and add service-level/UI regression coverage.
3. Decide which outstanding brief items are mandatory for 1.0; implement/test them as vertical slices.
4. Design executable plugin isolation before loading any third-party code.
5. Add production identity/updater and complete signed/notarized release validation.

This package is an expanded development build. It is not the completed production product described by the original brief.
