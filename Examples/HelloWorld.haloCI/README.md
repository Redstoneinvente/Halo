# Hello CI

This is Halo's starter Custom CI package for SDK 0.1.

Copy this directory, keep the `.haloCI` suffix, change the reverse-DNS `id`, then edit the declarative JSON.

Import it from **Halo Settings → Context Notch Interface → Custom CI → Import .haloCI…**. Grant `Media.ReadState` and `Media.Control` on its card for the media binding, trigger, artwork, and playback buttons.

For a complete creator-facing walkthrough—including package structure, static/dynamic sizing, Custom CI backgrounds, every currently implemented trigger, live context/binding key, permission, action, component, priority behavior, validation limits, and debugging—read:

**[`Docs/CustomCIAuthoring.md`](../../Docs/CustomCIAuthoring.md)**

For the canonical architecture/security contract and future SDK direction, read [`Docs/CISDK.md`](../../Docs/CISDK.md).

There is intentionally no Swift/JavaScript entry point. Halo owns rendering, actions, permissions, lifecycle, surface geometry, and priority arbitration.
