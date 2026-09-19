# Custom CI V2 framework

> **Required agent starting point:** follow the [Base CI template](Templates/BaseCI.md), fill its design record, and complete its verification matrix. Existing examples illustrate patterns; the template identifies the shared integration obligations and cleanup pitfalls.

V2 is an additive **SDK 0.2 / schema 1** implementation of Halo's existing declarative CI architecture. SDK 0.1 packages remain supported. It is not a scripting host or a promise that arbitrary macOS context is available.

## Create an interface

From the repository root, with macOS and the Xcode command-line tools:

```sh
swift run halo-ci init MyPanel.haloCI com.example.my-panel "My Panel"
swift run halo-ci validate MyPanel.haloCI
swift run halo-ci catalog
swift test --package-path SDK
```

`init` creates a validated, manual-only package with closed/expanded layouts, size and background contracts, and an accessible Close action. It never overwrites an existing destination. Edit its JSON, validate, then import the folder from Halo Settings → Custom CI. Re-import the same ID to update it; increment its package version.

`validate` uses the exact parser and validator compiled into Halo. Invalid packages exit nonzero and report property paths. `catalog` exports JSON descriptors containing each binding's key, type, unit, permission, introduction version and description. The CLI does not require building Halo's app UI.

Try `Examples/ContextDashboard.haloCI` for a manual context dashboard. `Examples/HelloWorld.haloCI` remains the SDK 0.1 compatibility example.

## Context contract

All existing 0.1 bindings retain their meaning. Set `sdkVersion` to `"0.2"` to use these additions:

| Key | Type / unit | Permission |
| --- | --- | --- |
| `media.duration`, `media.position` | Number, seconds | `Media.ReadState` |
| `audio.output.name` | String | `Audio.ReadState` |
| `audio.volume` | Number, 0–1 fraction | `Audio.ReadState` |
| `audio.canSetVolume` | Boolean | `Audio.ReadState` |
| `system.thermalState` | String | None |
| `system.network.downBytesPerSecond`, `system.network.upBytesPerSecond` | Number, bytes/second | None |
| `displays.count` | Number, screen count | None |
| `time.minuteOfDay` | Number, local minute 0–1439 | None |
| `ci.id`, `ci.name` | String, current package only | None |
| `ci.activation.kind` | `manual` or `automatic` | None |

The catalog is the discoverable schema source of truth, and `HaloCIContextProviderEngine` is the runtime authority that assembles snapshots for Custom CIs. Values come from Halo's existing services and event providers and are sampled, not promised to update every frame. See [ContextProviderEngine.md](ContextProviderEngine.md). Media/system/audio notifications are coalesced over 100 ms; time updates every minute; display changes use macOS notifications. The existing service lifecycle controls collection. Network rates describe aggregate traffic, not Internet reachability. Audio volume is absent when the output does not support volume control.

Permissions must be both declared and currently granted. Unknown keys, values from a newer SDK, nonfinite numbers and wrong boolean representations are removed by the broker. Missing or denied values resolve to an empty string, not a fabricated measurement. Strings are bounded to 8,192 characters. No raw service objects, file paths, clipboard contents, calendar events or secrets are added by this version.

`ci.activation.kind` describes the current manual request versus automatic eligibility; it does not grant surface ownership. All existing priority and sizing rules still apply.

SDK 0.2 also exposes bounded transient context metadata for drag/drop, clipboard events, power transitions, notification-provider events and Bluetooth state. File paths, clipboard bodies and arbitrary notification text are intentionally not part of this context contract.

## App integration bridge

SDK 0.2 adds the revocable `AppIntegration.Execute` permission, the descriptive `AppIntegrations` capability label, and the brokered `app.integration.invoke` action.

The action accepts exactly two string arguments:

```json
{
  "id": "app.integration.invoke",
  "arguments": {
    "bundleIdentifier": "com.example.partner",
    "actionID": "convert.file"
  }
}
```

Halo resolves that pair against a currently installed, validated `HaloIntegration.json`; it does not provide arbitrary process execution. Partner files and typed options are selected at invocation time, and permission/app/action validity is rechecked after prompts.

Halo can also generate managed declarative CIs automatically from discovered partner manifests. See [AutoIntegrationCI.md](AutoIntegrationCI.md).
## New triggers

SDK 0.2 adds two conditions, composable with existing `any`/`all` triggers:

```json
{
  "match": "all",
  "triggers": [
    { "type": "lowPowerMode", "bool": true },
    { "type": "displayCount", "number": 2 }
  ]
}
```

`lowPowerMode` defaults to true if `bool` is omitted. `displayCount` is an exact match and requires an integer from 1 to 64. Neither requires sensitive access. These remain eligibility conditions; they do not resize a panel or bypass a higher-priority owner. Existing suppression-until-false behavior applies.

## Extending the framework safely

1. Add a context descriptor in `SDK/Sources/HaloCISDK/CIContracts.swift`, with an explicit SDK version, type, units and permission. Never add a key for a data source that does not exist.
2. Supply its value in `HaloCustomCIRuntimeStore.dataBus` and connect invalidation to the existing service. Keep missing values absent and avoid new polling loops.
3. Use the catalog filter at the broker boundary. Sensitive additions require a supported, explicit, revocable permission.
4. For triggers, add the version gate, strict validation, snapshot field, evaluator and real snapshot provider together. Preserve deterministic arbitration in `SurfaceView`.
5. Add success, unavailable-data, denial/revocation, malformed-input and backwards-compatibility tests in `SDK/Tests/HaloCISDKTests`.
6. Update the catalog, this guide, `CustomCI_Authoring.md` and `CISDK.md` together. Run the SDK tests and full Halo build before release.

The app compiles the same `CIContracts.swift` source directly, while the independent Swift package builds the author tools and contract tests. There is no copied schema or second runtime. Private app models are not exported as SDK API.

## Compatibility and boundaries

Schema stays at 1; 0.1 packages need no migration. New bindings, `Audio.ReadState` and the two new triggers require 0.2. Unsupported SDKs fail validation. Existing components, actions, backgrounds, state quotas and geometry semantics remain unchanged. Malformed mixed bindings, hidden executable payloads and boolean/fractional numeric fields now fail validation.

Actions recheck enabled state, the global Custom CI switch, installed manifest and declared/current grants. Their binding data is rebuilt at invocation; a stale view cannot reuse revoked context. URL confirmation rechecks access after the dialog returns.

No executable third-party code, generic process action, network broker, calendar/clipboard reading, signing, hot reload, simulator or visual Studio is introduced. Those remain separate future work under the canonical SDK architecture. Full UI checks still include priority collisions, close/reopen, permission revocation, device changes and multiple displays; unit tests alone cannot guarantee every visual configuration.
