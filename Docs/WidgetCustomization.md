# Widget customization and closed content

The closed notch now widens automatically during music playback, pinned files, capture/OCR, a running focus timer or stopwatch, or a recent/live activity. Settings → Closed notch → Automatic width controls the feature and its target width (400 pt by default). Active width never makes the notch narrower than its configured idle width. Height and offsets stay unchanged; opening the dashboard still uses its normal dimensions. Completed/status activities hold the wider width for eight seconds after creation, while progress activities remain active until completed or dismissed. Music is detected automatically in supported running players, subject to macOS Automation permission. Geometry editing temporarily suspends automatic width so sliders preview the actual idle size.

Open Settings → Widgets and select any opened-dashboard widget. Changes apply live to global layouts. In addition to typography, text/accent/card colors, background opacity, padding, corners, maximum width and minimum height, each widget now has independent content alignment, spacing, control sizing, border/shadow treatment and content opacity. Widget-specific sections expose the controls that actually matter to that module: timer presets, Shelf row/action density, media metadata and controls, Calendar event count/times/Join actions, Clipboard search/history density, System metrics, Launcher sources, Activity detail/progress, Notes height, Capture/OCR density and Stopwatch sizing. These settings are for the opened notch dashboard; Closed Notch slots keep their existing dedicated editor. Cards remain constrained by dashboard width. Reset affects only the selected widget. System controls may retain platform-specific sizing.

Clock also supports seconds, date, 12/24-hour time and a time zone. The closed clock follows these clock options and font family, with its own closed-content size and color. Save current settings as a profile to reuse them; profiles and theme export include widget settings. For display-specific layouts, apply a saved profile in Displays.

Settings → Closed notch provides left and right slots: none, clock, date, timer, battery, track title, playback visualizer, shelf file count or latest activity. Increase closed width in Appearance if content does not fit. Physical camera space is reserved, including horizontal and vertical offsets. A 16-point surface can only hold a status dot; a surface entirely behind the physical camera cannot display visible content there.

Halo detects playing Apple Music and Spotify instances automatically. Media & Files selects a preferred player and allows restricting detection to it. macOS may request Automation access for each player. Denied players are skipped until Retry detection; browser playback and other players are not supported. Bars, wave, pulse, waveform, ribbon, dots, rings, orbit and spectrum are decorative playback animations, not measured audio. They animate only while playing, at the display cadence up to 120 updates per second, and stop for Reduce Motion or Low Power Mode. Halo does not request microphone access.

Glass samples the desktop through native macOS material. Opacity now adjusts a light tint instead of covering glass with opaque black. Reduce Transparency intentionally uses a solid fallback. Image/video blur controls do not apply to native glass.


## Opened notch workspace

**Custom Workspace Layout is optional.** Existing Fixed, Scroll, and Pages opened-notch layouts remain the default for older profiles and are stored independently. Turning Custom Workspace off restores the legacy layout immediately without deleting the custom design. The custom workspace has its own Fixed/Scroll/Pages mode.

In the custom Fixed workspace, occupied rows and columns form the canvas. Each row and column has a relative size share, and every region can use a percentage of its grid slot plus independent padding. Items are allocated concrete width/height slots before they render; Fixed/Fit/Flexible/Fill sizing is clamped to the region, so cards cannot overlap or escape their designed area. Widgets receive their actual slot dimensions and automatically reduce padding/spacing/secondary content, switch presentation, truncate, and finally scroll only when the slot is genuinely too small.


The normal opened notch is now a workspace model rather than a fixed list of cards. Existing saved layouts remain valid: when an older profile has no `OpenNotchLayout`, Halo resolves its existing enabled-module order into a compatible center group, and the existing Fixed Canvas, Scroll, and Pages modes remain available.

The visual opened-notch editor arranges content as regions → groups → items. Regions can occupy top/middle/bottom and left/center/right positions, each with independent padding. Groups choose horizontal or vertical flow, alignment, spacing, and padding. Items can be full modules or lightweight elements such as time/date, battery, active-app identity, volume, timer/stopwatch, media metadata/controls, CPU/RAM/storage/network metrics, custom text/icons/images/GIFs, buttons, spacers, and dividers. Items use one shared renderer and can be dragged between groups/regions, reordered, resized, hidden, duplicated, grouped, and configured with Fixed, Fit Content, Flexible, or Fill Remaining Space sizing plus min/preferred/max dimensions.

Opened modules support Automatic, Compact, Regular, and Expanded presentation. Automatic responds to available space. Under pressure the layout reduces spacing first, then removes lower-priority metadata, then switches to compact presentation, then truncates, and only scrolls as a final fallback. Items have Always Visible, High, Normal, Low, and Optional priorities plus generic visibility rules for battery level, charging, playback, timer/stopwatch state, CPU load, and Low Power Mode.

