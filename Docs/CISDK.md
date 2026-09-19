# Halo CI SDK — Authoritative Architecture and Implementation Instructions

> **Custom CI V2 is implemented as SDK 0.2 / schema 1**, with SDK 0.1 compatibility. See [the V2 framework guide](CustomCI_V2.md) for the shared context catalog, new bindings/permissions/triggers, CLI starter and validator, tests and extension workflow. Earlier 0.1 examples below remain valid unless marked conceptual. The V2 guide defines the additive implemented contract.

> **Status:** Canonical design specification for Halo Custom Interfaces (CI).
>
> **Audience:** Halo maintainers, contributors, coding agents, and future SDK/tooling authors.
>
> **Rule:** If an implementation idea conflicts with this document, stop and resolve the conflict before coding. Do not invent a parallel plugin architecture.

## 1. Purpose

Halo CI is the programmable/customizable interface layer that allows the notch surface to become context-specific UI rather than a fixed collection of widgets.

The CI SDK must eventually let users and third-party creators build interfaces that can:

- render dynamic notch content;
- react to Halo and macOS state;
- launch from one or many triggers/contexts;
- invoke safe, permissioned Halo actions;
- persist isolated state;
- optionally communicate with approved network endpoints;
- be shared, imported, updated, signed, and distributed;
- be authored visually or from source files;
- run without compromising Halo stability, privacy, or security.

The SDK is a **platform contract**, not a convenient way to expose Halo internals.

The long-term direction is that Halo's own first-party CIs should increasingly use the same public runtime primitives as third-party CIs. This keeps the public SDK honest and prevents two incompatible systems from emerging.

## 2. Non-negotiable design principles

### 2.1 Declarative first

The default CI format is declarative. Layout, bindings, triggers, actions, animations, and permissions must be representable without executing third-party code.

Do not make scripting mandatory for ordinary CIs.

### 2.2 Halo owns rendering

A CI describes *what* to render. Halo decides *how* it is rendered using supported components and the current notch/surface system.

Third-party packages must not inject arbitrary SwiftUI/AppKit views into Halo's process.

### 2.3 Stable contract, private implementation

The SDK exposes versioned schemas and public capability names. It must not expose internal models such as `AppStore`, `WorkspaceStore`, concrete service classes, or private Swift types as API contracts.

Refactoring Halo internals must not require third-party packages to change unless a public SDK version changes.

### 2.4 Capability-based security

A CI receives no sensitive capability simply because it is installed.

Capabilities must be:

1. declared by the package;
2. validated by Halo;
3. approved by the user when appropriate;
4. granted through a brokered API;
5. revocable at any time.

### 2.5 No arbitrary in-process execution

This is critical.

Do **not** implement third-party execution using:

- `Bundle.load`;
- arbitrary dylib loading;
- unrestricted JavaScriptCore in the main Halo process;
- shell interpolation;
- arbitrary shell execution;
- downloaded Swift/native code executed in-process;
- `eval`-style execution in the app process.

If executable third-party logic is introduced, it must run in a **separate process/XPC-style host** with a versioned message protocol, strict capability brokering, quotas, cancellation, signature policy, revocation, and crash recovery.

Until that host exists, CI packages remain declarative.

### 2.6 Fail closed

Unknown schema versions, components, capabilities, actions, invalid signatures, malformed bindings, or unsupported package fields must never silently gain broader access.

Reject, ignore safely, or degrade to a clearly documented fallback.

## 3. Package format

Use the package extension:

```text
.haloCI
```

A CI package is an archive/directory with a deterministic structure:

```text
Example.haloCI/
├── manifest.json
├── interface.json
├── triggers.json              # optional
├── actions.json               # optional
├── permissions.json           # optional if embedded in manifest
├── assets/
│   ├── icon.svg
│   ├── artwork.webp
│   └── sounds/
├── localization/
│   ├── en.json
│   └── fr.json
└── scripts/                   # reserved until isolated runtime exists
    └── main.js
```

The `scripts` directory is reserved now so the format does not need a breaking redesign later. Presence of executable script content must be rejected while executable CI runtime support is unavailable.

Do not execute a file merely because it exists in the package.

## 4. Manifest contract

Every package requires `manifest.json`.

Minimum conceptual fields:

```json
{
  "schemaVersion": 1,
  "sdkVersion": "0.1",
  "id": "com.example.spotify-mini",
  "name": "Spotify Mini",
  "author": "Example Developer",
  "version": "1.0.0",
  "minimumHaloVersion": "1.0.0",
  "entryInterface": "interface.json",
  "description": "Compact media CI",
  "permissions": [],
  "capabilities": [],
  "supportedSurfaces": ["notch"],
  "supportedStates": ["closed", "expanded"]
}
```

