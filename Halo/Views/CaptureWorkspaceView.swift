import SwiftUI
import AppKit

/// One Capture UI shared by the regular opened-notch module and Visual Workspace.
/// The footprint only changes how much of the same CaptureService is exposed.
struct CaptureWorkspaceView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan

    @ObservedObject var service: CaptureService
    @ObservedObject var store: AppStore

    @State private var historyQuery = ""
    @State private var displayIndex = 1
    @State private var recordingTarget: HaloCaptureRecordingTarget = .region

    private var columns: Int {
        min(8, max(1, gridColumnSpan ?? Int(((availableWidth ?? 220) / 96).rounded())))
    }
    private var rows: Int {
        min(4, max(1, gridRowSpan ?? Int(((availableHeight ?? 150) / 86).rounded())))
    }
    private var spacing: CGFloat { max(5, CGFloat(style.resolvedContent.spacing) * 0.72) }
    private var recentURL: URL? { service.recentCaptures.first }
    private var filteredHistory: [HaloCaptureHistoryItem] {
        let query = historyQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return service.history }
        return service.history.filter { item in
            item.path.lowercased().contains(query) ||
            item.sourceApp.lowercased().contains(query) ||
            item.ocrText.lowercased().contains(query) ||
            item.mode.lowercased().contains(query) ||
            item.decodedCodes.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        Group {
            if columns == 1 && rows == 1 {
                micro
            } else if columns == 2 && rows == 1 {
                twoByOne
            } else if rows == 1 {
                horizontalStrip
            } else if columns >= 8 && rows >= 4 {
                captureWorkspace
            } else if columns >= 5 && rows >= 3 {
                large
            } else if columns >= 4 && rows >= 2 {
                actionGrid
            } else {
                medium
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .onAppear {
            if let current = service.displays.first(where: \.isMain) { displayIndex = current.index }
        }
    }

    // MARK: Exact footprint progression

    private var micro: some View {
        Button { perform(.region) } label: {
            VStack(spacing: 4) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(style.accentColor.color)
                Text("Capture").font(.caption2.weight(.semibold)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(service.busy || service.recording)
        .help("Capture region")
    }

    private var twoByOne: some View {
        HStack(spacing: spacing) {
            toolButton("Region", "viewfinder") { perform(.region) }
            toolButton("OCR", "text.viewfinder") { performOCR() }
        }
    }

    private var horizontalStrip: some View {
        HStack(spacing: spacing) {
            toolButton("Region", "viewfinder") { perform(.region) }
            toolButton("Window", "macwindow") { perform(.window) }
            toolButton("OCR", "text.viewfinder") { performOCR() }
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack(spacing: spacing) {
                toolButton("Region", "viewfinder") { perform(.region) }
                toolButton("Window", "macwindow") { perform(.window) }
                if columns >= 3 { toolButton("OCR", "text.viewfinder") { performOCR() } }
            }
            if rows >= 3 {
                HStack(spacing: spacing) {
                    toolButton("Color", "eyedropper") { service.sampleColor() }
                    toolButton("Measure", "ruler") { service.startMeasurement() }
                }
            }
            statusStrip
        }
    }

    /// 4×2 and similar sizes intentionally expose the six core tools requested for Capture.
    private var actionGrid: some View {
        VStack(alignment: .leading, spacing: spacing) {
            if style.showTitle { header }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3), spacing: spacing) {
                toolButton("Region", "viewfinder") { perform(.region) }
                toolButton("Window", "macwindow") { perform(.window) }
                toolButton("Screen", "display") { perform(.screen) }
                toolButton("OCR", "text.viewfinder") { performOCR() }
                toolButton("Color", "eyedropper") { service.sampleColor() }
                recordButton
            }
            statusStrip
        }
    }

    /// Large footprints add current result context without becoming a full Capture dashboard.
    private var large: some View {
        VStack(alignment: .leading, spacing: spacing) {
            if style.showTitle { header }
            HStack(spacing: spacing) {
                toolButton("Region", "viewfinder") { perform(.region) }
                toolButton("Window", "macwindow") { perform(.window) }
                toolButton("Screen", "display") { perform(.screen) }
                toolButton("OCR", "text.viewfinder") { performOCR() }
                toolButton("Color", "eyedropper") { service.sampleColor() }
                recordButton
            }
            HStack(alignment: .top, spacing: spacing) {
                recentPreview(compact: true).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 7) {
                    destinationPicker
                    HStack(spacing: 6) {
                        Button("Measure") { service.startMeasurement() }
                        Button("Freeze") { service.freezeScreen(displayIndex: displayIndex) }
                        if let recentURL { Button("Pin") { service.pinToScreen(recentURL) } }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    if !service.recognizedText.isEmpty {
                        Text("OCR RESULT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        Text(service.recognizedText).font(.caption).lineLimit(5).textSelection(.enabled)
                    } else if !service.smartSummary.isEmpty {
                        Text(service.smartSummary).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            statusStrip
        }
    }

    /// 8×4: a compact Capture utility workspace rather than a grid of oversized buttons.
    private var captureWorkspace: some View {
        HStack(alignment: .top, spacing: max(10, spacing)) {
            toolColumn
                .frame(width: max(165, min(205, (availableWidth ?? 760) * 0.23)))

            Divider().opacity(0.20)

            resultColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider().opacity(0.20)

            historyColumn
                .frame(width: max(185, min(235, (availableWidth ?? 760) * 0.28)))
        }
    }

    private var toolColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                toolButton("Region", "viewfinder") { perform(.region) }
                toolButton("Window", "macwindow") { perform(.window) }
                toolButton("Display", "display") { perform(.display) }
                toolButton("OCR", "text.viewfinder") { performOCR() }
                toolButton("QR", "qrcode.viewfinder") { performOCR() }
                toolButton("Color", "eyedropper") { service.sampleColor() }
                toolButton("Measure", "ruler") { service.startMeasurement() }
                toolButton("Freeze", "pause.rectangle") { service.freezeScreen(displayIndex: displayIndex) }
                toolButton("Smart", "sparkles.rectangle.stack") { service.smartCapture { integrate($0) } }
                recordButton
            }
            moreCaptureMenu
            recordingOptions
            Spacer(minLength: 0)
            displayPicker
            destinationPicker
        }
    }

    private var resultColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PREVIEW").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            recentPreview(compact: false)

            if let sample = service.colorSample {
                HStack(spacing: 7) {
                    Circle().fill(Color(red: sample.red, green: sample.green, blue: sample.blue)).frame(width: 18, height: 18)
                    Text(sample.hex).font(.caption.monospaced())
                    Text(sample.rgb).font(.caption2).foregroundStyle(.secondary)
                }
                .contextMenu {
                    Button("Copy HEX") { copy(sample.hex) }
                    Button("Copy RGB") { copy(sample.rgb) }
                    Button("Copy HSL") { copy(sample.hsl) }
                }
            }

            if let measure = service.measurement {
                Label(measure.description, systemImage: "ruler").font(.caption)
                    .contextMenu { Button("Copy measurement") { copy(measure.description) } }
            }

            if !service.decodedCodes.isEmpty {
                Text("QR / BARCODE").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(service.decodedCodes.prefix(3), id: \.self) { code in
                    Text(code).font(.caption).lineLimit(2).textSelection(.enabled)
                }
            }

            if !service.detectedValues.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(service.detectedValues.prefix(8)) { value in
                            Button {
                                copy(value.value)
                            } label: {
                                Label(value.value, systemImage: symbol(for: value.kind))
                                    .font(.caption2).lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                }
            }

            Divider().opacity(0.18)
            HStack {
                Text("OCR / TEXT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if !service.recognizedText.isEmpty { Button("Copy") { service.copyText() }.buttonStyle(.plain).font(.caption) }
            }
            ScrollView {
                Text(service.recognizedText.isEmpty ? "Capture a region or image to extract text, links, emails, phone numbers, numbers, QR codes and barcodes." : service.recognizedText)
                    .font(.caption)
                    .foregroundStyle(service.recognizedText.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var historyColumn: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("HISTORY").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            TextField("Search captures", text: $historyQuery)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredHistory.prefix(12)) { item in historyRow(item) }
                }
            }

            Divider().opacity(0.18)
            Text("ANNOTATE & EXPORT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            if let recentURL {
                HStack(spacing: 6) {
                    Button("Markup") { service.annotate(recentURL) }
                    Button("Pin") { service.pinToScreen(recentURL) }
                    Button("Export") { service.export(recentURL) }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                HStack(spacing: 6) {
                    Button("Scan") { service.scanDocument(recentURL) { integrate($0) } }
                    Button("Extract") { service.extractDominantImage(recentURL) { integrate($0) } }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            statusStrip
        }
    }

    // MARK: Controls

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "viewfinder").foregroundStyle(style.accentColor.color)
            Text("CAPTURE").font(.caption.weight(.bold)).tracking(0.7)
            Spacer(minLength: 0)
            if service.recording { Circle().fill(.red).frame(width: 7, height: 7) }
        }
    }

    @ViewBuilder private var recordButton: some View {
        if service.recording {
            toolButton("Stop", "stop.fill", prominent: true) { service.stopRecording() }
        } else {
            toolButton("Record", "record.circle") {
                let target = service.preferences.recordSystemAudio ? HaloCaptureRecordingTarget.display : recordingTarget
                service.startRecording(target: target, displayIndex: displayIndex) { integrate($0) }
            }
        }
    }

    private var recordingOptions: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Record", selection: $recordingTarget) {
                ForEach(HaloCaptureRecordingTarget.allCases) { Text($0.rawValue).tag($0) }
            }
            .controlSize(.mini)
            Toggle("System audio", isOn: preferenceBinding(\.recordSystemAudio))
                .disabled(!service.supportsSystemAudioRecording)
            Toggle("Microphone", isOn: preferenceBinding(\.recordMicrophone))
            Toggle("Show clicks", isOn: preferenceBinding(\.showRecordingClicks))
        }
        .font(.caption)
        .toggleStyle(.switch)
    }

    private var moreCaptureMenu: some View {
        Menu {
            Button("Delayed Capture") { perform(.delayed) }
            Button("Repeated Capture") { perform(.repeated) }
            Divider()
            Button("Open Image for OCR / QR…") { service.chooseImage() }
            if let recentURL {
                Button("Document Scan") { service.scanDocument(recentURL) { integrate($0) } }
                Button("Extract Dominant Image") { service.extractDominantImage(recentURL) { integrate($0) } }
            }
        } label: {
            Label("More Capture Tools", systemImage: "ellipsis.circle")
                .frame(maxWidth: .infinity)
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
    }

    private var displayPicker: some View {
        Picker("Display", selection: $displayIndex) {
            ForEach(service.displays) { display in
                Text(display.isMain ? "\(display.name) · Main" : display.name).tag(display.index)
            }
        }
        .controlSize(.small)
    }

    private var destinationPicker: some View {
        Picker("Destination", selection: preferenceBinding(\.destination)) {
            ForEach(HaloCaptureDestination.allCases) { Text($0.rawValue).tag($0) }
        }
        .controlSize(.small)
    }

    @ViewBuilder private func recentPreview(compact: Bool) -> some View {
        if let recentURL {
            VStack(alignment: .leading, spacing: 6) {
                CaptureSuiteThumbnail(url: recentURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? 92 : 142)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onDrag { NSItemProvider(object: recentURL as NSURL) }
                HStack(spacing: 7) {
                    Button("Quick Look") { store.shelfPreview.show(recentURL) }
                    Button("Copy") { service.copyImage(recentURL) }
                    Button("Reveal") { service.reveal(recentURL) }
                }
                .buttonStyle(.plain)
                .font(.caption2)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle").font(.title2).foregroundStyle(.secondary)
                Text("No captures yet").font(.caption.weight(.semibold))
                Text("Your latest capture will appear here.").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 90 : 130)
            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func historyRow(_ item: HaloCaptureHistoryItem) -> some View {
        Button { store.shelfPreview.show(item.url) } label: {
            HStack(spacing: 7) {
                CaptureSuiteThumbnail(url: item.url)
                    .frame(width: 40, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.url.lastPathComponent).font(.caption2.weight(.semibold)).lineLimit(1)
                    Text("\(item.sourceApp) · \(item.width)×\(item.height)")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 2)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy") { service.copyImage(item.url) }
            Button("Pin to Screen") { service.pinToScreen(item.url) }
            Button("Reveal in Finder") { service.reveal(item.url) }
            Button("Remove from History") { service.removeHistoryItem(item) }
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 7) {
            if service.busy { ProgressView().controlSize(.mini) }
            if service.recording { Circle().fill(.red).frame(width: 7, height: 7) }
            Text(service.countdown > 0 ? "\(service.countdown)" : (service.error ?? service.status))
                .font(.caption2)
                .foregroundStyle(service.error == nil ? Color.secondary : Color.orange)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func toolButton(_ title: String, _ symbol: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 26)
        }
        .buttonStyle(prominent ? .borderedProminent : .bordered)
        .disabled((service.busy || service.recording) && title != "Stop")
    }

    // MARK: Actions / integrations

    private func perform(_ mode: HaloCaptureMode) {
        service.capture(mode: mode, displayIndex: displayIndex) { integrate($0) }
    }

    private func performOCR() {
        service.recognizeRegion { integrate($0) }
    }

    private func integrate(_ url: URL) {
        let preferences = service.preferences
        if preferences.destination == .shelf || preferences.addToShelfAfterCapture {
            store.addFiles([url])
        }
        if preferences.destination == .notes || preferences.addToNotesAfterCapture {
            let text = service.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
            store.workspace.settings.notes += "\nCapture · \(url.lastPathComponent)\n\(url.path)" + (text.isEmpty ? "" : "\n\(text)") + "\n"
        }
        let clipboardText = service.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = clipboardText.isEmpty ? "Capture · \(url.lastPathComponent)" : clipboardText
        store.workspace.clipboard.entries.removeAll { $0.text == label }
        store.workspace.clipboard.entries.insert(ClipboardEntry(text: label), at: 0)
        store.workspace.clipboard.entries = Array(store.workspace.clipboard.entries.prefix(50))
    }

    private func preferenceBinding<T>(_ keyPath: WritableKeyPath<HaloCapturePreferences, T>) -> Binding<T> {
        Binding(
            get: { service.preferences[keyPath: keyPath] },
            set: { newValue in service.updatePreferences { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func symbol(for kind: HaloCaptureDetectedValue.Kind) -> String {
        switch kind {
        case .link: return "link"
        case .email: return "envelope"
        case .phone: return "phone"
        case .number: return "number"
        case .date: return "calendar"
        }
    }
}

private struct CaptureSuiteThumbnail: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color.primary.opacity(0.04)
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
        }
        .clipped()
        .onAppear { image = NSImage(contentsOf: url) }
        .onChange(of: url) { next in image = NSImage(contentsOf: next) }
    }
}
