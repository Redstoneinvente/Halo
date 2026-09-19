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
