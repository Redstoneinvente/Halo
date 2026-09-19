# Halo App Integration CI Architecture

> **Status: Authoritative target architecture for third-party app integrations.**
>
> This document defines how an installed macOS application becomes a configurable Halo Context Interface (CI), how triggers activate it, how privileged payloads are retained, and how actions are delivered back to the partner application.
>
> Where this document conflicts with the older generated-package design in `Docs/AutoIntegrationCI.md`, this document wins. The generated-package document remains useful as implementation history, but physical generation of one managed `.haloCI` package per compatible app is no longer the target architecture.

## 1. Goal

A compatible application should be able to integrate with Halo by shipping a manifest and handling invocation requests.

The app developer or coding agent should not need to modify Halo.

The desired flow is:

```text
Partner app
    ↓
HaloIntegration.json
    ↓
IntegrationDefinition
    ↓
IntegrationCIFactory
    ↓
CIRegistration
    ├── presentation
    ├── actions
    ├── triggers
    └── capabilities
            ↓
     CIConfigurationStore
            ↓
        TriggerRouter
            ↓
      eligible candidates
            ↓
        normal CI arbiter
            ↓
          winner
            ↓
      normal Halo surface
            ↓
    IntegrationActionBroker
            ↓
      IntegrationTransport
            ↓
        Partner app
```

The core invariant is:

> Adding support for a new partner app must require zero changes to `SurfaceView`, `WindowManager`, `WorkspaceStore`, or other app-specific Halo runtime code.

Only the partner manifest and partner-side action implementation should normally change.

## 2. Non-goals

This architecture does not:

- load arbitrary partner Swift, dylibs, JavaScript, or AppKit into Halo;
- give partner apps direct access to `NSPanel`, `WindowManager`, or Halo private models;
- create another priority system;
- make Drop CI the owner of file-drag detection;
- permit a trigger to directly resize or render the Halo surface;
- expose raw privileged payloads such as filesystem paths through the public declarative context bus;
- make a physical generated `.haloCI` directory the persistent identity of an app integration.

Third-party integration remains declarative and brokered.

## 3. One runtime representation: CIRegistration

The runtime should consume one common registration model regardless of where a CI came from.

Conceptually:

```swift
struct CIRegistration {
    let id: CIIdentifier
    let source: CISource
    let metadata: CIMetadata
    let presentation: CIPresentationDescriptor
    let triggers: [CITriggerDescriptor]
    let actions: [CIActionDescriptor]
    let capabilities: Set<CICapability>
}
```

Two different inputs may produce the same runtime form:

```text
Validated .haloCI package ──→ CustomCIFactory ───────┐
                                                     ↓
                                                CIRegistration
                                                     ↑
HaloIntegration.json ──→ IntegrationDefinition ──→ IntegrationCIFactory
```

`CIRegistration` is immutable runtime metadata. Mutable user choices do not belong inside it.

This lets the existing Custom CI arbitration/rendering path remain authoritative without requiring an integration app to masquerade as a generated on-disk package.

## 4. Discovery: IntegrationDefinition

`HaloIntegrationCatalog` should only discover and validate applications.

Its output is a normalized immutable model such as:

```swift
struct IntegrationDefinition {
    let protocolVersion: Int
    let app: IntegrationAppIdentity
    let actions: [IntegrationActionDefinition]
    let triggers: [IntegrationTriggerDefinition]
    let delivery: IntegrationDeliveryDefinition
}
```

Discovery may answer:

- which app was found;
- whether its bundle identifier matches;
- which actions it advertises;
- which typed inputs/options those actions accept;
- which trigger types it requests;
- which transport it supports.

Discovery must not:

- open Halo;
- make the CI active;
- mutate surface geometry;
- execute an action;
- hold a drag session;
- decide priority;
- render SwiftUI.

Discovery answers exactly one question:

> What capabilities does this installed application advertise?

## 5. Persistent customization: CIConfigurationStore

A CI registration and its user configuration are separate objects.

Configuration should be keyed by stable CI/action/trigger IDs and survive partner-manifest refreshes.

Conceptually:

```swift
struct CIConfiguration {
    var enabled: Bool
    var priority: Double
    var grantedPermissions: Set<String>
    var actionEnabled: [ActionID: Bool]
    var triggerEnabled: [TriggerID: Bool]
    var triggerSettings: [TriggerID: TriggerConfiguration]
    var actionDefaults: [ActionID: [String: CIValue]]
    var presentation: CIPresentationPreferences
}
```

