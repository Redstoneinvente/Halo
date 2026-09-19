# Halo Custom CI Authoring Guide

> **Custom CI V2 is implemented as SDK 0.2 / schema 1**, with SDK 0.1 compatibility. See [the V2 framework guide](CustomCI_V2.md) for the shared context catalog, new bindings/permissions/triggers, CLI starter and validator, tests and extension workflow. Earlier 0.1 examples below remain valid unless marked conceptual. The V2 guide defines the additive implemented contract.

This is the practical, copy-first guide for building third-party **Custom CIs** for Halo.

If you only want to make a CI, start here. If you are changing the SDK/runtime itself, also read `Docs/CISDK.md`, `Docs/Architecture.md`, `Docs/Plugins.md`, and `AGENTS.md`.

> Current public contract: **Halo CI SDK 0.1 / schema 1**.
>
> Custom CIs are **declarative**. They do not run arbitrary Swift, JavaScript, shell commands, dylibs, or downloaded native code inside Halo. Halo owns rendering, lifecycle, permissions, actions, sizing, backgrounds, and surface arbitration.

---

## 1. What a Custom CI is

A Custom CI is a `.haloCI` directory that describes:

- what the notch looks like when **closed**;
- what it looks like when **expanded**;
- how large the notch is allowed to become;
- the CI's own background;
- optional automatic triggers;
- safe bindings to Halo/macOS state;
- safe brokered actions;
- isolated local toggle/slider state.

A minimal package looks like this:

```text
MyCI.haloCI/
├── manifest.json
├── interface.json
└── triggers.json        # optional
```

You can also include validated local image assets:

```text
MyCI.haloCI/
├── manifest.json
├── interface.json
├── triggers.json
└── assets/
    └── icon.png
```

The package must remain a directory with the `.haloCI` suffix for SDK 0.1.

---

## 2. Fastest possible starter

Create a folder called `HelloCustom.haloCI`.

### `manifest.json`

```json
{
  "schemaVersion": 1,
  "sdkVersion": "0.1",
  "id": "com.example.hello-custom",
  "name": "Hello Custom",
  "author": "Your Name",
  "version": "1.0.0",
  "minimumHaloVersion": "1.0.0",
  "entryInterface": "interface.json",
  "description": "A tiny example Custom CI.",
  "permissions": [],
  "capabilities": ["LocalState"],
  "supportedSurfaces": ["notch"],
  "supportedStates": ["closed", "expanded"],
  "surface": {
    "sizing": {
      "mode": "static",
      "closed": { "width": 250, "height": 40 },
      "expanded": { "width": 500, "height": 220 }
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
        "secondaryColor": "#182033",
        "opacity": 1
      }
    }
  }
}
```

### `interface.json`

```json
{
  "closed": {
    "type": "HStack",
    "spacing": 7,
    "padding": 7,
    "children": [
      {
        "type": "Icon",
        "systemName": "sparkles",
        "width": 14,
        "height": 14,
        "foreground": "accent"
      },
      {
        "type": "Text",
        "text": "Hello from Custom CI",
        "style": "caption",
        "lineLimit": 1
      }
    ]
  },
  "expanded": {
    "type": "NotchContainer",
    "spacing": 12,
    "padding": 18,
    "children": [
      {
        "type": "Text",
        "text": "HELLO CUSTOM CI",
        "style": "caption",
        "foreground": "accent"
      },
      {
        "type": "Text",
        "text": "Your CI is running inside Halo.",
        "style": "headline"
      },
      {
        "type": "Toggle",
        "text": "Example local setting",
        "stateKey": "example.enabled",
        "defaultBool": true,
        "accessibilityLabel": "Example local setting"
      },
      {
        "type": "Button",
        "text": "Close CI",
        "systemName": "xmark",
        "accessibilityLabel": "Close Custom CI",
        "action": { "id": "halo.ci.close" }
      }
    ]
  }
}
```

Then import the directory from:

**Halo Settings → Context Notch Interface → Custom CI → Import .haloCI…**

Once installed, Halo shows the CI in the dedicated Custom CI library. It can be enabled/disabled, assigned a priority, granted/revoked permissions, opened manually, reloaded, or removed.

---

## 3. Surface contract: size is mandatory

Every Custom CI owns a real notch surface and therefore **must declare sizing**.

Halo will reject a package that does not provide `manifest.surface.sizing`.

### Static sizing

Use this when your layout has a known fixed size:

```json
"sizing": {
  "mode": "static",
  "closed": {
    "width": 250,
    "height": 40
  },
  "expanded": {
    "width": 560,
    "height": 260
  }
}
```

