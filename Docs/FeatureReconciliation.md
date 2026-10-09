# HALO feature reconciliation and research backlog

Audit date: **2026-10-10**. Baseline: `main` commit `969fd7a36c08ddada57164b63fa693375b45ec1e`.

> **Important:** This is a static audit of the repository, **not** a Mac build, a release certification, or proof that every feature works on users' machines. The [machine-readable inventory](FeatureInventory.json) links claims to code evidence. Run `python3 Scripts/check_feature_inventory.py` after source changes. The checker validates evidence markers, not functional behavior.

## Main reconciliation findings

The older `README.md` and `ImplementationStatus.md` described a significantly earlier Halo 0.2 prototype. They said that some features were missing even though newer code paths now exist. They also described the app as never compiled or signed, which **cannot be inferred about the current product** from the old document. This audit does not independently certify signing, build success or App Store acceptance.

| Area | Earlier impression | What the repository actually contains | Evidence |
| --- | --- | --- | --- |
| Modules | Fourteen basic modules, minimal graphics | Fifteen declared module identifiers, fourteen in the public `allCases` list (developer is declared but excluded) and a sizeable Visual Workspace Editor | [WorkspaceModels.swift](../Halo/Core/WorkspaceModels.swift), [WidgetSettingsView.swift](../Halo/Views/WidgetSettingsView.swift) |
| Music | No Safari/universal support, progress, shuffle or lyrics | Spotify/Apple Music service plus a Safari bridge; controls include progress/seek, shuffle/repeat handling, lyric retrieval and synchronized lyric presentation; compatibility varies by player | [Integrations.swift](../Halo/Services/Integrations.swift), [SafariMediaBridge.swift](../Halo/Services/SafariMediaBridge.swift), [SurfaceView.swift](../Halo/Views/SurfaceView.swift) |
| Audio visualization | Decorative fallback only | Dedicated audio spectrum service and opened-notch spectrum view | [AudioSpectrumService.swift](../Halo/Services/AudioSpectrumService.swift), [ModuleViews.swift](../Halo/Views/ModuleViews.swift) |
| System | Battery, free disk and uptime only | On-demand CPU, used-memory, swap, network-rate and thermal-state samples with histories | [Integrations.swift](../Halo/Services/Integrations.swift) |
| Clipboard | Text-only | The **regular clipboard module** remains text-only and memory-bound. A **separate Clipboard Context Interface** implements images, file types and short bounded history. Do not advertise these as one unified persistent clipboard manager | [Integrations.swift](../Halo/Services/Integrations.swift), [SurfaceView.swift](../Halo/Views/SurfaceView.swift) |
| Capture | Basic `screencapture` command | ScreenCaptureKit region capture with in-app selector and Vision OCR path | [CaptureService.swift](../Halo/Services/CaptureService.swift) |
| Activities and CI | Timer-only Live Activities, prototype plugins | Opt-in accessibility-based system activity source and richer declarative CIs, partner integration transport and arbitration. This is **not** an unrestricted third-party scripting runtime | [WorkspaceStore.swift](../Halo/Core/WorkspaceStore.swift), [CITriggerRuntime.swift](../Halo/Core/CITriggerRuntime.swift), [IntegrationTransport.swift](../Halo/Core/IntegrationTransport.swift) |
| Appearance | Fixed shapes with simple transitions | Large Visual Workspace/closed-notch customization paths, per-display overrides, HUDs, Pixel Pal, app bubbles, and custom CIs | [WindowManager.swift](../Halo/NotchEngine/WindowManager.swift), [SurfaceView.swift](../Halo/Views/SurfaceView.swift) |
| Updates | No updater | Direct-distribution Sparkle controller present, but **disabled unless a valid HTTPS appcast and public Ed25519 key are configured**. App Store builds use a different route | [SparkleUpdateController.swift](../Halo/Services/SparkleUpdateController.swift) |
| Payments | No entitlements | App Store StoreKit subscription handling and feature gates are present in source; production receipt, renewal and purchase QA not established here | [AppStoreLicensing.swift](../Halo/Core/AppStoreLicensing.swift) |

