# Pixel Pal v2 — Canonical Rebuild Specification

> **Status:** Authoritative product and implementation direction for Pixel Pal.
>
> **Scope:** Halo's built-in Pixel Pal widget only. This document does not define the public CI SDK.

## 1. Product definition

Pixel Pal is a premium, face-first pixel character that lives inside Halo. It should feel like a deliberately art-directed micro-character: cute, polished, expressive, animated, reactive, and highly customizable.

Pixel Pal is **not** a Tamagotchi, room simulator, habitat, dashboard, pet-care game, or generic retro terminal face.

The target feeling is a tiny living pixel companion whose personality is communicated almost entirely through facial expression, accessories, and animation.

### Core rule

> **Pixel Pal must be a premium, face-first pixel character: highly expressive, beautifully animated, space-filling, customizable, and cute — never a crude geometric gimmick, never a full pet simulator, and never cluttered with unnecessary UI.**

## 2. Non-negotiable design principles

### 2.1 Face-first

The face is the character. Pixel Pal should not gain a body, room, furniture, hunger, energy, care loops, inventory, habitat management, or other pet-game mechanics.

Personality should come from:

- eyes
- eye highlights
- eyebrows
- mouth
- blush / cheeks
- tears / sweat / hearts / sparkles
- small accessories
- expression transitions
- micro-animations

### 2.2 Pixel art, not crude procedural geometry

The current generation must not be treated as a reason to keep ultra-simple block geometry. Pixel Pal v2 should use intentional pixel-art construction with curated sprite components and consistent proportions.

A procedural renderer may still draw the final pixels, but the **art source of truth must be authored sprite data**, not ad-hoc rectangles assembled differently for every expression.

### 2.3 High quality over artificial minimalism

Pixel Pal may be simple, but it must not look cheap. Increase internal logical resolution when needed to support attractive eyes, brows, mouths, accessories, highlights, and animation.

### 2.4 Fill the square

The face should occupy most of its square canvas in normal states.

- target normal face occupancy: roughly 80–95% of the available square
- brief animation overshoot or extra breathing room is allowed
- do not leave a tiny face floating in unused space
- larger sizes improve fidelity and animation staging rather than adding UI clutter

### 2.5 Square-only footprints

Supported footprints are:

- `1×1`
- `2×2`
- `3×3`
- `4×4`

Rectangular Pixel Pal footprints are invalid. If old persisted layout data contains a rectangular footprint, normalize it to the nearest supported square.

## 3. Visual direction

Pixel Pal should read as high-quality kawaii pixel art rather than a diagnostic display.

Desired qualities:

- glossy or expressive pixel eyes
- clean, deliberate silhouettes
- balanced spacing and proportions
- readable mouths and brows
- attractive blush / cheek treatment
- tasteful pastel, monochrome, retro, or custom palettes
- small, polished accessories
- crisp integer-aligned pixels
- strong expression readability at a glance

Avoid:

- harsh terminal-only aesthetics as the default
- tiny symbolic faces made from only a few arbitrary blocks
- random pixel placement
- excessive empty space
- excessive effects
- vector-like anti-aliased art pretending to be pixel art

Reference images may inspire the design principle and expression vocabulary, but do not copy third-party artwork or sprite layouts.

## 4. Logical resolution and scaling

### 4.1 Canonical sprite grid

Start with a **16×16 logical pixel face grid** as the canonical v2 art resolution.

If the art still cannot achieve the intended quality, increasing to **20×20 or 24×24** is explicitly allowed. The goal is polished pixel art, not preserving an arbitrary low pixel count.

### 4.2 Rendering rules

- render using integer-aligned logical pixels
- prefer integer scaling when practical
- never blur the sprite to fake smoothness
- scale the authored sprite as a coherent face
- center the face, then allow animation transforms around that center
- preserve hard pixel edges
- the face should remain recognizable at every supported size

### 4.3 Size behavior

