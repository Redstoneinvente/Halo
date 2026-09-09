import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SurfaceView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var state: SurfaceState
    @ObservedObject var workspace: WorkspaceStore
    private var theme: Theme { state.theme }
    private var layout: WorkspaceLayout { state.layoutOverride ?? workspace.settings.layout }
    private var contour: HaloContour {
        HaloContour(kind: layout.appearance.surface.shape, radius: theme.cornerRadius,
                    topRadius: layout.appearance.surface.topRadius, bottomRadius: layout.appearance.surface.bottomRadius,
                    shoulder: layout.appearance.surface.shoulder)
    }
    @State private var targeted = false
    private var accent: Color { Color(hue: theme.tint, saturation: 0.65, brightness: 1) }
    var body: some View {
        VStack(spacing: 0) {
            Group {
              if !state.expanded && (state.renderSize.width < 100 || state.compactHeight < 28) {
                Circle().fill(store.deadline == nil ? accent : .green).frame(width: 6, height: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
              } else { HStack {
                Circle().fill(store.deadline == nil ? accent : .green).frame(width: 7, height: 7)
                Spacer()
                Image(systemName: state.expanded ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .bold))
              } }
            }
            .padding(.horizontal, state.renderSize.width < 100 ? 0 : max(16, layout.appearance.surface.shoulder + 8))
            .frame(height: state.expanded ? max(40, state.compactHeight) : state.compactHeight)
            .contentShape(Rectangle())
            .onTapGesture { state.expanded.toggle() }
            .accessibilityLabel("Toggle Halo dashboard")
            .accessibilityAddTraits(.isButton)
            if state.expanded {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Your space, within reach.").font(.headline)
                            Text("HALO / PERSONAL WORKSPACE").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(accent)
                        }
                        Spacer()
                        Button { state.pinned.toggle() } label: { Image(systemName: state.pinned ? "pin.fill" : "pin") }
                            .help("Keep expanded").accessibilityLabel("Keep expanded")
                    }
                    ScrollView {
                        VStack(spacing: layout.appearance.spacing) {
                            ForEach(layout.normalizedOrder().filter { layout.enabled.contains($0) }) { module in
                                switch module {
                                case .clock: clock
                                case .timer: timer
                                case .shelf: shelf
                                default: ModuleRegistry().view(for: module, store: store)
                                }
                            }
                        }
                    }
                    HStack {
                        Label("On-device. No account.", systemImage: "lock.shield").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Button("Settings") { NotificationCenter.default.post(name: Notification.Name("HaloOpenSettings"), object: nil) }
                    }
                }.padding(.horizontal, max(20, layout.appearance.surface.shoulder + 12)).padding(.vertical, 20).transition(.opacity)
            }
        }
        .frame(width: state.renderSize.width, height: state.renderSize.height, alignment: .top)
        .background {
            SurfaceBackground(appearance: layout.appearance, theme: theme, expanded: state.expanded, system: workspace.system)
        }
        .clipShape(contour)
        .contentShape(contour)
        .overlay(contour.stroke(targeted ? accent : .white.opacity(0.12), lineWidth: 1))
        .foregroundStyle(.white).preferredColorScheme(.dark)
        .buttonStyle(.borderless)
        .contextMenu {
            Button(state.pinned ? "Unpin" : "Keep open") { state.pinned.toggle() }
            ForEach(workspace.settings.profiles) { profile in Button(profile.name) { workspace.apply(profile) } }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in store.expireFiles() }
        .onHover { state.hover($0, enabled: store.configuration.hoverToExpand) }
        .onChange(of: targeted) { active in
            if active { state.collapseTask?.cancel(); state.expanded = true }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $targeted) { providers in
            state.expanded = true
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in store.addFiles([url]) }
                }
            }
            return !providers.isEmpty
        }
    }
    private var clock: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(context.date, format: .dateTime.hour().minute()).font(.system(size: 30, weight: .light, design: .rounded))
                Spacer()
                Text(context.date, format: .dateTime.weekday(.wide).month().day()).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(12).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
    private var timer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Focus", systemImage: "timer").font(.subheadline.bold())
                Spacer()
                if let deadline = store.deadline {
                    Text(deadline, style: .timer).monospacedDigit()
                } else if store.pausedSeconds > 0 {
                    Text("Paused · \(Int(store.pausedSeconds))s").font(.caption)
                } else if store.finished { Text("Session complete").foregroundStyle(.green) }
                else { Text("Make room for deep work").font(.caption).foregroundStyle(.secondary) }
            }
            HStack {
                if store.deadline != nil || store.pausedSeconds > 0 {
                    Button(store.deadline == nil ? "Resume" : "Pause") { store.pauseResume() }
                    Button("Reset") { store.resetTimer() }
                } else {
                    ForEach([5, 15, 25], id: \.self) { minutes in
                        Button("\(minutes) min") { store.startTimer(minutes: minutes) }
                    }
                }
            }.buttonStyle(.bordered)
        }.padding(12).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
    private var shelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("File shelf", systemImage: "tray").font(.subheadline.bold())
                Spacer()
                Button { store.chooseFiles() } label: { Image(systemName: "plus") }.accessibilityLabel("Add files")
            }
            if store.files.isEmpty {
                Text("Drop files here. Originals stay untouched.").font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
            }
            ForEach(store.files, id: \.self) { url in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 24, height: 24)
                    VStack(alignment: .leading) {
                        Text(url.lastPathComponent).font(.caption).lineLimit(1)
                        Text(fileDetail(url)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button { store.toggleFilePin(url) } label: { Image(systemName: store.pinnedFiles.contains(url) ? "pin.fill" : "pin") }.help("Keep this file on the shelf")
                    Button { store.shelfPreview.show(url) } label: { Image(systemName: "eye") }.help("Quick Look")
                    Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }.help("Reveal in Finder")
                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "arrow.up.forward.app") }.help("Open file")
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    Button { store.removeFile(url) } label: { Image(systemName: "xmark") }.help("Remove reference from shelf")
                }.onDrag { NSItemProvider(object: url as NSURL) }
            }
        }.padding(12).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
    private func fileDetail(_ url: URL) -> String {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else { return "Original unavailable" }
        if values.isDirectory == true { return "Folder" }
        return url.pathExtension.uppercased() + " · " + ByteCountFormatter.string(fromByteCount: Int64(values.fileSize ?? 0), countStyle: .file)
    }
}
