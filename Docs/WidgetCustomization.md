# Widget customization and closed content

The closed notch now widens automatically during music playback, a running focus timer or stopwatch, or a live activity. Settings → Closed notch → Automatic width controls the feature and its target width (400 pt by default). Active width never makes the notch narrower than its configured idle width. Height and offsets stay unchanged; opening the dashboard still uses its normal dimensions. Completed/status activities hold the wider width for eight seconds after creation, while progress activities remain active until completed or dismissed. Music requires connection to the selected player. Geometry editing temporarily suspends automatic width so sliders preview the actual idle size.

Open Settings → Widgets and select any of the fourteen widgets. Changes apply live to global layouts. Pick system, rounded, serif, monospaced or an installed custom font; set weight, text size, text/accent/card colors, background opacity, padding, corners, maximum card width and minimum height. Cards remain constrained by the dashboard width. Reset affects only the selected widget. System controls may retain platform-specific sizing.

Clock also supports seconds, date, 12/24-hour time and a time zone. The closed clock follows these clock options and font family, with its own closed-content size and color. Save current settings as a profile to reuse them; profiles and theme export include widget settings. For display-specific layouts, apply a saved profile in Displays.

Settings → Closed notch provides left and right slots: none, clock, date, timer, battery, track title, playback visualizer, shelf file count or latest activity. Increase closed width in Appearance if content does not fit. Physical camera space is reserved, including horizontal and vertical offsets. A 16-point surface can only hold a status dot; a surface entirely behind the physical camera cannot display visible content there.

Choose Apple Music or Spotify in Media & Files, open that player, then press Connect. Successful connection enables a background playback check every two seconds. Changing the selected player disconnects; permission errors or quitting the player stop polling until reconnect. Browsers and other players are not supported. Bars, wave and pulse are decorative playback animations, not measured audio. They animate only while playing, at up to 30 updates per second, and stop for Reduce Motion or Low Power Mode. Halo does not request microphone access.

Glass samples the desktop through native macOS material. Opacity now adjusts a light tint instead of covering glass with opaque black. Reduce Transparency intentionally uses a solid fallback. Image/video blur controls do not apply to native glass.

## Validation on a Mac

Run `bash Scripts/validate.sh` after pulling. The editing environment validated project structure and Swift grammar but could not run Xcode or XCTest.

1. Drag size/offset sliders while open and closed; rapidly reverse transitions. Confirm smooth motion and that notes/settings persist after quitting immediately after editing.
2. Test glass over light and dark windows, then enable Reduce Transparency. Test an image background and muted looping video, including collapse and battery pause.
3. Change each widget's font, size and colors; verify large text with narrow cards, notes editing, title toggles, and profile/theme round trips. Verify clock seconds, midnight, 12/24-hour format and another time zone.
4. On a notched Mac, test centered and offset slots, widths below/above the camera width, and a downward offset below the camera. Repeat on an external display.
5. Connect each supported player, play/pause externally, skip tracks, stop, quit and relaunch it. Verify animation follows playback within the polling interval and remains static under Reduce Motion/Low Power Mode. Switch players during refresh to check stale results are ignored.
6. Use Instruments or Activity Monitor to compare transition frame pacing, idle CPU and energy against the previous commit. No measured speedup is claimed yet.
