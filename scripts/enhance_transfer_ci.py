from pathlib import Path

surface_path = Path('Halo/Views/SurfaceView.swift')
settings_path = Path('Halo/Views/WorkspaceSettingsView.swift')

surface = surface_path.read_text()
settings = settings_path.read_text()

start = surface.index('private struct TransferContextView: View {')
end = surface.index('private struct TransferSurfaceBackground: View {')

replacement = r'''private struct TransferActivityIndicator: View {
    @ObservedObject var monitor: TransferActivityMonitor
    let compact: Bool
    @AppStorage("HaloContextTransferIndicatorStyle") private var style = "Edge Bar"
    @AppStorage("HaloContextTransferIndicatorShowSpeed") private var showSpeed = true
    @AppStorage("HaloContextTransferIndicatorThickness") private var thickness = 3.0
    @AppStorage("HaloContextTransferIndicatorIntensity") private var intensity = 1.0
    @AppStorage("HaloContextTransferThresholdMBps") private var thresholdMBps = 0.35

    private var uploadOnly: Bool {
        monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading")
    }
    private var accent: Color { uploadOnly ? .orange : .accentColor }
    private var currentSpeed: Double { max(monitor.downloadBytesPerSecond, monitor.uploadBytesPerSecond) }
    private var activity: Double {
        let threshold = max(50_000, thresholdMBps * 1_000_000)
        return min(1, max(0.10, currentSpeed / (threshold * 5)))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch style {
                case "Center Pulse":
                    HStack(spacing: 8) {
                        Image(systemName: uploadOnly ? "arrow.up" : "arrow.down")
                            .font(.system(size: compact ? 10 : 14, weight: .bold))
                        Capsule()
                            .fill(accent.opacity(0.18))
                            .frame(width: compact ? 56 : 110, height: max(2, thickness))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(accent.opacity(0.95 * intensity))
                                    .frame(width: (compact ? 56 : 110) * activity)
                                    .animation(.easeOut(duration: 0.25), value: activity)
                            }
                        if showSpeed { Text(speed(currentSpeed)).monospacedDigit() }
                    }
                    .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case "Dual Rails":
                    VStack(spacing: max(2, thickness)) {
                        rail(value: monitor.downloadBytesPerSecond, threshold: thresholdMBps, color: .accentColor, width: proxy.size.width)
                        rail(value: monitor.uploadBytesPerSecond, threshold: thresholdMBps, color: .orange, width: proxy.size.width)
                    }
                    .padding(.horizontal, compact ? 8 : 14)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .overlay(alignment: .center) {
                        if showSpeed {
                            Text(speed(currentSpeed))
                                .font(.system(size: compact ? 8 : 10, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.black.opacity(0.52), in: Capsule())
                        }
                    }

                case "Minimal":
                    HStack(spacing: 6) {
                        Image(systemName: uploadOnly ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundStyle(accent)
                        if showSpeed { Text(speed(currentSpeed)).monospacedDigit() }
                    }
                    .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                default:
                    VStack(spacing: 0) {
                        Spacer()
                        Capsule()
                            .fill(.white.opacity(0.10))
                            .frame(height: max(2, thickness))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(accent.opacity(0.95 * intensity))
                                    .frame(width: max(8, proxy.size.width * activity), height: max(2, thickness))
                                    .animation(.easeOut(duration: 0.25), value: activity)
                            }
                    }
                    .overlay(alignment: .center) {
                        HStack(spacing: 6) {
                            Image(systemName: uploadOnly ? "arrow.up" : "arrow.down")
                            if showSpeed { Text(speed(currentSpeed)).monospacedDigit() }
                        }
                        .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded))
                    }
                }
            }
        }
    }

    private func rail(value: Double, threshold: Double, color: Color, width: CGFloat) -> some View {
        let floor = max(50_000, threshold * 1_000_000)
        let fraction = min(1, max(0.05, value / (floor * 5)))
        return Capsule()
            .fill(color.opacity(0.12))
            .frame(height: max(2, thickness))
            .overlay(alignment: .leading) {
                Capsule().fill(color.opacity(0.92 * intensity))
                    .frame(width: max(5, width * fraction), height: max(2, thickness))
                    .animation(.easeOut(duration: 0.25), value: fraction)
            }
    }

    private func speed(_ value: Double) -> String {
        if value >= 1_000_000_000 { return String(format: "%.1f GB/s", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1f MB/s", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0f KB/s", value / 1_000) }
        return String(format: "%.0f B/s", value)
    }
}

private struct TransferContextView: View {
    @ObservedObject var monitor: TransferActivityMonitor
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextTransferOpenStyle") private var openStyle = "Dashboard"
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

    private var visibleStatCount: Int {
        (showDownload ? 1 : 0) + (showUpload ? 1 : 0) + ((!compact && showPeak) ? 2 : 0)
    }
    private var preferredSize: CGSize {
        switch openStyle {
        case "Indicator":
            return CGSize(width: 360, height: showElapsed ? 96 : 82)
        case "Minimal":
            let width = 300 + Double(max(0, min(2, visibleStatCount))) * 75
            return CGSize(width: width, height: showDirection || showElapsed ? 112 : 92)
        default:
            let statColumns = max(1, min(4, visibleStatCount))
            let width = compact ? (300 + Double(statColumns) * 72) : (360 + Double(statColumns) * 72)
            var height = compact ? 112.0 : 128.0
            if showGraph && !compact { height += 70 }
            if showSession && !compact { height += 34 }
            return CGSize(width: min(680, max(340, width)), height: min(280, height))
        }
    }
    private var sizingSignature: String {
        [openStyle, compact.description, showDirection.description, showDownload.description,
         showUpload.description, showPeak.description, showSession.description,
         showElapsed.description, showGraph.description].joined(separator: "|")
    }

    var body: some View {
        Group {
            if openStyle == "Indicator" {
                VStack(spacing: 8) {
                    TransferActivityIndicator(monitor: monitor, compact: false)
                        .frame(height: 34)
                    if showDirection || showElapsed {
                        HStack {
                            if showDirection { Text(monitor.direction).font(.caption.weight(.semibold)) }
                            Spacer()
                            if showElapsed { Label(elapsed, systemImage: "clock").font(.caption.monospacedDigit()) }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            } else if openStyle == "Minimal" {
                HStack(spacing: 12) {
                    Image(systemName: monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading") ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.accentColor)
                    if showDirection {
                        Text(monitor.direction).font(.headline)
                    }
                    if showDownload { compactStat("↓", speed(monitor.downloadBytesPerSecond)) }
                    if showUpload { compactStat("↑", speed(monitor.uploadBytesPerSecond)) }
                    Spacer(minLength: 4)
                    if showElapsed { Text(elapsed).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
            } else {
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

                    if visibleStatCount > 0 {
                        HStack(spacing: compact ? 10 : 14) {
                            if showDownload { stat("Download", value: speed(monitor.downloadBytesPerSecond), symbol: "arrow.down") }
                            if showUpload { stat("Upload", value: speed(monitor.uploadBytesPerSecond), symbol: "arrow.up") }
                            if showPeak && !compact {
                                stat("Peak ↓", value: speed(monitor.peakDownloadBytesPerSecond), symbol: "gauge")
                                stat("Peak ↑", value: speed(monitor.peakUploadBytesPerSecond), symbol: "gauge")
                            }
                        }
                    }

                    if showGraph && !compact {
                        TransferHistoryGraph(download: monitor.downloadHistory, upload: monitor.uploadHistory)
                            .frame(height: 56).padding(.vertical, 2)
                    }

                    if showSession && !compact {
                        HStack {
                            Label("↓ \(bytes(monitor.sessionDownloadedBytes))", systemImage: "tray.and.arrow.down")
                            Label("↑ \(bytes(monitor.sessionUploadedBytes))", systemImage: "tray.and.arrow.up")
                            Spacer()
                            Text("Session \(bytes(monitor.sessionDownloadedBytes + monitor.sessionUploadedBytes))")
                        }
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                .padding(compact ? 14 : 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { updatePreferredSize() }
        .onChange(of: sizingSignature) { _ in updatePreferredSize() }
    }

    private func updatePreferredSize() {
        surfaceState.contextPreferredSize = preferredSize
    }

    private func compactStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
        }
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

private struct TransferClosedContextView: View {
    @ObservedObject var monitor: TransferActivityMonitor
    @AppStorage("HaloContextTransferClosedStyle") private var closedStyle = "Stats"
    @AppStorage("HaloContextTransferShowDirection") private var showDirection = true
    @AppStorage("HaloContextTransferShowDownload") private var showDownload = true
    @AppStorage("HaloContextTransferShowUpload") private var showUpload = true

    var body: some View {
        Group {
            if closedStyle == "Indicator" {
                TransferActivityIndicator(monitor: monitor, compact: true)
                    .padding(.horizontal, 5)
            } else if closedStyle == "Minimal" {
                HStack(spacing: 6) {
                    Image(systemName: monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading") ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.accentColor)
                    Text(speed(max(monitor.downloadBytesPerSecond, monitor.uploadBytesPerSecond)))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced)).lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: monitor.direction.contains("Uploading") && !monitor.direction.contains("Downloading") ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.accentColor)
                    if showDirection {
                        Text(shortDirection).font(.system(size: 10, weight: .semibold, design: .rounded)).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if showDownload {
                        Label(speed(monitor.downloadBytesPerSecond), systemImage: "arrow.down")
                            .font(.system(size: 9, weight: .medium, design: .monospaced)).lineLimit(1)
                    }
                    if showUpload {
                        Label(speed(monitor.uploadBytesPerSecond), systemImage: "arrow.up")
                            .font(.system(size: 9, weight: .medium, design: .monospaced)).lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var shortDirection: String {
        if monitor.direction.contains("Uploading + Downloading") { return "Transfer" }
        if monitor.direction.contains("Uploading") { return "Uploading" }
        if monitor.direction.contains("Downloading") { return "Downloading" }
        return "Transfer"
    }

    private func speed(_ value: Double) -> String {
        if value >= 1_000_000_000 { return String(format: "%.1fG/s", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM/s", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0fK/s", value / 1_000) }
        return String(format: "%.0fB/s", value)
    }
}

'''

