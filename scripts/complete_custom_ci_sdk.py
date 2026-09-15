from pathlib import Path
import runpy
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: complete_custom_ci_sdk.py /tmp/apply_custom_ci.py")

# The staged generator's payload declarations are complete even though its original
# mutation tail was truncated. Running it is idempotent and gives us the decoded,
# canonical payload strings produced from the staging chunks.
ns = runpy.run_path(sys.argv[1])
RUNTIME = ns["RUNTIME"]
RENDERER = ns["RENDERER"]
SETTINGS = ns["SETTINGS"]
TESTS = ns["TESTS"]
DOCS = ns["DOCS"]
ARCH = ns["ARCH"]
EXAMPLE_MANIFEST = ns["EXAMPLE_MANIFEST"]
EXAMPLE_INTERFACE = ns["EXAMPLE_INTERFACE"]
EXAMPLE_TRIGGERS = ns["EXAMPLE_TRIGGERS"]
EXAMPLE_README = ns["EXAMPLE_README"]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing integration anchor: {label}")
    return text.replace(old, new, 1)


def append_once(path: Path, marker: str, payload: str) -> None:
    text = path.read_text()
    if marker not in text:
        path.write_text(text.rstrip() + "\n\n" + payload.strip() + "\n")


# Repair two serialization scars in the staged SDK payload. These are artifacts of
# the temporary chunk transport, not part of the SDK design. Keeping this repair here
# means the committed Swift source is canonical even if the staging files are removed.
models_path = Path("Halo/Core/WorkspaceModels.swift")
models = models_path.read_text()
models = models.replace(
    "init(from decoder: Decoder) throws { {",
    "init(from decoder: Decoder) throws {",
)
models = models.replace(
    '        }\nn", issues: &issues) { triggers = decoded }\n        }\n\n        let errors = issues.contains { $0.severity == .error }',
    '        }\n\n        let errors = issues.contains { $0.severity == .error }',
)
# Be defensive if whitespace changed slightly in the staged payload.
models = models.replace(
    'n", issues: &issues) { triggers = decoded }\n        }\n',
    '',
)
models_path.write_text(models)


# Runtime: keep it in the already-compiled WorkspaceStore source, then attach it
# to the existing service lifecycle rather than creating a parallel app runtime.
workspace_path = Path("Halo/Core/WorkspaceStore.swift")
workspace = workspace_path.read_text()
if "// MARK: - Custom CI runtime" not in workspace:
    workspace = workspace.rstrip() + "\n\n" + RUNTIME.strip() + "\n"
if "HaloCustomCIRuntimeStore.shared.attach(to: self)" not in workspace:
    anchor = "        evaluateSchedules(); system.refresh(); audio.refresh(); refreshApps(); updateHotkey(); updateRetroGameHotkey(); updateClipboardCIHotkey()\n        pollMedia()"
    replacement = "        evaluateSchedules(); system.refresh(); audio.refresh(); refreshApps(); updateHotkey(); updateRetroGameHotkey(); updateClipboardCIHotkey()\n        HaloCustomCIRuntimeStore.shared.attach(to: self)\n        pollMedia()"
    workspace = replace_once(workspace, anchor, replacement, "WorkspaceStore.start custom runtime attach")
if "HaloCustomCIRuntimeStore.shared.detach();" not in workspace:
    workspace = replace_once(
        workspace,
        "    func stop() { pendingSave?.cancel();",
        "    func stop() { HaloCustomCIRuntimeStore.shared.detach(); pendingSave?.cancel();",
        "WorkspaceStore.stop custom runtime detach",
    )
workspace_path.write_text(workspace)


# Surface integration: custom packages are one more candidate in Halo's existing
# arbitration. Built-in CI implementations are not rewritten or migrated.
surface_path = Path("Halo/Views/SurfaceView.swift")
surface = surface_path.read_text()
if "// MARK: - Declarative Custom CI renderer" not in surface:
    surface = surface.rstrip() + "\n\n" + RENDERER.strip() + "\n"

