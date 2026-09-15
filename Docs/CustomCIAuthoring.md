# Building Custom Interfaces for Halo

> **Custom CI author guide — SDK 0.1**
>
> This is the practical guide for people who want to build and share a Halo Custom Interface (`.haloCI`). For the security model, architecture rules, and long-term SDK design, see [`CISDK.md`](CISDK.md). If this guide and `CISDK.md` ever disagree on architecture, `CISDK.md` is authoritative.

Halo Custom Interfaces let a package temporarily own the notch surface and replace its contents with a declarative interface. A Custom CI can have a compact closed state, a richer expanded state, its own size, its own background, live Halo/macOS data bindings, automatic triggers, local state, and brokered actions.

Custom CIs are intentionally **declarative**. You describe the interface in JSON; Halo owns rendering, permissions, actions, notch geometry, animation, lifecycle, and priority arbitration. SDK 0.1 does not execute package JavaScript, Swift, shell scripts, dylibs, Python, or other arbitrary code.

---

## 1. The fastest possible start

Start by copying:

```text
Examples/HelloWorld.haloCI/
```

Rename the directory, change the package `id`, then edit its JSON files.

A normal package looks like this:

```text
MyInterface.haloCI/
├── manifest.json
├── interface.json
├── triggers.json       # optional
└── assets/             # optional local images
```

Then import it from:

```text
Halo Settings
→ Context Notch Interface
→ Custom CI
→ Import .haloCI…
```

SDK 0.1 imports an **unpacked directory whose name ends in `.haloCI`**. A packed ZIP/archive is not automatically extracted yet.

Re-importing a package with the same `id` updates that installed CI instead of creating a second unrelated CI.

---

## 2. Mental model

A Custom CI has four important parts:

1. **Manifest** — identity, permissions, supported states, surface size, and background.
2. **Interface** — the declarative UI tree for closed and expanded states.
3. **Triggers** — optional conditions that make the CI eligible to own the notch.
4. **Halo runtime** — resolves bindings, enforces permissions, arbitrates priority, renders the UI, and performs approved actions.

A package does **not** create its own window. It participates in Halo's existing Context Interface system.

When several CIs could activate at once, Halo resolves ownership by priority. A lower-priority Custom CI does not get to open underneath a higher-priority owner. Halo checks arbitration before evaluating lower-priority Custom CI triggers, so losing packages do not animate or flash briefly before disappearing.

---

# 3. `manifest.json`

Every package requires `manifest.json`.

A complete static-size example:

```json
{
  "schemaVersion": 1,
  "sdkVersion": "0.1",
  "id": "com.example.nowplaying",
  "name": "Now Playing",
  "author": "Example Developer",
  "version": "1.0.0",
  "minimumHaloVersion": "1.0.0",
  "entryInterface": "interface.json",
  "description": "A compact media interface for Halo.",

  "permissions": [
    "Media.ReadState",
    "Media.Control"
  ],

  "capabilities": [
    "AutomaticTriggers",
    "MediaControls",
    "LocalState"
  ],

  "supportedSurfaces": [
    "notch"
  ],

  "supportedStates": [
    "closed",
    "expanded"
  ],

  "surface": {
    "sizing": {
      "mode": "static",
      "closed": {
        "width": 250,
        "height": 40
      },
      "expanded": {
        "width": 560,
        "height": 250
      }
    },

    "background": {
      "closed": {
        "type": "solid",
        "color": "#0C0D10",
        "opacity": 1
      },
      "expanded": {
        "type": "gradient",
        "color": "#0C0D10",
        "secondaryColor": "#161A24",
        "opacity": 1
      }
    }
  }
}
```

## Identity fields

- `schemaVersion`: currently `1`.
- `sdkVersion`: currently `"0.1"`.
- `id`: stable, unique reverse-DNS-style identifier such as `com.example.weather-mini`.
- `name`: human-readable CI name.
- `author`: creator/developer name.
- `version`: semantic version such as `1.2.0`.
- `minimumHaloVersion`: minimum Halo version expected by the package.
- `entryInterface`: normally `interface.json`.
- `description`: short explanation shown to users/developers.

