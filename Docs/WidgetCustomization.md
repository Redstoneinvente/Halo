# Widget customization and closed content

The closed notch now widens automatically during music playback, pinned files, capture/OCR, a running focus timer or stopwatch, or a recent/live activity. Settings → Closed notch → Automatic width controls the feature and its target width (400 pt by default). Active width never makes the notch narrower than its configured idle width. Height and offsets stay unchanged; opening the dashboard still uses its normal dimensions. Completed/status activities hold the wider width for eight seconds after creation, while progress activities remain active until completed or dismissed. Music is detected automatically in supported running players, subject to macOS Automation permission. Geometry editing temporarily suspends automatic width so sliders preview the actual idle size.

Open Settings → Widgets and select any opened-dashboard widget. Changes apply live to global layouts. In addition to typography, text/accent/card colors, background opacity, padding, corners, maximum width and minimum height, each widget now has independent content alignment, spacing, control sizing, border/shadow treatment and content opacity. Widget-specific sections expose the controls that actually matter to that module: timer presets, Shelf row/action density, media metadata and controls, Calendar event count/times/Join actions, Clipboard search/history density, System metrics, Launcher sources, Activity detail/progress, Notes height, Capture/OCR density and Stopwatch sizing. These settings are for the opened notch dashboard; Closed Notch slots keep their existing dedicated editor. Cards remain constrained by dashboard width. Reset affects only the selected widget. System controls may retain platform-specific sizing.

Clock also supports seconds, date, 12/24-hour time and a time zone. The closed clock follows these clock options and font family, with its own closed-content size and color. Save current settings as a profile to reuse them; profiles and theme export include widget settings. For display-specific layouts, apply a saved profile in Displays.

Settings → Closed notch provides left and right slots: none, clock, date, timer, battery, track title, playback visualizer, shelf file count or latest activity. Increase closed width in Appearance if content does not fit. Physical camera space is reserved, including horizontal and vertical offsets. A 16-point surface can only hold a status dot; a surface entirely behind the physical camera cannot display visible content there.

Halo detects playing Apple Music and Spotify instances automatically. Media & Files selects a preferred player and allows restricting detection to it. macOS may request Automation access for each player. Denied players are skipped until Retry detection; browser playback and other players are not supported. Bars, wave, pulse, waveform, ribbon, dots, rings, orbit and spectrum are decorative playback animations, not measured audio. They animate only while playing, at the display cadence up to 120 updates per second, and stop for Reduce Motion or Low Power Mode. Halo does not request microphone access.

Glass samples the desktop through native macOS material. Opacity now adjusts a light tint instead of covering glass with opaque black. Reduce Transparency intentionally uses a solid fallback. Image/video blur controls do not apply to native glass.

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
