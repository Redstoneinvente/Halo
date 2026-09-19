# Halo Context Interface (CI) Implementation Guide

> **Required agent starting point:** follow the [Base CI template](Docs/Templates/BaseCI.md), fill its design record, and complete its verification matrix. Existing examples illustrate patterns; the template identifies the shared integration obligations and cleanup pitfalls.

## Purpose

This document explains how to implement a built-in visual Context Interface in Halo without breaking notch ownership, sizing, priority arbitration, closed-notch rendering, or the surrounding WindowManager architecture.

The primary reference implementation is the Audio/Music CI currently implemented as ContextMusicView and the .music ActiveContextInterface.

This guide is intentionally about the visual/runtime integration contract. A CI may have a service, monitor, system event source, app integration, or no backend at all. Those data-source details are separate from the rules that let a CI participate safely in Halo's notch.

---

# 1. What a Context Interface actually is

A Context Interface is not a second window and it is not allowed to resize an NSPanel directly.

A CI is a temporary visual owner of Halo's existing surface.

The important pipeline is:

    context becomes eligible
        ↓
    SurfaceView adds it to builtInContextCandidates
        ↓
    activeContext selects exactly one winner
        ↓
    winner controls what SurfaceView renders
        ↓
    CI may request a preferred surface size through SurfaceState
        ↓
    WindowManager converts that request into panel geometry

The CI should therefore think in terms of:

- eligibility
- priority
- ownership
- presentation
- sizing
- cleanup

It should not think in terms of "create my own notch window."

---

# 2. Audio/Music CI as the reference implementation

The UI calls this the Music CI. Some source comments refer to its geometry as the Audio CI.

Its core pieces are:

- ContextMusicOptions in Halo/Core/WorkspaceModels.swift
- ContextMusicSettings in Halo/Views/WorkspaceSettingsView.swift
- ContextMusicView in Halo/Views/SurfaceView.swift
- .music in ActiveContextInterface
- HaloContextMusicPriority
- HaloContextMusicUseFullNotchArea
- HaloContextMusicKeepClosedNotchContents
- workspace.media.hasNowPlayingPresentation as its eligibility signal

The Music CI is a useful reference because it is largely self-contained visually:

- it has its own layouts
- it has its own background
- it requests its own expanded size
- it supports full-surface and below-strip rendering
- it supports keeping Closed Notch contents visible
- it does not need a special NSPanel
- it does not bypass activeContext arbitration

---

# 3. The most important rule: eligibility is not ownership

Do not render a CI merely because its trigger is active.

For Music, this would be wrong:

    if workspace.media.hasNowPlayingPresentation {
        ContextMusicView(...)
    }

That ignores every other CI.

Instead, the trigger only makes Music a candidate:

    if contextOptions.enabled && workspace.media.hasNowPlayingPresentation {
        candidates.append((.music, contextMusicPriority, 2))
    }

Then activeContext chooses the winner.

The current arbitration model is conceptually:

    eligible candidates
        ↓
    compare priority
        ↓
    if priorities are equal, compare tieRank
        ↓
    one ActiveContextInterface wins

Only the winner should render.

This guarantees that two CIs do not simultaneously believe they own the notch.

---

# 4. The three states every CI author must understand

## 4.1 Eligible

The feature's context currently qualifies.

For Music:

    contextOptions.enabled
    &&
    workspace.media.hasNowPlayingPresentation

Eligibility does not imply that Halo is expanded.

Eligibility does not imply that this CI won the priority contest.

## 4.2 Active / owner

The CI won activeContext.

For Music:

    private var contextMusicActive: Bool {
        activeContext == .music
    }

This is the value presentation code should normally use.

## 4.3 Expanded

Halo itself is open:

    state.expanded == true

A CI can be eligible and active while Halo is closed.

Music uses this intentionally: music can be the current context, but the normal Closed Notch remains visible until the user opens Halo.

This is why a CI should not automatically set state.expanded merely because it is eligible unless auto-opening is explicitly part of that CI's behavior.

---

# 5. Minimum integration contract for a new built-in CI

Assume the new feature is called Example CI.

At minimum, a built-in visual CI normally needs all of the following.

## 5.1 An ActiveContextInterface case

In SurfaceView.swift:

    private enum ActiveContextInterface: String {
        case drop
        case teleprompter
        case transfer
        case clipboard
        case custom
        case music
        case bluetooth
        case retro
        case example
    }

This is the identity used by the central arbiter.

Do not use a collection of unrelated booleans as a substitute for this.

---

## 5.2 An enable setting

A normal user-configurable CI should have a persistent enable state.

