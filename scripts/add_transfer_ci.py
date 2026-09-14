from pathlib import Path

surface = Path('Halo/Views/SurfaceView.swift')
s = surface.read_text()

s = s.replace('import SwiftUI\nimport AppKit\n', 'import SwiftUI\nimport AppKit\nimport Darwin\n', 1)

anchor = 'struct SurfaceViewportView: View {'
if anchor not in s:
    raise SystemExit('Surface viewport anchor missing')

transfer_code = r'''
// MARK: - Transfer Context Interface

@MainActor
final class TransferActivityMonitor: ObservableObject {
    static let shared = TransferActivityMonitor()

    @Published private(set) var downloadBytesPerSecond: Double = 0
    @Published private(set) var uploadBytesPerSecond: Double = 0
    @Published private(set) var peakDownloadBytesPerSecond: Double = 0
    @Published private(set) var peakUploadBytesPerSecond: Double = 0
    @Published private(set) var sessionDownloadedBytes: Double = 0
    @Published private(set) var sessionUploadedBytes: Double = 0
    @Published private(set) var sessionStartedAt: Date?
    @Published private(set) var isActive = false
    @Published private(set) var direction = "Idle"
    @Published private(set) var downloadHistory: [Double] = []
    @Published private(set) var uploadHistory: [Double] = []

    private var timer: Timer?
    private var previousBytes: (received: UInt64, sent: UInt64)?
    private var previousDate = Date()
    private var lastBusyDate = Date.distantPast
    private var busySamples = 0

    private init() {
        previousBytes = networkByteTotals()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func preference(_ key: String, fallback: Double) -> Double {
        guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
        return UserDefaults.standard.double(forKey: key)
    }

    private func preference(_ key: String, fallback: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func sample() {
        let now = Date()
        let totals = networkByteTotals()
        guard let previousBytes else {
            self.previousBytes = totals
            previousDate = now
            return
        }
        self.previousBytes = totals
        let elapsed = max(0.1, now.timeIntervalSince(previousDate))
        previousDate = now

        let receivedDelta = totals.received >= previousBytes.received ? totals.received - previousBytes.received : 0
        let sentDelta = totals.sent >= previousBytes.sent ? totals.sent - previousBytes.sent : 0
        downloadBytesPerSecond = Double(receivedDelta) / elapsed
        uploadBytesPerSecond = Double(sentDelta) / elapsed

        let historyLimit = 60
        downloadHistory.append(downloadBytesPerSecond)
        uploadHistory.append(uploadBytesPerSecond)
        if downloadHistory.count > historyLimit { downloadHistory.removeFirst(downloadHistory.count - historyLimit) }
        if uploadHistory.count > historyLimit { uploadHistory.removeFirst(uploadHistory.count - historyLimit) }

        let threshold = max(0.01, preference("HaloContextTransferThresholdMBps", fallback: 0.35)) * 1_000_000
        let reactDownloads = preference("HaloContextTransferReactDownloads", fallback: true)
        let reactUploads = preference("HaloContextTransferReactUploads", fallback: true)
        let downloadBusy = reactDownloads && downloadBytesPerSecond >= threshold
        let uploadBusy = reactUploads && uploadBytesPerSecond >= threshold
        let busy = downloadBusy || uploadBusy

        if downloadBusy && uploadBusy { direction = "Uploading + Downloading" }
        else if downloadBusy { direction = "Downloading" }
        else if uploadBusy { direction = "Uploading" }
        else if isActive { direction = downloadBytesPerSecond >= uploadBytesPerSecond ? "Downloading" : "Uploading" }
        else { direction = "Idle" }

        if busy {
            busySamples += 1
            lastBusyDate = now
            if !isActive && busySamples >= 2 {
                isActive = true
                sessionStartedAt = now
                sessionDownloadedBytes = 0
                sessionUploadedBytes = 0
                peakDownloadBytesPerSecond = 0
                peakUploadBytesPerSecond = 0
            }
        } else {
            busySamples = 0
        }

        if isActive {
            sessionDownloadedBytes += Double(receivedDelta)
            sessionUploadedBytes += Double(sentDelta)
            peakDownloadBytesPerSecond = max(peakDownloadBytesPerSecond, downloadBytesPerSecond)
            peakUploadBytesPerSecond = max(peakUploadBytesPerSecond, uploadBytesPerSecond)
            let linger = max(0, preference("HaloContextTransferLingerSeconds", fallback: 2.5))
            if !busy && now.timeIntervalSince(lastBusyDate) > linger {
                isActive = false
                direction = "Idle"
                sessionStartedAt = nil
            }
        }
    }

    private func networkByteTotals() -> (received: UInt64, sent: UInt64) {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return (0, 0) }
        defer { freeifaddrs(pointer) }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let item = current {
            let entry = item.pointee
            let flags = Int32(entry.ifa_flags)
            if (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0, let raw = entry.ifa_data {
                let data = raw.assumingMemoryBound(to: if_data.self).pointee
                received &+= UInt64(data.ifi_ibytes)
                sent &+= UInt64(data.ifi_obytes)
            }
            current = entry.ifa_next
        }
        return (received, sent)
    }
}

private struct TransferHistoryGraph: View {
    let download: [Double]
    let upload: [Double]

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(1, (download + upload).max() ?? 1)
            ZStack {
                path(values: download, size: proxy.size, maxValue: maxValue)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                path(values: upload, size: proxy.size, maxValue: maxValue)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func path(values: [Double], size: CGSize, maxValue: Double) -> Path {
        Path { path in
            guard values.count > 1 else { return }
            for (index, value) in values.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(max(1, values.count - 1))
                let y = size.height - size.height * CGFloat(min(1, max(0, value / maxValue)))
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
    }
}

private struct TransferContextView: View {
    @ObservedObject var monitor: TransferActivityMonitor
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextTransferCompact") private var compact = false
    @AppStorage("HaloContextTransferShowDirection") private var showDirection = true
    @AppStorage("HaloContextTransferShowDownload") private var showDownload = true
    @AppStorage("HaloContextTransferShowUpload") private var showUpload = true
    @AppStorage("HaloContextTransferShowPeak") private var showPeak = true
    @AppStorage("HaloContextTransferShowSession") private var showSession = true
    @AppStorage("HaloContextTransferShowElapsed") private var showElapsed = true
    @AppStorage("HaloContextTransferShowGraph") private var showGraph = true

    private var elapsed: String {
        guard let start = monitor.sessionStartedAt else { return "0:00" }
        let seconds = max(0, Int(Date().timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 14) {
            HStack(spacing: 10) {
                Image(systemName: monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading") ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: compact ? 18 : 23, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    if showDirection { Text(monitor.direction).font(compact ? .headline : .title3.bold()) }
                    Text("LIVE TRANSFER").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
                if showElapsed { Label(elapsed, systemImage: "clock").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            }

            HStack(spacing: compact ? 10 : 14) {
                if showDownload { stat("Download", value: speed(monitor.downloadBytesPerSecond), symbol: "arrow.down") }
                if showUpload { stat("Upload", value: speed(monitor.uploadBytesPerSecond), symbol: "arrow.up") }
                if showPeak && !compact {
                    stat("Peak ↓", value: speed(monitor.peakDownloadBytesPerSecond), symbol: "gauge.with.dots.needle.50percent")
                    stat("Peak ↑", value: speed(monitor.peakUploadBytesPerSecond), symbol: "gauge.with.dots.needle.67percent")
                }
            }

            if showGraph && !compact {
                TransferHistoryGraph(download: monitor.downloadHistory, upload: monitor.uploadHistory)
                    .frame(height: 56)
                    .padding(.vertical, 2)
            }

            if showSession && !compact {
                HStack {
                    Label("↓ \(bytes(monitor.sessionDownloadedBytes))", systemImage: "tray.and.arrow.down")
                    Label("↑ \(bytes(monitor.sessionUploadedBytes))", systemImage: "tray.and.arrow.up")
                    Spacer()
                    Text("Session \(bytes(monitor.sessionDownloadedBytes + monitor.sessionUploadedBytes))")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 14 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { surfaceState.contextPreferredSize = CGSize(width: compact ? 430 : 620, height: compact ? 120 : 230) }
        .onChange(of: compact) { value in surfaceState.contextPreferredSize = CGSize(width: value ? 430 : 620, height: value ? 120 : 230) }
    }

    private func stat(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: compact ? 15 : 18, weight: .semibold, design: .rounded)).monospacedDigit()
        }
        .padding(.horizontal, compact ? 10 : 12).padding(.vertical, compact ? 7 : 9)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func speed(_ value: Double) -> String {
        if value >= 1_000_000_000 { return String(format: "%.2f GB/s", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1f MB/s", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0f KB/s", value / 1_000) }
        return String(format: "%.0f B/s", value)
    }

    private func bytes(_ value: Double) -> String {
        if value >= 1_000_000_000 { return String(format: "%.2f GB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1f MB", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0f KB", value / 1_000) }
        return String(format: "%.0f B", value)
    }
}

'''
s = s.replace(anchor, transfer_code + anchor, 1)
s = s.replace('case drop, teleprompter, music, bluetooth, retro', 'case drop, teleprompter, transfer, music, bluetooth, retro', 1)
s = s.replace('    @ObservedObject private var bluetooth = BluetoothStateService.shared\n', '    @ObservedObject private var bluetooth = BluetoothStateService.shared\n    @ObservedObject private var transfer = TransferActivityMonitor.shared\n', 1)
s = s.replace('    @AppStorage("HaloContextTeleprompterPriority") private var teleprompterPriority = 70.0\n', '    @AppStorage("HaloContextTeleprompterPriority") private var teleprompterPriority = 70.0\n    @AppStorage("HaloContextTransferEnabled") private var transferCIEnabled = true\n    @AppStorage("HaloContextTransferPriority") private var transferPriority = 65.0\n    @AppStorage("HaloContextTransferUseFullNotchArea") private var transferUsesFullNotchArea = true\n    @AppStorage("HaloContextTransferKeepClosedNotchContents") private var transferKeepsClosedContents = false\n', 1)