#### 1×1

- full-quality face identity
- almost the entire square is used
- accessories may simplify if necessary
- expressions must remain attractive and readable
- this must be a first-class size, not a compromised fallback

#### 2×2

- same core face identity
- additional room for accessory silhouettes and reaction effects
- recommended everyday size

#### 3×3

- additional staging room for bounce, squash, hearts, notes, sparkles, tears, or contextual effects
- do not add dashboards, rooms, or body scenes

#### 4×4

- maximum expression and animation fidelity
- richer reaction choreography is allowed
- still a face-first widget

## 5. Layered sprite architecture

The visual system should be composed from reusable pixel-art layers.

Required conceptual layers:

1. base face / silhouette
2. eyes
3. eye highlights / catchlights
4. eyebrows
5. mouth
6. cheeks / blush
7. expression overlay
8. accessory
9. transient FX overlay

Each layer should be independently replaceable and themeable where appropriate.

### 5.1 Recommended sprite representation

Prefer declarative Swift sprite maps or another deterministic data format that can be version controlled.

Example direction:

```swift
struct PixelPalSprite {
    let width: Int
    let height: Int
    let pixels: [PixelPalSpritePixel]
}

struct PixelPalSpritePixel {
    let x: Int
    let y: Int
    let role: PixelPalColorRole
    let alpha: Double
}
```

The renderer can then draw those pixels through `Canvas`, but facial art remains authored data instead of one-off geometry code.

Useful color roles include:

- `.primary`
- `.secondary`
- `.accent`
- `.highlight`
- `.blush`
- `.shadow`
- `.white`
- `.background`

## 6. Face styles

Face styles should change actual shape language, not merely rename a palette.

Minimum styles:

### Soft

Default. Rounded, cute, friendly, compatible with glossy eyes and blush.

### Minimal

Cleaner and calmer, with reduced embellishment while remaining attractive.

### Robot

More angular / screen-like proportions and strong compatibility with digital eyes.

### Cat

Subtle cat-inspired top silhouette / ear implication and compatible mouth options. The face remains the primary object.

Potential future styles:

- Ghost
- Arcade
- Pastel mascot
- Angel
- Mischief / demon-cute

## 7. Eye system

Eye selection must visibly change the face. Variants that differ by only one inconsequential pixel are not acceptable.

Required initial styles:

### Classic

Balanced, readable default pixel eyes.

### Glossy

Large cute eyes with deliberate catchlights and optional accent/shadow pixels. This should be a premium-looking default alternative.

### Dot

Small, intentionally minimal eyes.

### Wide

Wider eye geometry for a more cartoony expression language.

### Digital

Segmented / display-like geometry, especially suitable for Robot.

### Sparkle

Star/cross-like expressive construction for magical or excited states.

Potential additions:

- Sleepy
- Chibi / big-eye
- Anime-inspired pixel eye
- Hollow

### Expression compatibility

Eye style must remain meaningful across expressions. Happy, sleepy, wink, bored, confused, worried, focused, and other expressions must not silently bypass the selected eye style unless the expression explicitly requires a special eye sprite such as hearts.

## 8. Mouth system

Initial mouth modes:

- `Automatic` / Expression
- `None`
- `Tiny`
- `Smile`
- `Flat`

Recommended additional authored mouths:

- open happy
- rounded `o`
- cat smile
- worried curve
- wavy uneasy
- tongue-out
- sleepy
- smug

`Automatic` should choose the authored mouth best suited to the active expression.

## 9. Eyebrows, cheeks, and overlays

### Eyebrows

Support authored brow states such as:

- none
- raised
- worried
- serious
- annoyed
- mischievous
- sleepy

### Cheeks

Support:

- none
- soft blush
- stronger kawaii blush
- shy blush

### Expression overlays

Support lightweight pixel overlays such as:

- tears
- sweat drop
- hearts
- sparkles
- music notes
- shock lines
- exclamation
- sleep `z`

