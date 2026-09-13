from pathlib import Path
p = Path('Halo/Views/WidgetSettingsView.swift')
s = p.read_text()

old = '''        case .capture:\n            Section("Capture & OCR") {\n                Toggle("Show permission hint", isOn: content.captureShowHelp)\n                Toggle("Show capture controls", isOn: content.showControls)\n                Toggle("Show progress / errors", isOn: content.showStatus)\n                PreciseSlider(title: "OCR text lines", value: Binding(get: { Double(content.wrappedValue.captureTextLines) }, set: { content.wrappedValue.captureTextLines = Int($0) }), range: 2...40, step: 1)\n            }'''
if old not in s:
    raise SystemExit('Normal Capture settings anchor not found')
s = s.replace(old, '''        case .capture:\n            CaptureSettingsControls()''', 1)

old = '''        case .capture:\n            Section("Capture") {\n                Picker("Primary action", selection: adaptive.capturePrimaryAction) { ForEach(VisualCapturePrimaryAction.allCases) { Text($0.rawValue).tag($0) } }\n                Toggle("Recent capture", isOn: adaptive.captureShowRecent)\n                if adaptive.wrappedValue.captureShowRecent { PreciseSlider(title: "Thumbnail size", value: Binding(get: { Double(adaptive.wrappedValue.captureThumbnailSize) }, set: { adaptive.wrappedValue.captureThumbnailSize = CGFloat($0) }), range: 64...320, step: 4, suffix: "pt") }\n                Toggle("OCR result", isOn: adaptive.captureShowOCR)\n                Text("Only the existing interactive region capture and image OCR paths are exposed; unsupported full-screen/editor tooling is not faked.").font(.caption2).foregroundStyle(.secondary)\n            }'''
if old not in s:
    raise SystemExit('Visual Workspace Capture settings anchor not found')
s = s.replace(old, '''        case .capture:\n            CaptureSettingsControls()''', 1)

old = '''    @ViewBuilder private var addMenu: some View {\n        Menu("Widget") { ForEach(ModuleID.allCases) { module in Button(module.title) { addModule(module) } } }\n        Menu("Lightweight element") { ForEach(OpenNotchElementKind.allCases) { element in Button(element.title) { addElement(element) } }\n    }'''
if old not in s:
    raise SystemExit('Lightweight element menu anchor not found')
s = s.replace(old, '''    @ViewBuilder private var addMenu: some View {\n        Menu("Widget") { ForEach(ModuleID.allCases) { module in Button(module.title) { addModule(module) } } }\n    }''', 1)

p.write_text(s)