The package ID is its identity. Keep it stable across updates.

---

# 4. Surface contract — every CI must define its size

Every Custom CI must explicitly describe the notch space it wants. This is mandatory because the notch window itself needs to resize to the CI, not merely place differently-sized content inside an unrelated Halo window.

Two sizing modes exist.

## 4.1 Static sizing

Use static sizing when the CI should always take exactly the same dimensions in a state:

```json
"sizing": {
  "mode": "static",
  "closed": {
    "width": 250,
    "height": 40
  },
  "expanded": {
    "width": 560,
    "height": 250
  }
}
```

For `static`, use `width` and `height`.

Current SDK validator bounds are:

| State | Width | Height |
|---|---:|---:|
| Closed | 48–720 | 16–160 |
| Expanded | 160–1100 | 96–820 |

Halo can still enforce physical display safety constraints. On a real notched Mac, the physical camera/notch area is a hard minimum. Display bounds are a hard maximum.

## 4.2 Dynamic sizing

Use dynamic sizing when the declarative content can naturally grow or shrink:

```json
"sizing": {
  "mode": "dynamic",
  "closed": {
    "minWidth": 210,
    "preferredWidth": 280,
    "maxWidth": 420,
    "minHeight": 36,
    "preferredHeight": 40,
    "maxHeight": 72
  },
  "expanded": {
    "minWidth": 420,
    "preferredWidth": 560,
    "maxWidth": 760,
    "minHeight": 180,
    "preferredHeight": 280,
    "maxHeight": 520
  }
}
```

For dynamic sizing, do not use `width` / `height` as the surface rule. Halo measures the declarative render tree and clamps the result to your min/preferred/max bounds.

Keep the ordering valid:

```text
minWidth  <= preferredWidth  <= maxWidth
minHeight <= preferredHeight <= maxHeight
```

### Interface size vs surface size

The `surface.sizing` declaration is the notch/window contract. Width and height fields on interface components only affect the component layout inside that surface.

For a static CI, it is usually easiest to make the root component dimensions match the declared surface dimensions.

---

# 5. Every Custom CI owns its background

The active Custom CI replaces Halo's normal notch background while it owns the surface.

Define both states when you support both states:

```json
"background": {
  "closed": {
    "type": "solid",
    "color": "#090A0D",
    "opacity": 1
  },
  "expanded": {
    "type": "gradient",
    "color": "#090A0D",
    "secondaryColor": "#20273A",
    "opacity": 1
  }
}
```

Current background types:

- `solid`
- `gradient`
- `glass`
- `clear`

Background style fields currently include:

```text
type
color
secondaryColor
opacity
blur
```

Example glass background:

```json
{
  "type": "glass",
  "color": "#111318",
  "opacity": 0.85,
  "blur": 20
}
```

Do not depend on Halo's normal album artwork/background being visible underneath a Custom CI. A Custom CI is a surface owner.

---

# 6. `interface.json`

`interface.json` contains a root component for each visual state.

`expanded` is required. `closed` is optional, although if your manifest advertises `closed`, you should provide it. If you omit a declared closed tree, Halo falls back to a safe package-name presentation.

Example:

```json
{
  "closed": {
    "type": "HStack",
    "width": 250,
    "height": 40,
    "spacing": 8,
    "padding": 7,
    "children": [
      {
        "type": "Icon",
        "systemName": "music.note",
        "width": 15,
        "height": 15,
        "foreground": "accent"
      },
      {
        "type": "Text",
        "text": "{{ media.title }}",
        "style": "caption",
        "lineLimit": 1
      }
    ]
  },

  "expanded": {
    "type": "NotchContainer",
    "width": 560,
    "height": 250,
    "spacing": 12,
    "padding": 18,
    "children": [
      {
        "type": "Text",
        "text": "NOW PLAYING",
        "style": "caption",
        "foreground": "accent"
      },
      {
        "type": "Text",
        "text": "{{ media.title }}",
        "style": "headline",
        "lineLimit": 1
      },
      {
        "type": "Text",
        "text": "{{ media.artist }}",
        "style": "caption",
        "foreground": "secondary",
        "lineLimit": 1
      },
      {
        "type": "HStack",
        "spacing": 8,
        "children": [
          {
            "type": "Button",
            "text": "Previous",
            "systemName": "backward.fill",
            "accessibilityLabel": "Previous track",
            "action": { "id": "media.previous" }
          },
          {
            "type": "Button",
            "text": "Play / Pause",
            "systemName": "playpause.fill",
            "accessibilityLabel": "Play or pause media",
            "action": { "id": "media.playPause" }
          },
          {
            "type": "Button",
            "text": "Next",
            "systemName": "forward.fill",
            "accessibilityLabel": "Next track",
            "action": { "id": "media.next" }
          }
        ]
      },
      {
        "type": "Button",
        "text": "Close",
        "systemName": "xmark",
        "accessibilityLabel": "Close Now Playing CI",
        "action": { "id": "halo.ci.close" }
      }
    ]
  }
}
```

