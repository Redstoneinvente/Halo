# HALO | Native macOS notch workspace

HALO is a customizable macOS notch utility with **Simple** and **Advanced** modes, a visual workspace editor, contextual interfaces, media and audio controls, profiles, automation, and optional integrations. Open `Halo.xcodeproj` to build the macOS app.

> **Documentation status (2026-10-10):** This README supersedes a historical 0.2 implementation handoff that was no longer accurate about the current code. Features below are **found in source**, not independently certified to work in a signed release. See [Feature Expansion](Docs/FeatureExpansion2026-10.md), [Feature Reconciliation](Docs/FeatureReconciliation.md), [Feature Inventory](Docs/FeatureInventory.json), and [Implementation Status](Docs/ImplementationStatus.md). Published release/version behavior still requires testing on a supported Mac.

## What exists in the source

- **Workspace:** Simple and Advanced notch modes; visual grid editor; custom widget placement, layouts, backgrounds, typography, open/closed geometry, transition tuning and display overrides.
- **Profiles and automation:** Saved and built-in profiles, profile/background schedules, rules driven by foreground app, power, battery, display count, local hour and media playback. Automation settings on the reconciliation branch show the last auto-activation reason, only for the current session.
- **Widgets:** Clock, timer, shelf, media, audio, calendar, clipboard, system, launcher, activities, Pixel Pal, notes, capture and stopwatch. A developer module enum case exists but is not in the current `ModuleID.allCases` list, so it must not be advertised as an enabled standard module.
- **Music:** Apple Music and Spotify playback integrations with supported controls; Safari bridge and system-audio fallback; artwork, audio visualizers, lyric retrieval and timed lyric UI. Support and data quality vary by player and permissions.
- **Productivity:** Calendar and meeting links, file shelf with Quick Look, screenshot-region capture with ScreenCaptureKit and OCR using Vision, keyboard shortcuts, and selected partner actions.
- **Clipboard:** The regular clipboard module stores bounded **text-only, in-memory** history. A **separate Clipboard Context Interface** supports contextual actions and image/file-aware, bounded in-memory history. These are not yet a unified cross-device clipboard manager.
- **System and context:** Battery, CPU, memory, swap, disk, network and thermal readings; audio output selection; Bluetooth context; contextual HUD events; app bubbles; Pixel Pal/environmental reactions; teleprompter features.
- **Live activities and extensions:** Internal Live Activity model, opt-in accessibility-derived system events, declarative Custom Interface SDK and registered app integration/broker paths. Executable third-party code is not loaded inside HALO.
- **Distribution:** Distinct Direct and App Store build configurations, StoreKit entitlement/subscription handling, and a Sparkle update controller for **configured Direct builds only**. The existence of these paths does not establish production configuration, purchases, App Store acceptance, or release testing.

## Not yet established as complete

The expansion branch now includes opt-in commercial-key Weather, a Capture widget camera mirror, native App Intents, a local developer activity JSON bridge, a meeting countdown, and a curated eight-template gallery. These additions are source implementations **not yet Mac release-verified**. AI remains a provider contract; direct per-agent adapters, an online community template service, and an iPhone companion remain unfinished. See the [reconciliation](Docs/FeatureReconciliation.md) for what to verify before implementing anything twice.

## Build and validate

Requirements in the checked-in project include a **macOS 13.0 deployment target** and a Swift 5 build configuration. Xcode with the necessary Apple SDK and signing configuration is required to validate real behavior.

```sh
# Xcode scheme: Halo (alternatively inspect Halo Direct / Halo App Store)
xcodebuild -project Halo.xcodeproj -scheme Halo -configuration Debug CODE_SIGNING_ALLOWED=NO build

# Existing project checks: build, tests and supporting validation on macOS
bash Scripts/validate.sh

# Source-evidence drift check (works with Python 3.9+ on any OS)
python3 Scripts/check_feature_inventory.py
```

The Python inventory checker **does not compile Swift** or verify runtime behavior. Run Xcode unit tests and the full [Release Checklist](Docs/ReleaseChecklist.md) on a supported Mac, including both distribution configurations.

## Privacy, security and distribution

HALO requests optional macOS access for specific functionality (for example calendar, screen capture, system activities, audio and clipboard workflows). Check the current implementation, settings and disclosures for each permission. Do not assume that source-only safeguards replace operating-system tests.

Third-party Custom Interfaces are **declarative**. The existing SDK is designed around centralized surface ownership and brokered capabilities. Do not import executable packages or extend permissions without following [AGENTS.md](AGENTS.md), [CISDK.md](Docs/CISDK.md), [Custom CI Authoring](Docs/CustomCI_Authoring.md), and [App Integration CI Architecture](Docs/AppIntegrationCIArchitecture.md).

No secrets or private signing keys should be committed. Sparkle requires a valid HTTPS appcast and public signing key configured for a Direct build. The App Store path must exclude Sparkle components as designed.

## Next priorities

1. Stabilize and benchmark closed/open notch geometry, media seeking, display changes, Pixel Pal, capture permissions and sleep/wake.
2. Extend **context transparency** and user override controls rather than creating a second automation engine.
3. Build developer activities using the current Live Activity and CI contracts.
4. Offer vetted, local workspace templates before a hosted community gallery.
5. Consider small independent additions such as native App Intents, enhanced meeting UX and a real weather provider.

See [Docs/FeatureExpansion2026-10.md](Docs/FeatureExpansion2026-10.md) for setup, security and constraints, and [Docs/FeatureReconciliation.md](Docs/FeatureReconciliation.md) for the longer-term plan. Development work belongs on feature branches; do not merge to `main` before Mac validation.
