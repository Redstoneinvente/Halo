# Halo App Integration Discovery

Halo can discover capabilities exposed by installed macOS applications without loading third-party code into the Halo process.

This protocol is **capability discovery only**. It does not create a second CI renderer, bypass Context Interface arbitration, or grant an external app direct access to Halo UI. Halo remains responsible for any CI presentation, permissions, ownership, sizing, backgrounds, and user interaction.

## Manifest location

A partner app includes this file in its bundle:

\`\`\`text
Partner App.app/
└── Contents/
    └── Resources/
        └── HaloIntegration.json
\`\`\`

In Xcode, add \`HaloIntegration.json\` to the app target's **Copy Bundle Resources** build phase.

Halo scans:

- \`/Applications\`
- \`~/Applications\`
- \`/System/Applications\`
- \`/System/Library/CoreServices/Applications\`
- currently running app bundles, including Xcode/DerivedData builds

Running copies are considered first so a developer build can be tested without installing it into \`/Applications\`.

## Protocol v1

Example:

\`\`\`json
{
  "protocolVersion": 1,
  "name": "Partner App",
  "bundleIdentifier": "com.example.partner",
  "actions": [
    {
      "id": "convert.image",
      "name": "Convert Image",
      "supportedExtensions": ["png", "jpg", "jpeg"],
      "options": [
        {
          "key": "quality",
          "name": "Quality",
          "type": "integer",
          "required": false,
          "description": "Output quality"
        }
      ]
    }
  ]
}
\`\`\`

### Root fields

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| \`protocolVersion\` | Integer | Yes | Must currently be \`1\`. |
| \`name\` | String | Yes | Human-readable app name. |
| \`bundleIdentifier\` | String | Yes | Must match the actual macOS app bundle identifier. |
| \`actions\` | Array | Yes | One or more actions exposed to Halo. |

### Action fields

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| \`id\` | String | Yes | Stable unique action ID within the app. |
| \`name\` | String | Yes | Human-readable action name. |
| \`supportedExtensions\` | String array | Yes | File extensions accepted by the action. \`"*"\` means any extension. |
| \`options\` | Array | Yes | Typed parameters accepted by the action. May be empty. |

### Option fields

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| \`key\` | String | Yes | Unique option key within the action. |
| \`name\` | String | Yes | Human-readable label. |
| \`type\` | String | Yes | One of the supported types below. |
| \`required\` | Boolean | Yes | Whether the caller must provide the option. |
| \`description\` | String/null | No | Help text. |

Supported option types:

- \`string\`
- \`integer\`
- \`double\`
- \`boolean\`
- \`stringArray\`
- \`integerArray\`
- \`doubleArray\`

## Validation and trust boundary

Halo validates the manifest before adding an app to the integration catalogue:

- protocol version must be supported;
- the manifest is size-bounded;
- app name and bundle identifier must be non-empty;
- the declared bundle identifier must match the actual app bundle;
- action IDs must be non-empty and unique;
- option keys must be non-empty and unique per action;
- option types must be from the supported set.

Malformed manifests are ignored and surfaced in CI Settings diagnostics.

Halo does **not** use \`Bundle.load\`, load a third-party dylib, evaluate scripts, or execute code merely because an app provides this manifest. Discovery reads static JSON from the app's Resources directory.

## Halo UI

Open:

**Halo Settings → Context Notch Interfaces → App integrations**

Halo lists each discovered app, bundle identifier, application path, supported file extensions, actions, and typed options. **Scan Again** refreshes the catalogue.

The catalogue is independent of Drop CI. Future file-drag or other Context Interface experiences may consume this catalogue, but ownership still has to go through Halo's normal CI arbitration.

## Base CI design record

This feature is **not itself a Context Interface**. It is an app-capability discovery service intended to feed Halo-owned CI experiences, so it deliberately does not register an `ActiveContextInterface`, render a surface, publish geometry, or participate in priority arbitration.

```text
CI name / stable identity: App Integration Discovery Catalog (service, not a CI owner)
Implementation path and reason: Native app-owned discovery service; filesystem/app-bundle discovery cannot be expressed by a .haloCI package, and no new render path is introduced.
Purpose: Find installed partner apps that explicitly advertise Halo-compatible actions.
Real context source / existing service: NSWorkspace running applications plus standard macOS application folders and static app Resources.
Enable setting and default: not needed — discovery is passive metadata lookup when the catalogue is created/refreshed.
Priority setting and default (normal range 0...100): not needed — catalogue does not compete for the surface.
Tie behavior / reason: not needed — no arbitration candidate is registered.
Side-effect-free eligibility rule: not needed — discovery produces metadata, not eligibility.
Manual activation behavior: not needed — Scan Again only refreshes the catalogue.
Automatic expansion policy (default: no auto-open): no auto-open.
Dismissal / retrigger policy: not needed.
Closed presentation (default: normal Closed Notch): unchanged.
Expanded presentation: unchanged; CI Settings only lists discovered capabilities.
Full-surface ownership (default: false for native opened-only CI): false / not applicable.
Keep Closed Notch contents while expanded (default: false): unchanged / not applicable.
Background owner / layer: none — discovery does not render a notch background.
Expanded size rule and sizing inputs: none.
Compact width / height / minimum expanded width (only if needed): none.
Geometry publication and handoff/cleanup owner: none.
Global versus profile settings: global read-only catalogue; no profile state.
Context bindings, units, unavailable-data behavior: none.
Permissions / revocation / commercial-access boundaries: no sensitive Halo data is granted; malformed/unsupported manifests are ignored with diagnostics.
Actions and their broker: discovery only — no partner action is executed by this implementation.
Subscriptions / refresh cadence / cancellation: initial refresh on catalogue creation plus explicit Scan Again; running app URLs are snapshotted before detached scanning.
Per-display versus shared state: shared global catalogue; it has no per-display surface state.
Settings card / controls / accessibility: Context Notch Interfaces → App integrations, with Scan Again and readable action/option metadata.
Compatibility and persistence migration: protocol v1 matches the existing Halo-Integration-Test-App manifest; no persisted migration.
Tests and manual checks: protocol-v1 decode, bundle-ID mismatch, duplicate actions and unsupported option types covered by HaloCoreTests; macOS build/test workflow added.
```

### Verification matrix

| Check | Result | Reason |
| --- | --- | --- |
| Disabled at launch / disabled while active | Not applicable | Discovery is not a CI owner and has no enable lifecycle. |
| Eligible closed vs expanded / auto-open | Pass by construction | No eligibility registration and no expansion mutation. |
| Higher/equal-priority arbitration | Not applicable | No arbitration candidate is added. |
| Replaced by another CI / geometry cleanup | Pass by construction | No SurfaceState geometry is written. |
| Full-surface/background ownership | Not applicable | Catalogue renders only in Settings. |
| Close/dismiss/pinning | Not applicable | No surface activation. |
| Permission denial/revocation / stale UI action | Not applicable for discovery | No protected data or partner action execution is introduced. |
| Unavailable/malformed context | Covered by tests/diagnostics | Invalid manifests fail validation and are omitted. |
| Two displays / host removal / sleep-wake | Not applicable | Catalogue is global metadata and owns no display host. |
| Settings/accessibility | Implemented; manual runtime check not run here | Settings uses standard SwiftUI controls/text. |
| Existing SDK 0.1 compatibility | Unchanged | No `.haloCI` schema/component/action/permission field changed. |
| Full Halo Xcode build/test | Workflow added; result not claimed here | `validate-app-integration-discovery.yml` runs macOS build + tests on this branch. |