Rules:

- `id` is stable and globally unique.
- Reinstalling the same `id` is an update/replace flow, not a second unrelated CI.
- Versions follow semantic versioning.
- Schema and SDK versions are separate.
- Halo must validate package size, asset count, file paths, JSON depth, numeric ranges, string lengths, and supported values before installation.
- Relative paths may not escape the package root.
- Duplicate normalized paths are invalid.
- Symlink/path traversal tricks must not be followed.

## 5. Declarative UI schema

The CI interface is a tree of Halo-owned components.

Example:

```json
{
  "type": "HStack",
  "spacing": 8,
  "children": [
    {
      "type": "Image",
      "source": "{{ media.artwork }}",
      "width": 36,
      "height": 36,
      "cornerRadius": 8
    },
    {
      "type": "VStack",
      "children": [
        {
          "type": "Text",
          "value": "{{ media.title }}",
          "lineLimit": 1
        },
        {
          "type": "Text",
          "value": "{{ media.artist }}",
          "style": "secondary",
          "lineLimit": 1
        }
      ]
    }
  ]
}
```

### 5.1 Initial component set

SDK 0.1 should support a deliberately bounded set:

- `Text`
- `Image`
- `Icon`
- `Button`
- `Toggle`
- `Slider`
- `Progress`
- `ProgressRing`
- `Spacer`
- `Divider`
- `HStack`
- `VStack`
- `ZStack`
- `Grid`
- `ScrollView`
- `Badge`
- `DropZone`

Halo-specific components may include:

- `NotchContainer`
- `MediaArtwork`
- `AudioVisualizer`
- `AppIcon`
- `DeviceBattery`
- `SystemMetric`
- `ClipboardPreview`
- `ActivityIndicator`

Do not expose arbitrary view class names.

### 5.2 Component behavior

Every public component must define:

- allowed properties;
- types and ranges;
- default values;
- accessibility behavior;
- binding support;
- event support;
- animation support;
- closed/expanded surface behavior;
- clipping rules;
- performance expectations.

Unknown properties must not mutate internal objects by reflection.

## 6. Reactive data bus

CIs consume state through a namespaced, read-only public data bus.

Potential namespaces:

```text
halo.*
system.*
media.*
audio.*
clipboard.*
apps.*
calendar.*
network.*
displays.*
bluetooth.*
recording.*
ci.*
```

Example public keys:

```text
halo.surface.state
halo.surface.isExpanded
halo.profile.id

system.battery.level
system.battery.isCharging
system.memory.usedFraction
system.storage.freeBytes

media.isPlaying
media.title
media.artist
media.artwork

audio.output.name
audio.volume

apps.active.bundleID
apps.active.name

calendar.nextEvent.title
calendar.nextEvent.startDate
```

Important: a public data key must correspond to data Halo can actually provide reliably. Do not advertise fake metrics. For example, current Halo architecture does not imply CPU/GPU telemetry exists just because a UI wants it.

Sensitive data remains permission-gated even when represented as a binding.

### 6.1 Binding syntax

Use simple, deterministic expressions first:

```text
{{ media.title }}
{{ system.battery.level }}
```

SDK 0.1 should avoid a full general-purpose expression language.

Add controlled transforms later, for example:

```text
{{ format.percent(system.battery.level) }}
{{ coalesce(media.title, "Nothing Playing") }}
```

Do not implement arbitrary code evaluation as a binding feature.

## 7. CI state model

Each CI instance has isolated runtime state.

Conceptual categories:

- package metadata;
- configuration chosen by the user;
- transient runtime state;
- persistent key/value state;
- secrets stored separately;
- permission grants;
- trigger activation state;
- current render tree/state.

A CI must never read another CI's private state.

State updates must not recreate the entire Halo surface/window unless required by the existing surface architecture.

## 8. Trigger system

A CI may define one or many launch/activation triggers.

Triggers are declarative and evaluated by Halo's trigger engine.

Examples:

- keyboard shortcut;
- mouse shortcut/button;
- supported trackpad gesture;
- active application/bundle ID;
- application launch/quit;
- media starts/stops;
- screen recording starts/stops;
- clipboard type changes;
- file dragged over notch;
- Bluetooth device connects/disconnects;
- battery threshold;
- charging state;
- display count/change;
- time window;
- calendar event proximity;
- timer completion;
- Halo profile/state;
- explicit user command.

