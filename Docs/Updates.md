# Halo Updates (Sparkle 2)

Halo uses Sparkle 2.9.6 for direct-distribution updates. The app expects its appcast at:

`https://halo.redstoneinvente.com/appcast.xml`

## One-time signing setup

Do **not** commit a Sparkle private key to this repository or put it in CI logs.

1. Resolve/build the Sparkle package once in Xcode.
2. Run Sparkle's `generate_keys` tool on the release-signing Mac.
3. Keep the private Ed25519 key in that Mac's Keychain (and back it up securely).
4. Put only the printed public key in the ignored `Halo/Config/Secrets.xcconfig`:

   `HALO_SPARKLE_PUBLIC_KEY = <base64 public key>`

The checked-in `Base.xcconfig` intentionally leaves this value blank. Halo will not start Sparkle in a build without a valid public key; Settings > Updates explains the missing configuration instead of presenting a broken updater.

## Publishing a release

1. Archive and distribute Halo with Developer ID signing + notarization.
2. Export the final app as a `.zip` or `.dmg` suitable for Sparkle.
3. Place release archives and matching `.html` or `.md` release-note files in your Sparkle updates directory.
4. Run Sparkle's `generate_appcast` tool. It creates the appcast, Ed25519 signatures, and supported delta updates.
5. Upload the generated appcast as `https://halo.redstoneinvente.com/appcast.xml` and upload the release archives/release notes referenced by it.
6. Test **Check for Updates…** from a previously shipped build before publishing broadly.

Never hand-edit an archive's `sparkle:edSignature`. Regenerate the appcast after changing release assets.

## What's New

`HaloWhatsNewCoordinator` remembers the last version shown. After an installed version changes it presents Halo's native What's New window once. It is also available from the status menu and Settings > Updates.

Add release-specific cards to `HaloReleaseStory.forCurrentBuild()` when preparing a new marketing version. Unknown versions fall back to a generic polished release summary rather than failing to show.
