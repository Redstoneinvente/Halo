from pathlib import Path
import re

source_path = Path('/tmp/adaptive_widgets_patch.py')
source = source_path.read_text()
pattern = re.compile(r"\n    # Add to Views group\..*?\n    # Add only to the Halo app source phase\.", re.S)
replacement = """
    # Halo keeps source file references directly in its main Halo PBXGroup.
    group_anchor = '\\t\\t\\t\\t00000000000000000000006C /* Views/ModuleViews.swift */,\\n'
    if group_anchor not in project: raise SystemExit('Halo group ModuleViews anchor missing')
    project = project.replace(group_anchor, group_anchor + f'\\t\\t\\t\\t{file_id} /* Views/VisualWorkspaceAdaptiveWidgets.swift */,\\n', 1)

    # Add only to the Halo app source phase."""
source, count = pattern.subn(lambda _: replacement, source, count=1)
if count != 1:
    raise SystemExit('Could not adapt the Xcode project patch block')
source = source.replace('path = VisualWorkspaceAdaptiveWidgets.swift; sourceTree = "<group>";', 'path = Views/VisualWorkspaceAdaptiveWidgets.swift; sourceTree = "<group>";')
namespace = {'__name__': '__main__', '__file__': str(source_path)}
exec(compile(source, str(source_path), 'exec'), namespace)

# Compiler-driven fixes in the new adaptive renderer. Keep these here so the guarded workflow
# always validates exactly the source that will be committed to main.
renderer_path = Path('Halo/Views/VisualWorkspaceAdaptiveWidgets.swift')
renderer = renderer_path.read_text()
renderer = renderer.replace(
    'StrokeStyle(lineWidth: 1.7, lineJoin: .round, lineCap: .round)',
    'StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)'
)
old_thumbnail = '''    var body: some View { Group { if let image { Image(nsImage: image).resizable().scaledToFill() } else { ZStack { Color.primary.opacity(0.04); Image(systemName: "photo").foregroundStyle(.secondary) } } }.task(id: url) { image = await Task.detached(priority: .utility) { NSImage(contentsOf: url) }.value } }
'''
new_thumbnail = '''    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { ZStack { Color.primary.opacity(0.04); Image(systemName: "photo").foregroundStyle(.secondary) } }
        }
        .onAppear { image = NSImage(contentsOf: url) }
        .onChange(of: url) { newURL in image = NSImage(contentsOf: newURL) }
    }
'''
if old_thumbnail not in renderer:
    raise SystemExit('CaptureThumbnail compiler-fix anchor missing')
renderer = renderer.replace(old_thumbnail, new_thumbnail, 1)
renderer_path.write_text(renderer)
