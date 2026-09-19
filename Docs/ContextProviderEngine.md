# Custom CI Context Provider Engine

`HaloCIContextProviderEngine` is the single authority for context exposed to declarative Custom CIs.

Custom CI rendering and brokered actions do not assemble workspace/macOS context themselves. They request a filtered snapshot from this engine, and the engine applies the shared `HaloCIContextCatalog` contract before any value reaches a package.

## Architecture

```text
Existing Halo services / real events
        │
        ├─ MediaService
        ├─ SystemService
        ├─ AudioService
        ├─ NSWorkspace app events
        ├─ display events
        ├─ BluetoothStateService
        ├─ ClipboardService
        ├─ Halo drag/drop destination
        └─ real notification providers
                 │
                 ▼
      HaloCIContextProviderEngine
                 │
      coalesced revision + snapshot
                 │
                 ▼
        HaloCIContextCatalog.filter
                 │
                 ▼
       Custom CI binding data bus
```

The engine does not participate in CI ownership, priority arbitration, sizing, backgrounds, triggers, or action execution. It only owns context collection and disclosure.

## Provider contract

A provider conforms to `HaloCIContextProvider`.

Providers must be:

- synchronous;
- side-effect free while producing a snapshot;
- bounded;
- backed by real Halo/macOS state;
- free of disk, network, AppleScript, shell, or other blocking I/O in the snapshot path.

I/O needed to prepare context must happen in an event-ingestion path before the snapshot is requested.

The engine ships with providers for:

- workspace/system/media/audio/application/time/display state;
- transient input/event context;
- Bluetooth state.

Additional providers can be registered by stable identifier. A provider with the same identifier replaces the old provider.

## Performance model

The engine deliberately adds no fast polling loop.

It reuses existing Halo service updates and macOS notifications. Provider changes are coalesced for 50 ms before one revision is published. Existing media/system/audio object changes are additionally debounced by 100 ms.

The only engine timer is once per minute for `time.minuteOfDay`.

File/folder classification is never performed in `draggingUpdated`. Halo reads the drag payload once on drag entry, publishes an immediate bounded summary, then classifies files versus folders on a utility task. A drop is classified the same way. The engine stores counts/extensions only; it does not retain dragged file paths.

Transient event metadata expires from the public snapshot after 30 seconds.

## Context categories

### Surface and CI

- `halo.surface.state`
- `halo.surface.isExpanded`
- `ci.id`
- `ci.name`
- `ci.activation.kind`

### Power and system

- `system.battery.level`
- `system.battery.isCharging`
- `system.battery.onBattery`
- `system.power.source`
- `system.lowPowerMode`
- CPU, memory, storage, network and thermal keys already defined by SDK 0.2

Charging/source transitions also become transient events such as:

```text
power.chargingStarted
power.chargingStopped
power.onBattery
power.onAC
```

### Applications, media and audio

The engine exposes the existing application/media/audio catalog through one snapshot authority. Existing permission rules still apply.

Examples of transient events include:

```text
application.activated
media.started
media.stopped
```

### Dragging files and folders

The engine exposes:

- whether a drag is active;
- item count;
- file count;
- folder count;
- kind: `none`, `files`, `folders`, or `mixed`;
- a bounded comma-separated extension summary.

No file path is exposed.

Drag context observation is independent of whether **Drop CI** is enabled. Observing drag metadata does not accept a drop or claim the Halo surface.

### Accepted drops

The engine remembers bounded metadata for the most recent accepted Halo drop:

- item/file/folder counts;
- kind;
- extension summary;
- age in seconds.

The engine does not retain the URLs in public context.

### Clipboard

Halo reuses the existing ClipboardService sampling. No new clipboard polling is added.

The public context contains metadata only:

- `clipboard.hasText`
- `clipboard.textLength`
- `clipboard.lastEvent`

`clipboard.lastEvent` can be `changed`, `copy`, or `paste`.

The engine does **not** expose clipboard text.

A real Halo-owned copy reports `copy`. A provider may call `reportClipboardPaste` when Halo genuinely observes/performs a paste. Halo deliberately does not install a global Command-V monitor or Accessibility hook just to infer paste events.

### Notifications and activities

The engine accepts bounded notification context through:

- `reportNotificationReceived`
- `reportNotificationSent`
- `reportActivityPublished`

and exposes:

- `notification.last.kind`
- `notification.last.source`
- `notification.last.ageSeconds`

Halo does not scrape other applications' Notification Center contents or use private notification APIs. `notification.received` therefore appears only when a real supported provider supplies that event.

### Bluetooth

The engine exposes non-content Bluetooth state already maintained by Halo:

- powered on/off;
- connected device count;
- last connection/power event kind.

Device names and addresses are not added to the Custom CI data bus by this engine.

## Generic transient event

The most recent context transition is exposed through:

- `context.event.kind`
- `context.event.source`
- `context.event.sequence`
- `context.event.ageSeconds`

This gives a Custom CI one common way to react visually to a recent context transition without every event family inventing another top-level lifecycle mechanism.

It remains context only. It does not make the CI eligible, open it automatically, or override another CI.

## Privacy boundary

The context engine exposes metadata that is already available to Halo and explicitly catalogued.

It does not expose:

- dragged file paths;
- clipboard bodies;
- arbitrary notification text;
- arbitrary app objects;
- EventKit objects;
- raw service objects;
- secrets.

Permission-protected existing keys such as media and active-application data remain filtered by the normal declared + granted permission rules.

## Adding a provider

When adding context:

1. use a real source that Halo actually implements;
2. add a bounded descriptor to `HaloCIContextCatalog`;
3. implement or extend a provider;
4. use events instead of new polling where possible;
5. keep expensive work outside `snapshot`;
6. call `invalidate` only through the provider engine's event/report path;
7. document unavailable-state behavior;
8. add contract tests;
9. verify the Halo app build.

Do not bypass the engine by adding another ad-hoc dictionary in a renderer or action broker.