Per-item styling reuses Halo's widget/element style model and adds alignment, external spacing, offsets, font overrides, border/shadow/tint/icon sizing, and density. The opened surface also has independent background overrides for solid/gradient/image/video/material sources plus blur, saturation, brightness, contrast, tint, grain, warmth, border, inner highlight, shadow, and restrained glow. Opened presets (Minimal, Media, Productivity, System Monitor, Focus, Developer, Information Dense, Showcase) are ordinary `OpenNotchLayout` values and remain editable after applying them.

The opened media module exposes real artwork, richer metadata, seek/timing when the player exposes duration and position, optional measured system-audio visualization, and shuffle/repeat only when the player's Automation interface supports them. Unsupported controls stay hidden. The opened system monitor adds CPU, memory, swap, disk, network, battery/power and thermal information with optional compact history graphs. Detailed monitor sampling and opened-only media details run only while the normal opened notch is visible; when it closes, Halo falls back to the existing lower-frequency shared polling.

## Validation on a Mac

Run `bash Scripts/validate.sh` after pulling. The editing environment validated project structure and Swift grammar but could not run Xcode or XCTest.

1. Drag size/offset sliders while open and closed; rapidly reverse transitions. Confirm smooth motion and that notes/settings persist after quitting immediately after editing.
2. Test glass over light and dark windows, then enable Reduce Transparency. Test an image background and muted looping video, including collapse and battery pause.
3. Change each widget's font, size and colors; verify large text with narrow cards, notes editing, title toggles, and profile/theme round trips. Verify clock seconds, midnight, 12/24-hour format and another time zone.
4. On a notched Mac, test centered and offset slots, widths below/above the camera width, and a downward offset below the camera. Repeat on an external display.
5. Launch each supported player, play/pause externally, skip tracks, stop, quit and relaunch it. Verify animation follows playback within the polling interval and remains static under Reduce Motion/Low Power Mode. Switch players during refresh to check stale results are ignored.
6. Use Instruments or Activity Monitor to compare transition frame pacing, idle CPU and energy against the previous commit. No measured speedup is claimed yet.

## Visualizer styles and artwork colors

In Settings → Closed notch → Music animation, choose one of nine styles and adjust speed, intensity, width and height. The preview animates independently of playback to show the selected style. The live notch only animates during playback; Reduce Motion disables animation. Large sizes may need a wider/taller closed notch.

Enable **Use colors from music artwork** to use up to two dominant cover colors as a gradient. Missing, undecodable, entirely black or entirely white artwork falls back to the manually selected closed-notch color. Dark extracted colors are brightened for visibility. Turning the option off restores the manual color immediately and cancels pending artwork work. The other closed-notch text retains its configured color.

Artwork is requested once per track change after detecting the player. Spotify artwork uses its HTTPS cover URL; Apple Music returns artwork through Automation. Network reads are limited to 5 MB and decoding uses a 40-pixel thumbnail off the main thread. Track and connection checks prevent a delayed old result from coloring a newer track. Artwork failures do not stop playback controls. There is no microphone capture or audio analysis.

On a Mac, verify all nine styles at minimum/maximum sizes, speed and intensity; test two tracks with visibly different covers in each player; toggle artwork colors during a fetch; skip tracks quickly; test unavailable artwork/offline Spotify; check manual fallback and Reduce Motion. Xcode compilation and native rendering remain required validation gates.

See [Personalization.md](Personalization.md) for timed profiles/backgrounds, grain and side icons/GIFs.

## Display cadence and content fit

On macOS 14+, surface transitions and playback visuals use a view-linked CADisplayLink, requesting up to 120 fps on capable displays. The link follows display moves and runs in common run-loop modes so tracking menus does not stall it. macOS 13 uses a timer matched to the detected maximum refresh rate. Low Power Mode requests at most 60 fps; Reduce Motion still stops animation. macOS and display settings decide the actual delivered cadence. Settings → General reports the requested target, not a measured frame rate.

Settings → Closed notch → Content fit enables **Auto-size to fit content** (default on) and horizontal/vertical padding. Auto-size measures text and includes visualizer/decorations, keeping the configured idle width as a minimum. Physical-camera reservations include horizontal offsets. The fitting contribution is capped at 640 pt and screen bounds; long text truncates once space runs out. Visualizers, symbols and GIFs respect the available closed height. Turn auto-size off to keep a fixed minimum width (activity expansion remains a separate setting).

Font and time-zone catalogs now open as searchable lazy lists rather than hundreds of eagerly constructed picker entries.

Mac checks: enable ProMotion/120 Hz, disable Low Power Mode, record frame pacing in Instruments while opening/closing Halo and scrolling settings. Move between 60/120 Hz screens and repeat. Test both slots with long titles, large custom clock fonts, seconds, a GIF plus visualizer, extreme padding, camera offsets and auto-size on/off. Native compilation and actual delivered frame rate have not been verified in this editing environment.
