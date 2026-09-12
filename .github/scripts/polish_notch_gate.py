from pathlib import Path

router = Path('Halo/Core/ExtensionContracts.swift')
app = Path('Halo/App/HaloApp.swift')

s = router.read_text()
s = s.replace('''        .onDisappear {
            if !account.isSignedIn || !license.state.isValid { surfaceState.contextPreferredSize = nil }
        }
''', '''        .onDisappear {
            surfaceState.contextPreferredSize = nil
        }
''', 1)
router.write_text(s)

s = app.read_text()
start = s.find('\n#if false\n@MainActor\nprivate struct HaloCommercialWelcomeView: View {')
end_marker = '\n#endif\n\nenum HaloHUDKeys {'
end = s.find(end_marker, start)
if start == -1 or end == -1:
    raise SystemExit('compiled-out legacy welcome block not found')
s = s[:start] + '\n\nenum HaloHUDKeys {' + s[end + len(end_marker):]
app.write_text(s)

print('Polished notch commercial gate transition and removed legacy welcome window')
