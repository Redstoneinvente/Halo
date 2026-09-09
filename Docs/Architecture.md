# Architecture

## Ownership

AppDelegate owns AppStore, WindowManager, status item and Settings. AppStore owns base configuration, deadline timer, file references and WorkspaceStore. WorkspaceStore owns profiles, module layout, automation rules and integration services.

WindowManager owns one NSPanel / SurfaceState pair per selected display. Screen UUIDs identify overrides. Global configuration changes rebuild windows while retaining expanded/pinned state. Workspace changes rebuild windows only when appearance or display overrides change; typing notes and editing module state do not rebuild panels.

SurfaceView renders enabled modules in normalized order. Existing clock/timer/shelf views retain their focused implementations. ModuleRegistry / HaloModule / ModuleContext dispatch integration module views; service state is observed by each module view. A future refactor can move the three original views behind the same factory.

## Data and persistence

- Configuration: legacy appearance fields and basic interaction/display switches.
- WorkspaceSettings v1: module layout, profiles, automation, privacy options, display overrides.
- ThemeArchive v2: theme plus module/background layout, with v1 Theme import compatibility.
- PluginManifest v1: declarative command descriptors, no native code.
- Timer uses wall-clock deadline across sleep and relaunch; paused duration is session-only.
- Shelf paths are persisted only on opt-in. Retention ages restart when restored.
- Notes/preferences use UserDefaults. This is appropriate for the present small bounded payloads, not a future binary clipboard/media database.

Theme import clamps finite numeric ranges, normalizes module order, strips asset paths, and rejects unsupported formats. Plugin import limits file size and commands, validates permissions/schemes, and asks before installation. No eval, shell interpolation, dylib loading or external script execution is present in the plugin path.

## Integrations

CalendarService uses EventKit and a version-gated access request. MediaService serializes fixed AppleScript commands with a five-second Apple-event timeout; it does not implement system-wide Now Playing. AudioService enumerates output streams and reads/writes the selected device's master volume only where supported. ClipboardService recognizes common concealed/transient markers and user app exclusions. SystemService reads installed memory, free storage, uptime and IOKit battery state; these are not CPU/GPU usage measurements.

CaptureService invokes the system region-selection tool only after user action and screen-capture access; Vision text recognition runs off the main thread. Git status runs off-main with fixed arguments and no optional locks. It has no build/run/test execution interface.

Polling: two-second clipboard change-count sampling, ten-second power/rule updates, calendar once per minute when globally enabled, shelf expiration every thirty seconds while a surface is mounted. Event observers refresh apps and screen state. This implementation has not been energy-profiled.

## Automation semantics

Rules apply profiles only on false-to-true transitions. The first newly matching rule in list order wins. Matching rule IDs are remembered, preventing repeated profile churn. Profile actions do not mutate privacy consent. Trigger state is not persisted; launch can reapply a matching rule. Conditions are app bundle ID, battery threshold, charging boolean, display count, and local hour. No arbitrary executable actions are supported.

## Extension boundaries

WeatherProvider and AIActionProvider are interfaces only. Providers require separate implementation and UI consent. NotchCommand, AutomationTrigger, AutomationAction and LiveActivityProvider define internal extension seams; only local timer completion is currently connected to live activities.

SignedLicense verifies Ed25519 signatures through CryptoKit, product identity, schema, and optional expiration. A nil expiry is perpetual. No public production key, issuance service, purchase UI, or gating is configured. Never embed a private signing key in the app.

## Known boundaries

No executable-plugin isolation, universal media transport, shader editor, network monitoring, comprehensive gestures, unattended task execution, updater, or production performance guarantees. See ImplementationStatus.md for the complete handoff.