---

# 7. Components available in SDK 0.1

The current renderer supports:

### Basic content

- `Text`
- `Image`
- `Icon`
- `Badge`
- `Divider`
- `Spacer`

### Controls

- `Button`
- `Toggle`
- `Slider`
- `Progress`
- `ProgressRing`

### Layout

- `HStack`
- `VStack`
- `ZStack`
- `Grid`
- `ScrollView`
- `NotchContainer`

### Halo-aware components

- `MediaArtwork`
- `AppIcon`
- `DeviceBattery`
- `SystemMetric`
- `ActivityIndicator`

The public component field set is deliberately bounded:

```text
type
id
text
value
source
systemName
metric
children
action
spacing
padding
width
height
cornerRadius
lineLimit
foreground
background
alignment
axis
columns
accessibilityLabel
stateKey
defaultBool
defaultNumber
minimum
maximum
step
style
```

Unknown SDK 0.1 fields fail validation rather than being forwarded into private SwiftUI/AppKit objects.

## Local images

`Image` can load a package-local image with an asset source:

```json
{
  "type": "Image",
  "source": "asset:assets/logo.png",
  "width": 48,
  "height": 48,
  "cornerRadius": 12
}
```

Keep assets inside the `.haloCI` package. Paths cannot escape the package root.

## Local state

`Toggle` and `Slider` can store isolated state by key:

```json
{
  "type": "Toggle",
  "text": "Show details",
  "stateKey": "showDetails",
  "defaultBool": true,
  "accessibilityLabel": "Show details"
}
```

```json
{
  "type": "Slider",
  "stateKey": "intensity",
  "defaultNumber": 0.5,
  "minimum": 0,
  "maximum": 1,
  "step": 0.05,
  "accessibilityLabel": "Intensity"
}
```

Local state is namespaced by package ID. One CI cannot read another CI's private state.

---

# 8. Live data / context available today

This is the most important distinction for authors:

**Triggers decide when a CI is eligible. Bindings are the live context/data available to the interface after Halo grants the appropriate permission.**

SDK 0.1 does not yet expose a general arbitrary `context.*` object or raw internal Halo service objects. Use the supported data bus keys below.

## Surface context

No permission required:

| Binding | Example value | Meaning |
|---|---|---|
| `{{ halo.surface.state }}` | `closed` / `expanded` | Current Custom CI surface state |
| `{{ halo.surface.isExpanded }}` | `true` / `false` | Whether the notch is expanded |

This is useful when a package wants labels/content that describe the current notch state.

## System context

No package permission currently required:

| Binding | Meaning |
|---|---|
| `{{ system.battery.level }}` | Battery percentage when a battery is available |
| `{{ system.battery.isCharging }}` | Charging state |
| `{{ system.lowPowerMode }}` | Low Power Mode state |
| `{{ system.cpu.usedPercent }}` | Halo's current CPU-used percentage value |
| `{{ system.memory.usedPercent }}` | Current memory-used percentage value |
| `{{ system.storage.usedPercent }}` | Current storage-used percentage value |

## Media context

Requires declaring and granting `Media.ReadState`:

| Binding | Meaning |
|---|---|
| `{{ media.isPlaying }}` | Whether Halo's active media source is playing |
| `{{ media.title }}` | Current title |
| `{{ media.artist }}` | Current artist |
| `{{ media.album }}` | Current album |

