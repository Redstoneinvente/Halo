# Implementation status | reconciled source review

**Review:** 2026-10-10. **Baseline:** `main` at `969fd7a36c08ddada57164b63fa693375b45ec1e`.

This replaces a historical Halo 0.2 prototype checklist that was out of sync with the current repository. **Source present is not equivalent to built, tested, approved or shipped.** This audit did not run Xcode, exercise macOS UI flows, verify StoreKit renewals, notarize an app, or measure energy usage.

See [FeatureExpansion2026-10.md](FeatureExpansion2026-10.md) for this branch's new code paths, [FeatureReconciliation.md](FeatureReconciliation.md) for context, source links and a prioritized roadmap; [FeatureInventory.json](FeatureInventory.json) for evidence markers; `python3 Scripts/check_feature_inventory.py` for a no-dependency drift check.

| Subsystem | Current source status | Remaining verification / important scope |
| --- | --- | --- |
| Modes, layout, presentation | Simple/Advanced, visual editor, closed/open surface controls, profiles, per-display settings, HUD and app bubbles are present | Real notched/external display QA, clipping, full-screen, Stage Manager, animation interruption |
| Widgets | 14 cases listed in `ModuleID.allCases`; an additional developer enum case is declared but excluded | Verify all standard widgets and adaptive footprints independently |
| Profiles and schedules | Eight presets, saved profiles, schedule windows, automation for app/battery/charging/display/hour | Manual override semantics, rule priority/conflicts, persistence; new branch shows session-only last activation explanation |
| Media | Apple Music/Spotify, Safari bridge/system audio paths, seeking, shuffle/repeat handling, artwork, lyrics and spectrum present | Per-player capability matrix, scrub correctness, permission denial, stale playback, lyric fallback consent |
| System | CPU/memory/swap/disk/network/thermal sampling exists, detailed reads mainly when open | Accuracy/energy measurements, hardware availability and non-invasive polling |
| Bluetooth | Connection events and contextual UI paths exist | Hardware testing, privacy prompts, reconnection and stale state |
| Clipboard | Basic text-only module plus separate image/file-aware Clipboard CI with bounded memory history | Sensitive-copy exclusions, user consent, high-frequency clipboard polling, UX consistency and clear retention policy |
| Files | Shelf, metadata, pins, drag operations and Quick Look paths present | Move/copy workflows, bookmarks, sandbox scoping, missing files, collision handling |
| Capture/OCR | ScreenCaptureKit region capture and Vision OCR paths present | Screen Recording permission transition, cancel/denied/fullscreen behavior, freeze regression |
| Live Activities | Internal activity model, accessibility-based notification/call source available by opt-in | Mac accessibility runtime QA, false positives, privacy, external agent activity ingestion |
| Custom Interfaces | Declarative CI SDK, trigger router, registration and app integration broker paths present | Fuzz tests, capability boundary enforcement, portability, documented public versioning |
| Pixel Pal and other surfaces | Advanced Pixel Pal, environmental reactions, teleprompter/menu-bar paths in source | Native macOS/Reduce Motion QA, clipping, resource footprint |
| Updates | Direct-build Sparkle controller is present but requires valid appcast/signing-key configuration; App Store variant excludes Sparkle | Production feed, signature, rollback, signed release and update install |
| Purchases | StoreKit subscription, license and feature gate paths in source | Real purchase/renewal/restore, cancellation, entitlement migration, variant QA |
| Weather | Commercial-key Open-Meteo provider with manual coordinates and Keychain-backed key was added in this branch; requires opt-in | Purchase/activate paid provider, confirm networking entitlement, test provider results and attribution |
| AI | Provider contract | Actual provider, data disclosures, key management, privacy and consent |
| Developer workspaces | Added bounded, opt-in file-fed Live Activity ingestion; existing internal primitives preserved | Native Xcode/Unity/Codex adapters, richer progress semantics and macOS sandbox-path QA |
| Sharing/marketplace | Added installable local eight-template gallery and existing theme/layout export-import | Online community upload, signed packages, moderation, assets and permission isolation |
| Native Shortcuts/camera mirror/iPhone | Added first-party App Intents and opt-in camera mirror; no iPhone app in this repository | Build and runtime tests for Shortcuts and AVFoundation; iPhone sync app remains future |

## Verification completed in this branch

- Reviewed active Swift services, models, Xcode build variants, CI SDK, app integrations, workspace settings and media presentation code.
- Reconciled previous documents against source-backed evidence instead of treating the 0.2 README as authoritative.
- Implemented a **session-only explanation for the most recent automatic profile activation** in Automation settings, an additional playback automation trigger and the seven scoped feature expansions in [FeatureExpansion2026-10.md](FeatureExpansion2026-10.md).
- Added a machine-readable inventory and source-evidence drift checker.

## Verification still required

1. On macOS run `python3 Scripts/check_feature_inventory.py` and `bash Scripts/validate.sh`. Capture passing/failing output.
2. Build both Halo Direct and Halo App Store schemes. Check frameworks, signing, entitlements and StoreKit configuration.
3. Test hover, pin, compact/open dimensions, widgets, multiple displays, fullscreen, Spaces, sleep and wake.
4. Reproduce and regress past reports: media scrubber, Pixel Pal flicker, screen-capture grant/freeze, clipped content and stuck closed notch.
5. Check accessibility, Reduce Motion, user permissions, data retention and power/CPU usage in Instruments.
6. Conduct release/install/upgrade tests on clean Macs. Avoid claiming a successful production build until actual artifacts pass.

See [ReleaseChecklist.md](ReleaseChecklist.md) for more.
