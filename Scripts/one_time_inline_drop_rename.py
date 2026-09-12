from pathlib import Path

path = Path('Halo/NotchEngine/DisplayClock.swift')
text = path.read_text()

def replace_once(old, new):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Expected exactly one match, found {count}: {old[:120]!r}')
    text = text.replace(old, new, 1)

replace_once('''@MainActor
private final class HaloDropZoneRuntimeModel: ObservableObject {
    @Published var hoveredZone: Int?
    @Published var itemCount = 1
    @Published var result: String?
}
''', '''@MainActor
private final class HaloDropZoneRuntimeModel: ObservableObject {
    @Published var hoveredZone: Int?
    @Published var itemCount = 1
    @Published var result: String?
    @Published var renameZoneID: UUID?
    @Published var renameURLs: [URL] = []
    @Published var renameText = ""

    var renameCommitHandler: ((String) -> Void)?
    var renameCancelHandler: (() -> Void)?

    func clearRename() {
        renameZoneID = nil
        renameURLs = []
        renameText = ""
        renameCommitHandler = nil
        renameCancelHandler = nil
    }
}
''')

replace_once('''private struct HaloDropZoneBoardView: View {
    @ObservedObject var settings: HaloDropZoneSettingsStore
    @ObservedObject var model: HaloDropZoneRuntimeModel

    var body: some View {
''', '''private struct HaloDropZoneBoardView: View {
    @ObservedObject var settings: HaloDropZoneSettingsStore
    @ObservedObject var model: HaloDropZoneRuntimeModel
    @FocusState private var renameFieldFocused: Bool

    var body: some View {
''')

replace_once('''            .foregroundStyle(.white)
        }
    }

    private func header(configuration: HaloDropZoneConfiguration) -> some View {
''', '''            .foregroundStyle(.white)
        }
        .onChange(of: model.renameZoneID) { zoneID in
            guard zoneID != nil else {
                renameFieldFocused = false
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                renameFieldFocused = true
            }
        }
    }

    private func header(configuration: HaloDropZoneConfiguration) -> some View {
''')

replace_once('''                HStack(spacing: 6) {
                    Image(systemName: model.hoveredZone == nil ? "cursorarrow.motionlines" : "arrow.down.circle.fill")
                        .font(.system(size: 8.5, weight: .semibold))
                    Text(model.hoveredZone == nil ? "Move over an action" : "Release to run this action")
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                }
                .foregroundStyle(model.hoveredZone == nil ? Color.white.opacity(0.36) : Color.white.opacity(0.70))
''', '''                HStack(spacing: 6) {
                    Image(systemName: model.renameZoneID != nil ? "pencil" : (model.hoveredZone == nil ? "cursorarrow.motionlines" : "arrow.down.circle.fill"))
                        .font(.system(size: 8.5, weight: .semibold))
                    Text(model.renameZoneID != nil ? "Type a new name · Return to confirm · Esc to cancel" : (model.hoveredZone == nil ? "Move over an action" : "Release to run this action"))
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                }
                .foregroundStyle(model.renameZoneID != nil ? Color.white.opacity(0.72) : (model.hoveredZone == nil ? Color.white.opacity(0.36) : Color.white.opacity(0.70)))
''')

replace_once('''                }
                .padding(compact ? 8 : 11)
            }
            .overlay(
''', '''                }
                .padding(compact ? 8 : 11)
                .opacity(model.renameZoneID == zone.id ? 0 : 1)
                .allowsHitTesting(model.renameZoneID != zone.id)

                if model.renameZoneID == zone.id {
                    renameEditor(zone: zone, accent: accent, compact: compact)
                        .padding(compact ? 8 : 11)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .overlay(
''')

replace_once('''    }
}

@MainActor
private final class HaloDropZoneHostView: NSView {
''', '''    }

    private func renameEditor(zone: HaloDropZone, accent: Color, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 9) {
            HStack(spacing: 7) {
                Image(systemName: "pencil")
                    .font(.system(size: compact ? 11 : 13, weight: .semibold))
                    .foregroundStyle(accent)
                Text(model.renameURLs.count > 1 ? "Rename \\(model.renameURLs.count) items" : "Rename")
                    .font(.system(size: compact ? 10 : 12, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
                Button {
                    model.renameCancelHandler?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.48))
                }
                .buttonStyle(.plain)
                .help("Cancel rename")
            }

            HStack(spacing: 5) {
                TextField("New name", text: $model.renameText)
                    .textFieldStyle(.plain)
                    .font(.system(size: compact ? 10 : 12, weight: .medium, design: .rounded))
                    .focused($renameFieldFocused)
                    .onSubmit { model.renameCommitHandler?(model.renameText) }
                    .onExitCommand { model.renameCancelHandler?() }
                    .padding(.horizontal, compact ? 7 : 9)
                    .padding(.vertical, compact ? 5 : 7)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(accent.opacity(0.55), lineWidth: 1)
                    )

                if model.renameURLs.count == 1,
                   let ext = model.renameURLs.first?.pathExtension,
                   !ext.isEmpty {
                    Text(".\\(ext)")
                        .font(.system(size: compact ? 8.5 : 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.42))
                }

                Button {
                    model.renameCommitHandler?(model.renameText)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: compact ? 15 : 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .disabled(model.renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Rename")
            }

            if !compact {
                Text(model.renameURLs.count > 1 ? "The same base name is applied and duplicates are numbered automatically." : "The current extension is preserved unless you type a different one.")
                    .font(.system(size: 7.8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.34))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@MainActor
private final class HaloDropZoneHostView: NSView {
''')

