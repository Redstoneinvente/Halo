//
//  ContextProviderEngine.swift
//  Halo
//
//  Central, event-driven context authority for declarative Custom CIs.
//

import AppKit
import Combine
import Foundation

struct HaloCIContextRequest {
    let packageID: String
    let packageName: String
    let sdkVersion: String
    let expanded: Bool
    let activationKind: String
    let declaredPermissions: Set<String>
    let grantedPermissions: Set<String>
}

/// Providers must be cheap, synchronous, and side-effect free.
/// They may only return already-available in-memory state. Any I/O belongs in an
/// event ingestion path, never in `values(for:workspace:engine:)`.
@MainActor
protocol HaloCIContextProvider {
    var identifier: String { get }
    func values(
        for request: HaloCIContextRequest,
        workspace: WorkspaceStore,
        engine: HaloCIContextProviderEngine
    ) -> [String: String]
}

private struct HaloCIWorkspaceContextProvider: HaloCIContextProvider {
    let identifier = "halo.workspace"

    func values(
        for request: HaloCIContextRequest,
        workspace: WorkspaceStore,
        engine: HaloCIContextProviderEngine
    ) -> [String: String] {
        var values: [String: String] = [
            "halo.surface.state": request.expanded ? "expanded" : "closed",
            "halo.surface.isExpanded": request.expanded ? "true" : "false",
            "ci.id": request.packageID,
            "ci.name": request.packageName,
            "ci.activation.kind": request.activationKind,

            "system.battery.isCharging": workspace.system.charging ? "true" : "false",
            "system.battery.onBattery": workspace.system.onBattery ? "true" : "false",
            "system.power.source": workspace.system.onBattery ? "battery" : "ac",
            "system.lowPowerMode": workspace.system.lowPower ? "true" : "false",
            "system.cpu.usedPercent": Self.number(workspace.system.cpuUsage),
            "system.memory.usedPercent": Self.number(workspace.system.memoryUsage),
            "system.storage.usedPercent": Self.number(workspace.system.diskUsage),
            "system.thermalState": workspace.system.thermalState,
            "system.network.downBytesPerSecond": Self.number(workspace.system.networkDownPerSecond),
            "system.network.upBytesPerSecond": Self.number(workspace.system.networkUpPerSecond),

            "media.isPlaying": workspace.media.isPlaying ? "true" : "false",
            "media.title": workspace.media.title,
            "media.artist": workspace.media.artist,
            "media.album": workspace.media.album,
            "media.duration": Self.number(workspace.media.duration),
            "media.position": Self.number(workspace.media.position),

            "audio.canSetVolume": workspace.audio.canSetVolume ? "true" : "false",

            "displays.count": String(NSScreen.screens.count)
        ]

        if let battery = workspace.system.battery {
            values["system.battery.level"] = String(battery)
        }

        if let output = workspace.audio.devices.first(where: { $0.id == workspace.audio.selected })?.name {
            values["audio.output.name"] = output
        }
        if workspace.audio.canSetVolume {
            values["audio.volume"] = Self.number(Double(workspace.audio.volume))
        }

        if request.grantedPermissions.contains("Applications.Observe") {
            let app = NSWorkspace.shared.frontmostApplication
            values["apps.active.bundleID"] = app?.bundleIdentifier ?? ""
            values["apps.active.name"] = app?.localizedName ?? ""
        }

        let clock = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: Date())
        values["time.minuteOfDay"] = String((clock.hour ?? 0) * 60 + (clock.minute ?? 0))

        return values
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

private struct HaloCITransientContextProvider: HaloCIContextProvider {
    let identifier = "halo.transient"

    func values(
        for request: HaloCIContextRequest,
        workspace: WorkspaceStore,
        engine: HaloCIContextProviderEngine
    ) -> [String: String] {
        engine.transientValues()
    }
}

private struct HaloCIBluetoothContextProvider: HaloCIContextProvider {
    let identifier = "halo.bluetooth"

