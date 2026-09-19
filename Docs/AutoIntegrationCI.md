# Automatic App Integration Custom CIs

Halo can turn compatible installed macOS apps into **managed declarative Custom CIs automatically**.

This framework connects the existing app-integration catalogue to the existing Custom CI runtime. It does **not** introduce another renderer, another priority system, or native partner code inside Halo.

The pipeline is:

```text
Partner App
  └─ Contents/Resources/HaloIntegration.json
        │
        ├─ functions/actions
        │    ├─ stable ID
        │    ├─ supported file types
        │    └─ typed options
        │
        └─ requested trigger(s)
                  ↓
          HaloIntegrationCatalog
                  ↓
     HaloAutoIntegrationCIGenerator
                  ↓
         one managed Custom CI
                  ↓
      normal Custom CI settings card
        ├─ CI enable/disable
        ├─ priority
        ├─ permissions
        ├─ per-function enable/disable
        └─ automatic trigger enable/disable
                  ↓
      normal Custom CI arbitration
                  ↓
       generated declarative UI
                  ↓
        app.integration.invoke
```

The generated Custom CI is the persistent product object. Dragging, clipboard events, or future integration triggers are only **trigger/input sources** for that CI; they are not separate Integration CIs.

## 1. What partner developers need to do

A compatible app only needs to ship a valid:

```text
Your App.app/Contents/Resources/HaloIntegration.json
```

In Xcode, add the JSON file to the app target's **Copy Bundle Resources** phase.

Example:

```json
{
  "protocolVersion": 1,
  "name": "Example Converter",
  "bundleIdentifier": "com.example.converter",
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
          "description": "Output quality."
        }
      ]
    }
  ]
}
```

No Halo SDK binary, dylib, JavaScript host, XPC service, or network service is required for protocol v1.

See [AppIntegrations.md](AppIntegrations.md) for the discovery manifest contract.

## 2. What Halo generates

For every valid discovered app, Halo creates one managed `.haloCI` package and exposes it as a normal card in **Loaded custom CI**.

The card is the authority for user configuration. It includes:

- normal Custom CI enable/disable;
- normal priority;
- normal per-CI permissions;
- Open;
- one toggle per advertised app function;
- live function metadata such as file types and typed option definitions;
- automatic-trigger enable/disable when the app requests a trigger.

All advertised functions are preserved in the managed package, but disabled functions are hidden from the actual generated notch UI and are excluded from trigger compatibility.

The generated package itself has:

- a deterministic stable CI ID derived from the partner bundle identifier;
- its own closed and expanded declarative presentation;
- its own sizing/background contract;
- one generated function group per advertised app function;
- the normal Halo Close action;
- the `AppIntegration.Execute` permission;
- the `AppIntegrations` capability label.

Generated packages use **SDK 0.2 / schema 1** and are passed through the same `HaloCIPackageValidator` as imported Custom CIs.

## 3. Managed identity and ownership

Generated packages use a reserved deterministic ID:

```text
com.redstoneinvente.halo.integration.<sanitized-bundle-id>.<stable-hash>
```

Halo also writes:

```text
.halo-generated-integration.json
```

inside the generated package.

That marker contains the generator version, source bundle identifier, package ID, and source-manifest fingerprint.

The marker is what lets Halo distinguish a managed package from a user-authored CI.

Halo will **never overwrite a package at the generated destination if the package does not contain a valid Halo-generated marker**. This prevents a discovery refresh from replacing a user's own CI.

## 4. Automatic synchronization

Automatic app CIs are enabled by default and can be switched off under:

**Halo Settings → Context Notch Interfaces → App integrations → Automatically create Custom CIs**

When enabled:

1. Halo scans compatible apps.
2. Each manifest is validated.
3. Halo calculates its deterministic generated package ID.
4. If the source manifest is unchanged and the existing generated CI still validates, Halo leaves it untouched.
5. If the source manifest changed, Halo regenerates the package using a staging directory and validates it before replacement.
6. If a previously generated app is no longer compatible or installed, only that Halo-generated package is removed.
7. User-authored packages are never removed by this synchronization.

Per-CI user preferences remain separate from the generated files. A generated package can therefore be regenerated without intentionally resetting its Custom CI enable toggle, priority, permission grants, or local state.

Turning automatic generation off removes the managed packages, but does not delete unrelated imported Custom CIs.

## 5. Generated CI activation

Without an automatic trigger, the generated integration CI behaves like an ordinary manual Custom CI.

A partner app can request:

```json
"triggers": [
  {
    "type": "fileDrag",
    "supportedExtensions": ["txt"]
  }
]
```

The runtime flow is deliberately split:

```text
NSDraggingSession
      ↓
HaloIntegrationDragSession
  holds actual dragged URLs privately
      ↓
generated CI compatibility
  = trigger requested
  + CI enabled
  + automatic trigger enabled
  + at least one enabled function accepts every dragged file
      ↓
normal Custom CI candidate
      ↓
normal activeContext arbitration
      ↓
if generated CI wins → expand Halo
```