surface = surface.replace(
    "private enum ActiveContextInterface: String {\n    case drop, teleprompter, transfer, clipboard, music, bluetooth, retro\n}",
    "private enum ActiveContextInterface: String {\n    case drop, teleprompter, transfer, clipboard, custom, music, bluetooth, retro\n}",
    1,
)
if "@ObservedObject private var customCI = HaloCustomCIRuntimeStore.shared" not in surface:
    surface = replace_once(
        surface,
        "    @ObservedObject private var clipboardCI = ClipboardContextMonitor.shared\n",
        "    @ObservedObject private var clipboardCI = ClipboardContextMonitor.shared\n    @ObservedObject private var customCI = HaloCustomCIRuntimeStore.shared\n",
        "SurfaceView custom runtime observer",
    )
if "@AppStorage(\"HaloDisableCustomCI\") private var disableCustomCI" not in surface:
    surface = replace_once(
        surface,
        "    @AppStorage(\"HaloContextClipboardPriority\") private var clipboardPriority = 68.0\n",
        "    @AppStorage(\"HaloContextClipboardPriority\") private var clipboardPriority = 68.0\n    @AppStorage(\"HaloDisableCustomCI\") private var disableCustomCI = false\n",
        "SurfaceView Custom CI global switch",
    )
if "private var activeCustomCandidate: HaloCustomCICandidate?" not in surface:
    surface = replace_once(
        surface,
        "    private var activeContext: ActiveContextInterface? {\n",
        "    private var activeCustomCandidate: HaloCustomCICandidate? {\n        customCI.activeCandidate(workspace: workspace, globalDisabled: disableCustomCI)\n    }\n    private var activeContext: ActiveContextInterface? {\n",
        "SurfaceView active custom candidate",
    )
if "candidates.append((.custom, custom.priority" not in surface:
    surface = replace_once(
        surface,
        "        if contextOptions.enabled && workspace.media.isPlaying {\n",
        "        if let custom = activeCustomCandidate {\n            candidates.append((.custom, custom.priority, custom.manual ? 100 : 3))\n        }\n        if contextOptions.enabled && workspace.media.isPlaying {\n",
        "SurfaceView custom arbitration candidate",
    )
if "private var customContextActive: Bool" not in surface:
    surface = replace_once(
        surface,
        "    private var clipboardContextActive: Bool { activeContext == .clipboard }\n",
        "    private var clipboardContextActive: Bool { activeContext == .clipboard }\n    private var customContextActive: Bool { activeContext == .custom }\n",
        "SurfaceView custom active flag",
    )

# Custom CIs use the normal notch state machine and therefore do not create a
# separate takeover window. Their closed and opened roots replace normal contents.
surface = surface.replace(
    "        case .clipboard: return false\n        case .none: return false",
    "        case .clipboard: return false\n        case .custom: return false\n        case .none: return false",
    1,
)
surface = surface.replace(
    "        case .clipboard: return false\n        case .none:\n",
    "        case .clipboard: return false\n        case .custom: return false\n        case .none:\n",
    1,
)

# Render Custom CI before the generic tiny-dot fallback so a 16x16 starting notch
# can still publish the package's requested closed width.
custom_closed = """                      if !state.expanded && customContextActive, let candidate = activeCustomCandidate {
                        HaloCustomCISurfaceView(package: candidate.package, surfaceState: state, workspace: workspace)
                      } else if !state.expanded && (state.compactWidth < 48 || state.compactHeight < 16) {"""
if "if !state.expanded && customContextActive, let candidate = activeCustomCandidate" not in surface:
    surface = replace_once(
        surface,
        "                      if !state.expanded && (state.compactWidth < 48 || state.compactHeight < 16) {",
        custom_closed,
        "SurfaceView Custom CI closed renderer",
    )

if "if customContextActive, let candidate = activeCustomCandidate {\n                        HaloCustomCISurfaceView" not in surface:
    surface = replace_once(
        surface,
        "                if state.expanded {\n                    if transferContextActive {",
        "                if state.expanded {\n                    if customContextActive, let candidate = activeCustomCandidate {\n                        HaloCustomCISurfaceView(package: candidate.package, surfaceState: state, workspace: workspace)\n                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)\n                            .transition(.opacity.combined(with: .scale(scale: 0.985)))\n                    } else if transferContextActive {",
        "SurfaceView Custom CI expanded renderer",
    )

