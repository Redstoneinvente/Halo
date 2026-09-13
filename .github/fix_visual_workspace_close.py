from pathlib import Path

path = Path('Halo/Views/WidgetSettingsView.swift')
text = path.read_text()

old_body = '''    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                toolbar
                Divider()
                ScrollView([.horizontal, .vertical]) { preview.padding(26).frame(minWidth: 640, minHeight: 560) }
            }.frame(minWidth: 650)
            inspector.frame(minWidth: 320, idealWidth: 380, maxWidth: 430)
        }
        .onAppear { materialize(); calendarSources.refresh() }
    }
'''

new_body = '''    var body: some View {
        VStack(spacing: 0) {
            visualWorkspaceHeader
            Divider()
            HSplitView {
                VStack(spacing: 0) {
                    toolbar
                    Divider()
                    ScrollView([.horizontal, .vertical]) { preview.padding(26).frame(minWidth: 640, minHeight: 560) }
                }.frame(minWidth: 650)
                inspector.frame(minWidth: 320, idealWidth: 380, maxWidth: 430)
            }
        }
        .onAppear { materialize(); calendarSources.refresh() }
    }

    private var visualWorkspaceHeader: some View {
        HStack(spacing: 10) {
            Label("Visual Workspace", systemImage: "rectangle.3.group")
                .font(.headline)
            Text(opened.preset.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 16)
            Button { dismiss() } label: {
                Label("Close", systemImage: "xmark")
            }
            .keyboardShortcut(.cancelAction)
            .help("Close Visual Workspace")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .zIndex(1000)
    }
'''

if old_body not in text:
    raise SystemExit('Visual Workspace body anchor not found')
text = text.replace(old_body, new_body, 1)

old_close = '''            Spacer()
            Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title3) }.buttonStyle(.plain).help("Close editor")
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
'''
if old_close not in text:
    raise SystemExit('Old clipped toolbar close controls not found')
text = text.replace(old_close, '            Spacer(minLength: 0)\n', 1)

path.write_text(text)
print('Pinned Visual Workspace close control above split view.')