The actual file URLs are never placed in the declarative Custom CI context bus. The Context Provider Engine still publishes bounded drag metadata for general Custom CI bindings, while the Halo-owned integration drag session privately retains the real URLs needed to deliver the eventual app action.

If Drop CI is also enabled, both may become candidates. The generated app CI defaults to priority 100 and uses the app-specific drag tie rank above generic Drop CI at equal priority. If the user changes the generated CI's priority, that choice is respected.

When the user drops while the generated integration CI owns the surface, the session commits those files to that generated CI. Pressing one of its compatible enabled functions then uses the dropped files directly rather than asking for them again.

Leaving the drag without dropping cancels the uncommitted session. Executing a committed function or dismissing the integration CI ends the session.

## 6. The brokered action

SDK 0.2 adds one brokered action:

```text
app.integration.invoke
```

Permission:

```text
AppIntegration.Execute
```

Capability label:

```text
AppIntegrations
```

Example action descriptor:

```json
{
  "id": "app.integration.invoke",
  "arguments": {
    "bundleIdentifier": "com.example.converter",
    "actionID": "convert.image"
  }
}
```

The action requires both arguments. Unknown arguments fail package validation.

The action is intentionally **not** a generic process launcher. It can only target an action that the installed app currently advertises through a valid `HaloIntegration.json`.

## 7. Permission behavior

A generated CI declares `AppIntegration.Execute`, but the permission is still controlled by the user through the normal per-CI permission UI.

At execution time Halo rechecks:

- the Custom CI still exists;
- the package manifest has not been replaced underneath the mounted view;
- the CI is still enabled;
- Custom CIs are not globally disabled;
- `AppIntegration.Execute` is still declared;
- `AppIntegration.Execute` is still granted;
- the target app still exists;
- the target app's bundle identifier still matches;
- its current `HaloIntegration.json` still validates;
- the requested action ID is still advertised.

The checks are performed again after interactive file/option prompts before delivery.

Revoking the permission from a stale mounted CI therefore prevents the eventual request.

## 8. File input

For an action with:

```json
"supportedExtensions": ["png", "jpg"]
```

Halo asks the user to choose one or more files and validates that **every selected file** matches the advertised extension set.

`"*"` accepts any file extension.

An empty `supportedExtensions` array means the action requires **no file input** and Halo skips the file picker.

The broker does not give a partner app arbitrary filesystem access. It delivers only the URLs selected for that invocation.

## 9. Typed options

If an action declares options, Halo builds a native option prompt at invocation time.

Supported protocol-v1 types are:

- `string`
- `integer`
- `double`
- `boolean`
- `stringArray`
- `integerArray`
- `doubleArray`

Required values must be supplied before the request is sent. Optional booleans can be omitted.

The selected values are JSON encoded into the request file.

## 10. Request delivery

Halo writes a temporary `.halorequest` file:

```json
{
  "protocolVersion": 1,
  "requestID": "UUID",
  "sourceBundleIdentifier": "com.redstoneinvente.Halo",
  "action": "convert.image",
  "options": {
    "quality": 90
  }
}
```

Halo then opens the partner application with:

```text
request.halorequest
selected-file-1.png
selected-file-2.png
```

The partner app can receive those URLs through the normal macOS open-URL/application delegate path.

The request file is removed later after allowing time for a cold app launch.

Protocol v1 does not currently define a callback/result channel back into Halo.

## 11. Partner-side handling

A partner app should:

1. receive the opened URLs;
2. locate the `.halorequest` file;
3. decode it;
4. verify `protocolVersion`;
5. match the requested `action` against its own supported action implementation;
6. validate the supplied options;
7. treat every accompanying file as untrusted input;
8. perform only that declared operation.

Do not infer an action from a display name. Use the stable action ID.

The existing **Halo-Integration-Test-App** repository demonstrates this request model.

## 12. Authoring a non-generated CI that uses an app integration

The same action is available to an ordinary SDK 0.2 package.

Manifest:

```json
{
  "sdkVersion": "0.2",
  "permissions": ["AppIntegration.Execute"],
  "capabilities": ["AppIntegrations"]
}
```

Button:

```json
{
  "type": "Button",
  "text": "Convert with Example Converter",
  "accessibilityLabel": "Convert with Example Converter",
  "action": {
    "id": "app.integration.invoke",
    "arguments": {
      "bundleIdentifier": "com.example.converter",
      "actionID": "convert.image"
    }
  }
}
```

This still cannot call an arbitrary application command. The target/action pair must resolve against a currently valid installed integration manifest.

## 13. Limits

Protocol v1 currently accepts at most:

- 64 actions per app;
- 32 typed options per action;
- the existing 256 KB integration-manifest limit.