A future trigger model may support compound conditions:

```text
(activeApp == Xcode) AND (screenRecording == false)
```

Rules:

- trigger evaluation must be deterministic;
- avoid uncontrolled polling where event APIs exist;
- document refresh frequency where polling is unavoidable;
- state transitions should be edge-triggered when appropriate to avoid repeated opening/churn;
- multiple matching CIs require a deterministic priority/ownership policy;
- trigger evaluation must not silently grant permissions.

## 9. Context system

A trigger answers **when** a CI is eligible to activate. Context describes **why/how** it was activated and what contextual payload is available.

Examples:

```text
keyboardShortcut
fileDrop
clipboardChanged
screenRecordingStarted
appOpened
mediaStarted
```

A single CI can support multiple contexts and adapt its UI accordingly.

The context payload must be typed and bounded. Do not pass arbitrary internal service objects.

`HaloCIContextProviderEngine` is the runtime authority for Custom CI context. Renderers and action brokers consume its filtered snapshots rather than assembling their own context dictionaries. Providers must be synchronous and side-effect free at snapshot time; event ingestion may prepare bounded state off-main when needed. See `Docs/ContextProviderEngine.md`.

## 10. Action system

CIs invoke operations through a public, brokered action catalog.

Examples:

```text
halo.ci.open
halo.ci.close
halo.ci.replace
halo.profile.activate
halo.notification.show

app.open
url.open
clipboard.copy
media.playPause
media.next
media.previous
app.integration.invoke
audio.volume.set
shortcut.run
file.openSelected
```

Each action definition must specify:

- identifier;
- input schema;
- output schema, if any;
- required capability/permission;
- whether user confirmation is required;
- cancellation behavior;
- timeout behavior;
- errors.

Actions may be chained declaratively, but chains must have hard limits on length and recursion.

No action may secretly become a generic shell escape hatch.

## 11. Interaction model

Supported event hooks may include:

- click/tap;
- double click;
- hover enter/exit;
- scroll;
- drag begin/end;
- drop;
- keyboard submit;
- value change;
- supported gesture;
- long press where meaningful on macOS input hardware.

Every event ultimately resolves to a supported declarative action or, in the future, a request to the isolated scripting host.

## 12. Permissions and capabilities

Use granular capability names rather than one giant "system access" permission.

Candidate permissions:

```text
Clipboard.Read
Clipboard.Write
Files.ReadSelected
Files.WriteSelected
Calendar.Read
Media.ReadState
Media.Control
Audio.ReadState
Audio.Control
Applications.Observe
AppIntegration.Execute
Bluetooth.Observe
ScreenRecording.Observe
Network.HTTP
Notifications.Post
Shortcuts.Run
```

Potential high-risk capabilities must be treated separately and may be forbidden for marketplace packages.

### 12.1 Shell/process execution

Do not expose unrestricted shell execution to normal public CIs.

If local/developer packages ever gain a process-execution capability, it must be clearly separated from marketplace eligibility, heavily permissioned, and never implied by a generic action.

### 12.2 Permission UX

Installation should show requested capabilities before approval.

Sensitive first-use access may require an additional prompt containing the exact operation/destination.

Permissions must be reviewable and revocable in Halo Settings.

## 13. Network model

A CI requiring HTTP must declare allowed hosts.

Example:

```json
{
  "network": {
    "hosts": [
      "api.github.com"
    ]
  }
}
```

Rules:

- HTTPS by default;
- exact or intentionally-scoped host allowlists;
- redirect destinations revalidated;
- request/response size caps;
- timeout limits;
- rate limits;
- no access to localhost/private-network targets by default;
- secrets never injected into requests unless the CI explicitly references a user-approved secret.

Network access must go through Halo's broker, not arbitrary socket APIs.

## 14. Storage and secrets

Provide two separate concepts.

### 14.1 Isolated key/value storage

For ordinary CI settings/state:

```text
ci.storage.get
ci.storage.set
ci.storage.remove
```

Storage is namespaced by CI ID and optionally instance ID.

Apply size quotas.

### 14.2 Secret storage

API tokens and other credentials must use Keychain-backed secret storage through a dedicated broker.

Secrets are never returned to another CI.

UI must clearly distinguish normal settings from secrets.

## 15. Assets

Supported package assets should be explicit and validated.

Examples:

- PNG/WebP images;
- SVG with a deliberately supported subset or pre-rasterization path;
- short audio files;
- localization JSON;
- optional video only after resource/performance rules are defined.

