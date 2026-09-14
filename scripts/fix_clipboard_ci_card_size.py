from pathlib import Path

path = Path("Halo/Views/WorkspaceSettingsView.swift")
text = path.read_text()

old = '''        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "doc.on.clipboard.fill")
'''

new = '''        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.24), Color.black.opacity(0.96)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 7) {
                            Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                            Text("COPIED")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                            Spacer()
                            Text("JUST NOW")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.38))
                        }

                        Text("https://halo.redstoneinvente.com")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        HStack(spacing: 7) {
                            Label("Open", systemImage: "arrow.up.forward.app")
                            Label("Search", systemImage: "magnifyingglass")
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.07), in: Capsule())
                    }
                    .padding(14)
                }
                .frame(height: 112)

                HStack {
                    Image(systemName: "doc.on.clipboard.fill")
'''

if old not in text:
    raise SystemExit("Clipboard card insertion point not found")

text = text.replace(old, new, 1)
path.write_text(text)
print("Added standard 112pt Clipboard CI preview panel")