The generated interface remains below Halo's Custom CI component-count limits.

## 14. Security boundary

Automatic integration CIs remain declarative.

The framework does **not**:

- load the partner application's bundle;
- load partner dylibs;
- execute partner JavaScript or Swift inside Halo;
- run a shell command;
- expose an arbitrary `open application + arguments` primitive;
- give generated CIs direct AppKit or `NSPanel` control;
- bypass Custom CI permissions;
- bypass CI priority arbitration.

The only execution bridge is the versioned, manifest-backed `app.integration.invoke` broker.

## 15. Base CI design record

```text
CI name / stable identity: one generated Custom CI per compatible app; deterministic ID derived from bundle identifier
Implementation path and reason: declarative .haloCI generated by Halo; the standard SDK can express the UI, sizing, background and brokered action
Purpose: expose an installed app's declared actions as a normal Halo Context Interface
Real context source / existing service: HaloIntegrationCatalog and the partner app's validated HaloIntegration.json
Enable setting and default: per-package Custom CI enablement; automatic generation globally enabled by default
Priority setting and default (normal range 0...100): existing package priority, default 50
Tie behavior / reason: existing Custom CI ordering; no new tie override
Side-effect-free eligibility rule: manual activation only; no generated automatic trigger
Manual activation behavior: normal Custom CI Open flow; still respects higher-priority surface ownership
Automatic expansion policy (default: no auto-open): no auto-open from discovery
Dismissal / retrigger policy: existing Custom CI dismissal semantics
Closed presentation (default: normal Closed Notch): generated compact app-name/action-count presentation while the package owns closed state
Expanded presentation: generated scrollable list of advertised app actions
Full-surface ownership (default: false for native opened-only CI): package uses the existing Custom CI surface path, not a new native owner
Keep Closed Notch contents while expanded (default: false): existing package behavior
Background owner / layer: generated package's own closed/expanded background contract
Expanded size rule and sizing inputs: generated static size bounded by action count; long action lists scroll
Compact width / height / minimum expanded width (only if needed): generated closed size 280x42; expanded width 580
Geometry publication and handoff/cleanup owner: existing HaloCustomCISurfaceView → SurfaceState path
Global versus profile settings: generation toggle is global; enable/priority/permissions remain per generated package
Context bindings, units, unavailable-data behavior: no extra context data required
Permissions / revocation / commercial-access boundaries: AppIntegration.Execute, rechecked before and after prompts; global Custom CI disable still applies
Actions and their broker: app.integration.invoke → fresh manifest validation → selected files/options → .halorequest delivery
Subscriptions / refresh cadence / cancellation: generated packages synchronize after completed integration-catalogue refreshes
Per-display versus shared state: package preferences are shared; actual surface ownership remains per Halo surface
Settings card / controls / accessibility: App integrations generation toggle; normal Custom CI cards; generated action buttons have accessibility labels
Compatibility and persistence migration: SDK 0.1 packages unchanged; new action/permission/capability require SDK 0.2
Tests and manual checks: SDK action validation/authorization tests; generator create/update/remove tests; full macOS workflow
```

## 16. Verification matrix

| Check | Result / coverage |
| --- | --- |
| Generation disabled at launch / while active | Implemented through `HaloAutoIntegrationCIEnabled`; managed packages are removed without touching user CIs |
| Discovery while Halo is closed | Generates packages only; does not expand the surface |
| Higher-priority CI owns surface | Existing Custom CI arbitration remains authoritative |
| Equal priority | Existing deterministic Custom CI ordering remains unchanged |
| Partner manifest changes | Fingerprint changes regenerate and revalidate the package |
| Partner app disappears | Its marked generated package is removed on the next completed catalogue sync |
| User-authored CI at destination | Not overwritten because it lacks the valid generated marker |
| Permission revoked from stale UI | Action authorization is rechecked after interactive prompts |
| App/action removed after UI rendered | Fresh manifest is re-read and action ID revalidated before delivery |
| Unsupported files | Delivery rejected |
| Invalid typed options | Delivery rejected before request creation |
| Two displays / geometry ownership | No new geometry path; existing Custom CI surface coordinator remains in charge |
| SDK 0.1 compatibility | Existing 0.1 packages do not need migration |
| Full build/runtime | Covered by the app-integration macOS workflow; manual end-to-end UI exercise remains recommended before release |

## 17. Drag-triggered generated CIs

Protocol v1 now supports a declarative `fileDrag` integration trigger. Halo converts it into the standard SDK 0.2 Custom CI trigger and evaluates it from the Context Provider Engine's classified drag snapshot.

The trigger stores no file paths and performs no work during `draggingUpdated`. File/folder classification happens off-main once at drag entry; only then can `fileDrag` become true.

The generated CI still reuses the existing package, action broker, permissions and `activeContext` arbitration. No separate built-in App Integration CI is introduced.