# Detailed system values should stay alive while an opened Custom CI is visible.
surface = surface.replace(
    "activeContext == nil || transferContextActive || clipboardContextActive",
    "activeContext == nil || transferContextActive || clipboardContextActive || customContextActive",
)

# Do not clear the package-requested geometry while the Custom CI is the winner.
surface = surface.replace(
    "if !transferContextActive && !clipboardContextActive {",
    "if !transferContextActive && !clipboardContextActive && !customContextActive {",
)

if 'HaloCustomCIOpenRequested' not in surface:
    surface = replace_once(
        surface,
        "        .onReceive(NotificationCenter.default.publisher(for: .init(\"HaloClipboardCIToggle\"))) { _ in\n",
        "        .onReceive(NotificationCenter.default.publisher(for: .init(\"HaloCustomCIOpenRequested\"))) { _ in\n            guard !disableCustomCI else { return }\n            state.collapseTask?.cancel()\n            state.expanded = true\n        }\n        .onReceive(NotificationCenter.default.publisher(for: .init(\"HaloCustomCICloseRequested\"))) { _ in\n            state.contextPreferredSize = nil\n            state.contextPreferredCompactWidth = nil\n            state.contextMinimumExpandedWidth = nil\n            if !state.pinned { state.expanded = false }\n        }\n        .onReceive(NotificationCenter.default.publisher(for: .init(\"HaloClipboardCIToggle\"))) { _ in\n",
        "SurfaceView Custom CI open/close notifications",
    )

surface_path.write_text(surface)


# Settings: leave the existing Available CI grid byte-for-byte alone and place the
# new third-party package controls in a dedicated section directly underneath it.
settings_path = Path("Halo/Views/WorkspaceSettingsView.swift")
settings = settings_path.read_text()
if "private struct HaloCustomCISettingsSection: View" not in settings:
    settings = settings.rstrip() + "\n\n" + SETTINGS.strip() + "\n"
if "            HaloCustomCISettingsSection()\n\n            Section {\n                Label(\"CI can react" not in settings:
    settings = replace_once(
        settings,
        "            Section {\n                Label(\"CI can react to live system context without turning the notch into one giant settings page.\", systemImage: \"rectangle.stack.badge.plus\")",
        "            HaloCustomCISettingsSection()\n\n            Section {\n                Label(\"CI can react to live system context without turning the notch into one giant settings page.\", systemImage: \"rectangle.stack.badge.plus\")",
        "WorkspaceSettings dedicated Custom CI section",
    )
settings_path.write_text(settings)


# Contract tests are inserted into the existing HaloCoreTests class so SwiftPM tests
# exercise the exact validator/binding/trigger types used by the app.
tests_path = Path("Tests/HaloCoreTests.swift")
tests = tests_path.read_text()
if "testCustomCIBindingResolverIsDeterministic" not in tests:
    closing = tests.rfind("\n}")
    if closing < 0:
        raise SystemExit("Could not find HaloCoreTests closing brace")
    tests = tests[:closing] + "\n" + TESTS.rstrip() + tests[closing:]
    tests_path.write_text(tests)


# Public contract + architecture handoff.
append_once(Path("Docs/CISDK.md"), "## Implemented Custom CI SDK 0.1 contract", DOCS)
append_once(Path("Docs/Architecture.md"), "## Custom CI runtime path", ARCH)


# Working starter package for third-party authors.
example = Path("Examples/HelloWorld.haloCI")
example.mkdir(parents=True, exist_ok=True)
(example / "manifest.json").write_text(EXAMPLE_MANIFEST)
(example / "interface.json").write_text(EXAMPLE_INTERFACE)
(example / "triggers.json").write_text(EXAMPLE_TRIGGERS)
(example / "README.md").write_text(EXAMPLE_README)

print("Completed Custom CI runtime, renderer, settings, tests, docs and starter package integration")
