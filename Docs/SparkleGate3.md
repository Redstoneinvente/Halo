# Sparkle Gate 3 — signed 0.2.0 → 0.2.1 update

Gate 3 proves a real signed Sparkle update before any updater work reaches `main`.

## What is committed

- Sparkle 2.9.6 via Swift Package Manager.
- Manual-only `Check for Updates…`.
- `SUFeedURL` and `SUPublicEDKey` are build-setting substitutions.
- Automatic checks and automatic installation remain disabled.
- `CFBundleShortVersionString` comes from `MARKETING_VERSION`.
- `CFBundleVersion` comes from `CURRENT_PROJECT_VERSION`.

The Sparkle private key is **never** committed. Sparkle's `generate_keys` stores it in the macOS login Keychain.

## 1. Download the full Sparkle 2.9.6 distribution

The Swift Package Manager archive provides the framework, but Gate 3 also needs Sparkle's release tools (`generate_keys` and `generate_appcast`). Download the full **Sparkle 2.9.6** release distribution from the official Sparkle GitHub release and extract it locally.

You should have a directory containing:

```text
bin/generate_keys
bin/generate_appcast
bin/sign_update
```

## 2. Generate Halo's Ed25519 key once

From the extracted Sparkle distribution:

```bash
./bin/generate_keys
```

The tool stores the **private key** in your login Keychain and prints the public key. Keep the private key in Keychain; do not put it in the repository, CI variables, chat, or the update server.

Running `generate_keys` again later can print the existing public key.

## 3. Configure local Secrets.xcconfig

Create or edit:

```text
Halo/Config/Secrets.xcconfig
```

Add:

```xcconfig
HALO_SPARKLE_PUBLIC_KEY = <the-public-key-printed-by-generate_keys>
HALO_SPARKLE_FEED_URL = https:/$()/YOUR-HTTPS-HOST/gate3/appcast.xml
```

`Secrets.xcconfig` is ignored by Git. The `$()` between `https:` and `//` is intentional because `//` begins a comment in xcconfig syntax; Xcode expands `$()` to an empty string and the built Info.plist receives a normal `https://…` URL.

Use an HTTPS staging location you control. For example:

```xcconfig
HALO_SPARKLE_FEED_URL = https:/$()/halo.redstoneinvente.com/updates/gate3/appcast.xml
```

## 4. Build both test versions and generate the appcast

Run from the repository root:

```bash
SPARKLE_BIN="$HOME/Downloads/Sparkle-2.9.6/bin" \
HALO_SPARKLE_DOWNLOAD_URL_PREFIX="https://YOUR-HTTPS-HOST/gate3/" \
bash Scripts/sparkle_gate3_local.sh
```

The helper builds and code-sign-verifies:

```text
Halo 0.2.0 (200)
Halo 0.2.1 (201)
```

It then creates full ZIP archives, adds release notes, invokes Sparkle's official `generate_appcast`, and refuses to continue if build 201 or an Ed25519 enclosure signature is missing.

By default artifacts are written to:

```text
~/Desktop/Halo-Sparkle-Gate3/
```

The important paths are:

```text
install/Halo.app          # baseline 0.2.0 (200)
updates/appcast.xml
updates/Halo-0.2.0.zip
updates/Halo-0.2.1.zip
updates/Halo-0.2.1.md
```

You can override the workspace using `HALO_SPARKLE_GATE3_DIR`.

## 5. Upload the update directory

Upload the contents of `updates/` to the exact HTTPS directory used by `HALO_SPARKLE_DOWNLOAD_URL_PREFIX`.

Confirm in a browser that the feed URL from `Secrets.xcconfig` returns `appcast.xml` over HTTPS and that the 0.2.1 archive URL in the appcast downloads successfully.

Do not hand-edit the generated Ed25519 signature.

## 6. Perform the real update

Use the baseline app from the Gate 3 output, not your ordinary development build. Put it in a dedicated writable test folder, for example:

```text
~/Applications/Halo Gate 3/Halo.app
```

Launch that copy and verify **About/System Information** or its Info.plist reports `0.2.0 (200)`.

Then choose:

```text
Halo menu → Check for Updates…
```

Expected flow:

```text
0.2.0 (200)
→ Sparkle reads HTTPS appcast
→ 0.2.1 (201) is offered
→ release notes render
→ signed archive downloads
→ Ed25519 verification passes
→ update installs
→ Halo relaunches
→ Halo 0.2.1 (201) launches normally
```

After relaunch, verify:

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "$HOME/Applications/Halo Gate 3/Halo.app/Contents/Info.plist"

/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
  "$HOME/Applications/Halo Gate 3/Halo.app/Contents/Info.plist"

codesign --verify --deep --strict --verbose=4 \
  "$HOME/Applications/Halo Gate 3/Halo.app"
```

The expected values are `0.2.1` and `201`, and code-sign verification must succeed.

## Gate 3 pass criteria

Gate 3 passes only when all of these are true on the real Mac:

1. The baseline app launches normally.
2. Manual Check for Updates finds 0.2.1.
3. Sparkle shows the generated release notes.
4. The archive downloads over HTTPS.
5. Ed25519 verification succeeds.
6. Installation completes.
7. Halo relaunches itself.
8. The relaunched app reports 0.2.1 (201).
9. `codesign --verify --deep --strict` succeeds after the update.

Only after that should the Sparkle branch be considered eligible for merging or moving on to automatic update settings and What's New.
