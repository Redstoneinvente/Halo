from pathlib import Path

path = Path("Halo/Views/WidgetSettingsView.swift")
text = path.read_text()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f"{label}: already applied")
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    print(f"{label}: patched")
    return text.replace(old, new, 1)


text = replace_once(
    text,
    '''            GeometryReader { proxy in
                editorLayout(availableSize: proxy.size)
            }
''',
    '''            GeometryReader { proxy in
                editorLayout(availableSize: proxy.size)
            }
            .clipped()
''',
    "clip embedded editor to its content bounds",
)

text = replace_once(
    text,
    '''        if !showsCloseButton && availableSize.width < 900 {
            VSplitView {
                editorCanvasPane
                    .frame(minHeight: 350)
                inspector
                    .frame(minHeight: 250, idealHeight: 320)
            }
''',
    '''        if !showsCloseButton && availableSize.width < 900 {
            let desiredCanvasHeight = min(420, max(180, availableSize.height * 0.55))
            let canvasHeight = min(desiredCanvasHeight, max(120, availableSize.height - 140))
            VStack(spacing: 0) {
                editorCanvasPane
                    .frame(height: canvasHeight)
                    .clipped()
                Divider()
                inspector
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .frame(width: availableSize.width, height: availableSize.height, alignment: .top)
            .clipped()
''',
    "replace overflowing narrow VSplitView",
)

text = replace_once(
    text,
    '''        VStack(spacing: 0) {
            toolbar
            Divider()
''',
    '''        VStack(spacing: 0) {
            toolbar
                .fixedSize(horizontal: false, vertical: true)
            Divider()
''',
    "keep toolbar controls from vertical compression",
)

path.write_text(text)
print("Visual Workspace resize overlap fix applied.")