This store is where Halo persists:

- CI enabled/disabled state;
- priority;
- per-function enabled state;
- per-trigger enabled state;
- keyboard shortcut assignments;
- auto-open preferences;
- permission grants;
- action option defaults;
- supported presentation preferences.

If a partner updates `HaloIntegration.json`, Halo refreshes the registration while preserving configuration for IDs that still exist.

No generated-package fingerprinting is required to preserve these preferences.

## 6. Settings UI

Integration CIs should use the same normal CI settings shell as built-in and declarative CIs.

The common card should expose, where applicable:

- icon;
- CI name;
- enabled toggle;
- priority;
- Open/Test;
- Configure;
- permission state.

The integration-specific configuration section is generated from the registration:

- advertised actions;
- per-action enable toggles;
- typed option metadata/defaults;
- triggers;
- per-trigger enable toggles;
- trigger-specific settings such as keyboard shortcut assignment or auto-open;
- diagnostics for invalid/unavailable capabilities.

The app developer should not have to write Halo Settings UI.

## 7. TriggerRouter

Trigger detection must be independent from every CI.

Halo owns event sources. Event sources publish a normalized `TriggerEvent`.

Conceptually:

```swift
struct TriggerEvent {
    let id: UUID
    let kind: TriggerKind
    let timestamp: Date
    let metadata: [String: CIValue]
    let payloadHandle: PayloadHandle?
}
```

Initial trigger kinds may include:

```text
manual
fileDrag
fileDrop
keyboardShortcut
appActivated
appDeactivated
clipboardChanged
mediaStarted
mediaStopped
partnerEvent
systemEvent
```

A trigger event never directly opens a CI.

The flow is:

```text
event source
    ↓
TriggerRouter
    ↓
CIEligibilityEngine
    ↓
matching enabled CI registrations
    ↓
candidate set
    ↓
normal Halo CI arbitration
```

This is the critical decoupling.

### 7.1 File dragging is not Drop CI

Drop CI must not own file-drag detection.

For a text file drag:

```text
fileDrag event
     ↓
TriggerRouter
     ├── Drop CI matches
     └── Partner Text Utility CI matches
                 ↓
            candidate set
                 ↓
          normal priority arbiter
                 ↓
               winner
```

If Drop CI is disabled, the partner CI must still receive eligibility from `fileDrag`.

This behavior requires a permanent regression test.

## 8. CIEligibilityEngine

Eligibility evaluates registrations against an event and current user configuration.

A CI is eligible only when all required conditions hold, for example:

- CI enabled;
- trigger enabled;
- permissions required for trigger evaluation are available;
- event kind matches;
- trigger predicate matches event metadata;
- at least one enabled action is compatible where the trigger depends on action compatibility.

Eligibility must be:

- cheap;
- side-effect free;
- deterministic for the supplied event/configuration snapshot;
- independent from surface expansion;
- independent from geometry.

Eligibility is not ownership.

Ownership is decided only by the normal CI arbiter.

## 9. Trigger metadata versus privileged payload

Triggers may contain both safe descriptive metadata and privileged input.

These must be separated.

Example file drag:

```text
TriggerEvent
    metadata:
        itemCount = 2
        fileCount = 2
        extensions = ["txt"]

    payloadHandle:
        7B20...9AF
             ↓
      TriggerPayloadStore
             ↓
    [actual URL 1, actual URL 2]
```

Safe bounded metadata may flow through `HaloCIContextProviderEngine`.

The actual file URLs must not be placed into the declarative context bus.

The privileged payload is retained by a Halo-owned `TriggerPayloadStore` and referenced through an opaque handle.

Only an authorized brokered action may resolve that handle.

The same design can later support other sensitive payloads without exposing them to renderers.

## 10. CIActivationSession

Every triggered activation should have an explicit session.

Conceptually:

```swift
struct CIActivationSession {
    let id: UUID
    let ciID: CIIdentifier
    let triggerEventID: UUID
    let payloadHandle: PayloadHandle?
    let activatedAt: Date

    var committed: Bool
    var dismissed: Bool
    var openedSurfaceAutomatically: Bool
}
```

The activation session owns transient lifecycle state, not the CI registration.

For file drag:

1. files enter Halo;
2. one drag trigger event is created;
3. compatible CIs become candidates;
4. the arbiter selects a winner;
5. winning activation may open Halo according to user/runtime policy;
6. leaving without drop cancels the uncommitted payload/session;
7. dropping commits the payload;
8. invoking an action consumes or otherwise completes the payload according to policy;
9. dismissal ends the session.

