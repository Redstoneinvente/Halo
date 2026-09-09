# Mac build and release gates

Do not distribute as production until these gates pass. The scripts are supplied, not executed in the Linux authoring environment.

## Build

- Open Halo.xcodeproj in Xcode 15+ with macOS 13+ deployment support.
- Set your own unique bundle identifier and Apple Developer team.
- Run bash Scripts/validate.sh; also build Release.
- Run Command–U and inspect the results. These are model/manifest/license tests, not UI tests.
- Verify with the minimum supported OS and current stable macOS; review deprecation warnings.

## Functional matrix

- First launch/onboarding, quit/relaunch, login item installed in Applications.
- Every style on a notched Mac and external non-notched display; scaled modes.
- Attach/detach/reorder displays, change main display, independent override/profile.
- Spaces, fullscreen, Stage Manager, menu-bar access, sleep/wake.
- Hover rapidly, pin, toggle hotkey, conflict with another shortcut, edit appearance while open.
- Timer run/pause/resume/reset, app restart with active timer, sleep past deadline, authorized and denied notification access.
- Empty/missing/large file references, drag out, share, retention, persistence disabled/enabled. Confirm originals never change.
- Enable/disable clipboard, excluded password apps, concealed markers, 50-item bound, clear on quit.
- Calendar access: not determined, denied, granted, revoked; no events and multiple meetings.
- Music/Spotify absent, stopped, playing, denied automation, timeout, track changes.
- Output device hotplug and devices that reject master-volume writes.
- Screenshot permission denied/granted, cancel capture/save, OCR image failure, text-copy behavior.
- Profile rules crossing both directions, competing conditions, deleted target profiles.
- Valid/invalid/oversized plugin imports, unsupported URLs, command rejection.
- Imported v1/v2 themes, malformed/nonfinite values, unavailable local background files.
- Read-only Git folder selection including non-repository, unavailable git, long output.
- VoiceOver, keyboard navigation, larger text, Reduce Motion and Reduce Transparency.

## Performance and security

- Profile idle/expanded/video CPU and energy in Instruments; record actual budgets.
- Check every observer/task/player is released on quit/rebuild.
- Review Apple-event entitlement and privacy strings.
- Review UserDefaults retention, clipboard exclusions and sensitive-text exposure.
- Implement outstanding feature gates and threat-model executable plugins before enabling them.
- Add a production app icon and privacy policy; no icon is claimed in this package.

## Archive and notarize

Use your own configured signing identity and notarytool Keychain profile:

```sh
bash Scripts/archive.sh YOUR_TEAM_ID
bash Scripts/export-notarize.sh YOUR_NOTARYTOOL_KEYCHAIN_PROFILE
```

The second script contacts Apple and requires your locally configured credentials. It does not install an updater or publish a release. Verify the stapled app on a clean Mac using Gatekeeper, then package it for distribution.

An updater, release feed, signing-key handling, rollback policy and licensing UX remain separate engineering work. No credentials or production license keys are bundled.

## Apple API references

- Calendar access: https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:)
- Automation usage: https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription
- Local OCR: https://developer.apple.com/documentation/vision/vnrecognizetextrequest
- Screen access: https://developer.apple.com/documentation/coregraphics/cgrequestscreencaptureaccess()
- License signatures: https://developer.apple.com/documentation/cryptokit/curve25519/signing/publickey
