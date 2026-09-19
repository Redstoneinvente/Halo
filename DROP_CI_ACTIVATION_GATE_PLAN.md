# Drop CI Activation Gate Fix Plan

## Purpose

This document records the intended fix for the Drop CI activation/licensing bug before changing runtime behavior.

Current bug: Drop CI can react to file drags even when Halo commercial access is not granted.

The fix must preserve Halo's existing activation/licensing architecture, File Shelf behavior, multi-display behavior, activation-sequence behavior, and normal Drop CI behavior for licensed users.

Do not implement this by merely hiding DropContextView in SurfaceView. The bug occurs earlier, at the AppKit drag-destination boundary.

## Confirmed current architecture

### Commercial access authority

AppDelegate owns the authoritative commercial access decision through commercialAccessGranted, based on the signed-in account and HaloLicenseManager access validity.

refreshCommercialAccess() starts/stops licensed services according to that value.

The panel/geometry engine intentionally exists even without access so Halo can render the locked/sign-in/license surface. Do not move WindowManager behind licensing.

### WindowManager is always alive

configureCommercialAccessGate() constructs and starts WindowManager before account/license restoration finishes.

Therefore any feature implemented directly in WindowManager, NSPanel, or the root NSHostingView must explicitly respect commercial access.

### Why the other CIs stay locked

Normal CI rendering is reached through the gated SwiftUI surface/router:

WindowManager / NSPanel
→ HaloDropHostingView
→ ActivationSequenceSurfaceHost
→ HaloSurfaceRouter
→ licensed/locked routing
→ SurfaceView and normal CIs

Music, Transfer, Clipboard, Bluetooth, Retro, Custom CI, etc. are effectively behind the normal surface access routing.

### Why Drop CI bypasses the gate

HaloDropHostingView is an AppKit NSDraggingDestination that wraps the router itself.

Its registration is currently controlled only by HaloContextDropEnabled. It does not currently require commercial access.

The current default is fail-open:

    private var acceptsFileDrop: Bool {
        dropEnabled?() ?? true
    }

During HaloDropHostingView initialization, refreshDropRegistration() runs before WindowManager assigns dropEnabled. That means the hosting view can initially register for file drags before its actual permission provider exists.

The current dragStateHandler also checks only the Drop CI UserDefaults setting before calling host.state.beginFileDrop(count:), which mutates dropTargeted, dropItemCount, and expanded.

The current dropHandler similarly checks only that setting before reaching store.addFiles(urls).

Both presentation state and the actual file drop must therefore be gated.

# Intended fix

## 1. Keep AppDelegate as the single access authority

Do not make WindowManager independently reconstruct the licensing rule.

Do not duplicate account/trial/press/paid validity logic inside WindowManager.

AppDelegate.commercialAccessGranted remains authoritative so AppKit and SwiftUI cannot drift into different definitions of valid access.

## 2. Give WindowManager an in-memory commercial-access state

Add an in-memory value that defaults false because WindowManager starts before account/license restoration completes:

    private var commercialAccessGranted = false

Expose one setter, for example:

    func setCommercialAccessGranted(_ granted: Bool)

No Keychain, Firebase, LicenseSeat, Firestore, network, or other entitlement lookup should happen from drag callbacks. This must remain an in-memory gate.

## 3. Publish access changes from AppDelegate

In refreshCommercialAccess(), calculate the existing authoritative value once and propagate it immediately to WindowManager:

    let granted = commercialAccessGranted
    engine?.setCommercialAccessGranted(granted)

Then preserve the existing licensed/unlicensed service behavior.

This must cover cold launch before restore, successful account restore, paid validation, local trial, press license, new activation, sign out, deactivation, invalidation, and trial expiry.

## 4. Centralize Drop CI permission in WindowManager

Define one internal decision:

    Drop CI allowed =
        commercial access granted
        AND
        HaloContextDropEnabled

Suggested shape:

    private var dropCIAllowed: Bool {
        guard commercialAccessGranted else {
            return false
        }

        let defaults = UserDefaults.standard

        return defaults.object(forKey: "HaloContextDropEnabled") == nil
            ? true
            : defaults.bool(forKey: "HaloContextDropEnabled")
    }

