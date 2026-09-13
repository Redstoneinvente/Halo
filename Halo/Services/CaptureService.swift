import AppKit
import Vision
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import ScreenCaptureKit
import AVFoundation
import ApplicationServices

// MARK: - Capture models

enum HaloCaptureMode: String, Codable, CaseIterable, Identifiable {
    case region = "Region"
    case window = "Window"
    case screen = "Full Screen"
    case display = "Display"
    case delayed = "Delayed"
    case repeated = "Repeated"
    var id: String { rawValue }
}

enum HaloCaptureFormat: String, Codable, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case heic = "HEIC"
    case pdf = "PDF"
    var id: String { rawValue }
    var fileExtension: String {
        switch self { case .png: return "png"; case .jpeg: return "jpg"; case .heic: return "heic"; case .pdf: return "pdf" }
    }
    var typeIdentifier: CFString {
        switch self {
        case .png: return UTType.png.identifier as CFString
        case .jpeg: return UTType.jpeg.identifier as CFString
        case .heic: return UTType.heic.identifier as CFString
        case .pdf: return UTType.pdf.identifier as CFString
        }
    }
}

enum HaloCaptureDestination: String, Codable, CaseIterable, Identifiable {
    case desktop = "Desktop"
    case downloads = "Downloads"
    case custom = "Custom Folder"
    case clipboard = "Clipboard Only"
    case shelf = "Shelf Only"
    case notes = "Notes"
    var id: String { rawValue }
}

enum HaloCaptureRecordingTarget: String, Codable, CaseIterable, Identifiable {
    case region = "Region"
    case window = "Window"
    case display = "Display"
    var id: String { rawValue }
}

struct HaloCaptureDisplay: Identifiable, Equatable {
    let index: Int
    let displayID: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let isMain: Bool
    var id: CGDirectDisplayID { displayID }
}

struct HaloCaptureDetectedValue: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case link, email, phone, number, date }
    let id: UUID
    let kind: Kind
    let value: String
    init(kind: Kind, value: String) { id = UUID(); self.kind = kind; self.value = value }
}

struct HaloCaptureHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var path: String
    var createdAt: Date
    var sourceApp: String
    var sourceBundleID: String
    var width: Int
    var height: Int
    var mode: String
    var ocrText: String
    var decodedCodes: [String]
    var url: URL { URL(fileURLWithPath: path) }
}

struct HaloCaptureColorSample: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    var hue: Double
    var saturation: Double
    var lightness: Double
    var hex: String
    var rgb: String { "rgb(\(Int((red * 255).rounded())), \(Int((green * 255).rounded())), \(Int((blue * 255).rounded())))" }
    var hsl: String { "hsl(\(Int((hue * 360).rounded()))°, \(Int((saturation * 100).rounded()))%, \(Int((lightness * 100).rounded()))%)" }
}

struct HaloCaptureMeasurement: Equatable {
    let start: CGPoint
    let end: CGPoint
    let scale: Double
    var widthPixels: Int { Int((abs(end.x - start.x) * scale).rounded()) }
    var heightPixels: Int { Int((abs(end.y - start.y) * scale).rounded()) }
    var distancePixels: Int { Int((hypot(end.x - start.x, end.y - start.y) * scale).rounded()) }
    var description: String { "\(widthPixels) × \(heightPixels) px · \(distancePixels) px diagonal" }
}

struct HaloCapturePreferences: Codable, Equatable {
    var defaultMode: HaloCaptureMode = .region
    var format: HaloCaptureFormat = .png
    var quality = 0.92
    var destination: HaloCaptureDestination = .desktop
    var customFolderPath = ""
    var namingTemplate = "{app}_{date}_{time}_{seq}"
    var prefix = "Halo"
    var sequence = 1
    var delaySeconds = 5
    var repeatCount = 3
    var repeatInterval = 1.0

    var copyAfterCapture = true
    var ocrAfterCapture = false
    var copyOCRAfterRecognition = false
    var pasteOCRAfterRecognition = false
    var openAfterCapture = false
    var addToShelfAfterCapture = false
    var addToNotesAfterCapture = false

    var recordSystemAudio = false
    var recordMicrophone = false
    var showRecordingClicks = false
    var recordCountdown = 3

    var neverStoreCaptures = false
    var excludedBundleIDs: [String] = ["com.1password.1password", "com.apple.keychainaccess"]
    var historyLimit = 60

    func normalized() -> HaloCapturePreferences {
        var value = self
        value.quality = min(1, max(0.2, quality))
        value.namingTemplate = String(namingTemplate.prefix(160))
        value.prefix = String(prefix.prefix(48))
        value.sequence = max(1, sequence)
        value.delaySeconds = min(60, max(1, delaySeconds))
        value.repeatCount = min(60, max(2, repeatCount))
        value.repeatInterval = min(60, max(0.25, repeatInterval))
        value.recordCountdown = min(10, max(0, recordCountdown))
        value.historyLimit = min(250, max(10, historyLimit))
        value.excludedBundleIDs = Array(Set(excludedBundleIDs.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(180)) }.filter { !$0.isEmpty })).sorted()
        return value
    }
}

