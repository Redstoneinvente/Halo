# Smart Notch Dismissal

Halo uses a centralized, per-surface dismissal coordinator for pointer-driven automatic closing.

## Architecture

Each `SurfaceState` owns one `HaloDismissCoordinator`. There is no global dismissal singleton, so one display cannot cancel or commit another display's pending close.

The normal pointer flow is:

```text
SwiftUI/AppKit pointer exit
        ↓
SurfaceState.hover(false)
        ↓
HaloDismissCoordinator.requestDismissal(.pointerExit)
        ↓
preset + active CI policy
        ↓
holds / logical Halo region / grace perimeter
        ↓
single cancellable Task
        ↓
final state revalidation
        ↓
existing SurfaceState.expanded transition
        ↓
existing WindowManager animation path
```

Returning the pointer calls `pointerEntered()`, which cancels and invalidates the only pending dismissal task. A generation counter prevents a stale task from closing Halo after cancellation.

## Close Behaviour

The persisted global setting lives in `Configuration`:

- **Instant** — approximately 60 ms.
- **Smart** — default; CI-aware timing.
- **Relaxed** — approximately 900 ms.
- **Manual** — pointer exit does not close Halo.
- **Custom** — user-selected 0–2000 ms.

Old saved `Configuration` payloads do not contain these optional fields and therefore resolve to Smart automatically.

## Smart CI timing

`CIDismissBehavior` provides four policies:

| Policy | Smart pointer delay | Intended use |
| --- | ---: | --- |
| `transient` | ~280 ms | short informational surfaces |
| `standard` | ~450 ms | ordinary Halo interactions |
| `interactive` | ~680 ms | drag/control-heavy interfaces |
| `persistent` | no pointer dismissal | focused/editor-like interfaces |

Current built-in mapping is intentionally conservative:

- Music and Bluetooth: `standard`
- Drop, Transfer, Clipboard, Retro Game: `interactive`
- Teleprompter: `persistent`

Partner and declarative Custom CIs can declare `dismissBehavior`. File-drag partner/custom registrations default to `interactive` when the metadata is omitted; other third-party CIs default to `standard`.

## Hold-open tokens

The coordinator uses independent tokenized holds rather than a simple set, so two callers can acquire the same reason without releasing each other accidentally.

Current hold reasons include:

- mouse down / slider manipulation;
- dragging, including Drop CI and third-party file drag;
- scrolling;
- text editing;
- Halo-owned popovers;
- menus/context menus;
- keyboard interaction;
- CI/external Halo interaction hooks.

Scrolling and keyboard interaction use renewable short-lived pulse holds. File drag uses a lifecycle token acquired when the drag reaches Halo and released on drop/cancel completion.

## Logical interaction region

Pointer exit from the original SwiftUI surface is only a request. Before committing, the coordinator checks the actual Halo interaction environment:

- main Halo panel;
- geometry editor panel;
- child windows owned by the Halo panel;
- an active field editor.

A hidden 8-point perimeter around the main panel adds a small amount of extra grace without changing rendering or running a polling loop.

## Explicit dismissal

Explicit operations can bypass pointer-delay policy:

- Escape, when a field editor is not consuming it;
- explicit close/toggle operations;
- CI completion.

Drop CI's existing post-drop presentation delay is still preserved, but its 650 ms completion timing is now scheduled by the central coordinator rather than by an independent collapse task.

## Concurrency and performance

The system is event-driven:

- no continuous pointer polling;
- one pending dismissal task per surface;
- one local event monitor reused for mouse/scroll/key interaction holds;
- existing menu/popover notifications;
- cancellation plus generation invalidation;
- final eligibility re-check before collapse.

The existing WindowManager surface animator remains authoritative for visible open/close animation.

## Future extension

`HaloDismissDestination` already distinguishes `compact` and `closed`, but the current surface callback intentionally preserves Halo's existing behavior and collapses to its existing compact/closed state. Media/timer-specific destination policy can be added later without introducing another dismissal scheduler.
