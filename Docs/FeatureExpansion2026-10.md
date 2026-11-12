# HALO feature expansion, October 10, 2026

This branch adds seven **incremental implementations**, not seven fully commercialized subsystems. The source is subject to successful Xcode build and runtime testing. `main` remains unchanged.

## 1. Context Engine expansion

An existing profile automation rule can now match **music playback active / paused-or-stopped**, using Halo's real `MediaService.isPlaying` value. Use **Settings → Automation → Profile switching → Add rule → Music playback is**. Manual profile application and existing rule arbitration are preserved. Includes a matching unit test. The full Wi-Fi/Focus-aware rules engine, conflict inspector, and timed override UX remain future work.

## 2. Developer Live Activities

A new opt-in, bounded local feed maps developer events to Halo's existing `LiveActivity` model, not to executable plugins.

1. In **Settings → Utilities**, enable **Read local developer activity snapshots**. This requires the existing Live Activities entitlement/feature gate.
2. Use **Copy path** to obtain the **exact** Application Support file path for the installed app. In an App Store sandbox it may be inside the app's container; do not guess it.
3. A trusted local producer creates that file (and its parent folder) and updates it with a JSON object like:

```json
{
  "events": [
    { "id": "unity-build", "title": "Compiling scripts", "detail": "Assembly-CSharp", "state": "running", "progress": 0.45 },
    { "id": "codex-task", "title": "Codex needs attention", "detail": "Review proposed changes", "state": "waiting" }
  ]
}
```

Values: `state` may be `running`, `waiting`, `ended`, or `failed`; `progress` is optional and between 0 and 1. Update the snapshot at least every 90 seconds while active. Events are limited to 12 per poll; JSON to 64 KiB; source timestamps to 90 seconds freshness; titles/details to bounded lengths, IDs to 80 alphanumeric/underscore/dot/hyphen characters. Live Activities expire when the producer is inactive. The bridge does not run commands or fetch arbitrary files. Additional per-app adapters (Unity/Xcode/Claude Code/Codex/GitHub Actions) still need to be written and tested.

## 3. Template Gallery

**Settings → Profiles → Explore 8 workspace templates** now installs curated, editable, local copies of the preset profile designs. No network fetch, untrusted code, silent permissions or downloaded assets. This is **not yet** a hosted user-uploaded Community Template Gallery. Hosting, signed template distribution, creator moderation, review and deep links remain future work.

## 4. Weather widget

**System widget → Weather element** shows current temperature and conditions after opt-in. In **Settings → Utilities**, enable weather, enter latitude/longitude manually (no macOS location permission), and configure a **commercial Open-Meteo API key**. The key is stored in macOS Keychain. Data uses `https://customer-api.open-meteo.com` only, at most once per 15 minutes during normal display use. Free Open-Meteo requests are explicitly not used because HALO is a commercial product. The provider requires attribution (shown in settings). The production developer must maintain an authorized subscription and verify internet permissions and disclosure. Network delivery and provider availability still require runtime QA.

## 5. Camera Mirror

The **Capture widget → Camera mirror** element is initially hidden, and the preview can also be started in **Settings → Utilities**. It calls the system camera permission prompt only after Start, previews locally through AVFoundation, and stops on explicit Stop/view exit. It does not record or upload frames. The project already declares `NSCameraUsageDescription`, which requires review and test on both distribution schemes. Confirm device switching, camera contention and lifecycle under sleep/wake.

## 6. Meeting companion

**Settings → Utilities → Show joinable upcoming meetings in Calendar** enables a countdown/Join banner in the Calendar widget for relevant non-all-day events beginning within 20 minutes or currently ongoing, subject to display space. Only permitted EventKit entries and already recognized HTTPS links for Zoom/Google Meet/Microsoft Teams are used. **Not implemented**: microphone/camera mute controls, conferencing app APIs, meeting transcription, automatic attendance, or cross-app call management.

## 7. Native macOS Shortcuts

Introduced first-party `AppIntent` handlers for **Toggle HALO**, **Open HALO Settings**, and **Apply HALO Profile** (exact profile name, case-insensitive). This extends, rather than replaces, Halo's existing keyboard shortcuts and CI action system. Shortcut actions bring HALO into the process and route into its existing notification and workspace paths. Confirm discovery/action routing in macOS Shortcuts with the signed app, especially when the accessory app was previously closed.

## Safe merge gate

- Pass Xcode builds for Direct and App Store schemes and existing Halo Core Tests.
- Confirm weather Keychain operations/provider status and App Store network sandbox behavior.
- Confirm AVFoundation lifecycle and permissions, including camera denied/allowed and app closed.
- Confirm live-activity file production under both sandbox schemes and failure cases.
- Confirm the template profile can be installed/edited/saved without silently selecting it.
- Confirm profile matching and manual override still work.
- Confirm Shortcuts actions appear and execute correctly.
- Regression test notch geometry, live activity arbitration, clipboard permissions, capture, media scrubber, displays, sleep/wake.