For artwork, prefer the `MediaArtwork` component rather than expecting an arbitrary image URL binding.

## Active application context

Requires declaring and granting `Applications.Observe`:

| Binding | Meaning |
|---|---|
| `{{ apps.active.bundleID }}` | Frontmost app bundle identifier |
| `{{ apps.active.name }}` | Frontmost app display name |

### Binding syntax

Bindings are deterministic string interpolation:

```json
{
  "type": "Text",
  "text": "Playing: {{ media.title }}",
  "lineLimit": 1
}
```

SDK 0.1 deliberately does **not** provide arbitrary expressions, JavaScript, reflection, method calls, or `eval` inside bindings.

---

# 9. Triggers available today

`triggers.json` is optional. If you omit it, your package is effectively manual-only and can still be opened from Halo's Custom CI library.

A trigger document has this shape:

```json
{
  "match": "any",
  "triggers": [
    {
      "type": "mediaPlaying",
      "bool": true
    }
  ]
}
```

`match` can be:

- `any` — at least one automatic trigger must match.
- `all` — every automatic trigger must match.

A package can declare at most 32 triggers.

## 9.1 `manual`

```json
{
  "type": "manual"
}
```

`manual` is never treated as an automatic match. Manual activation comes from Halo's explicit **Open** action for that installed CI.

You normally do not need a `triggers.json` at all for a manual-only CI.

## 9.2 `mediaPlaying`

Requires `Media.ReadState`.

Activate while media is playing:

```json
{
  "type": "mediaPlaying",
  "bool": true
}
```

Activate while Halo's media source is not playing:

```json
{
  "type": "mediaPlaying",
  "bool": false
}
```

## 9.3 `activeApplication`

Requires `Applications.Observe`.

```json
{
  "type": "activeApplication",
  "value": "com.apple.dt.Xcode"
}
```

The `value` is the exact bundle identifier of the frontmost application.

Useful examples:

```text
com.apple.dt.Xcode
com.apple.Safari
com.google.Chrome
com.spotify.client
com.apple.Music
```

Do not assume an app's display name is its bundle ID.

## 9.4 `batteryBelow`

```json
{
  "type": "batteryBelow",
  "number": 20
}
```

Matches when the current battery percentage is below the numeric threshold.

## 9.5 `batteryAbove`

```json
{
  "type": "batteryAbove",
  "number": 80
}
```

Matches when battery percentage is above the threshold.

## 9.6 `charging`

Activate while charging:

```json
{
  "type": "charging",
  "bool": true
}
```

Activate while not charging:

```json
{
  "type": "charging",
  "bool": false
}
```

## 9.7 `timeWindow`

Time windows use local minute-of-day values from `0` through `1439`.

For example, 09:00–17:00:

```json
{
  "type": "timeWindow",
  "startMinute": 540,
  "endMinute": 1020
}
```

Calculation:

```text
hour × 60 + minute
```

An overnight window works too. For example, 22:00–06:00:

```json
{
  "type": "timeWindow",
  "startMinute": 1320,
  "endMinute": 360
}
```

When the start and end minute are equal, the current evaluator treats the window as matching the entire day.

---

# 10. Combining triggers

### Media playing OR Xcode active

```json
{
  "match": "any",
  "triggers": [
    {
      "type": "mediaPlaying",
      "bool": true
    },
    {
      "type": "activeApplication",
      "value": "com.apple.dt.Xcode"
    }
  ]
}
```

Manifest permissions for that example:

```json
"permissions": [
  "Media.ReadState",
  "Applications.Observe"
]
```

### Xcode active AND charging AND evening

```json
{
  "match": "all",
  "triggers": [
    {
      "type": "activeApplication",
      "value": "com.apple.dt.Xcode"
    },
    {
      "type": "charging",
      "bool": true
    },
    {
      "type": "timeWindow",
      "startMinute": 1080,
      "endMinute": 1380
    }
  ]
}
```

`1080` is 18:00 and `1380` is 23:00.

---

# 11. Priority and ownership

Installed Custom CIs have a configurable priority in Halo.

