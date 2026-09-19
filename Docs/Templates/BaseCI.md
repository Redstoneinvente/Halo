# Base CI template — required starting point for agents

Use this template whenever creating or substantially changing a Halo Context Interface. Fill in the design record below before implementation and include the completed record in the CI's documentation or PR. This is an integration template for the existing architecture, **not an implemented `BaseCI` Swift class** or a second runtime.

Read `AGENTS.md`, `Docs/CISDK.md`, and the applicable authoring guide first. For native CIs also read `CI_IMPLEMENTATION_GUIDE.md`. Reinspect the named symbols on the current branch; line numbers and existing special cases can change. Architecture/security rules in `CISDK.md` remain authoritative.

## 1. Choose the existing implementation path

| Path | When to use | Starting point |
| --- | --- | --- |
| Declarative `.haloCI` | Supported components, context and brokered actions can express the interface | `swift run halo-ci init MyCI.haloCI com.example.my-ci "My CI"`; `Docs/CustomCI_V2.md` |
| Native built-in CI | A concrete app-owned requirement cannot be expressed by the SDK | Music's presentation/sizing pattern, plus the native integration steps below |

Prefer SDK primitives for new experiences where sufficient. State the reason for a native implementation. A package must not add an `ActiveContextInterface` case, its own priority engine, direct panel access, or arbitrary executable code. Its existing runtime already supplies these integration responsibilities.

## 2. Fill in this design record

Copy this section into the feature document/PR. Replace every placeholder; write `not needed — reason` for optional behavior.

```text
CI name / stable identity:
Implementation path and reason:
Purpose:
Real context source / existing service:
Enable setting and default:
Priority setting and default (normal range 0...100):
Tie behavior / reason:
Side-effect-free eligibility rule:
Manual activation behavior:
Automatic expansion policy (default: no auto-open):
Dismissal / retrigger policy:
Closed presentation (default: normal Closed Notch):
Expanded presentation:
Full-surface ownership (default: false for native opened-only CI):
Keep Closed Notch contents while expanded (default: false):
Background owner / layer:
Expanded size rule and sizing inputs:
Compact width / height / minimum expanded width (only if needed):
Geometry publication and handoff/cleanup owner:
Global versus profile settings:
Context bindings, units, unavailable-data behavior:
Permissions / revocation / commercial-access boundaries:
Actions and their broker:
Subscriptions / refresh cadence / cancellation:
Per-display versus shared state:
Settings card / controls / accessibility:
Compatibility and persistence migration:
Tests and manual checks:
```

For packages, enablement and priority are existing per-package runtime preferences, not new manifest fields. The CLI starter defaults to manual activation; package surface size and backgrounds are mandatory. Use only documented manifest fields.

## 3. Shared responsibilities — implement each once

| Concern | Existing authority | New CI's responsibility |
| --- | --- | --- |
| Identity | Native `ActiveContextInterface`; package `manifest.id` | One stable identity; preserve it across updates |
| Enablement | Existing Settings/preferences or profile layout | Runtime and Settings use the same key/default |
| Eligibility | Existing context service; package trigger evaluator | Pure, cheap predicate; no I/O, expansion or geometry writes |
| Priority | `SurfaceView.builtInContextCandidates` / `activeContext`; package runtime | Register a candidate, use configured priority, document tie behavior |
| Presentation | `SurfaceView` winner branches | Render only the selected owner, exactly once |
| Geometry | `SurfaceState` requests → `WindowManager` | Publish bounded stable requests; never resize an `NSPanel` |
| Lifecycle | Existing surface/runtime and service owner | Cancel stale work, release only owned state, respect pinning |
| Context | Existing services; SDK catalog/data broker for packages | Reuse data, define missing values, gate sensitive access |
| Actions | Existing service action or SDK broker | Recheck access at execution; do not create a shell escape hatch |
| Settings | `WorkspaceSettingsView`, profile models or runtime preferences | Matching defaults, useful controls, accessible labels |

Eligibility, winning ownership, and `state.expanded` are three different facts. Never use one as a substitute for another.

## 4. Native registration template

The following are **insertion snippets**, not a standalone compilable file. `exampleModel` means the real existing/integrated source selected in the design record. Do not create fake context just to satisfy the snippet.

