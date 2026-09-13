from pathlib import Path

path = Path('Halo/Views/WidgetSettingsView.swift')
text = path.read_text()
anchor = '                Toggle("Show controls", isOn: value.showControls.withDefault(adaptive.wrappedValue.showControls))\n                Button("Reset This Size to Automatic") { override.wrappedValue = nil }\n'
insert = '''                Toggle("Show controls", isOn: value.showControls.withDefault(adaptive.wrappedValue.showControls))
                Text("Information for this size").font(.caption).foregroundStyle(.secondary)
                ForEach(module.widgetElements.filter { !module.visualAdaptiveAlwaysInformation.contains($0.key) }) { descriptor in
                    Toggle(descriptor.title, isOn: Binding(get: {
                        let hidden = value.wrappedValue.hiddenInformation ?? adaptive.wrappedValue.hiddenInformation
                        return !hidden.contains(descriptor.key)
                    }, set: { enabled in
                        var hidden = value.wrappedValue.hiddenInformation ?? adaptive.wrappedValue.hiddenInformation
                        if enabled { hidden.removeAll { $0 == descriptor.key } }
                        else if !hidden.contains(descriptor.key) { hidden.append(descriptor.key) }
                        value.wrappedValue.hiddenInformation = hidden
                    }))
                }
                Button("Reset This Size to Automatic") { override.wrappedValue = nil }
'''
if anchor not in text:
    raise SystemExit('Per-size adaptive override anchor not found')
text = text.replace(anchor, insert, 1)
path.write_text(text)
print('Per-size information overrides added')
