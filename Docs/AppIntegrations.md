# Halo App Integration Discovery

> **Target architecture:** Discovery feeds the shared CI registration/runtime described in [`AppIntegrationCIArchitecture.md`](AppIntegrationCIArchitecture.md). The current branch still contains generated-package implementation work, but physical managed `.haloCI` generation is a migration detail, not the long-term integration contract.

Halo discovers capabilities exposed by installed macOS applications by reading a static manifest from the application bundle. It does not load third-party code into Halo.

Discovery feeds the [Automatic App Integration Custom CI framework](AutoIntegrationCI.md). Halo can generate normal declarative `.haloCI` packages from discovered manifests, but the discovery layer itself remains static capability metadata.

## Manifest location

A partner app includes:

```text
Partner App.app/
└── Contents/
    └── Resources/
        └── HaloIntegration.json
```

In Xcode, add `HaloIntegration.json` to the app target's **Copy Bundle Resources** build phase.

Halo scans:

- `/Applications`
- `~/Applications`
- `/System/Applications`
- `/System/Library/CoreServices/Applications`
- currently running app bundles, including Xcode/DerivedData builds

Running copies are considered first so a developer build can be tested without copying it to `/Applications`.

## Protocol v1

```json
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
```

### Root fields

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `protocolVersion` | Integer | Yes | Must currently be `1`. |
| `name` | String | Yes | Human-readable app name. |
| `bundleIdentifier` | String | Yes | Must match the actual macOS app bundle identifier. |
| `actions` | Array | Yes | One or more actions exposed to Halo; maximum 64. |
| `triggers` | Array | No | Automatic generated-CI activation requests. Protocol v1 currently supports `fileDrag`. |

### Trigger fields

Protocol v1 currently supports one automatic trigger:

```json
"triggers": [
  {
    "type": "fileDrag",
    "supportedExtensions": ["txt"]
  }
]
```

`fileDrag` makes the generated Custom CI eligible while files matching the declared extensions are being dragged over Halo. It does not require Drop CI to be enabled.

`supportedExtensions` is optional. If omitted or empty, Halo derives the trigger extensions from the union of the app's advertised action extensions. Explicit trigger extensions must be supported by at least one advertised action.

A drag containing folders does not satisfy `fileDrag`.

### Action fields

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `id` | String | Yes | Stable unique action ID within the app. |
| `name` | String | Yes | Human-readable action name. |
| `supportedExtensions` | String array | Yes | Accepted extensions. `"*"` accepts any file; an empty array means no file input. |
| `options` | Array | Yes | Typed parameters accepted by the action; maximum 32. May be empty. |

### Option fields

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `key` | String | Yes | Unique option key within the action. |
| `name` | String | Yes | Human-readable label. |
| `type` | String | Yes | One of the supported types below. |
| `required` | Boolean | Yes | Whether the caller must provide the option. |
| `description` | String/null | No | Help text. |

Supported option types:

- `string`
- `integer`
- `double`
- `boolean`
- `stringArray`
- `integerArray`
- `doubleArray`

## Validation and trust boundary

Halo validates a manifest before adding the app to the integration catalogue:

- protocol version must be supported;
- the manifest is limited to 256 KB;
- app name and bundle identifier must be non-empty;
- the declared bundle identifier must match the actual app bundle;
- at least one action is required;
- no more than 64 actions are accepted;
- no more than 16 integration triggers are accepted;
- protocol v1 integration triggers must currently use `fileDrag`;
- explicit file-drag extensions must correspond to an advertised action;
- action IDs must be non-empty and unique;
- action display names must be non-empty;
- no more than 32 options are accepted per action;
- option keys must be non-empty and unique per action;
- option types must be from the supported set.

Malformed manifests are ignored and surfaced in CI Settings diagnostics.

Halo does **not** use `Bundle.load`, load a partner dylib, evaluate scripts, or execute code because an app provides this manifest.

## Halo UI and generated CIs

Open:

**Halo Settings → Context Notch Interfaces**

Discovery itself only establishes compatibility. When automatic app CIs are enabled, Halo turns each discovered app into **one managed Custom CI card** under **Loaded custom CI**.

That card is where the user configures the integration:

- enable/disable the CI;
- priority;
- permissions;
- which advertised functions are enabled;
- whether requested automatic triggers are enabled.

The separate discovery section reports compatible-app count and diagnostics; it is not a second function-configuration surface.

For `fileDrag`, trigger compatibility is evaluated against the app's **currently enabled functions**. An app advertising `.txt` and `.png` functions will not open for `.png` if every `.png` function has been disabled by the user.

Discovery and generated integration triggers are independent of Drop CI. They still participate in the same central surface arbitration as every other CI.

See [AutoIntegrationCI.md](AutoIntegrationCI.md) for the full generated-CI and drag-session lifecycle.

## Discovery design record

```text
Feature identity: App Integration Discovery Catalog
Implementation path: native app-owned discovery service; it does not own a CI surface
Purpose: find installed apps that explicitly advertise Halo-compatible actions
Real source: NSWorkspace running applications plus standard macOS app folders
Eligibility/priority/presentation/geometry: not applicable — discovery is metadata only
Permissions: no sensitive Halo data is granted by discovery
Refresh: initial scan plus explicit Scan Again
Per-display state: none; catalogue is shared
Failure behavior: malformed manifests are omitted and diagnostic text is surfaced
Generated-CI handoff: completed catalogue results are consumed by HaloAutoIntegrationCIGenerator
```
