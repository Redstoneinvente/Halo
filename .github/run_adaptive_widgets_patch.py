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
source, count = pattern.subn(replacement, source, count=1)
if count != 1:
    raise SystemExit('Could not adapt the Xcode project patch block')
namespace = {'__name__': '__main__', '__file__': str(source_path)}
exec(compile(source, str(source_path), 'exec'), namespace)