For a simple CI this can be AppStorage:

    @AppStorage("HaloContextExampleEnabled")
    private var exampleCIEnabled = false

If the CI has a larger Codable visual configuration, follow Music and store that configuration in WorkspaceLayout instead.

Music uses:

    layout.contextMusic

with:

    ContextMusicOptions

This is preferable when the visual configuration belongs to profiles/layouts rather than global app preferences.

---

## 5.3 A priority setting

A built-in CI should participate in the same priority system:

    @AppStorage("HaloContextExamplePriority")
    private var examplePriority = 50.0

Then expose this in Settings.

Current CI priority is user-facing and is normally in the 0...100 range.

Priority answers:

    "If several CIs are eligible, which one owns the notch?"

Do not solve collisions by manually hiding other views.

---

## 5.4 A clear eligibility expression

Keep eligibility easy to reason about.

Example:

    private var exampleEligible: Bool {
        guard exampleCIEnabled else { return false }
        return exampleModel.hasPresentation
    }

Then register it in builtInContextCandidates:

    if exampleEligible {
        candidates.append((.example, examplePriority, 2))
    }

Eligibility should describe whether the context is relevant.

It should not perform side effects.

It should not resize the notch.

It should not start synchronous I/O.

---

## 5.5 A tie rank

Candidates currently use:

    (interface, priority, tieRank)

Priority is the primary comparison.

tieRank is the deterministic fallback when priorities are equal.

Existing examples currently use different tie ranks depending on CI semantics. Do not give every new CI an arbitrarily huge tieRank to force it to win.

Choose a conservative tieRank based on how interruptive the CI should be, and document why.

Manual/emergency-style interactions may justifiably have stronger tie behavior than passive ambient context.

---

## 5.6 An active helper

Add the same pattern used by the current CIs:

    private var exampleContextActive: Bool {
        activeContext == .example
    }

Use this for rendering, background decisions, cleanup, and ownership-sensitive actions.

---

# 6. Notch ownership

Halo has two main expanded presentation modes for a built-in CI.

## 6.1 Normal content-area ownership

The CI is rendered inside the normal expanded content area.

The top/closed-notch strip is still part of SurfaceView's layout.

Conceptually:

    [ closed/top strip ]
    [                 ]
    [   Example CI    ]
    [                 ]

Music uses this when HaloContextMusicUseFullNotchArea is false.

In the main expanded branch, the pattern is:

    } else if exampleContextActive {
        if !exampleUsesFullNotchArea {
            ExampleContextView(surfaceState: state)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .transition(
                    .opacity.combined(
                        with: .scale(scale: 0.985)
                    )
                )
        }
    }

---

## 6.2 Full-surface ownership

The CI owns the entire expanded Halo surface, including the area normally occupied by the top strip.

This is controlled centrally by contextOwnsFullSurface.

The current structure intentionally checks:

    guard state.expanded else { return false }

Then dispatches according to activeContext.

For a new CI:

    case .example:
        return exampleUsesFullNotchArea

This is important:

Full-surface ownership should normally only exist while Halo is expanded.

Do not make contextOwnsFullSurface true merely because a trigger exists while the notch is closed.

When contextOwnsFullSurface is true, the CI is rendered in the separate full-surface layer:

    if contextOwnsFullSurface {
        Group {
            if exampleContextActive {
                ExampleContextView(surfaceState: state)
            }
            ...
        }
    }

If you add an entry to contextOwnsFullSurface but forget the matching full-surface render branch, the CI can make normal content disappear while rendering nothing.

If you add the full-surface render branch but forget contextOwnsFullSurface, you can double-render the CI.

Always add both sides together.

---

# 7. Keeping Closed Notch contents visible

This is separate from full-surface ownership.

Music exposes:

    HaloContextMusicKeepClosedNotchContents

and SurfaceView resolves it through:

    keepsClosedContentsWhileExpanded

For a new CI that supports this option:

    case .example:
        return exampleKeepsClosedContents

This allows users to decide whether the Closed Notch content remains visible while the CI is open.

Do not use the normal opened-notch appearance setting for a CI-specific behavior. Existing CIs intentionally have independent ownership settings.

A CI may also have a more specialized preservation rule.

Music has preservesMusicClosedVisualizer so the Closed Notch visualizer can remain alive independently of the general keep-closed-contents setting.

Only add special preservation behavior when the CI genuinely needs it.

---

# 8. What happens while the CI is active but Halo is closed

Not every CI needs a custom closed view.

Music is the simplest reference:

- Music can be the active context.
- While Halo is closed, it normally leaves ClosedNotchView in place.
- When Halo opens, ContextMusicView replaces the normal opened dashboard.