Priority is not cosmetic. It decides who is allowed to claim the notch.

The important rule is:

> If a higher-priority CI already owns or claims the notch, a lower-priority Custom CI is not allowed to trigger/open underneath it.

For Custom CIs, Halo sorts eligible packages by configured priority and evaluates them from highest to lowest. Once a package claims the surface, lower-priority packages are not trigger-evaluated for that arbitration pass.

Built-in Halo CIs also participate in the central arbitration system. A higher-priority built-in CI can block a Custom CI.

Manual **Open** does not grant a Custom CI permission to ignore a higher-priority owner. It still respects arbitration.

This prevents:

- two CIs rendering on top of each other;
- a low-priority CI opening for one frame and disappearing;
- background ownership conflicts;
- trigger side effects from CIs that cannot win the surface.

When `halo.ci.close` dismisses an automatically triggered Custom CI, Halo suppresses that CI until its trigger becomes false. This avoids an immediate close/reopen loop.

---

# 12. Permissions

A package must declare sensitive access in `manifest.json`, and the user can grant/revoke it from Halo.

Current SDK 0.1 permissions:

| Permission | Allows |
|---|---|
| `Media.ReadState` | Media bindings, `MediaArtwork`, media trigger state |
| `Media.Control` | Play/pause, next, previous actions |
| `Applications.Observe` | Active-app bindings and trigger |
| `Clipboard.Write` | `clipboard.copy` action |
| `URL.Open` | `url.open` action |

Declaring a permission does not automatically grant it. Halo brokers access at runtime.

A protected trigger with no granted permission evaluates false. A protected binding is not inserted into that CI's data bus until permission is granted.

---

# 13. Capabilities

Supported descriptive capability labels are:

```text
LocalAssets
LocalState
AutomaticTriggers
MediaControls
```

Capabilities describe package behavior. They are **not security permissions** and do not grant authority.

For example, a package that wants to control media still needs:

```json
"permissions": ["Media.Control"]
```

---

# 14. Actions available today

Buttons can ask Halo to perform a bounded action:

```json
{
  "type": "Button",
  "text": "Next",
  "systemName": "forward.fill",
  "accessibilityLabel": "Next track",
  "action": {
    "id": "media.next"
  }
}
```

Current action IDs:

| Action | Required permission | Purpose |
|---|---|---|
| `halo.ci.close` | none | Dismiss this CI |
| `clipboard.copy` | `Clipboard.Write` | Copy a value to the clipboard |
| `url.open` | `URL.Open` | Open approved `http`, `https`, or `mailto` URL after confirmation |
| `media.playPause` | `Media.Control` | Toggle playback |
| `media.next` | `Media.Control` | Next track |
| `media.previous` | `Media.Control` | Previous track |

Example copy button:

```json
{
  "type": "Button",
  "text": "Copy title",
  "systemName": "doc.on.doc",
  "accessibilityLabel": "Copy media title",
  "action": {
    "id": "clipboard.copy",
    "value": "{{ media.title }}"
  }
}
```

Example URL button:

```json
{
  "type": "Button",
  "text": "Open website",
  "systemName": "safari",
  "accessibilityLabel": "Open website",
  "action": {
    "id": "url.open",
    "value": "https://example.com"
  }
}
```

There is no generic `run`, shell, script, AppleScript, process, arbitrary Swift selector, or native plugin action in Custom CI SDK 0.1.

---

# 15. A complete manual-only CI

`manifest.json`:

```json
{
  "schemaVersion": 1,
  "sdkVersion": "0.1",
  "id": "com.example.hellohalo",
  "name": "Hello Halo",
  "author": "Example Developer",
  "version": "1.0.0",
  "minimumHaloVersion": "1.0.0",
  "entryInterface": "interface.json",
  "description": "Minimal Custom CI example.",
  "permissions": [],
  "capabilities": ["LocalState"],
  "supportedSurfaces": ["notch"],
  "supportedStates": ["closed", "expanded"],
  "surface": {
    "sizing": {
      "mode": "static",
      "closed": {
        "width": 240,
        "height": 40
      },
      "expanded": {
        "width": 500,
        "height": 220
      }
    },
    "background": {
      "closed": {
        "type": "solid",
        "color": "#0D0F14",
        "opacity": 1
      },
      "expanded": {
        "type": "gradient",
        "color": "#0D0F14",
        "secondaryColor": "#1E2948",
        "opacity": 1
      }
    }
  }
}
```