Overlays must remain subordinate to the face.

## 10. Accessory system

Accessories are a first-class v2 feature. They should be small, polished, and attached to the face composition without turning Pixel Pal into a body-based character.

Initial accessory set:

- none
- bow
- cat ears
- glasses
- shades
- headphones
- halo
- horns
- flower
- sleeping cap
- crown
- sprout
- small bandage

Accessory modes:

- Off
- Manual
- Contextual
- Random from allowed set

### Contextual examples

- music → headphones
- Xcode / coding → glasses
- night / sleepy → sleeping cap
- mischievous → horns
- cute / happy rare reaction → flower, bow, sprout, or halo
- game / cool reaction → shades

Contextual accessories should be optional and separately configurable.

## 11. Expression library

Required v2 expressions:

- neutral
- blink
- happy
- superHappy
- excited
- love
- sleepy
- bored
- focused
- surprised
- confused
- worried
- sad
- crying
- shy
- mischievous
- smug
- annoyed
- wink
- shocked

Potential later expressions:

- dizzy
- panic
- sneeze
- yawn
- proud
- curious

### Expression definition

Each expression should resolve through a definition rather than through one enormous rendering switch.

```swift
struct PixelPalExpressionDefinition {
    let id: PixelPalExpression
    let eyeSprite: PixelPalSpriteID
    let browSprite: PixelPalSpriteID?
    let mouthSprite: PixelPalSpriteID?
    let cheekStyle: PixelPalCheekStyle
    let overlay: PixelPalOverlay?
    let accessoryOverride: PixelPalAccessory?
    let idleAnimation: PixelPalIdleAnimation
    let transitionStyle: PixelPalTransitionStyle
}
```

Special expressions such as love or crying may intentionally override normal eye or overlay selection.

## 12. Animation system

Pixel Pal must feel alive without becoming visually noisy.

### 12.1 Idle animations

Required initial idle animation vocabulary:

- normal blink
- slow blink
- glance left
- glance right
- tiny bounce
- tiny sway
- micro bob
- soft squash
- cheek pulse
- eye shimmer / highlight shift
- sleepy droop

Idle animations should be low-amplitude and occur at tasteful intervals.

### 12.2 Direct interaction animations

#### Hover

Possible behavior:

- eyes subtly track pointer
- eyes brighten / perk
- small smile
- tiny face movement toward cursor

#### Click

Default reaction pool:

- blink-pop
- happy bounce
- small squash-and-release
- blush pop
- sparkle

#### Double click

Default behavior:

- love / super-happy expression
- small heart burst
- two-step bounce

#### Long press

Default behavior:

- sleepy / shy reaction
- soft squish-hold
- optional later quick-action menu

### 12.3 Context reactions

#### Charging

- happy or love expression
- gentle pulse / bounce
- optional heart overlay

#### Low battery

- worried / sleepy expression
- droop or tiny wobble
- optional sweat / tear

#### Music

- rhythmic bob / bounce
- happy or excited eyes
- optional note overlay
- optional headphones in Contextual accessory mode

#### Timer finished

- surprised / excited pop
- alert bounce
- optional exclamation overlay

#### Notification, if/when Halo exposes reliable notification context

- quick perk / glance
- alert blink

Do not fake a notification signal if Halo does not have one.

#### Idle / away

- bored side glance
- yawn / sleepy blink
- low-frequency ambient reaction

#### User returns

- perk up
- sparkle blink
- short happy bounce

#### Night

- sleepy expression
- slower blink
- optional sleeping cap

#### Morning

- wake-up blink sequence
- small squash / stretch illusion
- happy settle

#### Xcode

- focused expression
- optional glasses

#### Game detected

- excited expression
- optional shades
- slightly more energetic bounce

### 12.4 Surface power transitions

When the host Halo surface opens or closes, Pixel Pal should behave like a tiny LED display rather than continuing its full idle renderer through the geometry animation.