## Features not yet established as complete

- **Weather:** a `WeatherProvider` protocol and weather-aware models exist. The settings explicitly say weather/solar details stay hidden until a real provider supplies values. Verify a production weather service before claiming live weather.
- **AI:** an `AIActionProvider` contract exists. No generally available AI feature or consent/account/key-management flow was proven in this audit.
- **Developer activity API:** internal `publish`/`upsertLiveActivity` paths exist. A documented, authenticated external progress feed for Unity/Xcode/Codex/Claude Code was not established.
- **Community gallery:** theme and profile import/export exist, but an online gallery, safe package distribution and creator moderation were not established.
- **Camera mirror and iPhone companion:** not identified in this audit; check feature requests and other app repositories before treating them as absent everywhere.
- **App Intents/Shortcuts:** HALO registers in-app hotkeys and declarative shortcut URL commands. A native App Intents integration was not established by this audit.
- **Meeting companion:** EventKit meeting links/Join Meeting UI exist, but microphone/camera toggles, call controls, and meeting-state lifecycle are not verified as a cohesive feature.
- **Clipboard:** prioritize bringing the Clipboard CI's rich-media pipeline and privacy defaults into a coherent product story, rather than implementing a third separate clipboard manager.

## Highest-value near-term changes

1. **Stabilize existing behavior.** Verify compact/expanded geometry, clipping, scrubber, Pixel Pal, screen recording permission transitions, sleeping/waking, full screen and multi-display behavior. Do not call any of these fixed without a Mac regression run.
2. **Context transparency and override UX.** Users need to understand which rule or schedule changed their workspace. The current feature branch adds a session-only `lastProfileAutomationEvent` explanation to Automation settings without changing routing or persistence. Follow with explicit pause/resume and time-limited override semantics once unit-tested.
3. **Reuse existing primitives.** Build developer activities on the existing activity model and CI trigger/arbitration contract. Preserve permission isolation and prohibit untrusted executable plugins inside the app.
4. **Curated local template gallery before a server.** Start with reviewed templates and clear previews; do not silently apply permissions or machine-specific file paths. An online marketplace can follow after package signing and moderation.
5. **Native App Intents and meeting affordances.** Prefer small, privacy-conscious additions that can be tested independently rather than adding large competing systems.

## Suggested acceptance matrix before release

| Test | Expected observable behavior |
| --- | --- |
| Fresh install + existing-user migration | Defaults/migrations work without losing existing workspace, CI or theme data |
| Direct and App Store schemes | Distinct purchase/update policies; no Sparkle framework in App Store bundle |
| Notched/external displays | No clipping, misaligned surfaces or stranded expanded panels |
| Music and Safari | Correct seek/time state; network lyrics opt-in; stale media cannot lock CI open |
| Clipboard | Sensitive/private copy exclusions work; Clipboard CI/history behavior clearly documented |
| Capture region | TCC denied, newly granted, restart, selected and canceled flows do not freeze |
| Automatic profile switch | Event reason shown; manual selection clears displayed auto reason |
| macOS sleep/wake | Correct state restoration and no uncontrolled polling after shutdown |
| Accessibility and Reduce Motion | Keyboard navigation, clear labels, animations disabled where appropriate |
| Idle and active energy use | Capture actual CPU, energy, memory and frame-pacing measurements in Instruments |
| Production release | Signed, notarized, StoreKit/licensing tested on a clean supported Mac |

## Validation boundaries

- This work is intentionally isolated on `feature/halo-reconciliation-2026-10-10`.
- No CI/plugin permissions, sandbox configuration, billing or public API contracts are expanded by the automation-explanation change.
- `python3 Scripts/check_feature_inventory.py` checks that every evidence marker still exists. It **does not** execute a Swift compiler or macOS UI tests.
- Run `bash Scripts/validate.sh` and the manual release checklist on a Mac before merging. Review the branch diff carefully, particularly the two modified Swift files.
