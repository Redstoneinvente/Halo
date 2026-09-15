# Hello CI

Copy this directory, keep the `.haloCI` suffix, change the reverse-DNS `id`, then edit the declarative JSON.

Import it from **Halo Settings → Context Notch Interface → Custom CI → Import .haloCI…**. Grant `Media.ReadState` and `Media.Control` on its card for the media binding/trigger/buttons.

There is intentionally no Swift/JavaScript entry point. Halo owns rendering, actions, permissions, lifecycle and arbitration. See `Docs/CISDK.md` for the implemented SDK 0.1 contract.