private struct HaloCaptureAnalysis {
    var text = ""
    var codes: [String] = []
    var values: [HaloCaptureDetectedValue] = []
    var rectangles = 0
    var width = 0
    var height = 0
}

// MARK: - Capture service

@MainActor
final class CaptureService: ObservableObject {
    static let shared = CaptureService()

    @Published var busy = false
    @Published var recording = false
    @Published var countdown = 0
    @Published var recognizedText = ""
    @Published var detectedValues: [HaloCaptureDetectedValue] = []
    @Published var decodedCodes: [String] = []
    @Published var smartSummary = ""
    @Published var error: String?
    @Published var status = "Ready"
    @Published var recentCaptures: [URL] = []
    @Published var history: [HaloCaptureHistoryItem] = []
    @Published var colorSample: HaloCaptureColorSample?
    @Published var measurement: HaloCaptureMeasurement?
    @Published var preferences: HaloCapturePreferences { didSet { persistPreferences() } }

    private let defaults: UserDefaults
    private let preferenceKey = "HaloCapturePreferences.v2"
    private let historyKey = "HaloCaptureHistory.v2"
    private var activeProcess: Process?
    private var recordingSession: AnyObject?
    private var lastSourceApp = "Mac"
    private var lastSourceBundleID = ""

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: preferenceKey),
           let decoded = try? JSONDecoder().decode(HaloCapturePreferences.self, from: data) {
            preferences = decoded.normalized()
        } else { preferences = HaloCapturePreferences() }
        if let data = defaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([HaloCaptureHistoryItem].self, from: data) {
            history = decoded.filter { FileManager.default.fileExists(atPath: $0.path) }
            recentCaptures = history.map(\.url)
        }
    }

    var displays: [HaloCaptureDisplay] {
        let screens = NSScreen.screens
        let main = NSScreen.main
        return screens.enumerated().compactMap { offset, screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return HaloCaptureDisplay(index: offset + 1,
                                      displayID: CGDirectDisplayID(number.uint32Value),
                                      name: screen.localizedName,
                                      frame: screen.frame,
                                      isMain: screen == main)
        }
    }

    func updatePreferences(_ body: (inout HaloCapturePreferences) -> Void) {
        var value = preferences
        body(&value)
        preferences = value.normalized()
    }

    // Backwards-compatible entry point used by the existing regular Capture module.
    func capture(completion: @escaping (URL) -> Void) { capture(mode: preferences.defaultMode, completion: completion) }

    func capture(mode: HaloCaptureMode, displayIndex: Int = 1, completion: @escaping (URL) -> Void = { _ in }) {
        guard !busy, !recording else { return }
        guard prepareSourceAndPrivacy() else { return }
        guard ensureScreenPermission() else { return }
        if mode == .repeated {
            captureRepeated(displayIndex: displayIndex, completion: completion)
            return
        }
        busy = true
        error = nil
        status = mode == .delayed ? "Waiting for delayed capture…" : "Capture ready…"
        let snapshot = preferences.normalized()
        snapshotSource()
        Task {
            do {
                let url = try await performScreenshot(mode: mode, displayIndex: displayIndex, preferences: snapshot)
                try await finishCapture(url: url, mode: mode, preferences: snapshot)
                completion(url)
            } catch is CancellationError {
                status = "Capture cancelled"
            } catch {
                self.error = error.localizedDescription
                status = "Capture failed"
            }
            busy = false
        }
    }

    func captureRepeated(displayIndex: Int = 1, completion: @escaping (URL) -> Void = { _ in }) {
        guard !busy, !recording else { return }
        guard prepareSourceAndPrivacy(), ensureScreenPermission() else { return }
        busy = true
        error = nil
        snapshotSource()
        let snapshot = preferences.normalized()
        Task {
            do {
                for index in 0..<snapshot.repeatCount {
                    countdown = snapshot.repeatCount - index
                    status = "Repeated capture \(index + 1) of \(snapshot.repeatCount)"
                    let url = try await performScreenshot(mode: .display, displayIndex: displayIndex, preferences: snapshot, sequenceOffset: index)
                    try await finishCapture(url: url, mode: .repeated, preferences: snapshot)
                    completion(url)
                    if index + 1 < snapshot.repeatCount {
                        try await Task.sleep(nanoseconds: UInt64(snapshot.repeatInterval * 1_000_000_000))
                    }
                }
                countdown = 0
                status = "Repeated capture complete"
            } catch {
                countdown = 0
                self.error = error.localizedDescription
                status = "Repeated capture failed"
            }
            busy = false
        }
    }

    func recognize(_ url: URL) {
        guard !busy else { return }
        busy = true
        error = nil
        status = "Reading text and codes…"
        Task {
            do {
                let analysis = try await Task.detached(priority: .userInitiated) { try Self.analyze(url: url) }.value
                applyAnalysis(analysis)
                if preferences.copyOCRAfterRecognition { copyText(analysis.text) }
                if preferences.pasteOCRAfterRecognition, !analysis.text.isEmpty {
                    copyText(analysis.text); Self.pasteClipboardIfTrusted()
                }
                updateHistoryAnalysis(url: url, analysis: analysis)
                status = analysis.text.isEmpty && analysis.codes.isEmpty ? "No text or code found" : "Analysis complete"
            } catch {
                self.error = error.localizedDescription
                status = "OCR failed"
            }
            busy = false
        }
    }

    func recognizeRegion(completion: @escaping (URL) -> Void = { _ in }) {
        let old = preferences.ocrAfterCapture
        updatePreferences { $0.ocrAfterCapture = true }
        capture(mode: .region) { [weak self] url in
            self?.updatePreferences { $0.ocrAfterCapture = old }
            completion(url)
        }
    }

    func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .pdf]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { recognize(url) }
    }

    func chooseImageForCodes() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url { recognize(url) }
    }

    func smartCapture(completion: @escaping (URL) -> Void = { _ in }) {
        capture(mode: .region) { [weak self] url in
            self?.recognize(url)
            completion(url)
        }
    }

    // MARK: Recording

    func startRecording(target: HaloCaptureRecordingTarget, displayIndex: Int = 1, completion: @escaping (URL) -> Void = { _ in }) {
        guard !recording, !busy else { return }
        guard prepareSourceAndPrivacy(), ensureScreenPermission() else { return }
        snapshotSource()
        error = nil
        let snapshot = preferences.normalized()
        if snapshot.recordSystemAudio {
            guard target == .display else {
                error = "System-audio recording uses Display mode. Region and Window recording can still use the microphone."
                return
            }
            guard #available(macOS 15.0, *) else {
                error = "System-audio file recording requires macOS 15 or newer."
                return
            }
        }
        recording = true
        Task {
            do {
                try await runCountdown(snapshot.recordCountdown)
                let url = recordingURL(preferences: snapshot)
                if snapshot.recordSystemAudio, #available(macOS 15.0, *) {
                    guard let display = displays.first(where: { $0.index == displayIndex }) ?? displays.first else {
                        throw NSError(domain: "HaloCapture", code: 31, userInfo: [NSLocalizedDescriptionKey: "Display unavailable."])
                    }
                    let session = HaloScreenCaptureRecordingSession(outputURL: url) { [weak self] result in
                        Task { @MainActor in
                            guard let self else { return }
                            self.recording = false
                            self.recordingSession = nil
                            switch result {
                            case .success(let finished):
                                self.registerRecording(finished, target: target)
                                completion(finished)
                            case .failure(let failure):
                                self.error = failure.localizedDescription
                                self.status = "Recording failed"
                            }
                        }
                    }
                    recordingSession = session
                    try await session.start(displayID: display.displayID,
                                            includeSystemAudio: true,
                                            includeMicrophone: snapshot.recordMicrophone,
                                            showClicks: snapshot.showRecordingClicks)
                    status = snapshot.recordMicrophone ? "Recording display + system audio + microphone" : "Recording display + system audio"
                } else {
                    try await startNativeRecording(target: target, displayIndex: displayIndex, url: url, preferences: snapshot, completion: completion)
                }
            } catch {
                recording = false
                recordingSession = nil
                self.error = error.localizedDescription
                status = "Recording failed"
            }
        }
    }

    func stopRecording() {
        guard recording else { return }
        status = "Finishing recording…"
        if #available(macOS 15.0, *), let session = recordingSession as? HaloScreenCaptureRecordingSession {
            session.stop()
        } else if let process = activeProcess, process.isRunning {
            process.interrupt()
        } else {
            recording = false
        }
    }

    // MARK: Utility tools

    func sampleColor() {
        NSColorSampler().show { [weak self] color in
            guard let color else { return }
            Task { @MainActor in
                self?.colorSample = Self.makeColorSample(color)
                self?.status = "Color sampled"
            }
        }
    }

    func startMeasurement() {
        measurement = nil
        HaloMeasurementOverlayController.shared.begin { [weak self] result in
            self?.measurement = result
            self?.status = result == nil ? "Measurement cancelled" : "Measurement complete"
        }
    }

    func pinToScreen(_ url: URL) { HaloCapturePinController.shared.pin(url: url) }

    func freezeScreen(displayIndex: Int = 1) {
        guard !busy else { return }
        guard ensureScreenPermission() else { return }
        busy = true
        snapshotSource()
        var snapshot = preferences
        snapshot.destination = .clipboard
        snapshot.format = .png
        Task {
            do {
                let url = try await performScreenshot(mode: .display, displayIndex: displayIndex, preferences: snapshot)
                let screen = displays.first(where: { $0.index == displayIndex }).flatMap { target in NSScreen.screens.first(where: { Self.displayID($0) == target.displayID }) } ?? NSScreen.main
                HaloFreezeScreenController.shared.show(url: url, screen: screen)
                status = "Screen frozen · press Esc to dismiss"
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }

    func copyImage(_ url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        let board = NSPasteboard.general
        board.clearContents(); board.writeObjects([image])
        status = "Image copied"
    }

    func copyText(_ text: String? = nil) {
        let value = text ?? recognizedText
        guard !value.isEmpty else { return }
        let board = NSPasteboard.general
        board.clearContents(); board.setString(value, forType: .string)
        status = "Text copied"
    }

    func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    func annotate(_ url: URL) { NSWorkspace.shared.open(url) }

    func scanDocument(_ url: URL, completion: @escaping (URL) -> Void = { _ in }) {
        guard !busy else { return }
        busy = true; status = "Straightening document…"
        Task {
            do {
                let output = try await Task.detached(priority: .userInitiated) { try Self.documentScan(url: url) }.value
                registerExternalResult(output, mode: "Document Scan")
                recognize(output)
                completion(output)
            } catch { self.error = error.localizedDescription; busy = false; status = "Document scan failed" }
        }
    }

    func extractDominantImage(_ url: URL, completion: @escaping (URL) -> Void = { _ in }) {
        guard !busy else { return }
        busy = true; status = "Finding dominant image…"
        Task {
            do {
                let output = try await Task.detached(priority: .userInitiated) { try Self.cropLargestRectangle(url: url) }.value
                registerExternalResult(output, mode: "Image Extract")
                busy = false; status = "Image extracted"
                completion(output)
            } catch { self.error = error.localizedDescription; busy = false; status = "Image extraction failed" }
        }
    }

    func clearHistory(deleteFiles: Bool = false) {
        if deleteFiles {
            for item in history where item.path.contains("/Halo/Captures/") { try? FileManager.default.removeItem(at: item.url) }
        }
        history = []; recentCaptures = []; persistHistory()
    }

    func removeHistoryItem(_ item: HaloCaptureHistoryItem) {
        history.removeAll { $0.id == item.id }
        recentCaptures = history.map(\.url)
        persistHistory()
    }

    // MARK: Capture implementation

    private func performScreenshot(mode: HaloCaptureMode, displayIndex: Int, preferences: HaloCapturePreferences, sequenceOffset: Int = 0) async throws -> URL {
        let finalURL = makeOutputURL(format: preferences.format, sequenceOffset: sequenceOffset, preferences: preferences)
        let tempURL = preferences.format == .png ? finalURL : temporaryURL(extension: "png")
        var args = ["-x", "-tpng"]
        switch mode {
        case .region:
            args += ["-i", "-s"]
        case .window:
            args += ["-i", "-w"]
        case .screen:
            args += ["-m"]
        case .display:
            args += ["-D\(max(1, displayIndex))"]
        case .delayed:
            args += ["-D\(max(1, displayIndex))", "-T\(preferences.delaySeconds)"]
        case .repeated:
            args += ["-D\(max(1, displayIndex))"]
        }
        args.append(tempURL.path)
        try await runProcess(arguments: args)
        guard FileManager.default.fileExists(atPath: tempURL.path) else { throw CancellationError() }
        if preferences.format != .png {
            try Self.transcode(input: tempURL, output: finalURL, format: preferences.format, quality: preferences.quality)
            try? FileManager.default.removeItem(at: tempURL)
        }
        advanceSequence()
        return finalURL
    }

    private func finishCapture(url: URL, mode: HaloCaptureMode, preferences: HaloCapturePreferences) async throws {
        var analysis = HaloCaptureAnalysis()
        if preferences.ocrAfterCapture {
            analysis = try await Task.detached(priority: .userInitiated) { try Self.analyze(url: url) }.value
            applyAnalysis(analysis)
            if preferences.copyOCRAfterRecognition { copyText(analysis.text) }
            if preferences.pasteOCRAfterRecognition, !analysis.text.isEmpty { copyText(analysis.text); Self.pasteClipboardIfTrusted() }
        } else {
            let dimensions = Self.imageDimensions(url: url)
            analysis.width = dimensions.width; analysis.height = dimensions.height
        }
        register(url: url, mode: mode.rawValue, analysis: analysis, preferences: preferences)
        if preferences.copyAfterCapture || preferences.destination == .clipboard { copyImage(url) }
        if preferences.openAfterCapture { NSWorkspace.shared.open(url) }
        status = "Captured \(url.lastPathComponent)"
    }

    private func register(url: URL, mode: String, analysis: HaloCaptureAnalysis, preferences: HaloCapturePreferences) {
        let item = HaloCaptureHistoryItem(id: UUID(), path: url.path, createdAt: Date(), sourceApp: lastSourceApp,
                                          sourceBundleID: lastSourceBundleID, width: analysis.width, height: analysis.height,
                                          mode: mode, ocrText: analysis.text, decodedCodes: analysis.codes)
        history.removeAll { $0.path == url.path }
        history.insert(item, at: 0)
        history = Array(history.prefix(preferences.historyLimit))
        recentCaptures = history.map(\.url)
        if !preferences.neverStoreCaptures { persistHistory() }
    }

    private func registerExternalResult(_ url: URL, mode: String) {
        var analysis = HaloCaptureAnalysis()
        let dimensions = Self.imageDimensions(url: url); analysis.width = dimensions.width; analysis.height = dimensions.height
        register(url: url, mode: mode, analysis: analysis, preferences: preferences)
    }

    private func registerRecording(_ url: URL, target: HaloCaptureRecordingTarget) {
        var analysis = HaloCaptureAnalysis()
        register(url: url, mode: "Recording · \(target.rawValue)", analysis: analysis, preferences: preferences)
        status = "Recording saved"
        if preferences.openAfterCapture { NSWorkspace.shared.open(url) }
    }

    private func updateHistoryAnalysis(url: URL, analysis: HaloCaptureAnalysis) {
        guard let index = history.firstIndex(where: { $0.path == url.path }) else { return }
        history[index].ocrText = analysis.text; history[index].decodedCodes = analysis.codes
        if analysis.width > 0 { history[index].width = analysis.width; history[index].height = analysis.height }
        persistHistory()
    }

    private func applyAnalysis(_ analysis: HaloCaptureAnalysis) {
        recognizedText = analysis.text
        decodedCodes = analysis.codes
        detectedValues = analysis.values
        let textPart = analysis.text.isEmpty ? "no text" : "\(analysis.text.split(separator: "\n").count) text blocks"
        let codePart = analysis.codes.isEmpty ? "no codes" : "\(analysis.codes.count) code\(analysis.codes.count == 1 ? "" : "s")"
        smartSummary = "\(textPart) · \(codePart) · \(analysis.rectangles) rectangle\(analysis.rectangles == 1 ? "" : "s")"
    }

    private func startNativeRecording(target: HaloCaptureRecordingTarget, displayIndex: Int, url: URL, preferences: HaloCapturePreferences, completion: @escaping (URL) -> Void) async throws {
        var args = ["-v", "-x"]
        switch target {
        case .region: args += ["-i", "-Jvideo"]
        case .window: args += ["-i", "-Jwindow"]
        case .display: args += ["-D\(max(1, displayIndex))"]
        }
        if preferences.recordMicrophone { args.append("-g") }
        if preferences.showRecordingClicks { args.append("-k") }
        args.append(url.path)
        status = preferences.recordMicrophone ? "Recording with microphone" : "Recording"
        do {
            try await runProcess(arguments: args, exposeAsRecording: true)
            if FileManager.default.fileExists(atPath: url.path) {
                registerRecording(url, target: target); completion(url)
            }
        } catch is CancellationError {
            if FileManager.default.fileExists(atPath: url.path) { registerRecording(url, target: target); completion(url) }
        }
        recording = false
    }

    private func runCountdown(_ seconds: Int) async throws {
        guard seconds > 0 else { return }
        for value in stride(from: seconds, through: 1, by: -1) {
            countdown = value; status = "Recording starts in \(value)…"
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        countdown = 0
    }

    private func runProcess(arguments: [String], exposeAsRecording: Bool = false) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments
        activeProcess = process
        try process.run()
        let code: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
        }
        if activeProcess === process { activeProcess = nil }
        if code != 0 && !(exposeAsRecording && [2, 15].contains(code)) { throw CancellationError() }
    }

    private func prepareSourceAndPrivacy() -> Bool {
        let app = NSWorkspace.shared.frontmostApplication
        let bundle = app?.bundleIdentifier ?? ""
        let source = app?.localizedName ?? "Mac"
        if preferences.excludedBundleIDs.contains(bundle) {
            error = "Capture blocked for \(source) by Capture Privacy settings."
            status = "Privacy block"
            return false
        }
        return true
    }

    private func snapshotSource() {
        let app = NSWorkspace.shared.frontmostApplication
        lastSourceBundleID = app?.bundleIdentifier ?? ""
        lastSourceApp = app?.localizedName ?? "Mac"
    }

    private func ensureScreenPermission() -> Bool {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            error = "Allow Screen Recording in System Settings → Privacy & Security → Screen Recording, then relaunch Halo if macOS requests it."
            return false
        }
        return true
    }

    private func outputDirectory(preferences: HaloCapturePreferences) -> URL {
        let fm = FileManager.default
        if preferences.neverStoreCaptures || preferences.destination == .clipboard {
            return fm.temporaryDirectory.appendingPathComponent("HaloCapture", isDirectory: true)
        }
        switch preferences.destination {
        case .desktop: return fm.urls(for: .desktopDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        case .downloads: return fm.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        case .custom:
            if !preferences.customFolderPath.isEmpty { return URL(fileURLWithPath: preferences.customFolderPath, isDirectory: true) }
            fallthrough
        case .shelf, .notes:
            let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
            return base.appendingPathComponent("Halo/Captures", isDirectory: true)
        case .clipboard: return fm.temporaryDirectory
        }
    }

    private func makeOutputURL(format: HaloCaptureFormat, sequenceOffset: Int, preferences: HaloCapturePreferences) -> URL {
        let directory = outputDirectory(preferences: preferences)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let app = Self.sanitize(lastSourceApp.isEmpty ? "Mac" : lastSourceApp)
        let now = Date()
        let date = Self.dateFormatter.string(from: now)
        let time = Self.timeFormatter.string(from: now)
        let seq = preferences.sequence + sequenceOffset
        var name = preferences.namingTemplate
            .replacingOccurrences(of: "{app}", with: app)
            .replacingOccurrences(of: "{date}", with: date)
            .replacingOccurrences(of: "{time}", with: time)
            .replacingOccurrences(of: "{seq}", with: String(format: "%03d", seq))
            .replacingOccurrences(of: "{prefix}", with: Self.sanitize(preferences.prefix))
        name = Self.sanitize(name)
        if name.isEmpty { name = "Halo_\(date)_\(time)" }
        var result = directory.appendingPathComponent(name).appendingPathExtension(format.fileExtension)
        var suffix = 2
        while FileManager.default.fileExists(atPath: result.path) {
            result = directory.appendingPathComponent("\(name)_\(suffix)").appendingPathExtension(format.fileExtension); suffix += 1
        }
        return result
    }

    private func recordingURL(preferences: HaloCapturePreferences) -> URL {
        let directory = outputDirectory(preferences: preferences)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = Self.sanitize("\(preferences.prefix)_Recording_\(Self.dateFormatter.string(from: Date()))_\(Self.timeFormatter.string(from: Date()))")
        return directory.appendingPathComponent(name).appendingPathExtension("mp4")
    }

    private func temporaryURL(extension ext: String) -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("HaloCapture", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
    }

    private func advanceSequence() { updatePreferences { $0.sequence += 1 } }

    // MARK: Analysis / processing

    private static func analyze(url: URL) throws -> HaloCaptureAnalysis {
        let text = VNRecognizeTextRequest(); text.recognitionLevel = .accurate; text.usesLanguageCorrection = true
        let codes = VNDetectBarcodesRequest()
        let rectangles = VNDetectRectanglesRequest(); rectangles.maximumObservations = 12; rectangles.minimumConfidence = 0.45
        let handler = VNImageRequestHandler(url: url, options: [:])
        try handler.perform([text, codes, rectangles])
        var result = HaloCaptureAnalysis()
        result.text = text.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") ?? ""
        result.codes = Array(Set(codes.results?.compactMap(\.payloadStringValue) ?? [])).sorted()
        result.rectangles = rectangles.results?.count ?? 0
        let size = imageDimensions(url: url); result.width = size.width; result.height = size.height
        result.values = detectValues(in: result.text)
        return result
    }

    private static func detectValues(in text: String) -> [HaloCaptureDetectedValue] {
        guard !text.isEmpty else { return [] }
        var output: [HaloCaptureDetectedValue] = []
        let full = NSRange(text.startIndex..<text.endIndex, in: text)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.phoneNumber.rawValue | NSTextCheckingResult.CheckingType.date.rawValue) {
            for match in detector.matches(in: text, range: full) {
                if let url = match.url {
                    let raw = url.absoluteString
                    output.append(HaloCaptureDetectedValue(kind: raw.lowercased().hasPrefix("mailto:") ? .email : .link,
                                                           value: raw.replacingOccurrences(of: "mailto:", with: "")))
                } else if let phone = match.phoneNumber { output.append(.init(kind: .phone, value: phone)) }
                else if let date = match.date { output.append(.init(kind: .date, value: DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short))) }
            }
        }
        if let regex = try? NSRegularExpression(pattern: #"(?<![A-Za-z])[-+]?\d[\d,.]*\b"#) {
            for match in regex.matches(in: text, range: full).prefix(20) {
                if let range = Range(match.range, in: text) { output.append(.init(kind: .number, value: String(text[range]))) }
            }
        }
        var seen = Set<String>()
        return output.filter { seen.insert("\($0.kind.rawValue):\($0.value)").inserted }
    }

    private static func imageDimensions(url: URL) -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return (0, 0) }
        return ((properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0,
                (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0)
    }

    private static func transcode(input: URL, output: URL, format: HaloCaptureFormat, quality: Double) throws {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "HaloCapture", code: 41, userInfo: [NSLocalizedDescriptionKey: "Could not decode capture image."])
        }
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, format.typeIdentifier, 1, nil) else {
            throw NSError(domain: "HaloCapture", code: 42, userInfo: [NSLocalizedDescriptionKey: "Could not create \(format.rawValue) output."])
        }
        let properties: CFDictionary = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "HaloCapture", code: 43, userInfo: [NSLocalizedDescriptionKey: "Could not finish \(format.rawValue) output."])
        }
    }

    private static func largestRectangle(url: URL) throws -> VNRectangleObservation {
        let request = VNDetectRectanglesRequest(); request.maximumObservations = 8; request.minimumAspectRatio = 0.15; request.minimumSize = 0.12; request.minimumConfidence = 0.45
        try VNImageRequestHandler(url: url, options: [:]).perform([request])
        guard let result = request.results?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else {
            throw NSError(domain: "HaloCapture", code: 51, userInfo: [NSLocalizedDescriptionKey: "No clear document or image rectangle was detected."])
        }
        return result
    }

    private static func documentScan(url: URL) throws -> URL {
        let rectangle = try largestRectangle(url: url)
        guard let input = CIImage(contentsOf: url) else { throw NSError(domain: "HaloCapture", code: 52, userInfo: [NSLocalizedDescriptionKey: "Could not read image."]) }
        let extent = input.extent
        func point(_ normalized: CGPoint) -> CIVector { CIVector(x: extent.minX + normalized.x * extent.width, y: extent.minY + normalized.y * extent.height) }
        guard let perspective = CIFilter(name: "CIPerspectiveCorrection") else { throw NSError(domain: "HaloCapture", code: 53) }
        perspective.setValue(input, forKey: kCIInputImageKey)
        perspective.setValue(point(rectangle.topLeft), forKey: "inputTopLeft")
        perspective.setValue(point(rectangle.topRight), forKey: "inputTopRight")
        perspective.setValue(point(rectangle.bottomRight), forKey: "inputBottomRight")
        perspective.setValue(point(rectangle.bottomLeft), forKey: "inputBottomLeft")
        guard var output = perspective.outputImage else { throw NSError(domain: "HaloCapture", code: 54) }
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(output, forKey: kCIInputImageKey); controls.setValue(1.18, forKey: kCIInputContrastKey); controls.setValue(0.10, forKey: kCIInputSaturationKey); controls.setValue(0.02, forKey: kCIInputBrightnessKey)
            output = controls.outputImage ?? output
        }
        guard let cg = CIContext().createCGImage(output, from: output.extent) else { throw NSError(domain: "HaloCapture", code: 55) }
        let target = url.deletingPathExtension().appendingPathExtension("scan.png")
        try write(cgImage: cg, to: target, type: UTType.png.identifier as CFString, quality: 1)
        return target
    }

    private static func cropLargestRectangle(url: URL) throws -> URL {
        let rectangle = try largestRectangle(url: url)
        guard let input = CIImage(contentsOf: url) else { throw NSError(domain: "HaloCapture", code: 56) }
        let extent = input.extent
        let box = rectangle.boundingBox
        let crop = CGRect(x: extent.minX + box.minX * extent.width,
                          y: extent.minY + box.minY * extent.height,
                          width: box.width * extent.width,
                          height: box.height * extent.height).intersection(extent)
        guard crop.width > 4, crop.height > 4,
              let cg = CIContext().createCGImage(input.cropped(to: crop), from: crop) else { throw NSError(domain: "HaloCapture", code: 57) }
        let target = url.deletingPathExtension().appendingPathExtension("extract.png")
        try write(cgImage: cg, to: target, type: UTType.png.identifier as CFString, quality: 1)
        return target
    }

    private static func write(cgImage: CGImage, to url: URL, type: CFString, quality: Double) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type, 1, nil) else { throw NSError(domain: "HaloCapture", code: 58) }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "HaloCapture", code: 59) }
    }

    private static func makeColorSample(_ source: NSColor) -> HaloCaptureColorSample {
        let color = source.usingColorSpace(.deviceRGB) ?? source
        let r = Double(color.redComponent), g = Double(color.greenComponent), b = Double(color.blueComponent)
        let maxValue = max(r, max(g, b)), minValue = min(r, min(g, b)), delta = maxValue - minValue
        let lightness = (maxValue + minValue) / 2
        let saturation = delta == 0 ? 0 : delta / (1 - abs(2 * lightness - 1))
        var hue = 0.0
        if delta > 0 {
            if maxValue == r { hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxValue == g { hue = (b - r) / delta + 2 }
            else { hue = (r - g) / delta + 4 }
            hue /= 6; if hue < 0 { hue += 1 }
        }
        let hex = String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
        return HaloCaptureColorSample(red: r, green: g, blue: b, alpha: Double(color.alphaComponent), hue: hue, saturation: saturation, lightness: lightness, hex: hex)
    }

    nonisolated private static func pasteClipboardIfTrusted() {
        guard AXIsProcessTrusted() else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
    }

    nonisolated private static func sanitize(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>\n\r\t")
        return value.components(separatedBy: invalid).filter { !$0.isEmpty }.joined(separator: "_").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func displayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }

    private static let dateFormatter: DateFormatter = { let value = DateFormatter(); value.dateFormat = "yyyy-MM-dd"; return value }()
    private static let timeFormatter: DateFormatter = { let value = DateFormatter(); value.dateFormat = "HH-mm-ss"; return value }()

    private func persistPreferences() {
        if let data = try? JSONEncoder().encode(preferences.normalized()) { defaults.set(data, forKey: preferenceKey) }
    }
    private func persistHistory() {
        if let data = try? JSONEncoder().encode(Array(history.prefix(preferences.historyLimit))) { defaults.set(data, forKey: historyKey) }
    }
}

