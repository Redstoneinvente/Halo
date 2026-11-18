# Touchpad Notch quick actions

In Touchpad Notch settings, enable monitoring, record a spot, then choose a **Spot control**:

- Halo notch or Touchpad CI: retain the existing open/close behavior.
- Play / pause, next track, previous track: control the connected media source using Halo's existing transport and system fallback.
- Mute / unmute output: use Halo's existing output-volume mute behavior; does not mute the microphone.
- Volume down / up: change the current output level by 1/16, clamped by the existing audio service.

Quick controls use taps and slides by default: tap and release for play/pause or mute, swipe right/left for next/previous track, and slide up/down for repeated volume steps. Start inside the saved spot; sliding may continue outside it. Disable **Use taps and slides** to restore hold-to-activate. Both modes respect the saved pressure threshold. **Test selected action** bypasses gesture recognition, while live input hints show spot and pressure qualification. Multi-finger input blocks activation until all fingers lift. Recording and pressure calibration suppress actions. Haptics follow the existing preference. Unsupported audio outputs show a status message.

Existing settings retain their saved spot, pressure calibration, hold times and destination. The optional quickGestures preference defaults to taps and slides when absent. No additional permissions are introduced. These are built-in user-selected actions; Touchpad CI continues to use the existing permissions and arbitration path.

## Research and scope

Reviewed November 18, 2026:

- BetterTouchTool's [trackpad documentation](https://docs.folivora.ai/docs/trackpad-mouse/magic-mouse-trackpad/) describes configurable gestures, haptics and visible feedback.
- [Haptiker](https://haptiker.app/) uses deliberately initiated edge gestures for frequent volume/brightness adjustments and guards against ordinary gestures.
- [Notchy](https://notchy.dev/) advertises trackpad-triggered notch and playback actions, supporting the usefulness of quick actions alongside opening a surface.

The implementation applies those patterns to Halo's existing pressure-qualified saved spot. Brightness and global edge swipes are deferred: Halo's SystemService.setBrightness is currently a no-op, and unrestricted global swipes would need separate gesture arbitration. No unsupported hardware control is exposed.

## Manual hardware checks

On the direct-download edition, record a real trackpad spot and test each action with Music, Spotify, Safari, and a hardware-volume-controlled output. Check pressure qualification, repeat after release, two-finger cancellation, recording suppression, sleep/session pause, and an output without software volume control. Hardware interaction cannot be certified by the automated recognizer tests.