`interface.json`:

```json
{
  "closed": {
    "type": "HStack",
    "width": 240,
    "height": 40,
    "spacing": 8,
    "padding": 8,
    "children": [
      {
        "type": "Icon",
        "systemName": "sparkles",
        "width": 15,
        "height": 15,
        "foreground": "accent"
      },
      {
        "type": "Text",
        "text": "Hello Halo",
        "style": "caption",
        "lineLimit": 1
      }
    ]
  },
  "expanded": {
    "type": "NotchContainer",
    "width": 500,
    "height": 220,
    "spacing": 12,
    "padding": 18,
    "children": [
      {
        "type": "Icon",
        "systemName": "checkmark.seal.fill",
        "width": 32,
        "height": 32,
        "foreground": "accent"
      },
      {
        "type": "Text",
        "text": "Your first Custom CI is running.",
        "style": "headline",
        "lineLimit": 1
      },
      {
        "type": "Text",
        "text": "Surface: {{ halo.surface.state }}",
        "style": "caption",
        "foreground": "secondary"
      },
      {
        "type": "Toggle",
        "text": "Remember this preference",
        "stateKey": "example.enabled",
        "defaultBool": true,
        "accessibilityLabel": "Remember example preference"
      },
      {
        "type": "Button",
        "text": "Close",
        "systemName": "xmark.circle.fill",
        "accessibilityLabel": "Close Hello Halo",
        "action": {
          "id": "halo.ci.close"
        }
      }
    ]
  }
}
```

For a manual-only CI, omit `triggers.json`.

---

# 16. Useful CI ideas with today's SDK

Because triggers and bindings can be combined, SDK 0.1 is already enough for CIs such as:

- **Now Playing** — media trigger + title/artist/artwork + playback controls.
- **Xcode Focus CI** — active-app trigger for Xcode, app information, system metrics, local toggles.
- **Low Battery CI** — `batteryBelow` trigger, battery gauge, charging state.
- **Charging Desk CI** — charging + time window, system metrics and shortcuts represented through safe supported actions.
- **Evening Mode CI** — time-window trigger and a specialized visual surface.
- **App-specific control surface** — active app trigger with a custom informational layout.
- **Manual utility panel** — no automatic triggers, opened explicitly from Halo.

---

# 17. What is NOT a Custom CI trigger/context yet

The architecture specification mentions many future contexts. They are **not automatically available just because they appear in the design document**.

SDK 0.1 currently does **not** expose these as Custom CI triggers unless/until the runtime adds them and the SDK version documents them:

- clipboard changed/type;
- Bluetooth connect/disconnect;
- screen recording start/stop;
- file drag/drop context;
- calendar-event proximity;
- timer completion;
- display-count trigger;
- mouse/trackpad gestures;
- arbitrary keyboard shortcuts defined by a package;
- network state;
- microphone/camera activity;
- arbitrary app launch/quit events distinct from frontmost-app matching;
- arbitrary Halo internal events.

Similarly, SDK 0.1 does not provide generic objects such as:

```text
context.payload
workspace.*
AppStore
WorkspaceStore
NSWorkspace
SwiftUI environment objects
```

If a future Halo release adds one of these capabilities, it should become an explicit versioned public SDK feature rather than something packages infer from private implementation details.

---

# 18. Validation rules worth knowing

Halo validates a package before installation and again after staging.

Important current limits include:

- maximum package size: 10 MB;
- maximum files: 128;
- maximum JSON file size: 512 KB;
- maximum component count: 180;
- maximum component-tree depth: 16;
- maximum triggers: 32;
- only the `notch` surface is supported in SDK 0.1;
- `expanded` state is required;
- unknown SDK/schema fields fail closed;
- package paths cannot escape the package root;
- symbolic links/path traversal are rejected;
- executable/script content is rejected;
- unsupported actions, bindings, permissions, capabilities and triggers are rejected;
- interactive controls should have accessibility labels.