// MARK: - ScreenCaptureKit recording (macOS 15+)

@available(macOS 15.0, *)
private final class HaloScreenCaptureRecordingSession: NSObject, SCStreamDelegate, SCRecordingOutputDelegate {
    private let outputURL: URL
    private let completion: (Result<URL, Error>) -> Void
    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var finished = false

    init(outputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        self.outputURL = outputURL; self.completion = completion
    }

    func start(displayID: CGDirectDisplayID, includeSystemAudio: Bool, includeMicrophone: Bool, showClicks: Bool) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw NSError(domain: "HaloCapture", code: 71, userInfo: [NSLocalizedDescriptionKey: "ScreenCaptureKit could not find that display."])
        }
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(CGDisplayPixelsWide(displayID)))
        configuration.height = max(1, Int(CGDisplayPixelsHigh(displayID)))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 5
        configuration.showsCursor = true
        configuration.showMouseClicks = showClicks
        configuration.capturesAudio = includeSystemAudio
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        configuration.captureMicrophone = includeMicrophone

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        let outputConfiguration = SCRecordingOutputConfiguration()
        outputConfiguration.outputURL = outputURL
        outputConfiguration.outputFileType = .mp4
        let output = SCRecordingOutput(configuration: outputConfiguration, delegate: self)
        try stream.addRecordingOutput(output)
        self.stream = stream; recordingOutput = output
        try await stream.startCapture()
    }

    func stop() {
        guard let stream else { return }
        Task { try? await stream.stopCapture() }
    }

    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {}
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) { finish(.success(outputURL)) }
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) { finish(.failure(error)) }
    func stream(_ stream: SCStream, didStopWithError error: Error) { if !finished { finish(.failure(error)) } }

    private func finish(_ result: Result<URL, Error>) {
        guard !finished else { return }; finished = true; completion(result)
    }
}