Set package and per-asset size limits.

Reject unsupported codecs/formats rather than handing arbitrary payloads to unsafe decoders.

## 16. Lifecycle

A CI runtime should have explicit lifecycle states such as:

```text
installed
inactive
eligible
activating
active
suspended
deactivating
disabled
failed
```

Important lifecycle events:

- install;
- update;
- enable/disable;
- activation;
- context change;
- surface expansion/collapse;
- profile change;
- permission change;
- sleep/wake;
- screen change;
- app relaunch;
- uninstall.

The runtime must handle crashes or invalid packages without destabilizing Halo.

## 17. Surface ownership and arbitration

CI is powerful because it can own the notch surface, but ownership must be deterministic.

Define one central arbitration layer that decides which content owns the surface when these compete:

- currently active CI;
- built-in transient Halo event;
- drag/drop interaction;
- media expansion;
- timer/notification activity;
- explicit user-opened CI;
- automation-triggered CI.

Do not scatter ownership decisions across individual views.

The arbitration model must define:

- priority;
- interruption policy;
- replacement policy;
- restoration of previous content;
- modal/transient content;
- timeout/dismissal behavior;
- explicit user override.

## 18. Animation contract

CIs may request supported animations, but Halo retains control over actual rendering and Reduce Motion behavior.

Expose named animation primitives rather than arbitrary compositor code in early SDK versions.

Examples:

```text
fade
scale
slide
spring
morph
notchExpand
notchCollapse
```

Respect existing surface animation architecture and do not recreate windows merely to animate CI transitions.

## 19. Performance rules

A CI must not be able to turn Halo into a permanent high-CPU process.

Define and enforce:

- maximum component count;
- maximum tree depth;
- maximum update frequency;
- animation limits;
- asset memory limits;
- network quotas;
- persistent storage quotas;
- scripting CPU/memory/time quotas when scripting exists;
- cancellation and timeout rules.

Bindings should update only when their dependencies change where possible.

Avoid per-frame reevaluation of arbitrary expressions.

## 20. Accessibility

The SDK must not make accessibility an afterthought.

Components must support:

- accessibility labels;
- hints where appropriate;
- keyboard navigation;
- focus order;
- Reduce Motion;
- increased contrast where supported;
- Dynamic Type-style scaling where practical in the constrained notch surface.

Marketplace validation should flag missing labels on interactive controls.

## 21. Localization

A package may include localization resources.

Example binding:

```text
{{ loc("play") }}
```

Fallback order should be deterministic and ultimately fall back to package default language/key.

## 22. Developer Mode

Halo Settings should eventually expose **CI Developer Mode**.

Developer Mode can allow loading an unpacked local package from a developer-selected directory and hot-reloading validated declarative files.

Suggested workflow:

```text
~/Developer/HaloCI/MyCI/
```

On save:

1. validate changed package files;
2. preserve last-known-good runtime if validation fails;
3. show developer diagnostics;
4. reload only affected CI state/render tree where possible.

Developer Mode does not mean "disable all security".

## 23. CI Inspector

Provide an inspector before the SDK becomes large.

The inspector should expose:

- component hierarchy;
- resolved properties;
- bindings and current values;
- active triggers;
- context payload;
- action history;
- permission grants;
- network requests;
- runtime warnings/errors;
- performance/update frequency;
- package metadata.

Do not expose user secrets in logs.

## 24. CI Studio

CI Studio is the future visual authoring environment.

Recommended layout:

```text
Left:   Components / Data / Triggers / Actions
Center: Live notch preview
Right:  Properties / Bindings / Animation / Events
Bottom: Timeline / Logs / State / Simulator
```

Studio edits the same package/schema used by hand-authored CIs. Do not invent a proprietary second representation that must be translated later.

## 25. Simulator

The developer tools should simulate common states without requiring the real external event.

Examples:

- media playing;
- battery at 5%;
- active app = Xcode;
- clipboard contains URL;
- Bluetooth headphones connected;
- screen recording active;
- file dragged over notch;
- timer finished;
- network offline.

Simulated data must be visibly marked as simulated in tooling.

## 26. CLI

A future CLI may provide:

```bash
halo ci init
halo ci validate
halo ci dev
halo ci build
halo ci sign
halo ci publish
```

The CLI must share schema validators with the app where possible to avoid disagreement between "valid in CLI" and "invalid in Halo".

## 27. Signing and trust

Public/marketplace CIs should eventually be signed.

Signing should bind at least:

- package identity;
- version;
- canonical package contents/hash;
- developer identity;
- SDK/schema metadata.

Any modification invalidates the signature.

Unsigned local packages may be allowed only through an explicit Developer Mode flow.

Do not embed signing private keys in Halo.

## 28. Marketplace

Do not build the marketplace before package validation, permissions, signing, and runtime compatibility are stable.

Marketplace metadata can include:

- title;
- developer;
- category;
- description;
- screenshots/video;
- version history;
- permissions;
- minimum Halo version;
- supported devices/surfaces;
- reviews/ratings;
- privacy information.

Installation flow:

```text
Discover → Review CI → Review permissions → Install → Configure → Enable
```

Marketplace packages must never receive extra privileges simply because they are featured or first-party-looking.

## 29. Deep links and sharing

A future sharing format may use links such as:

```text
halo://ci/install/com.example.spotify-mini
```

Deep links may navigate to an install/review screen but must not silently install or grant permissions.

## 30. Executable scripting — future phase only

Scripting is useful, but it is deliberately not the first implementation phase.

When introduced, the scripting runtime must be hosted outside Halo's main process.

Required architecture:

```text
Halo App
  ↓ versioned IPC messages
CI Runtime Broker
  ↓ capability-filtered requests
Isolated CI Script Host
```

The host must have:

- process isolation;
- versioned IPC schema;
- package identity attached to every request;
- capability checks in the Halo-side broker;
- CPU time limits;
- memory limits;
- request quotas;
- cancellation;
- watchdog/termination;
- crash recovery;
- structured logging;
- code-signature/trust policy;
- revocation/disable support.

A script must never receive raw references to Halo internals.

Conceptual future API:

```javascript
Halo.on("clipboard.changed", event => {
  Halo.state.set("kind", event.kind)
})

Halo.actions.invoke("media.playPause")
```

The API above is conceptual only until the isolated runtime exists.

## 31. SDK versioning

Each package declares both schema and SDK compatibility.

Halo must maintain a compatibility matrix.

Rules:

- additive fields can be introduced in compatible SDK versions;
- breaking semantic changes require a new SDK major version;
- deprecations must produce developer warnings before removal;
- old packages should remain functional where practical;
- migration logic belongs in the runtime/validator, not scattered through views.

## 32. First-party CI rule

As the runtime matures, new first-party CI-like experiences should prefer public SDK primitives unless there is a concrete reason they cannot.

This is how we prevent the public SDK from becoming a toy while Halo uses a secret superior internal system.

However, do not prematurely force unrelated existing Halo views through the CI runtime if doing so would destabilize the app. Migration should be incremental.

## 33. Implementation phases

### Phase 0 — Foundation

Before public SDK work:

- define CI package model;
- define validation pipeline;
- define stable identifiers/versioning;
- define surface ownership/arbitration model;
- define public data/action/capability registries;
- document current supported data sources truthfully.

### SDK 0.1 — Declarative core

Implement:

- `.haloCI` import/export;
- manifest validation;
- declarative component tree;
- basic styling;
- read-only bindings;
- declarative actions;
- trigger/context integration;
- isolated key/value storage;
- permissions model;
- Developer Mode local loading;
- diagnostics/validation errors.

Do **not** add executable scripts in 0.1.

### SDK 0.2 — Developer ergonomics

Implement:

- richer components;
- network broker;
- Keychain-backed secrets;
- CI Inspector;
- hot reload;
- simulator;
- package signing prototype;
- CLI validator/build tooling.

### SDK 0.3 — Visual authoring

Implement:

- CI Studio;
- drag/drop composition;
- binding editor;
- trigger/action editor;
- animation editor;
- live preview;
- package export.

### SDK 0.4+ — Isolated scripting

Only after the process-isolated host exists:

- versioned script API;
- event subscriptions;
- state mutations;
- brokered actions;
- brokered network;
- quotas/watchdog;
- marketplace restrictions.

### SDK 1.0 — Stable public contract

Before declaring 1.0:

- freeze core schemas;
- publish developer documentation;
- publish compatibility policy;
- provide sample packages;
- provide validator/CLI;
- provide signing flow;
- provide migration/deprecation rules;
- establish marketplace review criteria.

## 34. Validation requirements

Before installation, validate at minimum:

- archive structure;
- file count and size;
- manifest schema;
- IDs and semantic versions;
- minimum Halo/SDK versions;
- component types/properties;
- tree depth/component count;
- bindings;
- trigger/action identifiers;
- permissions;
- network hosts;
- asset paths/types/sizes;
- unsupported executable content;
- signature when required.