- opening: all Pixel Pal LEDs, including inactive/background LEDs, remain dark while the notch is resizing; once the surface settles, run a short boot-up sequence before restoring the live face
- closing: run a brief lightweight shutdown sequence that collapses the face toward a center scanline, then leave every LED dark for the rest of the retraction
- the normal 24 Hz face/context renderer must not run while the display is powered off or performing the lightweight power transition
- boot effects should be crisp, pixel-aligned, and visually subordinate to the face
- users can independently choose boot-up and boot-down styles; initial styles are Scanline, Pixel Cascade, Core Pulse, Sparkle Burst, and None
- users can adjust power-animation speed without changing normal idle/reaction animation speed
- boot-up must complete before the live Pixel Pal face is shown
- boot-down must complete before the Halo panel begins its physical closing/retraction animation
- opening and closing are interruptible: reopening during shutdown cancels the delayed collapse and starts a fresh boot-up sequence
- Reduce Motion should replace scanline/sweep motion with a simple eye fade

## 13. Animation choreography and timing

Animation should be authored as named behaviors instead of scattered `Date()` modulo calculations.

Each reaction should define:

- enter duration
- hold duration
- exit duration
- optional cooldown
- motion amplitude
- optional overlay timing
- priority

Recommended conceptual runtime request:

```swift
struct PixelPalAnimationRequest {
    let trigger: PixelPalTrigger
    let expression: PixelPalExpression
    let accessoryOverride: PixelPalAccessory?
    let overlay: PixelPalOverlay?
    let duration: TimeInterval
    let priority: Int
}
```

Transitions may use pixel-art-friendly squash, pop, bounce, blink, and frame swaps. Avoid smooth vector morphing that destroys the pixel-art character.

## 14. Runtime state and priority

Pixel Pal should use a clear state machine so competing reactions do not fight each other.

Priority from highest to lowest:

1. explicit/manual temporary preview or user-triggered override
2. direct interaction reaction
3. high-priority context event, e.g. timer completed or low battery
4. active contextual state, e.g. music, charging, Xcode, game
5. hover / pointer tracking
6. ambient idle animation
7. neutral

Suggested runtime state:

```swift
struct PixelPalRuntimeState {
    var currentExpression: PixelPalExpression
    var currentAccessory: PixelPalAccessory?
    var activeOverlay: PixelPalOverlay?
    var animationPhase: PixelPalAnimationPhase
    var hoverAmount: Double
    var pointerOffset: CGPoint
    var lastTrigger: PixelPalTrigger?
    var lastInteractionDate: Date
}
```

Avoid unrestricted random state changes. Random cute behavior should be low-frequency, bounded, and subject to cooldown.

## 15. Preferences model

The v2 preferences schema should support at least the following concepts:

```swift
struct PixelPalPreferences: Codable, Equatable {
    var version: Int

    // Appearance
    var theme: PixelPalThemeID
    var faceStyle: PixelPalFaceStyle
    var eyeStyle: PixelPalEyeStyle
    var mouthStyle: PixelPalMouthStyle
    var cheekStyle: PixelPalCheekStyle
    var accessoryMode: PixelPalAccessoryMode
    var selectedAccessory: PixelPalAccessory?
    var allowedAccessories: Set<PixelPalAccessory>

    // Color
    var paletteMode: PixelPalPaletteMode
    var primaryColor: PixelPalColor
    var secondaryColor: PixelPalColor
    var accentColor: PixelPalColor
    var blushColor: PixelPalColor
    var backgroundStyle: PixelPalBackgroundStyle
    var backgroundColor: PixelPalColor
    var glowIntensity: Double

    // Layout
    var faceScale: Double
    var pixelSpacing: Double

    // Motion
    var animationSpeed: Double
    var animationIntensity: Double
    var respectReduceMotion: Bool
    var automaticBlinking: Bool

    // Direct interaction
    var hoverReactionEnabled: Bool
    var clickReactionEnabled: Bool
    var doubleClickReactionEnabled: Bool
    var longPressReactionEnabled: Bool
    var cursorTrackingEnabled: Bool

    // Context reactions
    var contextReactionsEnabled: Bool
    var chargingReactionEnabled: Bool
    var lowBatteryReactionEnabled: Bool
    var musicReactionEnabled: Bool
    var timerReactionEnabled: Bool
    var appReactionEnabled: Bool
    var idleReactionEnabled: Bool
    var nightReactionEnabled: Bool

    // Personality
    var personalityLevel: PixelPalPersonalityLevel
    var randomExpressionFrequency: Double
}
```