Supported ranges:

| State | Width | Height |
|---|---:|---:|
| closed | 48–720 | 16–160 |
| expanded | 160–1100 | 96–820 |

With `static`, use only `width` and `height`.

### Dynamic sizing

Use this when the CI should grow/shrink with its declarative content:

```json
"sizing": {
  "mode": "dynamic",
  "closed": {
    "minWidth": 180,
    "preferredWidth": 250,
    "maxWidth": 420,
    "minHeight": 32,
    "preferredHeight": 40,
    "maxHeight": 72
  },
  "expanded": {
    "minWidth": 360,
    "preferredWidth": 560,
    "maxWidth": 800,
    "minHeight": 180,
    "preferredHeight": 300,
    "maxHeight": 600
  }
}
```

For dynamic sizing:

```text
minWidth <= preferredWidth <= maxWidth
minHeight <= preferredHeight <= maxHeight
```

Do not mix `width`/`height` with dynamic bounds.

The **surface contract is authoritative**. Do not depend on accidental child-view dimensions to resize the notch outside these rules.

---

## 4. Every Custom CI owns its background

A Custom CI does not inherit Halo's normal notch background while it owns the surface.

Declare a background for every supported state:

```json
"background": {
  "closed": {
    "type": "solid",
    "color": "#0B0C10",
    "opacity": 1
  },
  "expanded": {
    "type": "gradient",
    "color": "#0B0C10",
    "secondaryColor": "#252B45",
    "opacity": 1
  }
}
```

Supported background types:

- `solid`
- `gradient`
- `glass`
- `clear`

Supported named colors include:

- `accent`
- `white`
- `black`
- `clear`
- `secondary`
- `green`
- `orange`
- `red`
- `blue`

Hex colors can use `#RRGGBB` or `#RRGGBBAA`.

`opacity` is `0...1`. `blur`, where used, is `0...40`.

---

## 5. Closed and expanded UI

`interface.json` contains two roots:

```json
{
  "closed": { ... },
  "expanded": { ... }
}
```

`expanded` is required. `closed` is required if the manifest declares closed support.

The CI follows Halo's normal notch interaction model. The closed state is the compact presentation; opening the notch switches to the expanded tree. Halo keeps ownership of the window, animation, clipping, lifecycle, and arbitration.

---

## 6. Components available in SDK 0.1

These component `type` values are currently accepted:

### Basic UI

- `Text`
- `Image`
- `Icon`
- `Button`
- `Toggle`
- `Slider`
- `Progress`
- `ProgressRing`
- `Spacer`
- `Divider`
- `Badge`
- `ActivityIndicator`

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

`SystemMetric.metric` currently accepts:

```text
battery
cpu
memory
storage
networkDown
networkUp
thermal
```

Common component fields include:

```text
text
value
source
systemName
metric
children
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
action
```

Unknown SDK 0.1 fields are rejected rather than silently ignored.

### Images

Package images use:

```json
{
  "type": "Image",
  "source": "asset:assets/icon.png"
}
```

SDK 0.1 only exposes local package images through `asset:<relative-path>`. Network image loading is not a public Image source yet.

---

## 7. Bindings: context/data available to a CI

Custom CIs consume read-only context through simple bindings:

```text
{{ media.title }}
{{ apps.active.name }}
{{ system.battery.level }}
```

SDK 0.1 deliberately does not expose arbitrary Halo objects or a scripting expression language.

### Halo surface context

```text
halo.surface.state
halo.surface.isExpanded
```

Use these when the presentation should describe or react visually to whether Halo is closed/expanded.

### System context

```text
system.battery.level
system.battery.isCharging
system.lowPowerMode
system.cpu.usedPercent
system.memory.usedPercent
system.storage.usedPercent
```

### Media context

Requires `Media.ReadState`:

```text
media.isPlaying
media.title
media.artist
media.album
```

### Active application context

Requires `Applications.Observe`:

```text
apps.active.bundleID
apps.active.name
```

Example:

```json
{
  "type": "VStack",
  "children": [
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
    }
  ]
}
```

A binding that needs a permission must also have that permission declared in the manifest and granted by the user.

---

## 8. Triggers available in SDK 0.1

`triggers.json` is optional. Without an automatic trigger, a CI can still be opened manually from Halo.

The document format is:

```json
{
  "match": "any",
  "triggers": [
    ...
  ]
}
```

`match` can be:

- `any` — at least one automatic trigger must match;
- `all` — every automatic trigger must match.

A package can define up to 32 triggers.