Transfer and Clipboard are examples of CIs that do have custom closed representations:

    TransferClosedContextView
    ClipboardClosedContextView

Choose one of these two models deliberately.

## Model A: opened-only CI

Use the normal Closed Notch while closed.

Good for:

- Music-like experiences
- large visual canvases
- contextual dashboards
- information that only needs to replace the opened notch

## Model B: closed + opened CI

Provide a compact closed representation and an expanded representation.

Good for:

- live transfer indicators
- clipboard events
- contexts where the closed state is itself useful

Do not create a custom closed view just because other CIs have one.

---

# 9. A visual-only CI template

This is a minimal visual CI view. It has no service or backend requirement.

    private struct ExampleContextView: View {
        @ObservedObject var surfaceState: SurfaceState

        var body: some View {
            GeometryReader { proxy in
                ZStack {
                    LinearGradient(
                        colors: [
                            .purple.opacity(0.45),
                            .black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 34))

                        Text("Example CI")
                            .font(.title2.bold())

                        Text("This CI owns Halo's current context surface.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                }
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height
                )
            }
            .task {
                publishPreferredSize()
            }
            .onDisappear {
                releasePreferredSizeIfOwned()
            }
        }

        private var preferredSize: CGSize {
            CGSize(width: 480, height: 300)
        }

        private func publishPreferredSize() {
            let next = preferredSize

            guard surfaceState.contextPreferredSize != next else {
                return
            }

            surfaceState.contextPreferredSize = next
        }

        private func releasePreferredSizeIfOwned() {
            guard surfaceState.contextPreferredSize == preferredSize else {
                return
            }

            surfaceState.contextPreferredSize = nil
        }
    }

This view is intentionally dumb about NSPanel.

It renders content and requests geometry.

WindowManager owns the actual window.

---

# 10. The SurfaceState sizing contract

SurfaceState exposes CI geometry requests:

    contextPreferredSize
    contextPreferredCompactWidth
    contextPreferredCompactHeight
    contextMinimumExpandedWidth

These are requests, not panel commands.

## contextPreferredSize

Requested expanded size.

Music's ContextMusicView calculates a preferredSurfaceSize from its content and publishes it.

WindowManager listens to this property and animates the existing panel to its resolved frame.

## contextPreferredCompactWidth

Requested width while Halo is closed.

Useful for CIs with custom closed presentations, such as Transfer and Clipboard.

An opened-only CI often does not need it.

## contextPreferredCompactHeight

Requested closed height.

Use only if the CI genuinely needs a different closed height.

## contextMinimumExpandedWidth

A floor for expanded width.

Transfer and Clipboard use this to ensure their expanded UI cannot become narrower than a usable size around a physical notch.

---

# 11. Never resize the panel from a CI view

Do not call:

- NSPanel.setFrame
- WindowManager geometry methods
- screen coordinate calculations
- panel animations

from ExampleContextView.

Instead:

    surfaceState.contextPreferredSize = ...

WindowManager already subscribes to these values and knows how to:

- respect the physical notch
- respect screen bounds
- preserve top anchoring
- handle left/right/bottom surface styles
- animate geometry
- update viewport state
- deal with multiple displays

A CI should not duplicate that logic.

---

# 12. Audio/Music CI sizing pattern

Music has a particularly good pattern worth copying.

Its preferred size is derived from stable visual structure:

- metadata
- lyrics
- scrub/progress row
- controls
- visualizer
- artwork
- spacing
- safe margins
- selected layout mode

A key detail is that it reserves the progress-row footprint even when MediaRemote temporarily omits duration.

That prevents:

    metadata refresh
        ↓
    duration temporarily disappears
        ↓
    preferred size shrinks
        ↓
    duration returns
        ↓
    notch grows again

A CI should size itself from stable presentation requirements, not noisy/transient samples.

If a data source flickers, the surface should not visibly breathe unless that resizing is intentional.

---

# 13. Use a sizing signature for configurable CIs

Music builds a sizingKey from every option that can materially change geometry.

It then uses:

    .task(id: sizingKey) {
        publishPreferredSize()
    }

This is better than recomputing and writing geometry on every body evaluation.

For a new configurable CI:

    private var sizingKey: String {
        [
            layout.rawValue,
            String(showHeader),
            String(showFooter),
            String(spacing),
            String(horizontalMargin)
        ]
        .joined(separator: "|")
    }

Then:

    .task(id: sizingKey) {
        publishPreferredSize()
    }

Only include values that can actually affect size.

---

# 14. Avoid redundant SurfaceState writes

This is mandatory.

Before assigning a preferred size, compare it to the current value.

Music does this with an approximate one-point comparison.

Example:

    if let current = surfaceState.contextPreferredSize,
       abs(current.width - next.width) < 1,
       abs(current.height - next.height) < 1 {
        return
    }

    surfaceState.contextPreferredSize = next

Why this matters:

SurfaceState is ObservableObject.

Unnecessary writes can invalidate SurfaceView and WindowManager subscriptions.

Halo has already encountered a macOS 26 AttributeGraph/update-storm problem caused by a state-writing observer pattern.

Treat published geometry as state that should change only when its value genuinely changed.

---

# 15. Cleanup must be ownership-aware

> The size-comparison example below is a legacy heuristic. Equal dimensions do not establish ownership. New CIs must use the handoff rules in `Docs/Templates/BaseCI.md`, including stale callbacks and equal-size owners.

Do not blindly clear shared CI geometry in onDisappear.

This is unsafe:

    .onDisappear {
        surfaceState.contextPreferredSize = nil
    }

Another CI may already have become active and published its own preferred size.

Music uses a safer ownership pattern:

1. calculate the size it owns
2. compare the current value to that size
3. clear only if it still owns that value

Conceptually:

    let owned = preferredSurfaceSize

    if surfaceState.contextPreferredSize == owned {
        surfaceState.contextPreferredSize = nil
    }

For CGFloat geometry, use a tolerance rather than exact equality when appropriate.

The same principle applies to:

- contextPreferredCompactWidth
- contextPreferredCompactHeight
- contextMinimumExpandedWidth

Never clean up another CI's state.

---

# 16. Republish when shared geometry is cleared unexpectedly

Music also handles this case:

    .onChange(of: surfaceState.contextPreferredSize) { requested in
        guard surfaceState.expanded, requested == nil else {
            return
        }

        publishPreferredSize()
    }

This lets the active Music CI restore its geometry if some other surface lifecycle clears the shared preferred size while Music still owns the expanded notch.

Use this only when it is needed.

Do not create a state-write loop.

Always guard both:

- "am I still the owner?"
- "is the requested value actually missing/different?"

---

# 17. Background ownership

There are two valid patterns.

## Pattern A: self-contained CI background

Music renders its background inside ContextMusicView:

    GeometryReader
        ↓
    ZStack
        ↓
    contextBackground(...)
        +
    CI content

This keeps the CI visually self-contained.

For a visual-only CI, this is often the easiest and safest pattern.

## Pattern B: shell-level background

Some CIs participate in SurfaceView.surfaceBackgroundLayer.

Current examples include Transfer, Clipboard, and Custom CI.

Use this when the CI background must be part of the outer Halo surface itself or must remain coordinated across presentation layers.

If you add a shell-level background, ensure only the active CI selects it.

Never make the global background depend merely on eligibility.

---

# 18. Halo surface layers

The normal surface stack is conceptually:

    selected background
        ↓
    NotchSkinLayer
        ↓
    CI / widget content
        ↓
    surface overlay / chrome

NotchSkinLayer is deliberately above the background and below useful content.

A CI should not accidentally place decorative effects above controls unless that is explicitly intended.

For a self-contained visual CI, prefer:

    CI background
    content
    controls

inside the CI's own ZStack.

---

# 19. Safe top spacing

Full-surface ownership changes the meaning of the top of the view.

Music accounts for:

- whether it uses the full notch area
- whether Closed Notch content is preserved
- whether the visualizer strip is preserved
- surfaceState.compactHeight
- user top margin

This is an important visual rule.

If your full-surface CI keeps the Closed Notch strip visible, its content must not begin underneath that strip.

A typical approach:

    if usesFullNotchArea && keepsClosedContents {
        topInset = surfaceState.compactHeight + gap
    } else {
        topInset = normalContentInset
    }

Do not hard-code a MacBook notch height.

Use SurfaceState geometry.

---

# 20. Full-surface CI checklist

If the CI supports "Use full notch area," all of these must agree:

1. AppStorage/config setting exists.
2. contextOwnsFullSurface returns that value for the CI.
3. normal expanded branch renders the CI only when full-surface is false.
4. full-surface branch renders the CI when it owns the whole surface.
5. CI internal padding respects closed-strip preservation.
6. the CI remains clipped by Halo's outer contour.
7. changing the setting while active does not produce two copies or zero copies.

This pair is critical:

    normal branch:
        active && !usesFullNotchArea

    full branch:
        contextOwnsFullSurface && active

---

# 21. Priority and tie behavior

Current built-in arbitration compares:

    priority first
    tieRank second

Examples currently include higher tie ranks for more direct/transient interactions and lower tie ranks for passive contexts.

Music currently participates with:

    (.music, contextMusicPriority, 2)

The exact numeric tie rank is not a universal requirement.

The requirement is deterministic ownership.

When adding Example CI, decide:

- Is it passive like an ambient state?
- Is it a direct user action?
- Is it temporary and urgent?
- Should equal-priority Music beat it or lose to it?

Then select and document the tieRank accordingly.

Do not use tieRank to defeat the user-set priority slider.

---

# 22. Auto-opening is a separate policy

Music demonstrates that a CI does not need to auto-open.

Its setting text is effectively:

    replace the opened notch while music is playing

That means:

- playback makes Music eligible
- activeContext can become .music
- the normal closed notch can remain closed
- when Halo opens, Music owns the opened surface

Other CIs may intentionally auto-open.

Clipboard "Pop Up" is one example.

If Example CI should auto-open, implement that as a separate event/lifecycle rule.

Do not put:

    state.expanded = true

inside the eligibility computed property.

Computed ownership logic must stay side-effect free.

---

# 23. A recommended visual-only Example CI integration

## State/settings

    @AppStorage("HaloContextExampleEnabled")
    private var exampleCIEnabled = false

    @AppStorage("HaloContextExamplePriority")
    private var examplePriority = 50.0

    @AppStorage("HaloContextExampleUseFullNotchArea")
    private var exampleUsesFullNotchArea = false

    @AppStorage("HaloContextExampleKeepClosedNotchContents")
    private var exampleKeepsClosedContents = false

## Eligibility

    private var exampleEligible: Bool {
        exampleCIEnabled && exampleModel.hasPresentation
    }

If it is purely manual/visual during development, a temporary @State Bool can be used as the trigger, but production eligibility should have a clear source of truth.

## Candidate registration

    if exampleEligible {
        candidates.append(
            (.example, examplePriority, 2)
        )
    }

## Active helper

    private var exampleContextActive: Bool {
        activeContext == .example
    }

## Full-surface ownership

Inside contextOwnsFullSurface:

    case .example:
        return exampleUsesFullNotchArea

## Closed-content preservation

Inside keepsClosedContentsWhileExpanded:

    case .example:
        return exampleKeepsClosedContents

## Normal expanded branch

    } else if exampleContextActive {
        if !exampleUsesFullNotchArea {
            ExampleContextView(
                surfaceState: state
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
            .transition(
                .opacity.combined(
                    with: .scale(scale: 0.985)
                )
            )
        }
    }

## Full-surface branch

    if contextOwnsFullSurface {
        Group {
            if exampleContextActive {
                ExampleContextView(
                    surfaceState: state
                )
            }
            ...
        }
    }

---

# 24. Settings integration

A production built-in CI should normally appear in the Context Notch Interfaces settings UI.

Follow the current pattern in WorkspaceSettingsView:

- add a CI selection case
- add a card to Available CI
- add a dedicated settings pane
- expose enabled state
- expose priority
- expose full-surface ownership when supported
- expose keep-closed-contents when supported
- expose only visual controls the CI actually uses

Music's settings are a strong reference because they separate:

- content
- CI priority
- CI surface
- margins
- lyrics
- artwork
- visualizer
- colors/background

Do not put all CI configuration into SurfaceView.

SurfaceView should coordinate ownership.

Settings views should own user configuration UI.

---

# 25. Where configuration should live

Use WorkspaceLayout/Codable options when:

- the configuration is part of a profile
- different displays/profiles may need different visual layouts
- it should export/import with workspace state
- it is a substantial set of visual options

Music uses ContextMusicOptions in WorkspaceLayout for this reason.

Use AppStorage when:

- the value is global behavior
- it is a small independent preference
- it should not vary with workspace profile

Current CI surface/priority toggles frequently use AppStorage.

Be deliberate. Do not scatter the same semantic setting across both systems.

---

# 26. Codable visual options should have resolved values

Music's ContextMusicOptions demonstrates the migration-friendly pattern:

    var spacing: Double?

    var resolvedSpacing: Double {
        min(32, max(4, spacing ?? 12))
    }

Optional persisted values let old profiles decode without needing every newly introduced field.

Resolved values provide:

- defaults
- clamping
- one authoritative interpretation

For a new profile-backed CI, prefer this approach over force-unwrapped migration assumptions.

Also implement validated() for imported/persisted data that can contain numeric values.

Reject non-finite values.

Clamp visual ranges.

---

# 27. CI view responsibilities

A well-behaved visual CI view should own:

- its visual hierarchy
- local visual state
- local async tasks
- content-driven preferred-size calculation
- accessibility for its controls
- cleanup of values it owns

It should not own:

- activeContext arbitration
- NSPanel creation
- WindowManager
- screen placement
- commercial license decisions
- direct conflict resolution with other CIs

---

# 28. Async work

Music uses task(id:) for artwork, playback, lyrics, and sizing.

This has useful lifecycle behavior:

- old work is cancelled when the identity changes
- work is associated with the view
- expensive work does not happen synchronously in body

For a new CI:

    .task(id: model.requestKey) {
        await loadSomething()
    }

Check Task.isCancelled before committing asynchronous results when appropriate.

Never perform blocking network, disk, Keychain, or system API calls directly inside body.

---

# 29. Avoid broad observable churn when possible

Observing a large ObservableObject means any published change can invalidate the view.

This is sometimes acceptable, but CI authors should avoid making SurfaceView itself observe rapidly changing state unless SurfaceView actually needs that state for arbitration.

Prefer:

- SurfaceView observes only the trigger needed to determine eligibility.
- The CI view observes the richer model needed to render itself.

This keeps high-frequency visual updates localized to the active CI.

The Transfer/macOS 26 debugging work demonstrated why broad state churn at the root surface can become expensive.

---

# 30. Never use onReceive merely to mirror state unless necessary

Be careful with @Published publishers attached to SurfaceView.

A publisher can emit its current value when a subscription is attached.

If that handler writes back into shared SurfaceState, it can create expensive invalidation cycles.

Prefer onChange when the semantic requirement is:

    "react when this value changes"

and guard redundant writes.

The Transfer CI issue on macOS 26 is the concrete warning here.

---

# 31. Commercial-access boundary

Normal built-in CIs rendered exclusively through HaloSurfaceRouter/SurfaceView are inside Halo's commercial surface gate.

However, any CI that installs behavior outside that router must gate itself explicitly.

Examples of "outside" behavior include:

- AppKit NSDraggingDestination
- global event monitors
- additional NSPanel
- system overlay windows
- external interaction handlers owned directly by WindowManager

The Drop CI bug demonstrated this.

A CI must not assume:

    "my SwiftUI view is hidden while locked, therefore my external event path is locked"

If a trigger exists outside the router, use the authoritative in-memory commercial-access state at that outer boundary.

Do not query Keychain or the network from event callbacks.

---

# 32. Multi-display rule

SurfaceState is per Host/display.

Do not put per-surface visual geometry into a global singleton.

When a CI writes:

    surfaceState.contextPreferredSize

it is requesting geometry for the specific Halo surface hosting that view.

This is what allows multiple displays to remain independent.

Global model state may describe the underlying context, but surface ownership and surface size belong to the current SurfaceState.

---

# 33. Pin and close behavior

Music provides explicit controls for:

- close
- pin/unpin
- CI surface options
- Settings

These are not mandatory for every minimal CI, but they are a good UX reference for substantial full-screen CIs.

If you provide a close control:

    if !surfaceState.pinned {
        surfaceState.expanded = false
    }

Do not close a pinned surface behind the user's back.

If your CI auto-closes after an event, check the pin state.

---

# 34. Visual controls and accessibility

Interactive CI controls should provide:

- accessibility labels
- help text where useful
- sufficient hit areas
- reduced-motion behavior when animation is significant
- disabled states that reflect actual capability

Music uses accessibilityReduceMotion for animation-sensitive visuals and gives explicit labels/help to its surface controls.

A purely decorative CI should not intercept input unnecessarily.

---

# 35. Surface transitions

The common built-in transition is:

    .transition(
        .opacity.combined(
            with: .scale(scale: 0.985)
        )
    )

Use the common transition unless the CI has a strong reason to differ.

Remember:

WindowManager already animates panel geometry.

A CI transition should animate content, not fight the panel resize.

---

# 36. Background + clipping

SurfaceView applies the outer Halo contour and clipping.

A CI should generally render to the available frame and let the shell perform final clipping.

Music also clips its internal context content to a rounded rectangle when it is not using the entire notch area.

That is a content design choice, not a replacement for the outer Halo contour.

Do not use fixed screen-shaped masks inside a CI.

---

# 37. Context ownership flow for Music

This is the current conceptual Music flow:

    MediaService reports presentable now-playing state
        ↓
    contextOptions.enabled is true
        ↓
    Music enters builtInContextCandidates
        with user priority
        and tieRank 2
        ↓
    activeContext arbitration
        ↓
    activeContext == .music
        ↓
    contextMusicActive == true
        ↓
    Halo closed?
        → normal ClosedNotchView continues

    Halo expanded?
        ↓
    contextMusicUsesFullNotchArea?
        ├─ false → ContextMusicView in normal expanded content branch
        └─ true  → ContextMusicView in full-surface ownership branch
        ↓
    ContextMusicView publishes preferredSurfaceSize
        ↓
    SurfaceState.contextPreferredSize
        ↓
    WindowManager targetFrame
        ↓
    existing Halo panel resizes
        ↓
    CI disappears / loses ownership
        ↓
    release owned geometry without clearing another CI's request

This is the model a new visual CI should imitate.

---

# 38. A reusable implementation sequence

When adding a new built-in CI, do the work in this order.

## Phase 1 — visual view only

1. Build ExampleContextView.
2. Feed it static/mock data.
3. Make it adaptive to whatever frame it receives.
4. Add its preferred size calculation.
5. Verify it does not know about NSPanel.

## Phase 2 — identity and eligibility

6. Add .example to ActiveContextInterface.
7. Add enabled setting.
8. Define exampleEligible.
9. Add priority.
10. Add candidate to builtInContextCandidates.
11. Add exampleContextActive.

## Phase 3 — ownership routing

12. Add normal expanded render branch.
13. If supported, add use-full-notch setting.
14. Add contextOwnsFullSurface switch case.
15. Add full-surface render branch.
16. If supported, add keep-closed-contents setting.
17. Add keepsClosedContentsWhileExpanded switch case.

## Phase 4 — geometry

18. Publish contextPreferredSize.
19. Only publish when the size changes.
20. Use compact size requests only if the CI has a custom closed view.
21. Clear only values owned by this CI.
22. Verify changing CI priority while open does not leave stale geometry.

## Phase 5 — real trigger

23. Connect the actual trigger/model.
24. Keep eligibility side-effect free.
25. Decide separately whether the trigger auto-opens Halo.
26. Localize high-frequency model observation to the CI view.

## Phase 6 — settings

27. Add CI card.
28. Add settings selection.
29. Add dedicated settings view.
30. Expose priority and ownership settings.
31. Add profile-backed visual options if needed.

## Phase 7 — regression

32. Test against every other CI at lower, equal, and higher priority.
33. Test pinned and unpinned.
34. Test full-surface on/off.
35. Test keep-closed-contents on/off.
36. Test closed → open → closed.
37. Test trigger ending while open.
38. Test trigger ending while closed.
39. Test rapid trigger changes.
40. Test multiple displays.
41. Test locked/unlicensed state if any external trigger exists.
42. Test macOS 26 and newer supported macOS versions.

---

# 39. Common failure modes

## Failure: rendering from eligibility instead of activeContext

Symptom:

Two CIs overlap or one CI appears despite losing priority.

Fix:

Render from activeContext == .yourCase.

---

## Failure: CI writes NSPanel geometry directly

Symptom:

Wrong screen anchoring, broken multi-display behavior, fighting WindowManager animations.

Fix:

Publish SurfaceState geometry requests.

---

## Failure: full-surface setting added only in the view

Symptom:

Top strip remains or CI is laid out twice.

Fix:

Integrate contextOwnsFullSurface and both render branches.

---

## Failure: contextOwnsFullSurface added without full-surface rendering

Symptom:

Expanded Halo becomes empty.

Fix:

Add the matching full-surface branch.

---

## Failure: clearing contextPreferredSize unconditionally

Symptom:

A newly selected CI snaps back to the default size when the old CI disappears.

Fix:

Clear only the geometry value owned by the disappearing CI.

---

## Failure: writing the same published geometry every update

Symptom:

Excess SurfaceView invalidation, animation churn, possible AttributeGraph performance problems.

Fix:

Compare before assignment.

---

## Failure: tying geometry to transient data

Symptom:

Notch repeatedly grows/shrinks during metadata refresh.

Fix:

Base geometry on stable visual structure, as Music does with its reserved progress row.

---

## Failure: trigger automatically opens Halo accidentally

Symptom:

Passive context becomes intrusive.

Fix:

Separate eligibility from expansion policy.

---

## Failure: outer/AppKit trigger ignores licensing

Symptom:

CI behavior occurs on the locked surface.

Fix:

Gate the external interaction boundary using AppDelegate's authoritative commercial access result.

---

## Failure: custom closed content steals the physical notch

Symptom:

Closed CI draws through the camera/notch area or calculates the wrong width.

Fix:

Use SurfaceState physical/compact geometry and follow Transfer/Clipboard sizing patterns.

---

# 40. "Must have" versus "only if needed"

## Every built-in CI must have

- an ActiveContextInterface identity
- a deterministic eligibility rule
- candidate registration
- priority behavior
- a single-owner activeContext route
- an expanded render path
- safe lifecycle cleanup
- no direct panel ownership
- no redundant shared-state writes
- correct behavior when it loses priority

## Most user-configurable CIs should have

- enabled setting
- priority setting
- Settings card/page
- profile-aware visual options when appropriate
- accessibility for interactive controls

## Only CIs that need it should have

- custom closed presentation
- contextPreferredCompactWidth
- contextPreferredCompactHeight
- contextMinimumExpandedWidth
- full-surface ownership
- keep-closed-contents option
- shell-level background
- auto-popup behavior
- external AppKit/global event integration

Do not add every feature to every CI.

---

# 41. Review checklist before merging a CI

Use this as a PR checklist.

### Ownership

- [ ] New ActiveContextInterface case exists.
- [ ] Eligibility is side-effect free.
- [ ] Candidate has user priority.
- [ ] Tie rank is intentional.
- [ ] Presentation checks activeContext, not trigger state.
- [ ] CI loses cleanly to higher-priority contexts.
- [ ] Equal-priority behavior is deterministic.

### Surface

- [ ] Normal expanded rendering works.
- [ ] Full-surface rendering is either fully integrated or not exposed.
- [ ] Closed-content preservation is either fully integrated or not exposed.
- [ ] No duplicate rendering when ownership mode changes.
- [ ] No blank surface when ownership mode changes.

### Geometry

- [ ] CI requests size through SurfaceState.
- [ ] No direct NSPanel resizing.
- [ ] Preferred size is stable.
- [ ] Shared state writes are equality-guarded.
- [ ] onDisappear only clears geometry owned by this CI.
- [ ] Compact geometry is used only if needed.

### Lifecycle

- [ ] Trigger start works.
- [ ] Trigger end works.
- [ ] Trigger changes while closed work.
- [ ] Trigger changes while open work.
- [ ] Pinning is respected.
- [ ] Auto-open policy is explicit.
- [ ] Async tasks cancel correctly.

### Visual

- [ ] CI adapts to its actual frame.
- [ ] Full-surface top inset respects compactHeight when needed.
- [ ] Background layer is intentional.
- [ ] Notch skin/content hierarchy remains correct.
- [ ] Controls have accessibility labels/help.
- [ ] Reduced Motion is respected where relevant.

### Integration

- [ ] Settings card exists if user configurable.
- [ ] Priority is configurable if appropriate.
- [ ] Profile/global storage choice is intentional.
- [ ] Multi-display behavior is correct.
- [ ] No blocking I/O in body.
- [ ] High-frequency observation is localized.
- [ ] External trigger paths are commercially gated if they bypass HaloSurfaceRouter.
- [ ] macOS 26 and newer supported versions are tested.

---

# 42. Files to inspect when implementing a new CI

The current built-in CI architecture primarily spans:

## Halo/Views/SurfaceView.swift

Look here for:

- ActiveContextInterface
- builtInContextCandidates
- activeContext
- per-CI active helpers
- contextOwnsFullSurface
- keepsClosedContentsWhileExpanded
- closed rendering
- normal expanded rendering
- full-surface rendering
- CI view implementation
- CI-specific surface background/overlay behavior
- active-context cleanup

## Halo/NotchEngine/WindowManager.swift

Look here for:

- SurfaceState
- contextPreferredSize
- contextPreferredCompactWidth
- contextPreferredCompactHeight
- contextMinimumExpandedWidth
- targetFrame
- context-size subscriptions
- actual panel geometry and animation

A normal visual CI should rarely need modifications here.

If you believe a new visual-only CI needs custom WindowManager code, first verify that the SurfaceState sizing contract cannot already express the requirement.

## Halo/Core/WorkspaceModels.swift

Use this for:

- profile-backed CI visual configuration
- Codable options
- resolved defaults
- validation

Music's ContextMusicOptions is the reference.

## Halo/Views/WorkspaceSettingsView.swift

Use this for:

- CI cards
- CI selection/navigation
- enable controls
- priority
- full-surface controls
- keep-closed-content controls
- CI-specific visual customization

---

# 43. Final architectural rule

A CI does not own Halo because its trigger is active.

A CI owns Halo only when the central context arbiter selects it.

A CI does not own the window.

It owns a presentation inside the window.

SurfaceView decides who owns the presentation.

SurfaceState describes the geometry that presentation needs.

WindowManager owns and animates the actual macOS surface.

Keeping those responsibilities separate is what allows Halo to add many Context Interfaces without every new CI becoming a special-case window system.