candidate_anchor = '''        if teleprompterCIEnabled && teleprompterActive {\n            candidates.append((.teleprompter, teleprompterPriority, 3))\n        }\n        if contextOptions.enabled && workspace.media.isPlaying {'''
candidate_new = '''        if teleprompterCIEnabled && teleprompterActive {\n            candidates.append((.teleprompter, teleprompterPriority, 3))\n        }\n        if transferCIEnabled && transfer.isActive {\n            candidates.append((.transfer, transferPriority, 3))\n        }\n        if contextOptions.enabled && workspace.media.isPlaying {'''
if candidate_anchor not in s: raise SystemExit('candidate anchor missing')
s = s.replace(candidate_anchor, candidate_new, 1)
s = s.replace('    private var teleprompterContextActive: Bool { activeContext == .teleprompter }\n', '    private var teleprompterContextActive: Bool { activeContext == .teleprompter }\n    private var transferContextActive: Bool { activeContext == .transfer }\n', 1)
s = s.replace('        case .teleprompter: return true\n        case .none: return false', '        case .teleprompter: return true\n        case .transfer: return transferUsesFullNotchArea\n        case .none: return false', 1)
s = s.replace('        case .teleprompter: return false\n        case .none:', '        case .teleprompter: return false\n        case .transfer: return transferKeepsClosedContents\n        case .none:', 1)
render_anchor = '''                    } else if contextMusicActive {\n                        ContextMusicView(media: workspace.media, options: contextOptions,\n                                         visualizer: layout.closedNotch?.visualizer ?? VisualizerOptions(), surfaceState: state)'''
render_new = '''                    } else if transferContextActive {\n                        TransferContextView(monitor: transfer, surfaceState: state)\n                    } else if contextMusicActive {\n                        ContextMusicView(media: workspace.media, options: contextOptions,\n                                         visualizer: layout.closedNotch?.visualizer ?? VisualizerOptions(), surfaceState: state)'''
if render_anchor not in s: raise SystemExit('render anchor missing')
s = s.replace(render_anchor, render_new, 1)
receive_anchor = '''        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in store.expireFiles() }\n        .onReceive(NotificationCenter.default.publisher(for: .init("HaloTeleprompterVisibilityChanged")))'''
receive_new = '''        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in store.expireFiles() }\n        .onReceive(transfer.$isActive.removeDuplicates()) { active in\n            if active && transferCIEnabled && activeContext == .transfer {\n                state.collapseTask?.cancel()\n                state.expanded = true\n            } else if !active && !state.pinned && activeContext == nil {\n                state.expanded = false\n                state.contextPreferredSize = nil\n            }\n        }\n        .onReceive(NotificationCenter.default.publisher(for: .init("HaloTeleprompterVisibilityChanged")))'''
if receive_anchor not in s: raise SystemExit('receive anchor missing')
s = s.replace(receive_anchor, receive_new, 1)
surface.write_text(s)

