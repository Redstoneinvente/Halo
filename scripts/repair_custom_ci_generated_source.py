from pathlib import Path

path = Path("Halo/Core/WorkspaceModels.swift")
text = path.read_text()

# The staging chunks overlap at one SDK boundary. The completion pass removes the
# duplicated suffix, but an older defensive cleanup also clipped the final `n` from
# `triggers.json`. Restore the canonical decode statement before compiling.
broken = '            if let decoded = decode(HaloCITriggerDocument.self, data: data, path: "triggers.jso\n        let errors = issues.contains { $0.severity == .error }'
fixed = '            if let decoded = decode(HaloCITriggerDocument.self, data: data, path: "triggers.json", issues: &issues) { triggers = decoded }\n        }\n\n        let errors = issues.contains { $0.severity == .error }'

if broken in text:
    text = text.replace(broken, fixed, 1)

# Also handle the raw overlap directly if the completion cleanup changes later.
overlap = '        }\nn", issues: &issues) { triggers = decoded }\n        }\n\n        let errors = issues.contains { $0.severity == .error }'
if overlap in text:
    text = text.replace(overlap, '        }\n\n        let errors = issues.contains { $0.severity == .error }', 1)

text = text.replace('init(from decoder: Decoder) throws { {', 'init(from decoder: Decoder) throws {')

if 'path: "triggers.jso\n' in text or '\nn", issues: &issues) { triggers = decoded }' in text:
    raise SystemExit("Custom CI SDK chunk-boundary repair did not converge")
if 'path: "triggers.json", issues: &issues) { triggers = decoded }' not in text:
    raise SystemExit("Canonical Custom CI trigger decode statement is missing")

path.write_text(text)
print("Repaired Custom CI SDK chunk-boundary serialization artifacts")
