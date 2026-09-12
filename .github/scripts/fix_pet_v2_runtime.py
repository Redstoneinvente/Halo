from pathlib import Path

p = Path('Halo/Views/CompanionSprite.swift')
s = p.read_text()
old = '''    func library(for kind: EIPetKind) -> HaloPetV2Library? {
        library?.species == kind.rawValue ? library : nil
    }
'''
new = '''    func library(for kind: EIPetKind) -> HaloPetV2Library? {
        let species = kind.rawValue.lowercased()
        return library?.species.lowercased() == species ? library : nil
    }
'''
if old not in s:
    raise SystemExit('library lookup block not found')
s = s.replace(old, new, 1)
old2 = '''            guard let self else { return }
            self.loadingSpecies = nil
            self.library = decoded
            self.revision &+= 1
'''
new2 = '''            guard let self else { return }
            // Publish on the next main-run-loop turn. Completing a decode can coincide with a
            // SwiftUI update pass; deferring ObservableObject publication avoids undefined
            // "Publishing changes from within view updates" behaviour.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.loadingSpecies = nil
                self.library = decoded
                self.revision &+= 1
            }
'''
if old2 not in s:
    raise SystemExit('asset publication block not found')
s = s.replace(old2, new2, 1)
p.write_text(s)
print('Applied pet V2 runtime lookup/publication fix')
