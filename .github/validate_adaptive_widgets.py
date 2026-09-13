from pathlib import Path
import subprocess
import sys

NEW_RENDERER = 'Halo/Views/VisualWorkspaceAdaptiveWidgets.swift'
EXPECTED_TRACKED = {
    'Halo/Core/WidgetModels.swift',
    'Halo/Views/ModuleViews.swift',
    'Halo/Views/SurfaceView.swift',
    'Halo/Core/AppStore.swift',
    'Halo/Core/WorkspaceStore.swift',
    'Halo/Services/CaptureService.swift',
    'Halo/Services/Integrations.swift',
    'Halo/Views/WidgetSettingsView.swift',
    'Halo.xcodeproj/project.pbxproj',
}
CHANGED_SWIFT = [
    'WidgetModels.swift','VisualWorkspaceAdaptiveWidgets.swift','ModuleViews.swift','SurfaceView.swift',
    'AppStore.swift','WorkspaceStore.swift','CaptureService.swift','Integrations.swift','WidgetSettingsView.swift'
]
WIDGETS = ['timer','media','audio','clipboard','system','launcher','activities','notes','capture','stopwatch']

def family(c, r):
    c=max(1,min(8,c)); r=max(1,min(4,r))
    if c == 1 and r == 1: return 'micro'
    if r == 1: return 'compact' if c == 2 else 'horizontal'
    if c == 1: return 'vertical'
    if c == 2 and r == 2: return 'compact'
    if c <= 3 and r <= 2: return 'standard'
    if c <= 2 and r >= 3: return 'vertical'
    if c >= 7 and r == 4: return 'hero'
    if c >= 6 and r >= 3: return 'dashboard'
    if c >= 4 and r >= 3: return 'expanded'
    if c >= 4 and r == 2: return 'expanded'
    if c >= 3 and r >= 3: return 'expanded'
    return 'standard'

def preflight():
    changed = set(subprocess.check_output(['git','diff','--name-only'], text=True).splitlines())
    if changed != EXPECTED_TRACKED:
        raise SystemExit(f'Unexpected tracked production scope: {sorted(changed)}')
    if not Path(NEW_RENDERER).is_file():
        raise SystemExit('Adaptive renderer file is missing')
    status = subprocess.check_output(['git','status','--porcelain','--',NEW_RENDERER], text=True).strip()
    if not status.startswith('?? '):
        raise SystemExit(f'Adaptive renderer should be a new production file, got status: {status!r}')
    print('Production scope verified, including new adaptive renderer.')
    expected = {(c,r) for c in range(1,9) for r in range(1,5)}
    for widget in WIDGETS:
        seen = {(c,r): family(c,r) for c,r in expected}
        assert len(seen) == 32
        assert seen[(1,1)] == 'micro'
        assert seen[(2,1)] == 'compact'
        assert seen[(4,1)] == 'horizontal'
        assert seen[(1,4)] == 'vertical'
        assert seen[(2,2)] == 'compact'
        assert seen[(8,4)] == 'hero'
        assert len({seen[(4,1)], seen[(2,2)], seen[(1,4)]}) == 3
        print(widget, ', '.join(f'{c}x{r}:{seen[(c,r)]}' for c,r in [(1,1),(2,1),(4,1),(1,4),(2,2),(4,2),(4,4),(8,4)]))
    print('320 footprint cases covered; key aspect-ratio distinctions verified.')
    module = Path('Halo/Views/ModuleViews.swift').read_text()
    if 'VisualWorkspaceCalendarView(service: workspace.calendar)' not in module:
        raise SystemExit('Calendar dedicated renderer missing')
    if 'VisualWorkspaceAdaptiveModuleView(module: .calendar' in module:
        raise SystemExit('Calendar was incorrectly routed into adaptive suite')
    if 'VisualWorkspaceAdaptiveModuleView(module: .clock' in module:
        raise SystemExit('Clock was incorrectly routed into adaptive suite')
    print('Clock/Calendar scope guard passed.')

def scan_log(path):
    log = Path(path).read_text(errors='replace')
    bad = [line for line in log.splitlines() if ' error:' in line and any('/'+name+':' in line for name in CHANGED_SWIFT)]
    if bad:
        print('\n'.join(bad))
        raise SystemExit('Compiler error reported in adaptive-widget production scope')
    print('No preflight compiler errors reported in changed Swift files.')

if __name__ == '__main__':
    if len(sys.argv) == 1 or sys.argv[1] == 'preflight': preflight()
    elif sys.argv[1] == 'scan-log' and len(sys.argv) == 3: scan_log(sys.argv[2])
    else: raise SystemExit('usage: validate_adaptive_widgets.py [preflight|scan-log <path>]')
