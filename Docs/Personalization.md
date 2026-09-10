# Schedules, automatic media and side decorations

## Automatic media

Open Apple Music or Spotify and play a track. Halo selects the playing app; controls and artwork colors follow it. If both play, the current player stays selected to avoid flicker; the preferred app breaks the initial tie. If neither plays, the last available player stays selected with a static visualizer. Playback notifications trigger a short debounced refresh, with a two-second fallback. An unavailable/hung app can delay a scan by its three-second Apple Events timeout.

macOS may ask for Automation access on the first detection of each running player. Denied apps are skipped until **Retry detection**. In **Media & Files**, disable automatic app selection to restrict detection to the preferred player. This covers Apple Music and Spotify, not browser tabs or arbitrary system audio. No microphone or loopback recording is performed.

## Timed profiles and backgrounds

**Settings → Schedules** provides ordered time ranges and weekdays. The first matching enabled entry wins. Start is inclusive, end is exclusive; equal times mean all day. An overnight range belongs to its start day (Monday 22:00–06:00 also covers early Tuesday). Evaluation uses the Mac's current local time, including daylight-saving changes, on startup, wake and minute boundaries.

Scheduled profiles are temporary overrides: normal settings return outside the range. Applying a profile manually or through an automation rule suppresses the current scheduled occurrence. A new day/range resumes scheduling, or press **Resume scheduled profiles now**. Display-specific layouts and themes retain precedence on their displays. The appearance/widgets settings editor edits the base layout; the Schedules page identifies an active scheduled profile.

Timed backgrounds live inside a layout and are included when saving a profile. They choose solid/gradient/glass/image/video, blur and grain. Outside matching ranges, the layout's ordinary background returns. Video keeps the normal collapse/battery pause rules. The existing hour automation trigger remains available for simple one-way profile switches.

## Grain and warmth

In **Appearance → Background**, enable **Soft grain** and adjust amount, grain size and warmth. The same controls exist per scheduled background. A cached grayscale tile supplies static grain; there is no noise animation timer. Native glass stays outside SwiftUI blur filters. Use the existing blur control on image/video backgrounds for additional diffusion.

## Icons and GIFs

In **Closed notch**, each side has its own icon/GIF settings with **Disabled**, **Always** or **Only while music plays**. Choose an SF Symbol (including a custom symbol name), or a local image/GIF. Icons have a tint and both types have a size control. Decorations sit beside the slot's existing content and scale to the closed height; increase height if you want larger artwork.

GIFs are limited to 10 MB and 120 frames, decoded once into thumbnails up to 128 px and played by Core Animation. Reduce Motion and Low Power Mode show the first frame. Missing/moved files cannot render and must be selected again. Only the file reference is saved; imported themes remove image paths and disable those image decorations until reselected.

Visible decorations reserve enough width to sit outside the physical camera notch. Automatic activity width also applies to pinned files, capture/OCR, running timers/stopwatches, media and live activities. New shelf additions and completion/status activities hold the wider state briefly. Unpinning the last file and ending the other active reasons returns to idle width. Geometry editing suspends these overrides to preview your requested idle size.

## Mac validation

Run `bash Scripts/validate.sh` after pulling. The Linux editing environment checks project references and Swift grammar; it cannot compile Apple SDK code or run XCTest.

1. Open both players; test first permission prompts, denied access, retry, external play/pause, switching players, quitting a player and rapid track changes. Check artwork-color fallback offline.
2. Create overlapping weekday and overnight profile ranges, then test a manual profile override, deleting a referenced profile, wake after a boundary and changing time zone. Confirm the base layout remains saved.
3. Schedule image/video/glass backgrounds with different grain settings. Test leaving the range and Low Power/Reduce Transparency behavior.
4. Test a static PNG and short GIF on either side, each visibility mode, minimum closed size, hardware camera offsets, Reduce Motion and Low Power Mode. Replace/delete the source file and reselect it.
5. Pin/unpin shelf references; add multiple files together; run a timer and capture/OCR alongside music. The notch should remain wide until every active reason ends, without changing height or opening the dashboard automatically.
6. Compare frame pacing and idle CPU in Instruments against the previous version. No numerical speedup is claimed without a Mac measurement.