Validation errors should be specific enough for a developer to fix the package.

Bad:

```text
Invalid CI
```

Good:

```text
interface.json:42 — Progress.value expects a number or numeric binding; received string literal "full".
```

## 35. Testing requirements

Each public SDK feature needs tests at the contract level.

Required categories:

- schema validation tests;
- malformed package tests;
- path traversal tests;
- permission denial tests;
- action broker tests;
- trigger edge-transition tests;
- binding update tests;
- state isolation tests;
- package upgrade tests;
- compatibility tests across supported SDK versions;
- performance/large-tree tests;
- crash/failure recovery tests;
- signature verification tests once signing exists.

Do not rely only on UI snapshots for runtime correctness.

## 36. Explicit anti-patterns

Agents and contributors must **not** do any of the following merely because it is faster:

- add a second independent plugin runtime;
- expose arbitrary Swift/SwiftUI classes to packages;
- execute package JavaScript in Halo's main process;
- expose unrestricted shell commands;
- silently add broad filesystem access;
- bypass permission prompts for convenience;
- let packages read other packages' state;
- let packages call arbitrary internal selectors/functions;
- create a separate CI Studio-only document format;
- add undocumented data keys that are not actually supported;
- poll at frame rate for state that changes rarely;
- let a CI recreate app windows during ordinary state changes;
- hard-code one CI's behavior into the generic runtime;
- change schema semantics without bumping/versioning the contract.

## 37. Rules for AI coding agents

When an AI agent is asked to implement or modify CI SDK work, it must:

1. read this document first;
2. read `Docs/Architecture.md` and `Docs/Plugins.md` before changing extension/runtime code;
3. inspect existing CI/surface/trigger/action code before inventing new abstractions;
4. reuse existing ownership, surface, profile, and automation infrastructure where appropriate;
5. keep the public SDK declarative until an isolated executable host is explicitly implemented;
6. avoid claiming unsupported macOS/Halo capabilities exist;
7. add tests for every new parser, validator, capability, action, or lifecycle rule;
8. update this document when a public contract changes;
9. preserve backwards compatibility or explicitly version a breaking change;
10. stop and document a conflict instead of silently violating this architecture.

A coding agent must not interpret "make CI more powerful" as permission to add arbitrary execution or broad system access.

## 38. Definition of done for CI SDK changes

A CI SDK change is not done merely because the demo works.

It is done when:

- the public contract is documented;
- the schema is validated;
- permissions are explicit;
- errors are actionable;
- state remains isolated;
- the change respects surface ownership;
- accessibility is considered;
- performance limits are defined where relevant;
- tests cover success and failure paths;
- old compatible packages continue to work;
- no new arbitrary-code path is introduced into Halo's main process.

## 39. Architectural summary

The intended end-state is:

```text
                        ┌─────────────────────┐
                        │     CI Packages     │
                        │ .haloCI / Studio    │
                        └──────────┬──────────┘
                                   │
                          validate / install
                                   │
                        ┌──────────▼──────────┐
                        │    CI Runtime       │
                        │ Renderer            │
                        │ Binding Engine      │
                        │ Lifecycle           │
                        │ State               │
                        └──────┬─────┬────────┘
                               │     │
                      read data│     │request actions
                               │     │
                ┌──────────────▼─┐ ┌─▼──────────────┐
                │ Public Data Bus│ │ Action/Perm    │
                │ Halo-owned     │ │ Broker         │
                └──────────────┬─┘ └─┬──────────────┘
                               │     │
                         ┌─────▼─────▼─────┐
                         │ Halo Services   │
                         │ + Surface Owner │
                         └─────────────────┘

Future executable logic only:

CI Runtime ──versioned IPC──> Isolated Script Host
```

The key idea is simple: **CI should be extremely capable without making Halo itself unsafe or impossible to maintain.**

---

## Implemented Custom CI SDK 0.1 contract

Halo now includes an in-app **declarative** Custom CI runtime. Built-in Context Interfaces remain native Halo features; custom packages are a separate library section and only enter the existing central CI arbitration as another candidate.

### Package format

SDK 0.1 currently imports an **unpacked directory** ending in `.haloCI`:

```text
MyInterface.haloCI/
  manifest.json
  interface.json
  triggers.json        # optional
  assets/              # optional; local images only
  localization/        # reserved for a later SDK revision
```