// MARK: - Pin / freeze / measurement windows

@MainActor
private final class HaloCapturePinController {
    static let shared = HaloCapturePinController()
    private var windows: [NSWindow] = []

    func pin(url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        let ratio = max(0.2, image.size.width / max(1, image.size.height))
        let width = min(640, max(240, image.size.width * 0.45))
        let height = min(520, max(140, width / ratio))
        let imageView = NSImageView(); imageView.image = image; imageView.imageScaling = .scaleProportionallyUpOrDown
        let window = NSPanel(contentRect: CGRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
        window.title = url.lastPathComponent; window.level = .floating; window.isFloatingPanel = true; window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = imageView; window.center(); window.makeKeyAndOrderFront(nil)
        windows.append(window); windows.removeAll { !$0.isVisible }
    }
}

@MainActor
private final class HaloFreezeScreenController {
    static let shared = HaloFreezeScreenController()
    private var window: NSPanel?
    private var monitor: Any?

    func show(url: URL, screen: NSScreen?) {
        dismiss()
        guard let screen, let image = NSImage(contentsOf: url) else { return }
        let imageView = NSImageView(frame: CGRect(origin: .zero, size: screen.frame.size)); imageView.image = image; imageView.imageScaling = .scaleAxesIndependently
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
        panel.level = .statusBar; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; panel.backgroundColor = .black; panel.contentView = imageView
        panel.makeKeyAndOrderFront(nil); window = panel
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.dismiss(); return nil }
            return event
        }
    }

    func dismiss() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        window?.orderOut(nil); window = nil
    }
}