The exact type names may adapt to the existing Halo codebase, but preserve the feature separation above.

## 16. Settings UI

Visual features must be selected visually where practical.

### 16.1 Preview

Provide a large live preview containing:

- current expression
- current accessory
- current palette
- live animation preview

The preview should be large enough to judge sprite quality.

### 16.2 Appearance

Controls:

- face style
- eye style
- mouth style
- cheek style
- palette / theme
- primary color
- accent color
- blush color
- background style
- background color where relevant
- glow
- face scale
- LED shape (Square, Circle, Triangle, Diamond, Star, Hexagon, Cross)
- pixel spacing

### 16.3 Eye / mouth / face selectors

Use clickable visual tiles with mini-previews. Do not require users to infer visual differences from text-only menus.

### 16.4 Accessories

Controls:

- mode: Off / Manual / Contextual / Random Allowed
- manual accessory
- allowed accessory set
- contextual accessories toggle

### 16.5 Interactions

Controls:

- hover reaction
- click reaction
- double-click reaction
- long-press reaction
- cursor tracking
- animation intensity

### 16.6 Context reactions

Controls:

- master enable
- charging
- low battery
- music
- timer
- app-specific reactions
- idle / away
- night

Only expose contexts that Halo genuinely implements.

### 16.7 Animation

Controls:

- speed
- intensity
- automatic blinking
- respect Reduce Motion
- personality / activity level

### 16.8 Expression preview

Allow manual preview of every built-in expression and key animation without permanently changing the runtime state.

## 17. Default preset

Recommended default configuration:

- Pixel spacing: `1 px`
- Face style: `Soft`
- Eye style: `Glossy`
- Mouth style: `Automatic`
- Cheeks: soft blush
- Accessory mode: `Contextual`
- Default manual accessory: none
- Background: transparent or black depending on Halo surface
- Face scale: approximately `0.92...0.96` if accessories need headroom; otherwise maximize safely
- Animation speed: `1.0`
- Animation intensity: medium
- Context reactions: enabled
- Cursor tracking: enabled
- Respect Reduce Motion: enabled

The default must look premium before the user changes any setting.

## 18. Migration

Pixel Pal v2 must decode older preferences safely.

Preserve when possible:

- palette / custom colors
- background style
- face scale
- animation speed
- context toggles
- direct interaction toggles

Map old style values to sensible v2 defaults when they do not have a direct equivalent.

Recommended fallbacks:

- unknown face style → `Soft`
- unknown eye style → `Glossy` or `Classic`
- unknown mouth style → `Automatic`
- unknown accessory → none

Never crash due to old persisted enum values. Version the schema deliberately.

## 19. Implementation architecture

The current `Halo/Views/PixelPetWidget.swift` implementation should be treated as the legacy implementation, not as the architectural constraint for v2.

The v2 implementation should be split into focused responsibilities instead of growing a single monolithic view file indefinitely.

Recommended direction:

- `PixelPalModels.swift` — enums, preferences, runtime state
- `PixelPalSprites.swift` — authored pixel component definitions
- `PixelPalExpressions.swift` — expression definitions / component composition
- `PixelPalRenderer.swift` — pixel rendering pipeline
- `PixelPalAnimationController.swift` — reaction scheduling and state transitions
- `PixelPalContextResolver.swift` — battery/media/timer/app/idle context mapping
- `PixelPalWidget.swift` — SwiftUI host and input gestures
- `PixelPalSettingsView.swift` — customization UI

Exact filenames can adapt to repository conventions, but keep these responsibilities separate.

## 20. Rendering pipeline

Recommended order:

1. resolve runtime trigger / expression
2. resolve theme and colors
3. resolve face style
4. resolve expression definition
5. resolve accessory
6. resolve overlay / FX
7. calculate logical sprite scale and placement
8. render background
9. render base face
10. render eyes
11. render highlights
12. render brows
13. render mouth
14. render cheeks
15. render accessory
16. render transient overlay / FX
17. apply animation transform / frame state

Do not anti-alias the pixel art itself.

## 21. Performance requirements

Pixel Pal must remain cheap enough to be always-on inside Halo.

Rules:

- no heavy particle systems
- no per-frame object churn where avoidable
- no expensive blur chains every frame
- cache authored sprite data
- use simple transforms for bounce / squash / sway
- reduce animation cadence when nothing is changing
- avoid waking the app at high frame rates for a static neutral face
- preserve integer pixel alignment

The widget should have negligible idle CPU cost and should not compromise Halo's 120 Hz surface responsiveness.

## 22. Accessibility

Respect macOS Reduce Motion by default.

Under Reduce Motion:

- reduce bounce and squash amplitudes
- remove flashy bursts where appropriate
- keep readable expression changes and blinking
- keep context information understandable without motion

Provide high-contrast themes such as white-on-black and retro green-on-black.

## 23. Implementation phases

### Phase 1 — Art and renderer foundation

- introduce sprite-layer architecture
- establish 16×16 canonical grid, increasing only if quality demands it
- build Soft face style
- build Glossy and Classic eyes
- build core mouths, brows, cheeks
- implement neutral, happy, love, sleepy, worried, surprised, confused, focused, bored
- enforce square-only footprints
- make the face fill the canvas attractively

### Phase 2 — Animation quality

- introduce animation controller / state machine
- blink and glance
- click / double-click / hover reactions
- bounce / squash / shimmer
- timer / charging / battery / music reactions
- Reduce Motion behavior

### Phase 3 — Customization and personality

- full eye library
- expanded mouth library
- accessory system
- contextual accessory rules
- full settings visual galleries
- expression preview tools

### Phase 4 — Polish

- timing refinement
- art cleanup at every supported square size
- rare tasteful reactions
- performance optimization
- migration tests
- regression tests

## 24. Tests and validation

Add automated coverage for:

- preference migration from existing Pixel Pal versions
- unknown / old enum fallback behavior
- square-only footprint normalization
- expression priority
- context priority
- interaction cooldowns
- Reduce Motion behavior where testable
- every registered expression resolves to valid sprite components
- every registered accessory resolves to valid sprite components
- no sprite pixel lies outside its declared logical bounds
- renderer accepts every supported combination of face style / eye style / mouth style / accessory

For implementation changes, run the repository's normal Swift tests where applicable and a full Halo Xcode build before considering the work complete.

## 25. Acceptance criteria

Pixel Pal v2 is not complete until all of the following are true.

### Visual

- the default face looks intentionally designed and premium
- it does not resemble a developer placeholder or novelty gimmick
- glossy eyes, mouth, brows, cheeks, and highlights form a cohesive style
- eye styles are immediately distinguishable
- accessories look authored rather than bolted on
- 1×1 is attractive and fully usable

### Animation

- neutral idle feels alive without being distracting
- click, hover, double-click, and long-press have polished reactions
- charging, battery, music, timer, app, idle, and night reactions are readable and cute
- competing reactions do not fight or flicker

### Customization