Packed/archive `.haloCI` files are not extracted yet. `scripts/` and executable/script content are rejected. Custom CIs never execute third-party Swift, JavaScript, shell commands, dylibs, or arbitrary native code inside Halo.

Installed packages live under Halo\'s Application Support `CustomCI` directory. Re-importing the same manifest `id` updates that package while preserving its per-CI preferences where possible.

### Global switch and library

Settings → Context Notch Interface has a dedicated **Custom CI** section beneath the existing **Available CI** section.

- **Disable custom CI = off**: all loaded custom CIs are visible and can be enabled, prioritized, permissioned, opened manually, updated, or removed.
- **Disable custom CI = on**: packages remain installed but cannot render, trigger, or run brokered actions. Built-in Halo CIs are unaffected.

Each package also has its own enable toggle, priority, permission grants, and isolated local state.

### Manifest

```json
{
  "schemaVersion": 1,
  "sdkVersion": "0.1",
  "id": "com.example.nowplaying",
  "name": "Now Playing",
  "author": "Example Developer",
  "version": "1.0.0",
  "minimumHaloVersion": "1.0.0",
  "entryInterface": "interface.json",
  "description": "A small media CI",
  "permissions": ["Media.ReadState", "Media.Control"],
  "capabilities": ["AutomaticTriggers", "MediaControls"],
  "supportedSurfaces": ["notch"],
  "supportedStates": ["closed", "expanded"]
}
```

Supported permissions: `Media.ReadState`, `Media.Control`, `Applications.Observe`, `Clipboard.Write`, `URL.Open`; SDK 0.2 additionally implements `Audio.ReadState`, `Clipboard.Observe`, `Bluetooth.Observe`, `Notifications.Observe`, and `AppIntegration.Execute`.

Supported capability labels: `LocalAssets`, `LocalState`, `AutomaticTriggers`, `MediaControls`; SDK 0.2 additionally implements `AppIntegrations`. Capabilities are descriptive; they never grant authority. Permissions remain explicit and revocable.

### Interface document

`expanded` is required; `closed` is optional. If closed support is declared but no closed root exists, Halo shows a safe package-name fallback.

```json
{
  "closed": {
    "type": "HStack",
    "width": 230,
    "height": 40,
    "spacing": 7,
    "children": [
      { "type": "Icon", "systemName": "music.note" },
      { "type": "Text", "text": "{{ media.title }}", "lineLimit": 1 }
    ]
  },
  "expanded": {
    "type": "VStack",
    "width": 560,
    "height": 240,
    "spacing": 10,
    "padding": 16,
    "children": [
      { "type": "Text", "text": "{{ media.title }}", "style": "headline" },
      {
        "type": "Button",
        "text": "Play / Pause",
        "accessibilityLabel": "Play or pause media",
        "action": { "id": "media.playPause" }
      }
    ]
  }
}
```

Supported components: `Text`, `Image`, `Icon`, `Button`, `Toggle`, `Slider`, `Progress`, `ProgressRing`, `Spacer`, `Divider`, `HStack`, `VStack`, `ZStack`, `Grid`, `ScrollView`, `Badge`, `NotchContainer`, `MediaArtwork`, `AppIcon`, `DeviceBattery`, `SystemMetric`, `ActivityIndicator`.

The bounded component field set is: `type`, `id`, `text`, `value`, `source`, `systemName`, `metric`, `children`, `action`, `spacing`, `padding`, `width`, `height`, `cornerRadius`, `lineLimit`, `foreground`, `background`, `alignment`, `axis`, `columns`, `accessibilityLabel`, `stateKey`, `defaultBool`, `defaultNumber`, `minimum`, `maximum`, `step`, `style`. Unknown fields fail validation.

`Image` accepts only package-local `asset:<relative-path>` sources. `SystemMetric.metric` accepts `battery`, `cpu`, `memory`, `storage`, `networkDown`, `networkUp`, or `thermal`. Toggle/Slider state is namespaced by CI id and bounded to 64 keys / 32 KB.

### Bindings

Bindings are simple interpolation only—no expression language, reflection, JavaScript, `eval`, or arbitrary property access:

```text
{{ media.title }}
```

Supported keys: `halo.surface.state`, `halo.surface.isExpanded`, `system.battery.level`, `system.battery.isCharging`, `system.lowPowerMode`, `system.cpu.usedPercent`, `system.memory.usedPercent`, `system.storage.usedPercent`, `media.isPlaying`, `media.title`, `media.artist`, `media.album`, `apps.active.bundleID`, `apps.active.name`.

Media keys require `Media.ReadState`; application keys require `Applications.Observe`. Protected values are absent from a package\'s data bus until permission is granted.

