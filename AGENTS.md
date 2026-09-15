# Halo — Instructions for Coding Agents

This file contains repository-level instructions for AI coding agents and automated contributors.

## CI / Custom Interface work

Any task involving Halo **CI (Custom Interfaces)**, CI packages, CI SDK, CI Studio, CI triggers/contexts, CI actions, third-party CI distribution, marketplace CIs, executable CI logic, or CI permissions must treat the following documents as authoritative:

1. `Docs/CustomCI_Authoring.md` — practical public authoring guide and current SDK 0.1 surface/trigger/context/action reference
2. `Docs/CISDK.md` — canonical SDK architecture and contract direction
3. `Docs/Architecture.md`
4. `Docs/Plugins.md`

Read them **before modifying code**.

### Hard rules

- Do not invent a second CI/plugin architecture.
- Do not expose arbitrary Halo Swift/SwiftUI/AppKit internals as a public SDK.
- Do not execute third-party JavaScript, Swift, dylibs, shell commands, or downloaded native code inside the Halo app process.
- Do not use `Bundle.load`, generic `eval`, shell interpolation, or unrestricted process execution as an SDK shortcut.
- Third-party executable logic is only allowed after Halo has a separate isolated process/XPC-style host with a versioned IPC contract, capability brokering, resource limits, cancellation, signature/trust policy, revocation, and crash recovery.
- Until that isolated host exists, third-party CI packages are declarative.
- Permissions and sensitive data access must be explicit, granular, brokered, reviewable, and revocable.
- Do not advertise data sources or macOS capabilities that Halo does not actually implement.
- Reuse existing surface ownership, trigger, automation, profile, and service infrastructure where appropriate instead of duplicating it.
- Preserve CI package/API compatibility unless a breaking change is explicitly versioned.
- Add tests for parsers, validators, permissions, bindings, triggers, actions, migrations, and failure paths introduced by the change.
- Update `Docs/CISDK.md` whenever a public CI SDK contract changes.
- Update `Docs/CustomCI_Authoring.md` whenever an author-visible component, binding/context key, trigger, action, permission, capability, sizing/background rule, or package field changes.

### Required implementation behavior

Before coding, inspect the relevant existing implementation. Do not infer architecture from filenames or from a prompt alone.

If a requested implementation conflicts with `Docs/CISDK.md`, stop the conflicting implementation and surface the architectural conflict rather than silently weakening the rules.

A demo that works is not sufficient. CI SDK work must also be validated, permission-safe, isolated, testable, backwards-aware, and compatible with Halo's existing surface/window architecture.

## General repository behavior

Prefer focused changes over speculative rewrites. Preserve established architecture unless the task explicitly requires an architectural change and that change is documented.

Never embed production private signing keys or secrets in the repository.