settings = Path('Halo/Views/WorkspaceSettingsView.swift')
w = settings.read_text()
w = w.replace('    case drop, music, teleprompter, bluetooth, retro', '    case drop, music, teleprompter, transfer, bluetooth, retro', 1)
w = w.replace('    @AppStorage("HaloContextDropEnabled") private var dropEnabled = true\n', '    @AppStorage("HaloContextDropEnabled") private var dropEnabled = true\n    @AppStorage("HaloContextTransferEnabled") private var transferEnabled = true\n', 1)
branch_anchor = '''        } else if selection == .bluetooth {\n            Section {'''
branch_new = '''        } else if selection == .transfer {\n            Section {\n                HStack(spacing: 12) {\n                    Button { withAnimation(.easeInOut(duration: 0.18)) { selection = nil } } label: { Label("All CI", systemImage: "chevron.left") }\n                    Spacer()\n                    Label("Transfer CI", systemImage: "arrow.up.arrow.down.circle.fill").font(.headline)\n                }\n            }\n            TransferContextSettings()\n        } else if selection == .bluetooth {\n            Section {'''
if branch_anchor not in w: raise SystemExit('settings branch anchor missing')
w = w.replace(branch_anchor, branch_new, 1)
card_anchor = '''                    TeleprompterContextInterfaceCard {\n                        withAnimation(.easeInOut(duration: 0.18)) { selection = .teleprompter }\n                    }\n                    BluetoothContextInterfaceCard(enabled: bluetoothEnabled) {'''
card_new = '''                    TeleprompterContextInterfaceCard {\n                        withAnimation(.easeInOut(duration: 0.18)) { selection = .teleprompter }\n                    }\n                    TransferContextInterfaceCard(enabled: transferEnabled) {\n                        withAnimation(.easeInOut(duration: 0.18)) { selection = .transfer }\n                    }\n                    BluetoothContextInterfaceCard(enabled: bluetoothEnabled) {'''
if card_anchor not in w: raise SystemExit('card grid anchor missing')
w = w.replace(card_anchor, card_new, 1)
card_struct_anchor = 'private struct TeleprompterContextInterfaceCard: View {'
if card_struct_anchor not in w: raise SystemExit('teleprompter card struct anchor missing')
transfer_settings = r'''
private struct TransferContextInterfaceCard: View {
    let enabled: Bool
    let action: () -> Void
    @AppStorage("HaloContextTransferPriority") private var priority = 65.0
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LinearGradient(colors: [Color.accentColor.opacity(0.30), Color.black.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    HStack(spacing: 18) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 30, weight: .semibold))
                        VStack(spacing: 5) { Capsule().fill(.white.opacity(0.85)).frame(width: 92, height: 6); Capsule().fill(.white.opacity(0.25)).frame(width: 68, height: 5) }
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 30, weight: .semibold))
                    }.foregroundStyle(.white)
                }.frame(height: 112)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) { Text("Transfer CI").font(.headline); Text("Downloads & Uploads").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Text(enabled ? "Enabled" : "Available").font(.caption2.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4).background((enabled ? Color.green : Color.secondary).opacity(0.12), in: Capsule()).foregroundStyle(enabled ? Color.green : Color.secondary)
                }
                Text("Appears automatically during sustained network transfers with live speed, peaks, totals, elapsed time and throughput history.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                HStack { Label("Automatic", systemImage: "bolt.fill").font(.caption2).foregroundStyle(.secondary); Text("Priority \(Int(priority))").font(.caption2).foregroundStyle(.secondary); Spacer(); Label("Edit", systemImage: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor) }
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(hovered ? 0.075 : 0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(hovered ? Color.accentColor.opacity(0.42) : Color.primary.opacity(0.08), lineWidth: 1)).contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }.buttonStyle(.plain).onHover { hovered = $0 }.animation(.easeOut(duration: 0.14), value: hovered)
    }
}

private struct TransferContextSettings: View {
    @AppStorage("HaloContextTransferEnabled") private var enabled = true
    @AppStorage("HaloContextTransferPriority") private var priority = 65.0
    @AppStorage("HaloContextTransferUseFullNotchArea") private var useFullNotchArea = true
    @AppStorage("HaloContextTransferKeepClosedNotchContents") private var keepClosedContents = false
    @AppStorage("HaloContextTransferThresholdMBps") private var threshold = 0.35
    @AppStorage("HaloContextTransferLingerSeconds") private var linger = 2.5
    @AppStorage("HaloContextTransferReactDownloads") private var reactDownloads = true
    @AppStorage("HaloContextTransferReactUploads") private var reactUploads = true
    @AppStorage("HaloContextTransferCompact") private var compact = false
    @AppStorage("HaloContextTransferShowDirection") private var showDirection = true
    @AppStorage("HaloContextTransferShowDownload") private var showDownload = true
    @AppStorage("HaloContextTransferShowUpload") private var showUpload = true
    @AppStorage("HaloContextTransferShowPeak") private var showPeak = true
    @AppStorage("HaloContextTransferShowSession") private var showSession = true
    @AppStorage("HaloContextTransferShowElapsed") private var showElapsed = true
    @AppStorage("HaloContextTransferShowGraph") private var showGraph = true
    var body: some View {
        Section("Transfer Context Interface") {
            Toggle("Enable Transfer CI", isOn: $enabled)
            Text("Transfer CI only becomes eligible when Halo detects sustained network transfer activity above your threshold, then closes after the transfer goes quiet.").font(.caption).foregroundStyle(.secondary)
            Toggle("React to downloads", isOn: $reactDownloads)
            Toggle("React to uploads", isOn: $reactUploads)
        }
        Section("Detection") {
            LabeledContent("Activation threshold") { Slider(value: $threshold, in: 0.05...10, step: 0.05); Text(String(format: "%.2f MB/s", threshold)).font(.caption.monospacedDigit()).frame(width: 78) }
            LabeledContent("Stay visible after activity") { Slider(value: $linger, in: 0...10, step: 0.5); Text(String(format: "%.1f s", linger)).font(.caption.monospacedDigit()).frame(width: 54) }
            Text("A short two-sample confirmation prevents tiny background requests from constantly opening the notch. The linger period prevents chunked transfers from flickering the CI.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Layout") {
            Toggle("Compact presentation", isOn: $compact)
            Toggle("Show transfer direction", isOn: $showDirection)
            Toggle("Show download speed", isOn: $showDownload)
            Toggle("Show upload speed", isOn: $showUpload)
            Toggle("Show peak speeds", isOn: $showPeak).disabled(compact)
            Toggle("Show transferred this session", isOn: $showSession).disabled(compact)
            Toggle("Show elapsed time", isOn: $showElapsed)
            Toggle("Show live throughput graph", isOn: $showGraph).disabled(compact)
            Text(compact ? "Compact mode requests a small 430 × 120 pt CI." : "Detailed mode requests a 620 × 230 pt CI with room for live history and session statistics.").font(.caption).foregroundStyle(.secondary)
        }
        Section("CI priority") {
            Slider(value: $priority, in: 0...100, step: 1) { Text("Transfer CI priority") }
            Text("Transfer defaults to priority 65: above Music and Bluetooth, below Teleprompter, Retro and Drop. Change it to decide which CI owns Halo when contexts overlap.").font(.caption).foregroundStyle(.secondary)
        }
        Section("CI surface") { Toggle("Use full notch area", isOn: $useFullNotchArea); Toggle("Keep closed-notch contents visible", isOn: $keepClosedContents) }
        Section("What Halo can detect") { Text("This version detects real system network throughput, so it works across browsers and apps without plugins. macOS does not expose a universal public API that identifies every app's file name or exact download progress, so Transfer CI reports network-level transfer statistics rather than inventing per-file progress.").font(.caption).foregroundStyle(.secondary) }
    }
}

'''
w = w.replace(card_struct_anchor, transfer_settings + card_struct_anchor, 1)
settings.write_text(w)
