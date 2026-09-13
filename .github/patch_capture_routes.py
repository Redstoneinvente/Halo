from pathlib import Path
import re

# One persistent Capture service.
p = Path('Halo/Core/WorkspaceStore.swift')
s = p.read_text()
s = s.replace('    let capture = CaptureService()\n', '    let capture = CaptureService.shared\n', 1)
p.write_text(s)

# Visual Workspace routes Capture directly to the new shared footprint UI.
p = Path('Halo/Views/VisualWorkspaceAdaptiveWidgets.swift')
s = p.read_text()
s = s.replace('''        case .capture:\n            VisualAdaptiveCaptureView(service: workspace.capture, store: store)''',
              '''        case .capture:\n            CaptureWorkspaceView(service: workspace.capture, store: store)''', 1)
p.write_text(s)

# Normal opened-notch Capture uses the exact same UI/service instead of a second lightweight implementation.
p = Path('Halo/Views/ModuleViews.swift')
s = p.read_text()
start = s.find('struct CaptureModuleView: View {')
end = s.find('\nstruct MediaModuleView: View {', start)
if start < 0 or end < 0:
    raise SystemExit('CaptureModuleView boundaries not found')
wrapper = '''struct CaptureModuleView: View {\n    @ObservedObject var service: CaptureService\n    @ObservedObject var store: AppStore\n    var body: some View { CaptureWorkspaceView(service: service, store: store) }\n}\n'''
s = s[:start] + wrapper + s[end:]
p.write_text(s)