For a licensed user, absence of HaloContextDropEnabled must continue to mean Drop CI enabled by default.

## 5. Make HaloDropHostingView fail closed

Change the provider fallback from allow to deny:

    private var acceptsFileDrop: Bool {
        dropEnabled?() ?? false
    }

Expected initialization sequence:

HaloDropHostingView.init
→ no provider yet
→ acceptsFileDrop is false
→ do not register

WindowManager assigns provider
→ dropEnabled.didSet
→ refreshDropRegistration()
→ register only if licensed and Drop CI enabled

## 6. Use the centralized gate for registration

Replace the UserDefaults-only provider with a WindowManager-backed provider:

    view.dropEnabled = { [weak self] in
        self?.dropCIAllowed ?? false
    }

## 7. Guard dragStateHandler as defense in depth

Registration alone is not the behavioral boundary.

The drag callback itself should verify dropCIAllowed before changing SurfaceState.

Preserve ActivationSequenceCoordinator.shared.cancelForInteraction() only when a valid licensed drag actually begins.

If access is denied while dropTargeted is still true, clean up the existing Drop state rather than letting it remain owned.

## 8. Guard dropHandler independently

The actual operation must re-check dropCIAllowed before calling completeFileDrop() or store.addFiles(urls).

This protects races such as:

licensed user begins drag
→ account/license becomes invalid or user signs out
→ user releases file

The final drop must not add files after access has been revoked.

## 9. Refresh registration whenever commercial access changes

setCommercialAccessGranted(_:) should:

1. update the stored in-memory value
2. refresh Drop CI registration on every Host
3. clear any currently active Drop CI state if access becomes unavailable

An unlicensed Drop CI must not remain visibly owned.

## 10. Reuse the same gate for UserDefaults changes

WindowManager.start() currently watches UserDefaults.didChangeNotification and separately derives HaloContextDropEnabled.

After the fix, use the centralized Drop CI permission rather than duplicating the setting logic.

The observer should continue to refresh registration and end an active drop when Drop CI becomes unavailable.

# Checks to perform before implementation

Before changing code, re-read the current versions on main of:

## Halo/App/HaloApp.swift

Check:

- commercialAccessGranted
- configureCommercialAccessGate()
- refreshCommercialAccess()
- licensed service start/stop behavior
- whether all entitlement transitions already flow through refreshCommercialAccess()

## Halo/NotchEngine/WindowManager.swift

Check:

- HaloDropHostingView
- acceptsFileDrop
- refreshDropRegistration()
- draggingEntered
- draggingUpdated
- draggingExited
- performDragOperation
- concludeDragOperation
- Host.refreshDropCIRegistration
- WindowManager.start()
- UserDefaults observer
- Host creation/reconcile path
- view.dropEnabled
- view.dragStateHandler
- view.dropHandler
- multi-display Host handling

## Halo/Views/SurfaceView.swift

Check:

- state.dropTargeted
- dropCIEnabled
- dropContextActive
- onChange of state.dropTargeted
- full-surface Drop CI ownership
- whether any SurfaceView code assumes Drop state can exist while locked

## Halo/Core/AppStore.swift

Check:

- addFiles(_:)
- account/license state only as needed to verify the existing authority

Do not assume line numbers remain unchanged.

# Regression checklist

## Locked / unactivated

With no valid commercial access:

- locked surface still appears normally
- dragging a file over the notch does nothing
- Drop CI does not appear
- notch does not expand because of file drag
- dropTargeted stays false
- dropItemCount is not changed
- store.addFiles is not called
- root Drop CI does not advertise an accepted copy operation

## Valid paid license

With valid paid access and Drop CI enabled:

- dragging triggers Drop CI
- item count is correct
- full-surface/non-full-surface setting still works
- actual drop still reaches store.addFiles
- Drop CI collapses as before

## Press license

Repeat the licensed test with Press entitlement. Behavior must match paid access.

## Trial

Repeat with an active local trial. Behavior must match paid access.

## Drop CI disabled

With commercial access granted but HaloContextDropEnabled false:

- surface-wide Drop CI does not register
- dragging does not expand Drop CI
- no Drop CI state mutation occurs

## File Shelf interaction

The root Drop CI currently unregisters when disabled so descendant drop targets, notably File Shelf, can remain usable.

Verify:

- licensed + Drop CI disabled + File Shelf available
- dragging onto File Shelf still works as before
- the root hosting view does not steal the drag
- locked mode does not expose licensed File Shelf behavior through another path

## Access granted without restart

Start Halo locked, then activate/sign in successfully.

Expected:

- no restart required
- WindowManager receives access true
- root Drop registration refreshes
- Drop CI begins working immediately if enabled

## Access revoked without restart

While Halo is running unlocked, sign out, deactivate, or invalidate entitlement.

Expected:

- root Drop registration is removed immediately
- active Drop state is cleared
- subsequent drags do nothing

## Revoke access during an active drag

Test:

1. begin dragging while licensed
2. revoke access before releasing
3. release the file

Expected:

- no file reaches store.addFiles
- Drop state is cleaned up
- no stale expanded ownership remains

## Enable/disable Drop CI while running

While licensed:

- disabling removes registration and closes current Drop CI
- enabling restores registration without restart

## Cold-launch restore race

Test with deliberately slow account/license restoration.

Expected:

- before restore completes, Drop CI is unavailable
- there is no brief fail-open registration window
- after access becomes valid, registration activates

This specifically validates changing the missing-provider fallback from true to false.

## Multi-display

With multiple Halo surfaces:

- every host refreshes registration on access changes
- drag activates only the intended display
- revocation clears targeted state on every host
- no Host remains registered accidentally

## Activation sequence interaction

Licensed valid drag must preserve ActivationSequenceCoordinator.shared.cancelForInteraction().

Locked drags should not cancel activation/locked presentation unnecessarily.

## Geometry / expansion

For licensed Drop CI:

- existing sizing is unchanged
- beginFileDrop, endFileDrop, and completeFileDrop timings remain unchanged unless explicitly required
- full-surface Drop CI remains responsive

## macOS 26 and macOS 27

Run the Drop CI tests on both.

The fix should be OS-independent. Do not introduce an OS-version branch unless a separately verified OS-specific issue requires one.

# Safety constraints

## Do not query Keychain from drag callbacks

The macOS 26 Keychain main-thread hang was already fixed by removing synchronous Keychain work from UI paths.

Do not reintroduce entitlement lookup from draggingEntered, draggingUpdated, performDragOperation, SwiftUI body evaluation, or AppKit registration callbacks.

Use only the in-memory access state supplied by AppDelegate.

## Do not move WindowManager behind licensing

WindowManager intentionally exists while locked.

Moving engine creation/start behind licensing could break the locked/sign-in surface, activation flow, and panel/geometry lifecycle.

Only gate the Drop CI drag capability.

## Do not gate only SurfaceView

If the fix only hides DropContextView, AppKit may still accept the drag, mutate SurfaceState, expand the notch, or call store.addFiles.

The gate belongs before those actions.

## Do not duplicate entitlement policy

There should not be a second interpretation of paid/trial/press validity inside WindowManager.

Use AppDelegate's existing commercial-access result.

# Expected final architecture

AppDelegate
→ authoritative commercialAccessGranted
→ WindowManager in-memory access state
→ dropCIAllowed
   - commercial access true
   - HaloContextDropEnabled true
→ registration
→ drag-state mutation
→ actual drop

All three Drop boundaries must require the same permission.

# Implementation completion criteria

The code change is complete only when:

- commercial access is propagated from AppDelegate into WindowManager
- Drop registration fails closed before its provider exists
- registration requires commercial access
- drag-state mutation requires commercial access
- final file-drop handling requires commercial access
- access changes refresh all Hosts
- active Drop CI is cancelled on access loss
- UserDefaults changes reuse the centralized gate
- File Shelf behavior is preserved
- no Keychain/network/license validation work is moved into drag callbacks
- locked, paid, Press, trial, disabled, transition, race, multi-display, macOS 26, and macOS 27 cases have been checked

Do not remove this document until the fix is implemented and verified.