This is also the correct place to remember whether that activation auto-opened Halo, preventing a later callback from collapsing a surface that the user opened independently.

## 11. Surface ownership

Integration CIs use the normal CI ownership path.

The state transition remains:

```text
trigger matched
    ↓
eligible candidate
    ↓
normal priority arbitration
    ↓
winner
    ↓
activation coordinator
    ↓
render through normal CI surface
```

The following remain distinct:

- eligible;
- active/owner;
- expanded.

A trigger must not directly call `WindowManager`, set `SurfaceState.expanded`, or resize an `NSPanel`.

Automatic expansion, when enabled, is performed by the activation coordinator only after the CI wins ownership.

Geometry still flows through the existing CI surface sizing contract into `WindowManager`.

## 12. Presentation

Protocol-level app integrations should begin with a first-party Halo renderer rather than requiring every app developer to design a complete interface.

For example:

```text
IntegrationCIView
    ├── app icon/name
    ├── current trigger/input summary
    ├── compatible enabled actions
    ├── typed action controls
    └── close/dismiss controls
```

The registration supplies descriptors; Halo supplies the SwiftUI.

A bespoke visual experience can still be provided through a normal declarative `.haloCI` package when needed.

This keeps simple integrations simple.

## 13. IntegrationActionBroker

Rendering must not know how to execute a partner action.

A generated action control calls one broker:

```text
execute(
    ciID,
    actionID,
    activationSessionID
)
```

The broker must re-resolve and revalidate current state at execution time:

1. CI still exists;
2. CI still enabled;
3. action still exists;
4. action still enabled;
5. declared permissions still exist;
6. user grants are still valid;
7. target app still exists;
8. target bundle identifier still matches;
9. current partner manifest still validates;
10. requested input is compatible;
11. required options are present and correctly typed;
12. privileged payload handle still belongs to this activation;
13. after any interactive prompt, all relevant authorization/state checks are repeated.

Only then does the broker call an `IntegrationTransport`.

## 14. IntegrationTransport

Delivery to the partner app is abstracted behind a transport interface.

Conceptually:

```swift
protocol IntegrationTransport {
    func deliver(_ invocation: IntegrationInvocation) async throws
}
```

Protocol v1 may continue using the existing open-request transport:

```text
request.halorequest
selected-file-1.txt
selected-file-2.txt
        ↓
NSWorkspace / normal macOS open-URL flow
        ↓
partner app
```

The request remains versioned and action-ID based.

Future transports could be added without changing CI rendering, triggering, or arbitration, for example:

- openRequest;
- XPC, if a properly designed versioned broker is introduced;
- another explicitly versioned safe transport.

There is no generic shell/process escape hatch.

## 15. Partner-to-Halo, event-to-CI, and Halo-to-partner are separate contracts

Do not merge these directions.

```text
PARTNER → HALO
HaloIntegration.json
"What can this app do?"

EVENT → HALO CI RUNTIME
TriggerEvent
"What just happened?"

HALO → PARTNER
IntegrationInvocation
"Perform this declared action with this authorized input."
```

Each has different trust, lifetime, and validation requirements.

## 16. Protocol v2 target manifest

Protocol v1 remains supported for compatibility.

Protocol v2 should remove duplicated trigger/action input declarations and generalize triggers.

Example:

```json
{
  "protocolVersion": 2,

  "app": {
    "name": "Halo Integration Test",
    "bundleIdentifier": "com.redstoneinvente.HaloIntegrationTest"
  },

  "presentation": {
    "card": {
      "bannerImage": "HaloCardBanner.png",
      "category": "File Tools",
      "description": "Read or rename dropped text files.",
      "accentColor": "#1E7BFF"
    }
  },

  "actions": [
    {
      "id": "read.text",
      "name": "Read Text File",
      "input": {
        "type": "files",
        "extensions": ["txt"],
        "multiple": false
      },
      "options": []
    },

    {
      "id": "rename.file",
      "name": "Rename File",
      "input": {
        "type": "files",
        "extensions": ["txt"],
        "multiple": false
      },
      "options": [
        {
          "key": "newName",
          "name": "New file name",
          "type": "string",
          "required": true
        },
        {
          "key": "preserveExtension",
          "name": "Preserve extension",
          "type": "boolean",
          "required": false,
          "default": true
        }
      ]
    }
  ],

  "triggers": [
    {
      "id": "files.dragged",
      "type": "fileDrag",
      "actions": ["read.text", "rename.file"]
    },
    {
      "id": "open.shortcut",
      "type": "keyboardShortcut"
    },
    {
      "id": "conversion.ready",
      "type": "partnerEvent",
      "event": "conversion.ready"
    }
  ],

  "delivery": {
    "type": "openRequest"
  }
}
```