    func values(
        for request: HaloCIContextRequest,
        workspace: WorkspaceStore,
        engine: HaloCIContextProviderEngine
    ) -> [String: String] {
        let bluetooth = BluetoothStateService.shared
        var values: [String: String] = [
            "bluetooth.poweredOn": bluetooth.poweredOn ? "true" : "false",
            "bluetooth.connectedCount": String(bluetooth.connectedDevices.count)
        ]
        if let event = bluetooth.lastEvent {
            values["bluetooth.lastEvent.kind"] = event.kind.contextValue
        }
        return values
    }
}

private extension BluetoothConnectionEventKind {
    var contextValue: String {
        switch self {
        case .connected: return "connected"
        case .disconnected: return "disconnected"
        case .poweredOn: return "poweredOn"
        case .poweredOff: return "poweredOff"
        }
    }
}

private struct HaloCIContextEvent {
    let kind: String
    let source: String
    let date: Date
    let sequence: UInt64
}

private struct HaloCIDragSummary: Equatable, Sendable {
    var itemCount = 0
    var fileCount = 0
    var folderCount = 0
    var extensions: [String] = []

    var kind: String {
        if itemCount == 0 { return "none" }
        if folderCount == itemCount { return "folders" }
        if fileCount == itemCount { return "files" }
        return "mixed"
    }
}

private struct HaloCIDropRecord {
    var summary = HaloCIDragSummary()
    var date = Date.distantPast
}

private struct HaloCIClipboardRecord {
    var hasText = false
    var textLength = 0
    var event = "none"
}

private struct HaloCINotificationRecord {
    var kind = "none"
    var source = ""
    var date = Date.distantPast
}

/// Single authority for context exposed to Custom CIs.
///
/// Performance rules:
/// - snapshots do no disk/network I/O;
/// - context changes are coalesced before publishing a revision;
/// - existing Halo service sampling is reused instead of adding new pollers;
/// - file/folder classification happens once, off-main, at drag/drop boundaries;
/// - transient payloads are bounded metadata, not retained file URLs or clipboard bodies.
@MainActor
final class HaloCIContextProviderEngine: ObservableObject {
    static let shared = HaloCIContextProviderEngine()

    @Published private(set) var revision: UInt64 = 0

    private weak var workspace: WorkspaceStore?
    private var providers: [String: any HaloCIContextProvider] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private var revisionTask: Task<Void, Never>?
    private var sequence: UInt64 = 0

    private var lastEvent: HaloCIContextEvent?
    private var dragActive = false
    private var dragSummary = HaloCIDragSummary()
    private var dragClassificationGeneration: UInt64 = 0
    private var lastDrop = HaloCIDropRecord()
    private var clipboard = HaloCIClipboardRecord()
    private var notification = HaloCINotificationRecord()

    private let transientLifetime: TimeInterval = 30

    private init() {
        register(HaloCIWorkspaceContextProvider())
        register(HaloCITransientContextProvider())
        register(HaloCIBluetoothContextProvider())
    }

    func register(_ provider: any HaloCIContextProvider) {
        providers[provider.identifier] = provider
        invalidate()
    }

    func unregisterProvider(identifier: String) {
        guard providers.removeValue(forKey: identifier) != nil else { return }
        invalidate()
    }

    func attach(to workspace: WorkspaceStore) {
        if self.workspace === workspace, !subscriptions.isEmpty { return }

        detach()
        self.workspace = workspace

        Publishers.MergeMany([
            workspace.media.objectWillChange.eraseToAnyPublisher(),
            workspace.system.objectWillChange.eraseToAnyPublisher(),
            workspace.audio.objectWillChange.eraseToAnyPublisher()
        ])
        .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        .sink { [weak self] _ in self?.invalidate() }
        .store(in: &subscriptions)

        workspace.$runningApps
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.invalidate() }
            .store(in: &subscriptions)