- face appearance is meaningfully customizable
- visual selectors show what eye / face / accessory choices actually look like
- user can disable unwanted interactions or context reactions
- settings persist safely

### Architecture

- sprite art is authored as reusable data
- expression composition is data-driven
- animation priority is centralized
- context resolution is separated from rendering
- the view is not one giant switch-based renderer
- old preference data does not break startup

### Performance

- static idle does not require unnecessary high-frequency updates
- pixel edges remain crisp
- Halo remains responsive

## 26. Explicit anti-goals

Do not reintroduce:

- rooms
- furniture
- habitat scenes
- hunger / energy / feeding loops
- inventory
- body walking around a room
- status cards
- dashboard text inside Pixel Pal
- fake complexity solely to justify larger widget sizes

Do not accept a visually crude result merely because it is technically pixelated.

## 27. Guidance for AI coding agents

Before modifying Pixel Pal:

1. read this file in full
2. inspect the current implementation and call sites
3. preserve Halo's existing module / workspace ownership model
4. do not invent a duplicate module system
5. migrate old preferences safely
6. keep square-only footprints
7. keep the feature face-first
8. validate visual settings through actual renderer paths
9. add tests for new state / migration logic
10. complete a full Halo Xcode build before claiming the implementation is finished

When an implementation shortcut conflicts with this document, prefer this document unless the user explicitly changes the product direction.


## 28. September 2026 sizing and LED polish

- Restore all four square footprints in validation, packing and the workspace size menu.
  Legacy rectangles normalize to the nearest square (ties choose the smaller square);
  narrow workspaces cap the result to the available columns. Existing 4×4 placements stay 4×4.
- The widget bypasses card padding and title chrome. The 24×24 LED display fills the
  largest square inside its actual cell, preserving the user's optional Face fill setting.
  Each LED edge is snapped independently to backing pixels, so fractional scaling cannot
  shrink the entire display to the previous integer multiple.
- LED geometry is user-selectable. Initial shapes are Square, Circle, Triangle, Diamond,
  Star, Hexagon and Cross. The same LED primitive must be used by active face pixels,
  inactive LEDs, power animations, and Pixel Pal's cookie pixels/crumbs so the display
  reads as one coherent piece of hardware.
- A stationary, dim palette-tinted LED matrix sits beneath the lit sprite. Lit LEDs share
  the exact same grid, with crisp edges and a one-backing-pixel gap where space permits.
- Direct reactions use a trigger-relative bounce that settles; hover tracks locally per
  widget and cannot override active context alerts. Exclusive gestures distinguish clicks,
  double-clicks and long presses. Reduce Motion freezes travel and FX while retaining blinks.
- Composition bounds include accessories and FX before applying movement, preventing
  clipped caps, ears and hearts. Settings use a live animation preview.
- Validation: square persistence, rectangle/narrow-grid normalization, backing-pixel geometry,
  and reaction timing regression tests; full macOS build/test in Validate Pixel Pal.


## 21. Personality micro-behaviour engine

Pixel Pal may use bounded, transient personality behaviours that strengthen the feeling of a tiny living companion without becoming a pet-care game.

Allowed examples include:

- an always-available optional cookie interaction with short eating/satisfaction choreography
- different immediate reactions to repeated treats, including temporary "full" refusal
- crumbs, licking / satisfied faces, and brief post-treat happiness
- cursor petting, poking, edge peeking, and occasional cursor chasing / avoidance
- drag-over curiosity for files, represented with a tiny file glyph or face reaction
- low-frequency sneeze, hiccup, curiosity, rare encounter, seasonal, wake-up, sleep and dream beats
- timer anticipation, charging / low-battery escalation, app-aware expressions, and audio-energy-reactive dancing
- short-lived affection / irritation bias that decays automatically
- personality presets that only tune reaction probabilities and tone

These systems must remain face-first, transient and low-pressure. They must not add hunger, energy, rooms, inventory management, care obligations, punishment for absence, or persistent chores.