private final class HaloMeasurementView: NSView {
    var completion: ((CGPoint, CGPoint) -> Void)?
    var startPoint: CGPoint?
    var hoverPoint: CGPoint?
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let startPoint { completion?(startPoint, point) }
        else { startPoint = point; hoverPoint = point; needsDisplay = true }
    }
    override func mouseMoved(with event: NSEvent) { hoverPoint = convert(event.locationInWindow, from: nil); needsDisplay = true }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { completion?(.zero, .zero) } else { super.keyDown(with: event) } }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); dirtyRect.fill()
        guard let start = startPoint, let end = hoverPoint else { return }
        NSColor.controlAccentColor.setStroke()
        let line = NSBezierPath(); line.lineWidth = 1.5; line.move(to: start); line.line(to: end); line.stroke()
        for point in [start, end] { NSBezierPath(ovalIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)).stroke() }
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
        let box = NSBezierPath(rect: rect); box.lineWidth = 1; box.stroke()
    }
}

@MainActor
private final class HaloMeasurementOverlayController {
    static let shared = HaloMeasurementOverlayController()
    private var panel: NSPanel?

    func begin(completion: @escaping (HaloCaptureMeasurement?) -> Void) {
        panel?.orderOut(nil)
        guard let screen = NSScreen.main else { completion(nil); return }
        let view = HaloMeasurementView(frame: CGRect(origin: .zero, size: screen.frame.size))
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
        panel.level = .screenSaver; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; panel.backgroundColor = NSColor.black.withAlphaComponent(0.08); panel.isOpaque = false
        panel.acceptsMouseMovedEvents = true; panel.contentView = view
        view.completion = { [weak self, weak panel] start, end in
            panel?.orderOut(nil); self?.panel = nil
            if start == .zero && end == .zero { completion(nil) }
            else { completion(HaloCaptureMeasurement(start: start, end: end, scale: Double(screen.backingScaleFactor))) }
        }
        self.panel = panel; panel.makeKeyAndOrderFront(nil); panel.makeFirstResponder(view)
        NSCursor.crosshair.push()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { NSCursor.pop() }
    }
}