        workspace.system.$charging
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] charging in
                self?.recordEvent(
                    kind: charging ? "power.chargingStarted" : "power.chargingStopped",
                    source: "system.power"
                )
            }
            .store(in: &subscriptions)

        workspace.system.$onBattery
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] onBattery in
                self?.recordEvent(
                    kind: onBattery ? "power.onBattery" : "power.onAC",
                    source: "system.power"
                )
            }
            .store(in: &subscriptions)

        workspace.media.$isPlaying
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] playing in
                self?.recordEvent(
                    kind: playing ? "media.started" : "media.stopped",
                    source: "media"
                )
            }
            .store(in: &subscriptions)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                self?.recordEvent(
                    kind: "application.activated",
                    source: app?.bundleIdentifier ?? "application"
                )
            }
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recordEvent(kind: "display.changed", source: "system.display")
            }
            .store(in: &subscriptions)

        BluetoothStateService.shared.$lastEvent
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.recordEvent(
                    kind: "bluetooth." + event.kind.contextValue,
                    source: "bluetooth"
                )
            }
            .store(in: &subscriptions)

        // Time is the only context that inherently changes without an event. One minute
        // is sufficient for the minute-of-day contract and replaces no existing fast poll.
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.invalidate() }
            .store(in: &subscriptions)

        invalidate()
    }

    func detach() {
        subscriptions.removeAll()
        revisionTask?.cancel()
        revisionTask = nil
        workspace = nil
        dragClassificationGeneration &+= 1
        dragActive = false
        dragSummary = HaloCIDragSummary()
        lastDrop = HaloCIDropRecord()
        clipboard = HaloCIClipboardRecord()
        notification = HaloCINotificationRecord()
        lastEvent = nil
    }

    func snapshot(
        package: HaloCIParsedPackage,
        expanded: Bool,
        activationKind: String,
        grantedPermissions: Set<String>
    ) -> [String: String] {
        guard let workspace else { return [:] }

        let request = HaloCIContextRequest(
            packageID: package.manifest.id,
            packageName: package.manifest.name,
            sdkVersion: package.manifest.sdkVersion,
            expanded: expanded,
            activationKind: activationKind,
            declaredPermissions: Set(package.manifest.permissions),
            grantedPermissions: grantedPermissions
        )

        var raw: [String: String] = [:]
        for key in providers.keys.sorted() {
            guard let provider = providers[key] else { continue }
            for (name, value) in provider.values(for: request, workspace: workspace, engine: self) {
                raw[name] = String(value.prefix(HaloCISDK.maximumStringLength))
            }
        }

        return HaloCIContextCatalog.filter(
            raw,
            sdkVersion: request.sdkVersion,
            declaredPermissions: request.declaredPermissions,
            grantedPermissions: request.grantedPermissions
        )
    }

    func reportDragStarted(urls: [URL]) {
        let clean = urls.filter(\.isFileURL)
        dragActive = !clean.isEmpty
        dragSummary = Self.quickSummary(clean)
        recordEvent(kind: "drag.entered", source: "input.drag")
        classify(urls: clean, target: .drag)
    }

    func reportDragEnded() {
        guard dragActive || dragSummary.itemCount > 0 else { return }
        dragClassificationGeneration &+= 1
        dragActive = false
        dragSummary = HaloCIDragSummary()
        recordEvent(kind: "drag.exited", source: "input.drag")
    }

    func reportDrop(urls: [URL]) {
        let clean = urls.filter(\.isFileURL)
        guard !clean.isEmpty else { return }
        dragClassificationGeneration &+= 1
        dragActive = false
        dragSummary = HaloCIDragSummary()
        lastDrop = HaloCIDropRecord(summary: Self.quickSummary(clean), date: Date())
        recordEvent(kind: "drop.received", source: "input.drop")
        classify(urls: clean, target: .drop)
    }

    func reportClipboardChanged(hasText: Bool, textLength: Int) {
        clipboard.hasText = hasText
        clipboard.textLength = min(100_000, max(0, textLength))
        clipboard.event = "changed"
        recordEvent(kind: "clipboard.changed", source: "clipboard")
    }

    func reportClipboardCopy(textLength: Int) {
        clipboard.hasText = textLength > 0
        clipboard.textLength = min(100_000, max(0, textLength))
        clipboard.event = "copy"
        recordEvent(kind: "clipboard.copy", source: "clipboard")
    }

    /// Call this only when Halo actually observes/performs a paste. The engine does not
    /// install a global Cmd-V keyboard monitor or Accessibility hook merely to infer paste.
    func reportClipboardPaste(textLength: Int) {
        clipboard.hasText = textLength > 0
        clipboard.textLength = min(100_000, max(0, textLength))
        clipboard.event = "paste"
        recordEvent(kind: "clipboard.paste", source: "clipboard")
    }

    /// Entry point for a real notification provider. Halo deliberately does not scrape
    /// other apps' Notification Center contents or use private notification APIs.
    func reportNotificationReceived(source: String = "notification") {
        notification = HaloCINotificationRecord(
            kind: "received",
            source: String(source.prefix(256)),
            date: Date()
        )
        recordEvent(kind: "notification.received", source: notification.source)
    }

    func reportNotificationSent(source: String = "halo") {
        notification = HaloCINotificationRecord(
            kind: "sent",
            source: String(source.prefix(256)),
            date: Date()
        )
        recordEvent(kind: "notification.sent", source: notification.source)
    }

    func reportActivityPublished(source: String = "halo") {
        notification = HaloCINotificationRecord(
            kind: "activity",
            source: String(source.prefix(256)),
            date: Date()
        )
        recordEvent(kind: "activity.published", source: notification.source)
    }

    fileprivate func transientValues() -> [String: String] {
        var values: [String: String] = [
            "input.drag.active": dragActive ? "true" : "false",
            "input.drag.itemCount": String(dragSummary.itemCount),
            "input.drag.fileCount": String(dragSummary.fileCount),
            "input.drag.folderCount": String(dragSummary.folderCount),
            "input.drag.kind": dragSummary.kind,
            "input.drag.extensions": dragSummary.extensions.joined(separator: ","),
            "clipboard.hasText": clipboard.hasText ? "true" : "false",
            "clipboard.textLength": String(clipboard.textLength),
            "clipboard.lastEvent": clipboard.event
        ]

        if lastDrop.date > Date.distantPast {
            values["input.drop.itemCount"] = String(lastDrop.summary.itemCount)
            values["input.drop.fileCount"] = String(lastDrop.summary.fileCount)
            values["input.drop.folderCount"] = String(lastDrop.summary.folderCount)
            values["input.drop.kind"] = lastDrop.summary.kind
            values["input.drop.extensions"] = lastDrop.summary.extensions.joined(separator: ",")
            values["input.drop.ageSeconds"] = Self.age(lastDrop.date)
        }

        if let event = lastEvent, Date().timeIntervalSince(event.date) <= transientLifetime {
            values["context.event.kind"] = event.kind
            values["context.event.source"] = event.source
            values["context.event.sequence"] = String(event.sequence)
            values["context.event.ageSeconds"] = Self.age(event.date)
        }

        if notification.date > Date.distantPast,
           Date().timeIntervalSince(notification.date) <= transientLifetime {
            values["notification.last.kind"] = notification.kind
            values["notification.last.source"] = notification.source
            values["notification.last.ageSeconds"] = Self.age(notification.date)
        }

        return values
    }

    private enum ClassificationTarget {
        case drag
        case drop
    }

    private func classify(urls: [URL], target: ClassificationTarget) {
        guard !urls.isEmpty else { return }
        dragClassificationGeneration &+= 1
        let generation = dragClassificationGeneration

        Task {
            let summary = await Task.detached(priority: .utility) {
                Self.classifiedSummary(urls)
            }.value

            guard !Task.isCancelled, generation == self.dragClassificationGeneration else { return }
            switch target {
            case .drag:
                guard self.dragActive else { return }
                self.dragSummary = summary
            case .drop:
                self.lastDrop.summary = summary
                self.lastDrop.date = Date()
            }
            self.invalidate()
        }
    }

    nonisolated private static func quickSummary(_ urls: [URL]) -> HaloCIDragSummary {
        let extensions = Array(Set(urls.compactMap { url -> String? in
            let ext = url.pathExtension.lowercased()
            return ext.isEmpty ? nil : ext
        })).sorted().prefix(24)

        return HaloCIDragSummary(
            itemCount: urls.count,
            fileCount: urls.count,
            folderCount: 0,
            extensions: Array(extensions)
        )
    }

    nonisolated private static func classifiedSummary(_ urls: [URL]) -> HaloCIDragSummary {
        var files = 0
        var folders = 0
        var extensions = Set<String>()

        for url in urls.prefix(256) {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values?.isDirectory == true {
                folders += 1
            } else {
                files += 1
                let ext = url.pathExtension.lowercased()
                if !ext.isEmpty, extensions.count < 24 {
                    extensions.insert(ext)
                }
            }
        }

        let boundedCount = min(256, urls.count)
        if files + folders < boundedCount {
            files += boundedCount - files - folders
        }

        return HaloCIDragSummary(
            itemCount: urls.count,
            fileCount: files,
            folderCount: folders,
            extensions: extensions.sorted()
        )
    }

    private func recordEvent(kind: String, source: String) {
        sequence &+= 1
        lastEvent = HaloCIContextEvent(
            kind: String(kind.prefix(128)),
            source: String(source.prefix(256)),
            date: Date(),
            sequence: sequence
        )
        invalidate()
    }

    private func invalidate() {
        guard revisionTask == nil else { return }
        revisionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled, let self else { return }
            self.revision &+= 1
            self.revisionTask = nil
        }
    }

    nonisolated private static func age(_ date: Date) -> String {
        String(format: "%.2f", max(0, Date().timeIntervalSince(date)))
    }
}