replace_once('''        model.hoveredZone = nil
        model.result = nil
        dropHandled = false
''', '''        model.hoveredZone = nil
        model.result = nil
        model.clearRename()
        dropHandled = false
''')

replace_once('''        let zone = settings.configuration.zones[index]
        if zone.action == .rename {
            dropHandled = true
            model.result = "Renaming…"
            let shelf = originalDropHandler
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self, weak target] in
                guard let self else { return }
                let result = HaloDropZoneActionExecutor.perform(
                    zone: zone,
                    urls: urls,
                    shelfHandler: shelf,
                    closeHandler: { target?.dragStateHandler?(false, 0) }
                )
                self.completeDrop(result: result)
            }
            return
        }
''', '''        let zone = settings.configuration.zones[index]
        if zone.action == .rename {
            beginInlineRename(zone: zone, urls: urls, target: target)
            return
        }
''')

replace_once('''    private func restoreParentDropHandler() {
        target?.dropHandler = originalDropHandler
    }
''', '''    private func beginInlineRename(zone: HaloDropZone, urls: [URL], target: any HaloGlobalDropTarget) {
        let accepted = urls.filter { zone.accepts.accepts($0) }
        guard !accepted.isEmpty else {
            completeDrop(result: "Nothing matched this zone's \\(zone.accepts.rawValue.lowercased()) filter.")
            return
        }

        dropHandled = true
        model.result = nil
        model.hoveredZone = nil
        model.renameURLs = accepted
        model.renameZoneID = zone.id
        model.renameText = accepted.first?.deletingPathExtension().lastPathComponent ?? ""

        let shelf = originalDropHandler
        model.renameCommitHandler = { [weak self, weak target] requestedName in
            guard let self else { return }
            let name = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                self.model.result = "Enter a new name"
                return
            }

            var runtimeZone = zone
            runtimeZone.parameter = name
            self.model.clearRename()
            let result = HaloDropZoneActionExecutor.perform(
                zone: runtimeZone,
                urls: accepted,
                shelfHandler: shelf,
                closeHandler: {}
            )
            target?.dragStateHandler?(false, 0)
            self.completeDrop(result: result)
        }
        model.renameCancelHandler = { [weak self, weak target] in
            guard let self else { return }
            self.model.clearRename()
            target?.dragStateHandler?(false, 0)
            self.completeDrop(result: "Rename cancelled")
        }

        if let window = targetView?.window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func restoreParentDropHandler() {
        target?.dropHandler = originalDropHandler
    }
''')

replace_once('''            case .rename:
                let template = zone.parameter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "{name}-renamed" : zone.parameter
                try accepted.forEach { try rename($0, template: template) }
                outcome = accepted.count == 1 ? "Renamed item" : "Renamed \\(accepted.count) items"
''', '''            case .rename:
                let requestedName = zone.parameter.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !requestedName.isEmpty else { return "Enter a new name." }
                try accepted.forEach { try rename($0, newName: requestedName) }
                outcome = accepted.count == 1 ? "Renamed item" : "Renamed \\(accepted.count) items"
''')

start = text.index('    private static func rename(_ url: URL, template: String) throws {')
end = text.index('\n    private static func launchDittoCompress', start)
old = text[start:end]
new = '''    private static func rename(_ url: URL, newName requestedName: String) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let ext = url.pathExtension
        var name = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        name = name.replacingOccurrences(of: "/", with: "-")
        name = name.replacingOccurrences(of: ":", with: "-")
        guard !name.isEmpty else { throw CocoaError(.fileWriteInvalidFileName) }
        if !ext.isEmpty && URL(fileURLWithPath: name).pathExtension.isEmpty {
            name += "." + ext
        }

        let directory = url.deletingLastPathComponent()
        var destination = directory.appendingPathComponent(name)
        if destination.standardizedFileURL == url.standardizedFileURL { return }
        if FileManager.default.fileExists(atPath: destination.path) {
            destination = uniqueURL(
                in: directory,
                stem: destination.deletingPathExtension().lastPathComponent,
                extension: destination.pathExtension
            )
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var moveError: Error?
        coordinator.coordinate(
            writingItemAt: url,
            options: .forMoving,
            writingItemAt: destination,
            options: [],
            error: &coordinationError
        ) { source, coordinatedDestination in
            do {
                try FileManager.default.moveItem(at: source, to: coordinatedDestination)
            } catch {
                moveError = error
            }
        }
        if let moveError { throw moveError }
        if let coordinationError { throw coordinationError }
    }
'''
text = text[:start] + new + text[end:]

replace_once('''        case .rename:
            acceptance = .all; subtitle = "Rename with a template"; parameter = "{name}-renamed"
''', '''        case .rename:
            acceptance = .all; subtitle = "Enter a new name after dropping"; parameter = ""
''')

replace_once('''                if zone.wrappedValue.action == .rename {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rename template").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("{name}-renamed", text: zone.parameter)
                        Text("Available: {name}, {ext}, {date}").font(.caption2).foregroundStyle(.secondary)
                    }
                } else if zone.wrappedValue.action == .copyFolder {
''', '''                if zone.wrappedValue.action == .rename {
                    Label("Drop an item here and this zone becomes a rename field. Type the new name, then press Return.", systemImage: "text.cursor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                } else if zone.wrappedValue.action == .copyFolder {
''')

replace_once('''                if action == .rename && configuration.zones[index].parameter.isEmpty { configuration.zones[index].parameter = "{name}-renamed" }
                if action != .rename && action != .copyFolder { configuration.zones[index].parameter = "" }
''', '''                if action != .copyFolder { configuration.zones[index].parameter = "" }
''')

path.write_text(text)
print('inline rename patch applied')