### `manual`

```json
{ "type": "manual" }
```

`manual` identifies a manually launched CI. It is not itself treated as an automatic condition by the automatic trigger evaluator.

### `mediaPlaying`

Requires `Media.ReadState`.

Open while media is playing:

```json
{
  "type": "mediaPlaying",
  "bool": true
}
```

Match when media is not playing:

```json
{
  "type": "mediaPlaying",
  "bool": false
}
```

### `activeApplication`

Requires `Applications.Observe`.

```json
{
  "type": "activeApplication",
  "value": "com.apple.dt.Xcode"
}
```

The value is an exact bundle identifier.

### `batteryBelow`

```json
{
  "type": "batteryBelow",
  "number": 20
}
```

### `batteryAbove`

```json
{
  "type": "batteryAbove",
  "number": 80
}
```

### `charging`

Match while charging:

```json
{
  "type": "charging",
  "bool": true
}
```

Or while not charging:

```json
{
  "type": "charging",
  "bool": false
}
```

### `timeWindow`

Uses minute-of-day values from `0...1439`.

For 09:00–17:00:

```json
{
  "type": "timeWindow",
  "startMinute": 540,
  "endMinute": 1020
}
```

Overnight windows work too. For 22:00–06:00:

```json
{
  "type": "timeWindow",
  "startMinute": 1320,
  "endMinute": 360
}
```

If start and end are equal, the current evaluator treats the window as always matching.

### Combining trigger context

Example: show a CI only while Xcode is frontmost **and** media is playing:

```json
{
  "match": "all",
  "triggers": [
    {
      "type": "activeApplication",
      "value": "com.apple.dt.Xcode"
    },
    {
      "type": "mediaPlaying",
      "bool": true
    }
  ]
}
```

Manifest permissions for that example:

```json
"permissions": [
  "Applications.Observe",
  "Media.ReadState"
]
```

---

## 9. Priority and surface ownership

A trigger matching does **not** guarantee that the CI gets to open.

Halo resolves ownership centrally.

Important rules:

1. Built-in and Custom CIs participate in priority arbitration.
2. If a higher-priority CI already owns/claims the notch, a lower-priority Custom CI does not get to take the surface.
3. Among eligible Custom CIs, Halo evaluates priority before granting ownership.
4. A lower-priority CI should not be treated as visually active merely because its trigger condition became true.
5. Manual Open still respects the current ownership rules rather than bypassing a higher-priority owner.
6. When a Custom CI owns the surface, its own size and background contract are used.

Authors should therefore design triggers as **eligibility**, not as an assumption of guaranteed presentation.

Users can change each Custom CI's priority in Halo Settings.

---

## 10. Permissions available in SDK 0.1

Current manifest permissions are:

```text
Media.ReadState
Media.Control
Applications.Observe
Clipboard.Write
URL.Open
```

Declare only what you use.

Examples:

```json
"permissions": [
  "Media.ReadState",
  "Media.Control"
]
```

Permissions are separate from capabilities. Declaring a permission makes the requested access visible to Halo; the user can still revoke it.

---

## 11. Capabilities available in SDK 0.1

Current capability names are:

```text
LocalAssets
LocalState
AutomaticTriggers
MediaControls
```

Use them to describe what the package intends to use. Do not invent capability strings: unknown values are rejected.

---

## 12. Actions available in SDK 0.1

Buttons can invoke brokered actions:

```json
{
  "type": "Button",
  "text": "Close",
  "accessibilityLabel": "Close CI",
  "action": {
    "id": "halo.ci.close"
  }
}
```

Current action IDs:

```text
halo.ci.close
clipboard.copy
url.open
media.playPause
media.next
media.previous
```

Permission requirements:

| Action | Permission |
|---|---|
| `halo.ci.close` | none |
| `clipboard.copy` | `Clipboard.Write` |
| `url.open` | `URL.Open` |
| `media.playPause` | `Media.Control` |
| `media.next` | `Media.Control` |
| `media.previous` | `Media.Control` |

Action `value` and string `arguments` can contain supported bindings.

---

## 13. Local state

`Toggle` and `Slider` can store isolated per-CI state.

Toggle:

```json
{
  "type": "Toggle",
  "text": "Show details",
  "stateKey": "details.enabled",
  "defaultBool": true,
  "accessibilityLabel": "Show details"
}
```

Slider:

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

State keys are private to that CI package. One CI must not depend on another CI's private state.

---

## 14. A useful media CI example

### `manifest.json`