In `SurfaceView.swift`, add `.example` to the existing `ActiveContextInterface` and use consistent preferences:

```swift
@AppStorage("HaloContextExampleEnabled") private var exampleEnabled = false
@AppStorage("HaloContextExamplePriority") private var examplePriority = 50.0

private var exampleEligible: Bool {
    exampleEnabled && exampleModel.hasPresentation
}

private var exampleContextActive: Bool {
    activeContext == .example
}
```

For profile-owned visual options, use a Codable layout model as Music does instead of duplicating those options into global preferences.

Inside the existing `builtInContextCandidates`, add:

```swift
if exampleEligible {
    let priority = examplePriority.isFinite ? min(100, max(0, examplePriority)) : 50
    candidates.append((.example, priority, 1))
}
```

`1` is a conservative passive-context example, not a universal rank. Inspect the current contenders and document equal-priority/equal-rank behavior. Do not reorder existing candidates to make a new CI win. The current comparator orders priority, then tie rank; equal values require a deliberate tested policy, not an assumption about ordering.

Do not copy Clipboard's special manual priority of `1000` or Custom CI's manual tie rank of `100` into another feature. Those are existing specialized behaviors, not defaults or permission to bypass arbitration. New manual opens normally respect configured priority.

## 5. Native presentation wiring — complete both sides

For the default opened-only, content-area CI:

- Add a winner-gated expanded render branch alongside Music/Clipboard/etc.
- Add `.example: return false` in both `contextOwnsFullSurface` and `keepsClosedContentsWhileExpanded` switches.
- Preserve normal Closed Notch rendering while closed.
- Choose the background layer deliberately; do not unintentionally obscure the skin or compose two backgrounds.

Only if the design calls for full-surface and/or closed-strip options, add these keys **in both runtime and Settings with matching defaults**:

```swift
@AppStorage("HaloContextExampleUseFullNotchArea") private var exampleUsesFullSurface = false
@AppStorage("HaloContextExampleKeepClosedNotchContents") private var exampleKeepsClosedContents = false
```

Then return those values from the corresponding switch cases. Keep the existing expanded-state guard in `contextOwnsFullSurface`. Wire both the content-area branch (`exampleContextActive && !exampleUsesFullSurface`) and the full-surface branch (under `contextOwnsFullSurface`, gated by `exampleContextActive`). Toggle the option while open to verify neither a blank surface nor duplicate content appears.

A custom closed representation is optional. If needed, follow Transfer/Clipboard's physical-notch-safe layout and request compact dimensions through `SurfaceState`. Do not draw through the camera area or infer display geometry independently.

## 6. Geometry and ownership handoff

Reuse Music's stable sizing inputs and `task(id: sizingKey)` pattern. Reserve layout space for temporarily missing data; track only options that actually affect geometry. Equality-guard every shared geometry write (approximately one point for sizes where appropriate).

All four shared requests must be considered:

```text
contextPreferredSize
contextPreferredCompactWidth
contextPreferredCompactHeight
contextMinimumExpandedWidth
```

Do not blindly copy an existing `onDisappear { ... = nil }`. Also, **matching a size does not prove ownership**: two CIs can request the same size. The older size-comparison cleanup examples are a heuristic, not a sufficient handoff guarantee.

Choose one explicit handoff strategy using the existing surface coordinator:

1. Prefer central cleanup of the outgoing CI's owned requests before publishing the incoming owner's requests, with publication gated by the current owner; or
2. If delayed callbacks are unavoidable, use an explicit per-surface ownership identity/generation and validate it before each publish/clear. Implement and test that support deliberately; do not pretend a token API already exists.

In both cases, cancellation and owner checks must happen **after any async wait/dispatch**, immediately before mutation. An old view's disappearance or async result must never erase or overwrite the winner's geometry. Do not start an observer loop that continually republishes geometry another owner is clearing.

Inspect existing central resets when adding a native CI. In particular, `SurfaceView` has cleanup branches in `onChange(of: activeContext)` and Transfer/Clipboard lifecycle handlers that recognize specific owners. Add the new owner's behavior deliberately so a reset cannot undo its requests. Do not treat all existing reset code as safe boilerplate.

## 7. Activation and cleanup policy

Use the same state transition rules for every new CI:

| Event | Required behavior |
| --- | --- |
| Context becomes eligible | Register candidate; do not assume ownership or auto-expand |
| Wins ownership | Publish its presentation/geometry; auto-open only under the recorded policy |
| Loses ownership | Stop owner-only work; preserve incoming owner state |
| Context ends or feature disabled | Release its eligibility and owned requests; cancel tasks |
| User dismisses | Follow recorded suppression/retrigger policy; prevent immediate reopening loops |
| Halo collapses | Follow recorded closed behavior; distinguish collapse from dismissal |
| Permission/access revoked | Remove protected data and reject actions immediately; clear affected eligibility |
| Display removed or host disappears | Cancel that host's work; do not clear another display's state |

If auto-open is needed, track whether **this activation** opened the surface. Collapse only if it still owns the relevant activation, no replacement owner requires the surface, and the surface is not pinned. Recheck these conditions in delayed callbacks. Avoid collapsing a surface the user opened independently.

AppKit/global event paths outside `HaloSurfaceRouter` must check AppDelegate's authoritative commercial-access state **before** mutating state or performing an operation. Read `DROP_CI_ACTIVATION_GATE_PLAN.md` for the boundary pattern; do not reconstruct licensing or query Keychain from interaction callbacks.

## 8. Context, settings and service checklist

- Reuse existing services and subscriptions; no synchronous I/O in view bodies/eligibility, no per-frame polling of slow data.
- For packages, inspect `halo-ci catalog`; use only supported keys and declare/grant their permissions. New SDK data requires descriptor, provider, invalidation, version gate, tests and documentation together.
- Distinguish unavailable data from zero/false; keep any preview/simulation visibly separate from real context.
- Keep local state isolated by package or feature; decide which state is shared and which belongs to a display.
- Add a Settings card/navigation route, enable control and priority slider (`0...100`) for a configurable native CI. Use the exact runtime key and default.
- Only expose full-surface/closed-strip/auto-open controls if their behavior is implemented. Do not copy unused toggles.
- Preserve profile decoding defaults and migrate persisted changes deliberately.
- Label interactive controls, support keyboard use where applicable and respect Reduce Motion.

## 9. Required verification and agent handoff

For a package: run `halo-ci validate`, the SDK contract suite for SDK changes, and import/render the package. For native/runtime changes: run applicable tests and a full Halo Xcode build. Add targeted regression tests for new state/ownership/permission behavior.

Record **pass / fail / not run with reason** for each applicable case:

- Disabled at launch and disabled while active.
- Eligible while closed versus expanded; expected auto-open policy.
- Higher-priority owner blocks it; changing priority transfers ownership.
- Equal priority and equal rank resolve consistently.
- Replaced by another CI; old cleanup/async work cannot change the new owner's size, including equal-size requests.
- Full-surface option toggled while open; one render path and correct background.
- Close/dismiss/retrigger, user pinning and independently opened Halo.
- Permission denial/revocation and action attempted from stale UI.
- Unavailable or rapidly changing context without geometry oscillation.
- Two displays, host removal, sleep/wake and cancellation.
- Settings/profile persistence, keyboard/accessibility and Reduce Motion.
- Existing SDK 0.1 example still validates after public-contract changes.

Before declaring completion, include the filled design record, changed integration symbols, test results and remaining limitations in the feature doc/PR. Never replace missing evidence with “follows Music.” Any deviation from this template must be stated with its reason and verification; it must not violate the canonical SDK architecture.

## Source patterns inspected for this template

- `Halo/Views/SurfaceView.swift`: `ActiveContextInterface`, `builtInContextCandidates`, `activeContext`, ownership switches, expanded/full-surface render branches and central cleanup.
- `ContextMusicView`: `sizingKey`, stable `preferredSurfaceSize`, cancellation and equality-guarded writes.
- Transfer/Clipboard: custom closed presentation, compact dimensions and ownership transitions.
- `Halo/Views/WorkspaceSettingsView.swift`: Music/Clipboard preference keys and Settings structure.
- `Halo/Core/WorkspaceStore.swift`: `HaloCustomCIRuntimeStore` candidate ordering, permissions, dismissal and data bus.
- `SDK/Sources/HaloCISDK/CIContracts.swift`: package validation, context catalog and action authorization.

These implementations provide evidence and reusable patterns; their specialized behavior and older cleanup shortcuts are not requirements for new CIs.