Actions own their input requirements.

Partner card presentation is optional additive metadata. `bannerImage` is resolved only as a filename inside the discovered app's Resources directory; absolute paths, path traversal and remote artwork are not accepted. Recommended partner artwork is 1200 × 540 px with important content kept inside a centered 1040 × 420 px safe area. If artwork is absent or cannot be loaded, Halo renders a generated fallback card.

A `fileDrag` trigger referencing actions derives compatibility from those actions instead of duplicating extensions in multiple places.

Protocol-v1 manifests continue to normalize into the same `IntegrationDefinition`.

## 17. File drag flow

The complete target flow is:

```text
User starts dragging file
        ↓
Halo drag event source
        ↓
classify payload once
        ↓
TriggerPayloadStore
    ├── actual URLs
    └── opaque handle
        ↓
TriggerRouter(fileDrag)
        ↓
evaluate every registered CI with an enabled fileDrag trigger
        ↓
candidate set
        ↓
normal priority arbiter
        ↓
winner
        ↓
CIActivationCoordinator
        ↓
expand only if policy says so and winner still owns surface
        ↓
IntegrationCIView
        ↓
user drops
        ↓
activation payload committed
        ↓
user invokes action
        ↓
IntegrationActionBroker
        ↓
resolve authorized payload handle
        ↓
validate action/options/files again
        ↓
IntegrationTransport
        ↓
partner app
```

Drop CI is not a dependency anywhere in this chain.

## 18. Keyboard shortcut flow

A partner may request the capability:

```json
{
  "id": "open.shortcut",
  "type": "keyboardShortcut"
}
```

The partner does not choose or register a global shortcut.

Halo Settings lets the user assign it.

```text
Halo HotkeyService
    ↓
TriggerEvent.keyboardShortcut
    ↓
TriggerRouter
    ↓
CIEligibilityEngine
    ↓
candidate
    ↓
normal arbitration
```

Halo remains the sole authority for Halo-trigger keyboard shortcuts and conflict handling.

## 19. Partner event flow

A partner-originated event is another event source, not another CI architecture.

A future partner-event ingress mechanism must:

- use a versioned protocol;
- identify the source app;
- validate source identity;
- accept only bounded declared event types/payloads;
- translate the event into a normal `TriggerEvent`;
- never directly render or resize Halo;
- never bypass CI enablement/priority/permissions.

The resulting event then follows the same router → eligibility → arbitration path.

## 20. Agent-friendly integration workflow

An agent integrating a partner app should normally perform only these steps:

1. inspect the app's supported operations;
2. create or update `HaloIntegration.json`;
3. create partner-side request/action handlers if required;
4. run the Halo manifest validator;
5. add the manifest to the app target's Copy Bundle Resources phase;
6. build/run the partner app;
7. Halo discovers the app;
8. Halo creates a runtime registration;
9. the CI card appears automatically;
10. the user configures actions, priority, permissions and triggers.

Useful CLI targets:

```text
halo-ci integration init
halo-ci integration validate HaloIntegration.json
halo-ci integration inspect HaloIntegration.json
```

Validation errors should identify the exact action, option or trigger that is invalid.

## 21. Migration from the current V2 implementation branch

The current `codex/implementation-of-custom-ci-v2` branch contains useful work that should be retained, including:

- app bundle discovery;
- manifest validation;
- typed app actions/options;
- declarative Custom CI runtime;
- `HaloCIContextProviderEngine`;
- brokered `app.integration.invoke` semantics;
- file-drag classification work;
- permission checks;
- existing open-request partner delivery;
- SDK validation/tests.

The architectural refactor is to separate responsibilities and remove the need for the generated on-disk package loop.

Target module boundaries:

```text
HaloIntegrationManifest
    decode + validation only

HaloIntegrationCatalog
    discovery only

IntegrationCIFactory
    IntegrationDefinition → CIRegistration

CIConfigurationStore
    persistent per-CI/action/trigger user settings

CITriggerRouter
    normalized event routing

CIEligibilityEngine
    side-effect-free event/registration matching

TriggerPayloadStore
    privileged ephemeral payload ownership

CIActivationCoordinator
    activation sessions + auto-open/dismiss lifecycle

IntegrationActionBroker
    permission/input/action revalidation

IntegrationTransport
    partner delivery

IntegrationCIView
    Halo-owned presentation
```