```json
{
  "schemaVersion": 1,
  "sdkVersion": "0.1",
  "id": "com.example.media-mini",
  "name": "Media Mini",
  "author": "Example Developer",
  "version": "1.0.0",
  "minimumHaloVersion": "1.0.0",
  "entryInterface": "interface.json",
  "description": "Compact media controls for Halo.",
  "permissions": [
    "Media.ReadState",
    "Media.Control"
  ],
  "capabilities": [
    "AutomaticTriggers",
    "MediaControls"
  ],
  "supportedSurfaces": ["notch"],
  "supportedStates": ["closed", "expanded"],
  "surface": {
    "sizing": {
      "mode": "static",
      "closed": { "width": 300, "height": 42 },
      "expanded": { "width": 560, "height": 250 }
    },
    "background": {
      "closed": {
        "type": "solid",
        "color": "#090A0D",
        "opacity": 1
      },
      "expanded": {
        "type": "glass",
        "color": "#11131A",
        "opacity": 0.92,
        "blur": 16
      }
    }
  }
}
```

### `interface.json`

```json
{
  "closed": {
    "type": "HStack",
    "spacing": 8,
    "padding": 7,
    "children": [
      {
        "type": "Icon",
        "systemName": "music.note",
        "width": 14,
        "height": 14,
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
    "spacing": 12,
    "padding": 18,
    "children": [
      {
        "type": "MediaArtwork",
        "width": 72,
        "height": 72,
        "cornerRadius": 14
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
        "spacing": 10,
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
            "accessibilityLabel": "Play or pause",
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
        "accessibilityLabel": "Close Media Mini",
        "action": { "id": "halo.ci.close" }
      }
    ]
  }
}
```

### `triggers.json`

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

---

## 15. Validation and limits

SDK 0.1 intentionally fails closed.

Important limits currently enforced include:

- package size: 10 MB maximum;
- file count: 128 maximum;
- JSON file size: 512 KB maximum;
- component count: 180 maximum;
- component tree depth: 16 maximum;
- trigger count: 32 maximum;
- unknown schema fields are rejected;
- symbolic links/path traversal are rejected;
- executable/script content is rejected;
- referenced package image assets must exist and remain inside the package.

Do not include `.js`, `.swift`, `.dylib`, `.sh`, `.py`, or similar executable payloads. The `scripts/` concept is reserved for a future isolated runtime and is not executable in SDK 0.1.

---

## 16. Design guidance

A good Custom CI should feel like it belongs to the notch rather than like a shrunken desktop window.

Recommended rules:

- Keep closed-state information glanceable.
- Use icons, progress, badges, short labels, and useful visual structure instead of leaving small surfaces visually empty.
- Prefer one strong purpose per CI.
- Keep text short and use `lineLimit` where appropriate.
- Give interactive controls an `accessibilityLabel`.
- Use dynamic sizing only when content actually benefits from it.
- Treat the declared min/max bounds as part of the product design.
- Give both closed and expanded states intentional backgrounds.
- Assume another CI can win arbitration at any time.
- Never rely on private Halo implementation types or undocumented behavior.

---

## 17. Updating a CI

Keep the same stable reverse-DNS `id` and increment `version` using semantic versioning:

```json
"id": "com.example.media-mini",
"version": "1.1.0"
```

Re-importing a package with the same ID is the update/replace path rather than a completely unrelated second CI.

---

## 18. Debug checklist

If Halo rejects a CI, check these first:

1. Folder ends in `.haloCI`.
2. `schemaVersion` is `1`.
3. `sdkVersion` is `"0.1"`.
4. `id` is a stable reverse-DNS style identifier.
5. `version` and `minimumHaloVersion` are valid semantic versions.
6. `surface.sizing` exists and uses valid static or dynamic dimensions.
7. `surface.background` exists for every supported state.
8. `expanded` exists in `interface.json`.
9. Every component type is in the SDK 0.1 list.
10. Every binding key is supported.
11. Required permissions are declared in the manifest.
12. Trigger fields match the selected trigger type.
13. Local images use `asset:<relative-path>`.
14. No scripts/executables/symlinks are present.
15. If a trigger matches but nothing opens, check CI priority: a higher-priority CI may already own the notch.

---

## 19. Source of truth

For authors:

- **Practical authoring:** this document
- **Working example:** `Examples/HelloWorld.haloCI`

For SDK/runtime maintainers:

- `Docs/CISDK.md`
- `Docs/Architecture.md`
- `Docs/Plugins.md`
- `AGENTS.md`

When Halo adds a public component, binding, trigger, action, permission, capability, surface behavior, or schema field, this guide should be updated in the same change.