Executable extensions such as JavaScript, Swift, shell scripts, Python, dylibs and similar code are intentionally rejected from Custom CI packages in SDK 0.1.

---

# 19. Debugging checklist

If a package imports but does not appear:

1. Make sure **Disable custom CI** is off.
2. Make sure the individual package is enabled.
3. Check the package's configured priority.
4. Check whether a higher-priority built-in or Custom CI owns the notch.
5. Check required permissions are declared **and granted**.
6. Check the automatic trigger is actually true.
7. Try the package's **Open** button to test rendering independently of automatic triggers.

If import fails:

1. Validate JSON commas/braces.
2. Confirm `schemaVersion: 1` and `sdkVersion: "0.1"`.
3. Confirm the folder itself ends in `.haloCI`.
4. Confirm `surface.sizing` and `surface.background` exist.
5. Confirm every protected binding/action/trigger has its permission declared in the manifest.
6. Remove unknown component/manifest fields.
7. Keep assets inside the package directory.

If the CI is the wrong size:

- For static sizing, inspect `manifest.json → surface.sizing`, not only root component dimensions.
- For dynamic sizing, inspect min/preferred/max bounds.
- Remember the physical notch can impose a larger minimum on notched Macs.

If the UI appears but media/app values are empty:

- declare the appropriate permission in the manifest;
- grant it on the installed CI's card in Halo Settings.

---

# 20. Updating and sharing a CI

To publish an update:

1. Keep the same package `id`.
2. Increment `version`.
3. Make your declarative changes.
4. Re-import the `.haloCI` directory.

For another user, share the complete `.haloCI` directory, including its JSON and local assets.

Do not instruct users to copy package files directly into Halo's Application Support directories. Use the Import flow so Halo can validate and stage the package.

---

# 21. Security model in one paragraph

A Custom CI is untrusted declarative input. Halo validates the package, owns the renderer, exposes only versioned data keys, checks permissions, brokers a small action catalog, keeps local state namespaced, and resolves notch ownership centrally. A package cannot obtain broader access by naming a private Swift type or adding a script file. This boundary is intentional: Custom CIs should be powerful without turning a theme/interface package into arbitrary code running inside Halo.

---

# 22. Source-of-truth files for contributors

If you are modifying Halo itself rather than merely authoring a package, read these before changing Custom CI behavior:

```text
AGENTS.md
Docs/CISDK.md
Docs/Architecture.md
Docs/Plugins.md
```

The working sample package is:

```text
Examples/HelloWorld.haloCI/
```

The implementation's public SDK registries and validator live with the Custom CI models; runtime eligibility/state/permissions live in the Custom CI runtime store; the surface renderer and background ownership are Halo-owned in the surface layer.

When adding a new public trigger, binding, component, action, permission, or manifest field, update `Docs/CISDK.md` and this guide in the same change.

---

## Quick reference

### Triggers

```text
manual
mediaPlaying
activeApplication
batteryBelow
batteryAbove
charging
timeWindow
```

### Live context / bindings

```text
halo.surface.state
halo.surface.isExpanded
system.battery.level
system.battery.isCharging
system.lowPowerMode
system.cpu.usedPercent
system.memory.usedPercent
system.storage.usedPercent
media.isPlaying
media.title
media.artist
media.album
apps.active.bundleID
apps.active.name
```

### Permissions

```text
Media.ReadState
Media.Control
Applications.Observe
Clipboard.Write
URL.Open
```

### Actions

```text
halo.ci.close
clipboard.copy
url.open
media.playPause
media.next
media.previous
```

### Backgrounds

```text
solid
gradient
glass
clear
```

### Components

```text
Text
Image
Icon
Button
Toggle
Slider
Progress
ProgressRing
Spacer
Divider
HStack
VStack
ZStack
Grid
ScrollView
Badge
NotchContainer
MediaArtwork
AppIcon
DeviceBattery
SystemMetric
ActivityIndicator
```

That is the implemented SDK 0.1 authoring surface. If it is not listed here, do not assume it is available to third-party Custom CIs yet.