Do not continue growing one integration file that performs all of these jobs.

## 22. Implementation order

Implement this architecture incrementally.

### Phase 1 — Runtime representation

- Add `CIRegistration`.
- Adapt existing Custom CI runtime to consume registrations.
- Do not change visible behavior yet.
- Add registration identity/configuration tests.

### Phase 2 — Integration factory

- Normalize protocol-v1 manifests to `IntegrationDefinition`.
- Create `IntegrationCIFactory`.
- Register compatible apps in memory without generating physical `.haloCI` packages.
- Persist configuration separately.

### Phase 3 — Manual activation

- Make an integration CI appear in normal CI Settings.
- Open it manually.
- Render through normal Custom CI surface ownership/sizing.
- Execute existing app integration actions through the broker.

### Phase 4 — Trigger router

- Introduce normalized trigger events.
- Route existing/manual/file-drag signals through it.
- Make eligibility independent from rendering and Drop CI.

### Phase 5 — Activation sessions and payload store

- Add opaque payload handles.
- Move actual dragged URLs into `TriggerPayloadStore`.
- Implement commit/cancel/consume lifecycle.
- Make stale callbacks session/generation safe.

### Phase 6 — File drag

- Enable `fileDrag` registrations.
- Verify partner CI opens with Drop CI disabled.
- Verify multiple compatible CIs compete only through normal priority arbitration.

### Phase 7 — Keyboard shortcut

- Add user-assigned Halo-owned shortcuts.
- Route shortcut events through the same trigger path.

### Phase 8 — Protocol v2

- Add generalized trigger descriptors.
- Keep protocol-v1 decoding as a compatibility adapter.
- Add validator/CLI support.

### Phase 9 — Partner events

- Add only after a secure, bounded versioned event-ingress mechanism is designed and tested.

## 23. Required regression tests

At minimum:

- compatible app discovered;
- invalid manifest rejected;
- manifest refresh preserves CI configuration;
- removed action removes only that action's runtime availability;
- CI disabled means no eligibility;
- trigger disabled means no trigger eligibility;
- file drag works while Drop CI is disabled;
- Drop CI and integration CI may both become candidates;
- higher priority wins;
- equal-priority behavior is deterministic;
- losing CI cannot resize the winner;
- stale activation callback cannot clear incoming geometry;
- drag leave cancels uncommitted payload;
- drop commits payload;
- payload cannot be resolved by another CI/activation;
- revoked permission blocks stale UI action;
- partner action removed after UI render blocks execution;
- unsupported files rejected;
- invalid typed options rejected;
- keyboard shortcut collision handled by Halo;
- user-opened surface is not collapsed by an unrelated finishing activation;
- two displays do not clear each other's activation/geometry state;
- sleep/wake and app removal cancel stale sessions safely;
- protocol-v1 integration still works after protocol-v2 support lands.

## 24. Architectural invariants

The implementation is wrong if any of the following becomes false:

1. Trigger detection is independent from individual CIs.
2. Drop CI is not required for app-integration file dragging.
3. Eligibility is separate from ownership.
4. Ownership is separate from expansion.
5. Only the central arbiter decides which CI owns the surface.
6. Integration renderers do not resize windows directly.
7. Privileged payloads are not published on the declarative context bus.
8. Action execution rechecks current permission and manifest state.
9. A partner app cannot invoke arbitrary code inside Halo.
10. A new partner app requires no Halo source patch.
11. User configuration is keyed to stable CI/action/trigger identity, not generated package files.
12. Trigger, renderer, broker, discovery, and transport remain separate responsibilities.
13. Built-in and third-party CIs converge on the same runtime registration/arbitration concepts rather than creating parallel systems.

## 25. Definition of done

The app-integration architecture is considered complete when a test partner app can:

1. ship a valid manifest;
2. be discovered automatically;
3. appear as a normal configurable CI card;
4. expose individually toggleable actions;
5. expose individually configurable triggers;
6. receive a file-drag trigger with Drop CI disabled;
7. compete normally against other CIs using priority;
8. open through a user-assigned keyboard shortcut;
9. receive only the authorized payload associated with the winning activation;
10. execute through the brokered transport;
11. update its manifest without losing unrelated user configuration;
12. accomplish all of the above without adding app-specific code to Halo.

That is the contract future agents should build toward.