surface = surface[:start] + replacement + surface[end:]
surface_path.write_text(surface)

s_start = settings.index('private struct TransferContextSettings: View {')
s_end = settings.index('private struct TeleprompterContextInterfaceCard: View {')

settings_replacement = r'''private struct TransferContextSettings: View {
    @AppStorage("HaloContextTransferEnabled") private var enabled = true
    @AppStorage("HaloContextTransferPriority") private var priority = 65.0
    @AppStorage("HaloContextTransferThresholdMBps") private var threshold = 0.35
    @AppStorage("HaloContextTransferLingerSeconds") private var linger = 2.5
    @AppStorage("HaloContextTransferReactDownloads") private var reactDownloads = true
    @AppStorage("HaloContextTransferReactUploads") private var reactUploads = true
    @AppStorage("HaloContextTransferClosedStyle") private var closedStyle = "Stats"
    @AppStorage("HaloContextTransferOpenStyle") private var openStyle = "Dashboard"
    @AppStorage("HaloContextTransferCompact") private var compact = false
    @AppStorage("HaloContextTransferShowDirection") private var showDirection = true
    @AppStorage("HaloContextTransferShowDownload") private var showDownload = true
    @AppStorage("HaloContextTransferShowUpload") private var showUpload = true
    @AppStorage("HaloContextTransferShowPeak") private var showPeak = true
    @AppStorage("HaloContextTransferShowSession") private var showSession = true
    @AppStorage("HaloContextTransferShowElapsed") private var showElapsed = true
    @AppStorage("HaloContextTransferShowGraph") private var showGraph = true
    @AppStorage("HaloContextTransferIndicatorStyle") private var indicatorStyle = "Edge Bar"
    @AppStorage("HaloContextTransferIndicatorShowSpeed") private var indicatorShowSpeed = true
    @AppStorage("HaloContextTransferIndicatorThickness") private var indicatorThickness = 3.0
    @AppStorage("HaloContextTransferIndicatorIntensity") private var indicatorIntensity = 1.0
    @AppStorage("HaloContextTransferBackgroundStyle") private var backgroundStyle = "Gradient"
    @AppStorage("HaloContextTransferBackgroundPrimaryHue") private var backgroundPrimaryHue = 0.58
    @AppStorage("HaloContextTransferBackgroundSecondaryHue") private var backgroundSecondaryHue = 0.72
    @AppStorage("HaloContextTransferBackgroundSaturation") private var backgroundSaturation = 0.72
    @AppStorage("HaloContextTransferBackgroundBrightness") private var backgroundBrightness = 0.30
    @AppStorage("HaloContextTransferBackgroundOpacity") private var backgroundOpacity = 1.0

    var body: some View {
        Section("Transfer Context Interface") {
            Toggle("Enable Transfer CI", isOn: $enabled)
            Text("Transfer CI replaces the contents and styling of the existing Halo notch while transfer activity is present. It still opens, closes, hovers, pins and animates exactly like your normal notch.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("React to downloads", isOn: $reactDownloads)
            Toggle("React to uploads", isOn: $reactUploads)
        }

        Section("Detection") {
            LabeledContent("Activation threshold") {
                Slider(value: $threshold, in: 0.05...10, step: 0.05)
                Text(String(format: "%.2f MB/s", threshold)).font(.caption.monospacedDigit()).frame(width: 78)
            }
            LabeledContent("Stay visible after activity") {
                Slider(value: $linger, in: 0...10, step: 0.5)
                Text(String(format: "%.1f s", linger)).font(.caption.monospacedDigit()).frame(width: 54)
            }
            Text("Two sustained samples prevent tiny background requests from constantly taking over the notch. Linger smooths chunked transfers.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Closed notch") {
            Picker("Presentation", selection: $closedStyle) {
                Text("Stats").tag("Stats")
                Text("Download indicator").tag("Indicator")
                Text("Minimal").tag("Minimal")
            }.pickerStyle(.segmented)
            Text(closedStyle == "Indicator" ? "Indicator mode turns the notch itself into a live transfer indicator, similar to Halo's update/download presentation. Because system-wide traffic does not expose universal file progress, the fill represents live transfer activity rather than a fake percentage." : "Choose how much transfer information should replace the normal closed-notch contents.")
                .font(.caption).foregroundStyle(.secondary)
        }

        if closedStyle == "Indicator" || openStyle == "Indicator" {
            Section("Indicator") {
                Picker("Style", selection: $indicatorStyle) {
                    Text("Edge Bar").tag("Edge Bar")
                    Text("Center Pulse").tag("Center Pulse")
                    Text("Dual Rails").tag("Dual Rails")
                    Text("Minimal").tag("Minimal")
                }
                Toggle("Show live speed", isOn: $indicatorShowSpeed)
                LabeledContent("Thickness") {
                    Slider(value: $indicatorThickness, in: 1.5...10, step: 0.5)
                    Text(String(format: "%.1f pt", indicatorThickness)).font(.caption.monospacedDigit()).frame(width: 48)
                }
                LabeledContent("Intensity") {
                    Slider(value: $indicatorIntensity, in: 0.2...1, step: 0.05)
                    Text("\(Int((indicatorIntensity * 100).rounded()))%").font(.caption.monospacedDigit()).frame(width: 42)
                }
            }
        }

        Section("Opened notch") {
            Picker("Presentation", selection: $openStyle) {
                Text("Dashboard").tag("Dashboard")
                Text("Indicator").tag("Indicator")
                Text("Minimal").tag("Minimal")
            }.pickerStyle(.segmented)
            if openStyle == "Dashboard" {
                Toggle("Compact presentation", isOn: $compact)
            }
            Toggle("Show transfer direction", isOn: $showDirection)
            Toggle("Show download speed", isOn: $showDownload).disabled(openStyle == "Indicator")
            Toggle("Show upload speed", isOn: $showUpload).disabled(openStyle == "Indicator")
            Toggle("Show peak speeds", isOn: $showPeak).disabled(compact || openStyle != "Dashboard")
            Toggle("Show transferred this session", isOn: $showSession).disabled(compact || openStyle != "Dashboard")
            Toggle("Show elapsed time", isOn: $showElapsed)
            Toggle("Show live throughput graph", isOn: $showGraph).disabled(compact || openStyle != "Dashboard")
            Text("Transfer CI now sizes itself from the content you enable. Removing graph, session totals, peaks or stat blocks shrinks the opened notch; enabling them grows it again.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("CI priority") {
            Slider(value: $priority, in: 0...100, step: 1) { Text("Transfer CI priority") }
            Text("Transfer defaults to priority 65: above Music and Bluetooth, below Teleprompter, Retro and Drop.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Background") {
            Picker("Style", selection: $backgroundStyle) {
                Text("Gradient").tag("Gradient")
                Text("Dynamic").tag("Dynamic")
                Text("Accent").tag("Accent")
                Text("Glass").tag("Glass")
                Text("Black").tag("Black")
            }
            if backgroundStyle == "Gradient" || backgroundStyle == "Dynamic" || backgroundStyle == "Glass" {
                LabeledContent("Primary hue") { Slider(value: $backgroundPrimaryHue, in: 0...1) }
            }
            if backgroundStyle == "Gradient" {
                LabeledContent("Secondary hue") { Slider(value: $backgroundSecondaryHue, in: 0...1) }
            }
            if backgroundStyle == "Gradient" || backgroundStyle == "Dynamic" || backgroundStyle == "Glass" {
                LabeledContent("Saturation") { Slider(value: $backgroundSaturation, in: 0...1) }
                LabeledContent("Brightness") { Slider(value: $backgroundBrightness, in: 0.05...1) }
            }
            LabeledContent("Background opacity") {
                Slider(value: $backgroundOpacity, in: 0.15...1)
                Text("\(Int((backgroundOpacity * 100).rounded()))%").font(.caption.monospacedDigit()).frame(width: 42)
            }
            Text(backgroundStyle == "Dynamic" ? "Dynamic shifts toward download/accent or upload/orange colors based on the active direction." : "Transfer styling is isolated from your normal notch appearance.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("What Halo can detect") {
            Text("System-wide transfer detection can report real throughput, direction, totals and peaks, but macOS does not expose a universal file progress percentage for every browser and app. Indicator mode therefore represents live transfer activity unless a future app-specific provider can supply real progress.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

'''

settings = settings[:s_start] + settings_replacement + settings[s_end:]
settings_path.write_text(settings)

print('Enhanced Transfer CI indicator modes and content-driven sizing.')