### Brokered actions

SDK 0.1 button actions are inline descriptors. Supported actions are:

- `halo.ci.close`
- `clipboard.copy` — `Clipboard.Write`
- `url.open` — `URL.Open`; only `http`, `https`, or `mailto`, with a confirmation prompt
- `media.playPause` — `Media.Control`
- `media.next` — `Media.Control`
- `media.previous` — `Media.Control`
- SDK 0.2: `app.integration.invoke` — `AppIntegration.Execute`; requires `bundleIdentifier` and `actionID`, and resolves only against a currently validated installed `HaloIntegration.json`

`app.integration.invoke` is a manifest-backed broker, not a generic process launcher. No action can launch a shell, script, dylib, arbitrary selector, or arbitrary AppKit/Swift call.

### Automatic app-integration CIs

Halo may generate managed SDK 0.2 `.haloCI` packages from validated installed-app integration manifests. Generation must use the normal package validator, normal per-package preferences, normal priority arbitration, and the same action authorization boundary. Generated packages are identified by Halo-owned marker metadata and must never overwrite an unmarked user package.

The authoritative implementation/partner guide is `Docs/AutoIntegrationCI.md`.
### Triggers

`triggers.json` is optional. Without automatic triggers a package can still be opened manually.

```json
{
  "match": "any",
  "triggers": [
    { "type": "mediaPlaying", "bool": true },
    { "type": "activeApplication", "value": "com.apple.Music" }
  ]
}
```

Supported trigger types: `manual`, `mediaPlaying`, `activeApplication`, `batteryBelow`, `batteryAbove`, `charging`, `timeWindow` (`startMinute` / `endMinute`, 0...1439). `match` is `any` or `all`. `manual` is never an automatic match. Protected triggers require their declared + granted permission.

### Surface lifecycle and arbitration

Custom CIs do not create a second notch window. They use Halo\'s existing open/closed surface state and central priority arbitration. The winning custom package replaces notch content, while Halo retains hover/click/pin/collapse, animation, geometry, display ownership, and safety boundaries. Manual package activation gets temporary priority above automatic contexts because it is an explicit user request. Automatic packages use their configured 0...100 priority. Collapsing a manually opened custom CI returns to normal Halo; automatic packages remain eligible while their trigger remains true. `halo.ci.close` suppresses an automatic package until its trigger goes false, preventing reopen loops.

### Validation and limits

Halo validates a package before installation and again after staging. SDK 0.1 rejects or bounds unknown schema/SDK versions and fields, unsupported components/bindings/actions/triggers/permissions/capabilities/surfaces, undeclared permissions, path traversal, symbolic links, missing/unsupported assets, executable/script content, malformed JSON, packages over 128 files or 10 MB, JSON files over 512 KB, component trees over 180 nodes or depth 16, and out-of-range layout/control values. Interactive controls without an accessibility label produce a warning.

A working starter package is committed at `Examples/HelloWorld.haloCI/`.


## Surface ownership contract: sizing, background, and priority

Every `.haloCI` package must declare `manifest.json.surface`. A Custom CI is rejected at import time if this contract is missing.

```json
"surface": {
  "sizing": {
    "mode": "static",
    "closed": { "width": 250, "height": 40 },
    "expanded": { "width": 560, "height": 250 }
  },
  "background": {
    "closed": { "type": "solid", "color": "#0C0D10", "opacity": 1 },
    "expanded": { "type": "gradient", "color": "#0C0D10", "secondaryColor": "#161A24", "opacity": 1 }
  }
}
```

`static` sizing makes the declared dimensions authoritative. `dynamic` sizing measures Halo's declarative render tree and clamps it to required `minWidth`, `preferredWidth`, `maxWidth`, `minHeight`, `preferredHeight`, and `maxHeight` values for each supported state. The physical camera/notch remains a hard safety floor on notched Macs, and the visible display bounds remain a hard ceiling.

A Custom CI always owns its background while it owns the notch. Backgrounds are state-specific and currently support `solid`, `gradient`, `glass`, and `clear`. Halo's normal workspace/album-art background is not composited behind an active Custom CI.

CI arbitration occurs before trigger evaluation. Halo evaluates eligible CIs from highest priority downward and stops at the first owner. If a built-in or Custom CI with a higher priority already owns/claims the notch, a lower-priority Custom CI is not trigger-evaluated, does not animate, and does not open. Manual Open requests use the CI's configured priority; they do not bypass a higher-priority owner.
