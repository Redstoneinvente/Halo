from pathlib import Path
import re, runpy

ROOT = Path('.')

def read(path): return (ROOT / path).read_text()
def write(path, text): (ROOT / path).write_text(text)

# Re-apply the architecture patch in this checkout; the first workflow validated syntax/diff
# but intentionally did not commit after its compiler gate caught missing service integration.
runpy.run_path(str(ROOT / 'Scripts/one_time_open_workspace_architecture.py'), run_name='__main__')

# -----------------------------------------------------------------------------
# System + media services used by opened-notch lightweight elements and expanded modules.
# -----------------------------------------------------------------------------
p = 'Halo/Services/Integrations.swift'
s = read(p)
if 'import Darwin' not in s:
    s = s.replace('import ImageIO\n', 'import ImageIO\nimport Darwin\n', 1)

system_start = s.index('@MainActor\nfinal class SystemService: ObservableObject {')
system_end = s.index('\nstruct AudioDevice: Identifiable', system_start)
new_system = r'''@MainActor
final class SystemService: ObservableObject {
    @Published var battery: Int?
    @Published var charging = false
    @Published var onBattery = false
    @Published var memory = ""
    @Published var storage = ""
    @Published var uptime = ""
    @Published var lowPower = false

    // Detailed monitor values are sampled only while the normal opened notch is visible.
    @Published var cpuUsage = 0.0
    @Published var memoryUsage = 0.0
    @Published var swapUsage = 0.0
    @Published var diskUsage = 0.0
    @Published var networkDownPerSecond = 0.0
    @Published var networkUpPerSecond = 0.0
    @Published var thermalState = "Nominal"
    @Published var cpuHistory: [Double] = []
    @Published var memoryHistory: [Double] = []
    @Published var networkHistory: [Double] = []
    // Display brightness is intentionally nil on machines where Halo cannot safely control it.
    @Published var brightness: Double?

    private struct CPUTicks {
        var user: UInt64; var system: UInt64; var idle: UInt64; var nice: UInt64
        var total: UInt64 { user + system + idle + nice }
        var active: UInt64 { user + system + nice }
    }
    private var previousCPUTicks: CPUTicks?
    private var previousNetworkBytes: (down: UInt64, up: UInt64, date: Date)?
    private var refreshing = false

    func refresh(detailed: Bool = false) {
        guard !refreshing else { return }
        refreshing = true
        let previousCPU = previousCPUTicks
        let previousNetwork = previousNetworkBytes
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            let uptime = "\(Int(ProcessInfo.processInfo.systemUptime / 3600))h uptime"
            let physicalMemory = ProcessInfo.processInfo.physicalMemory
            let memoryLabel = ByteCountFormatter.string(fromByteCount: Int64(physicalMemory), countStyle: .memory) + " installed"
            let home = URL(fileURLWithPath: NSHomeDirectory())
            let resource = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
            let free = resource?.volumeAvailableCapacityForImportantUsage
            let totalDisk = resource?.volumeTotalCapacity.map(Int64.init)
            let storageLabel = free.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) + " free" } ?? ""

            var battery: Int?, charging = false, onBattery = false
            if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
               let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
                for source in sources {
                    guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                          let current = info[kIOPSCurrentCapacityKey] as? Int,
                          let maximum = info[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
                    battery = Int(Double(current) / Double(maximum) * 100)
                    charging = (info[kIOPSIsChargingKey] as? Bool) ?? false
                    onBattery = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSBatteryPowerValue
                    break
                }
            }

            let ticks = detailed ? Self.cpuTicks() : nil
            let cpuPercent: Double = {
                guard let ticks, let old = previousCPU else { return 0 }
                let totalDelta = ticks.total >= old.total ? ticks.total - old.total : 0
                let activeDelta = ticks.active >= old.active ? ticks.active - old.active : 0
                guard totalDelta > 0 else { return 0 }
                return min(100, max(0, Double(activeDelta) / Double(totalDelta) * 100))
            }()
            let memoryPercent = detailed ? Self.memoryPercent(physical: physicalMemory) : 0
            let swapPercent = detailed ? Self.swapPercent() : 0
            let diskPercent: Double = {
                guard detailed, let free, let totalDisk, totalDisk > 0 else { return 0 }
                return min(100, max(0, (1 - Double(free) / Double(totalDisk)) * 100))
            }()
            let network = detailed ? Self.networkBytes() : (0, 0)
            let now = Date()
            let rates: (Double, Double) = {
                guard detailed, let old = previousNetwork else { return (0, 0) }
                let elapsed = max(0.2, now.timeIntervalSince(old.date))
                let down = network.0 >= old.down ? Double(network.0 - old.down) / elapsed : 0
                let up = network.1 >= old.up ? Double(network.1 - old.up) / elapsed : 0
                return (down, up)
            }()
            let thermal = detailed ? Self.thermalDescription(ProcessInfo.processInfo.thermalState) : "Nominal"
            let power = (battery, charging, onBattery)

            Task { @MainActor in
                guard let self else { return }
                self.refreshing = false
                if self.lowPower != lowPower { self.lowPower = lowPower }
                if self.uptime != uptime { self.uptime = uptime }
                if self.memory != memoryLabel { self.memory = memoryLabel }
                if self.storage != storageLabel { self.storage = storageLabel }
                if self.battery != power.0 { self.battery = power.0 }
                if self.charging != power.1 { self.charging = power.1 }
                if self.onBattery != power.2 { self.onBattery = power.2 }
                guard detailed else { return }
                if let ticks { self.previousCPUTicks = ticks }
                self.previousNetworkBytes = (network.0, network.1, now)
                self.cpuUsage = cpuPercent
                self.memoryUsage = memoryPercent
                self.swapUsage = swapPercent
                self.diskUsage = diskPercent
                self.networkDownPerSecond = rates.0
                self.networkUpPerSecond = rates.1
                self.thermalState = thermal
                Self.append(cpuPercent, to: &self.cpuHistory)
                Self.append(memoryPercent, to: &self.memoryHistory)
                Self.append(min(100, (rates.0 + rates.1) / 1_000_000 * 10), to: &self.networkHistory)
            }
        }
    }

    // Brightness remains hidden when the current display does not expose a safe software control.
    func setBrightness(_ value: Double) { _ = value }

    private static func append(_ value: Double, to history: inout [Double]) {
        history.append(value)
        if history.count > 60 { history.removeFirst(history.count - 60) }
    }

    private static func cpuTicks() -> CPUTicks? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(user: UInt64(info.cpu_ticks.0), system: UInt64(info.cpu_ticks.1), idle: UInt64(info.cpu_ticks.2), nice: UInt64(info.cpu_ticks.3))
    }

    private static func memoryPercent(physical: UInt64) -> Double {
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS, physical > 0 else { return 0 }
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let usedPages = UInt64(info.active_count) + UInt64(info.inactive_count) + UInt64(info.wire_count) + UInt64(info.compressor_page_count)
        return min(100, Double(usedPages * UInt64(pageSize)) / Double(physical) * 100)
    }

    private static func swapPercent() -> Double {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0, usage.xsu_total > 0 else { return 0 }
        return min(100, Double(usage.xsu_used) / Double(usage.xsu_total) * 100)
    }

    private static func networkBytes() -> (UInt64, UInt64) {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return (0, 0) }
        defer { freeifaddrs(pointer) }
        var down: UInt64 = 0, up: UInt64 = 0
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let node = current {
            let flags = Int32(node.pointee.ifa_flags)
            if (flags & IFF_LOOPBACK) == 0, let raw = node.pointee.ifa_data {
                let data = raw.assumingMemoryBound(to: if_data.self).pointee
                down += UInt64(data.ifi_ibytes); up += UInt64(data.ifi_obytes)
            }
            current = node.pointee.ifa_next
        }
        return (down, up)
    }

    private static func thermalDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state { case .nominal: return "Nominal"; case .fair: return "Fair"; case .serious: return "Serious"; case .critical: return "Critical"; @unknown default: return "Unknown" }
    }
}
'''
s = s[:system_start] + new_system + s[system_end:]

# Extend media state without changing the existing PlayerSnapshot compatibility contract.
fields_anchor = '    @Published private(set) var artworkColors: [WidgetColor] = []\n'
fields_add = '''    @Published private(set) var artworkImage: NSImage?\n    @Published private(set) var album = ""\n    @Published private(set) var duration = 0.0\n    @Published private(set) var position = 0.0\n    @Published private(set) var shuffleSupported = false\n    @Published private(set) var shuffleEnabled = false\n    @Published private(set) var repeatSupported = false\n    @Published private(set) var repeatMode = ""\n    private var openedDetailEnabled = false\n'''
if 'var artworkImage: NSImage?' not in s:
    s = s.replace(fields_anchor, fields_anchor + fields_add, 1)

old_disconnect = '        artworkTask?.cancel(); artworkKey = ""; trackID = ""; artworkColors = []\n        title = "Connect a player"; artist = "Apple Music or Spotify"\n'
new_disconnect = '        artworkTask?.cancel(); artworkKey = ""; trackID = ""; artworkColors = []; artworkImage = nil\n        album = ""; duration = 0; position = 0; shuffleSupported = false; shuffleEnabled = false; repeatSupported = false; repeatMode = ""\n        title = "Connect a player"; artist = "Apple Music or Spotify"\n'
s = s.replace(old_disconnect, new_disconnect, 1)

if 'func setOpenedDetailEnabled' not in s:
    retry_anchor = '''    func retryDetection(preferred: String) {\n        deniedApps.removeAll()\n        poll(app: preferred, automatic: automaticMode)\n    }\n'''
    retry_add = '''    func setOpenedDetailEnabled(_ enabled: Bool) {\n        guard openedDetailEnabled != enabled else { return }\n        openedDetailEnabled = enabled\n        if enabled, let app = connectedApp { refreshPlaybackDetails(app: app) }\n    }\n'''
    s = s.replace(retry_anchor, retry_anchor + retry_add, 1)

accept_anchor = '''        trackID = snapshot.trackID\n        requestArtwork(app: snapshot.app)\n'''
accept_new = '''        trackID = snapshot.trackID\n        requestArtwork(app: snapshot.app)\n        if openedDetailEnabled { refreshPlaybackDetails(app: snapshot.app) }\n'''
s = s.replace(accept_anchor, accept_new, 1)

request_anchor = '    private func requestArtwork(app: String) {\n'
media_methods = r'''    func seek(to seconds: Double) {
        guard openedDetailEnabled, let app = connectedApp, duration > 0 else { return }
        let target = min(duration, max(0, seconds))
        queue.async { [weak self] in
            let source = """
            if application id "\(app)" is running then
                tell application id "\(app)" to set player position to \(target)
            end if
            """
            var failure: NSDictionary?
            _ = NSAppleScript(source: source)?.executeAndReturnError(&failure)
            Task { @MainActor in if failure == nil { self?.position = target } }
        }
    }

    func toggleShuffle() {
        guard openedDetailEnabled, shuffleSupported, let app = connectedApp else { return }
        queue.async { [weak self] in
            let command = app == "com.apple.Music" ? "set shuffle enabled to not shuffle enabled" : "set shuffling to not shuffling"
            let source = "if application id \"\(app)\" is running then tell application id \"\(app)\" to \(command)"
            var failure: NSDictionary?
            _ = NSAppleScript(source: source)?.executeAndReturnError(&failure)
            Task { @MainActor in if failure == nil { self?.refreshPlaybackDetails(app: app) } }
        }
    }

    func cycleRepeat() {
        guard openedDetailEnabled, repeatSupported, let app = connectedApp else { return }
        queue.async { [weak self] in
            let command: String
            if app == "com.apple.Music" {
                command = "if song repeat is off then set song repeat to all else if song repeat is all then set song repeat to one else set song repeat to off"
            } else {
                command = "set repeating to not repeating"
            }
            let source = "if application id \"\(app)\" is running then tell application id \"\(app)\" to \(command)"
            var failure: NSDictionary?
            _ = NSAppleScript(source: source)?.executeAndReturnError(&failure)
            Task { @MainActor in if failure == nil { self?.refreshPlaybackDetails(app: app) } }
        }
    }

    private func refreshPlaybackDetails(app: String) {
        guard openedDetailEnabled else { return }
        let expectedGeneration = generation
        queue.async { [weak self] in
            let shuffleRead = app == "com.apple.Music" ? "shuffle enabled" : "shuffling"
            let repeatRead = app == "com.apple.Music" ? "song repeat as text" : "repeating as text"
            let source = """
            if application id "\(app)" is not running then return {"", 0, 0, false, false, false, ""}
            with timeout of 3 seconds
                tell application id "\(app)"
                    set albumName to ""
                    set durationValue to 0
                    set positionValue to 0
                    set shuffleAvailable to false
                    set shuffleValue to false
                    set repeatAvailable to false
                    set repeatValue to ""
                    try
                        set albumName to album of current track
                    end try
                    try
                        set durationValue to duration of current track
                        set positionValue to player position
                    end try
                    try
                        set shuffleValue to \(shuffleRead)
                        set shuffleAvailable to true
                    end try
                    try
                        set repeatValue to \(repeatRead)
                        set repeatAvailable to true
                    end try
                    return {albumName, durationValue, positionValue, shuffleAvailable, shuffleValue, repeatAvailable, repeatValue}
                end tell
            end timeout
            """
            var failure: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
            guard failure == nil, let result else { return }
            let album = result.atIndex(1)?.stringValue ?? ""
            var duration = result.atIndex(2)?.doubleValue ?? 0
            let position = result.atIndex(3)?.doubleValue ?? 0
            // Spotify exposes duration in milliseconds; Apple Music exposes seconds.
            if app == "com.spotify.client", duration > 10_000 { duration /= 1000 }
            let shuffleSupported = result.atIndex(4)?.booleanValue ?? false
            let shuffleEnabled = result.atIndex(5)?.booleanValue ?? false
            let repeatSupported = result.atIndex(6)?.booleanValue ?? false
            let repeatMode = result.atIndex(7)?.stringValue ?? ""
            Task { @MainActor in
                guard let self, self.openedDetailEnabled, self.generation == expectedGeneration, self.connectedApp == app else { return }
                self.album = album; self.duration = max(0, duration); self.position = min(max(0, position), max(0, duration))
                self.shuffleSupported = shuffleSupported; self.shuffleEnabled = shuffleEnabled
                self.repeatSupported = repeatSupported; self.repeatMode = repeatMode
            }
        }
    }

'''
if 'private func refreshPlaybackDetails' not in s:
    s = s.replace(request_anchor, media_methods + request_anchor, 1)

# Publish artwork image alongside its existing palette, reusing the same guarded track lifecycle.
old_colors = '''                    let colors = await ArtworkReader.palette(data: bytes, urlString: urlString)\n                    guard !Task.isCancelled, let self, self.artworkEnabled,\n                          self.generation == expectedGeneration, self.artworkKey == key else { return }\n                    self.artworkColors = colors\n'''
new_colors = '''                    async let colorsValue = ArtworkReader.palette(data: bytes, urlString: urlString)\n                    async let imageValue = ArtworkReader.image(data: bytes, urlString: urlString)\n                    let (colors, image) = await (colorsValue, imageValue)\n                    guard !Task.isCancelled, let self, self.artworkEnabled,\n                          self.generation == expectedGeneration, self.artworkKey == key else { return }\n                    self.artworkColors = colors\n                    self.artworkImage = image\n'''
if old_colors in s:
    s = s.replace(old_colors, new_colors, 1)

if 'static func image(data: Data?, urlString: String?) async -> NSImage?' not in s:
    art_anchor = 'private enum ArtworkReader {\n'
    art_add = r'''    static func image(data: Data?, urlString: String?) async -> NSImage? {
        var imageData = data
        if imageData == nil, let urlString, let url = URL(string: urlString), url.scheme == "https" {
            do {
                let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
                let (downloaded, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200, downloaded.count <= 5_000_000 else { return nil }
                imageData = downloaded
            } catch { return nil }
        }
        guard !Task.isCancelled, let imageData, imageData.count <= 5_000_000 else { return nil }
        return NSImage(data: imageData)
    }
'''
    s = s.replace(art_anchor, art_anchor + art_add, 1)
write(p, s)

# -----------------------------------------------------------------------------
# Opened visibility drives expensive detailed sampling. Shared/closed polling remains intact.
# -----------------------------------------------------------------------------
p = 'Halo/Core/WorkspaceStore.swift'
s = read(p)
if '@Published private(set) var openedNotchVisible' not in s:
    s = s.replace('    @Published var runningApps: [NSRunningApplication] = []\n',
                  '    @Published var runningApps: [NSRunningApplication] = []\n    @Published private(set) var openedNotchVisible = false\n    private var openedNotchVisibilityTokens = Set<UUID>()\n', 1)

if 'func setOpenedNotchVisible' not in s:
    anchor = '    @Published var stopwatchElapsed: TimeInterval = 0\n'
    addition = '''    func setOpenedNotchVisible(_ visible: Bool, token: UUID) {\n        if visible { openedNotchVisibilityTokens.insert(token) } else { openedNotchVisibilityTokens.remove(token) }\n        let next = !openedNotchVisibilityTokens.isEmpty\n        guard next != openedNotchVisible else { return }\n        openedNotchVisible = next\n        media.setOpenedDetailEnabled(next)\n        if next { system.refresh(detailed: true); audio.refresh() }\n    }\n'''
    s = s.replace(anchor, anchor + addition, 1)

old_tick = '''            if self.tick % 5 == 0 { self.system.refresh(); self.evaluateRules() }\n            if self.tick % 30 == 0, self.settings.layout.enabled.contains(.calendar) { self.calendar.refresh() }\n'''
new_tick = '''            if self.openedNotchVisible { self.system.refresh(detailed: true) }\n            else if self.tick % 5 == 0 { self.system.refresh() }\n            if self.tick % 5 == 0 { self.evaluateRules() }\n            if self.tick % 30 == 0, self.settings.layout.enabled.contains(.calendar) { self.calendar.refresh() }\n'''
if old_tick in s: s = s.replace(old_tick, new_tick, 1)
write(p, s)

# -----------------------------------------------------------------------------
# Make AudioSpectrumService multi-owner so opened media visualizer cannot stop closed uses.
# -----------------------------------------------------------------------------
p = 'Halo/Services/AudioSpectrumService.swift'
s = read(p)
if 'private var activeOwners = Set<String>()' not in s:
    s = s.replace('    private var wanted = false\n', '    private var wanted = false\n    private var activeOwners = Set<String>()\n', 1)

old_active = r'''    func setActive(_ active: Bool) {
        stateLock.lock()
        wanted = active
        idleStopTask?.cancel()
        idleStopTask = nil

        let shouldStart = active && stream == nil && !starting && !blockedForCurrentActivation
        if shouldStart { starting = true }
        let current = stream
        stateLock.unlock()

        if shouldStart {
            Task { await startIfNeeded() }
        } else if !active, let current {
            let task = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled, let self else { return }
                await self.stopIfStillIdle(current)
            }
            stateLock.lock()
            idleStopTask = task
            stateLock.unlock()
        }
    }
'''
new_active = r'''    func setActive(_ active: Bool) { setActive(active, owner: "legacy") }

    func setActive(_ active: Bool, owner: String) {
        stateLock.lock()
        if active { activeOwners.insert(owner) } else { activeOwners.remove(owner) }
        wanted = !activeOwners.isEmpty
        let nowWanted = wanted
        idleStopTask?.cancel()
        idleStopTask = nil

        let shouldStart = nowWanted && stream == nil && !starting && !blockedForCurrentActivation
        if shouldStart { starting = true }
        let current = stream
        stateLock.unlock()

        if shouldStart {
            Task { await startIfNeeded() }
        } else if !nowWanted, let current {
            let task = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled, let self else { return }
                await self.stopIfStillIdle(current)
            }
            stateLock.lock()
            idleStopTask = task
            stateLock.unlock()
        }
    }
'''
if old_active in s: s = s.replace(old_active, new_active, 1)
write(p, s)

# -----------------------------------------------------------------------------
# Rich opened modules and presentation variants. Unsupported media controls hide automatically.
# -----------------------------------------------------------------------------
p = 'Halo/Core/WidgetModels.swift'
s = read(p)
media_old = '''                .init("palette", "Artwork palette", "Colors extracted from current artwork.", defaultVisible: false),\n                .init("controls", "Playback controls", "Previous, play/pause, and next."),\n'''
media_new = '''                .init("artwork", "Album artwork", "Current track artwork."),\n                .init("album", "Album", "Current album metadata.", defaultVisible: false),\n                .init("progress", "Playback progress", "Seekable track progress where supported."),\n                .init("timing", "Elapsed / remaining", "Track timing where supported."),\n                .init("palette", "Artwork palette", "Colors extracted from current artwork.", defaultVisible: false),\n                .init("controls", "Playback controls", "Previous, play/pause, and next."),\n                .init("shuffle", "Shuffle", "Shuffle control where supported.", defaultVisible: false),\n                .init("repeat", "Repeat", "Repeat control where supported.", defaultVisible: false),\n                .init("visualizer", "Audio visualizer", "Measured system-audio spectrum while the opened notch is visible.", defaultVisible: false),\n                .init("lyrics", "Lyrics area", "Reserved for players that expose real lyric data.", defaultVisible: false),\n'''
if media_old in s: s = s.replace(media_old, media_new, 1)
system_old = '''                .init("uptime", "Uptime", "Current system uptime."),\n                .init("device", "Mac details", "macOS version and logical processor count.", defaultVisible: false)\n'''
system_new = '''                .init("uptime", "Uptime", "Current system uptime."),\n                .init("cpu", "CPU usage", "Current CPU utilization."),\n                .init("memoryUsage", "Memory usage", "Current physical-memory utilization."),\n                .init("swap", "Swap", "Current swap utilization.", defaultVisible: false),\n                .init("diskUsage", "Disk usage", "Current disk utilization."),\n                .init("network", "Network throughput", "Current network receive/transmit rate."),\n                .init("thermal", "Thermal state", "macOS thermal-pressure state.", defaultVisible: false),\n                .init("graphs", "Compact graphs", "Recent CPU, memory and network history.", defaultVisible: false),\n                .init("device", "Mac details", "macOS version and logical processor count.", defaultVisible: false)\n'''
if system_old in s: s = s.replace(system_old, system_new, 1)
write(p, s)

p = 'Halo/Views/ModuleViews.swift'
s = read(p)

def replace_struct(name, next_name, replacement):
    global s
    start = s.index(f'struct {name}: View {{')
    end = s.index(f'\nstruct {next_name}: View {{', start)
    s = s[:start] + replacement.rstrip() + '\n' + s[end:]

media_view = r'''struct MediaModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @ObservedObject var service: MediaService
    let app: String
    private var options: WidgetContentOptions { style.resolvedContent }

    var body: some View {
        Group {
            switch presentation {
            case .compact: compact
            case .expanded: expanded
            case .regular, .automatic: regular
            }
        }
        .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
        .onAppear { service.setArtworkEnabled(true) }
    }

    private var compact: some View {
        HStack(spacing: max(6, options.spacing)) {
            if let image = service.artworkImage {
                WidgetElement(key: "artwork", defaultPriority: .normal) { Image(nsImage: image).resizable().scaledToFill().frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 7)) }
                    .frame(width: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                WidgetElement(key: "track", defaultPriority: .alwaysVisible) { Text(service.title).lineLimit(1) }
                if options.mediaShowArtist && !service.artist.isEmpty { WidgetElement(key: "artist", defaultPriority: .low) { Text(service.artist).lineLimit(1) } }
            }
            Spacer(minLength: 4)
            if options.showControls, service.connectedApp != nil {
                WidgetElement(key: "controls", defaultPriority: .high) { Button { service.perform("playpause", app: app) } label: { Image(systemName: service.isPlaying ? "pause.fill" : "play.fill") } }
            }
        }
    }

    private var regular: some View {
        HStack(alignment: .top, spacing: options.spacing) {
            if let image = service.artworkImage {
                WidgetElement(key: "artwork", defaultPriority: .normal) { Image(nsImage: image).resizable().scaledToFill().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10)) }
                    .frame(width: 78)
            }
            VStack(alignment: .leading, spacing: max(4, options.spacing * 0.65)) { metadata; progress; controls }
        }
    }

    private var expanded: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if let image = service.artworkImage {
                WidgetElement(key: "artwork", defaultPriority: .normal) {
                    Image(nsImage: image).resizable().scaledToFill().frame(maxWidth: 260, minHeight: 120, maxHeight: 220).clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            metadata
            progress
            controls
            if service.shuffleSupported || service.repeatSupported {
                HStack {
                    if service.shuffleSupported { WidgetElement(key: "shuffle", defaultVisible: false, defaultPriority: .low) { Button { service.toggleShuffle() } label: { Label("Shuffle", systemImage: service.shuffleEnabled ? "shuffle.circle.fill" : "shuffle") } } }
                    if service.repeatSupported { WidgetElement(key: "repeat", defaultVisible: false, defaultPriority: .low) { Button { service.cycleRepeat() } label: { Label(service.repeatMode.isEmpty ? "Repeat" : service.repeatMode, systemImage: "repeat") } } }
                }
            }
            WidgetElement(key: "visualizer", defaultVisible: false, defaultPriority: .optional) { OpenMediaSpectrumView(accent: style.accentColor.color) }
            // Lyrics intentionally render nothing until a supported player exposes real lyric data.
            if options.showQuickActions { WidgetElement(key: "detection", defaultVisible: false, defaultPriority: .optional) { Button("Retry player detection") { service.retryDetection(preferred: app) } } }
            if options.showStatus, let error = service.error { WidgetElement(key: "status", defaultPriority: .normal) { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
        }
    }

    @ViewBuilder private var metadata: some View {
        WidgetElement(key: "track", defaultPriority: .alwaysVisible) { Text(service.title).lineLimit(options.mediaTitleLines) }
        if options.mediaShowArtist && !service.artist.isEmpty { WidgetElement(key: "artist", defaultPriority: .normal) { Text(service.artist) } }
        if !service.album.isEmpty { WidgetElement(key: "album", defaultVisible: false, defaultPriority: .low) { Text(service.album) } }
        if options.mediaShowSource, let source = service.connectedApp {
            WidgetElement(key: "source", defaultPriority: .low) { Label(source == "com.apple.Music" ? "Apple Music" : source == "com.spotify.client" ? "Spotify" : "System Audio", systemImage: "app.badge") }
        }
        WidgetElement(key: "playback", defaultPriority: .low) { Label(service.connectedApp == nil ? "Waiting for a player" : (service.isPlaying ? "Playing" : "Paused"), systemImage: service.connectedApp == nil ? "music.note" : (service.isPlaying ? "play.fill" : "pause.fill")) }
    }

    @ViewBuilder private var progress: some View {
        if service.duration > 0 {
            WidgetElement(key: "progress", defaultPriority: .normal) { Slider(value: Binding(get: { service.position }, set: { service.seek(to: $0) }), in: 0...max(1, service.duration)) { Text("Playback position") } }
            WidgetElement(key: "timing", defaultPriority: .low) {
                HStack { Text(Self.time(service.position)); Spacer(); Text("−" + Self.time(max(0, service.duration - service.position))) }.monospacedDigit()
            }
        }
    }

    @ViewBuilder private var controls: some View {
        if options.showControls, service.connectedApp != nil {
            WidgetElement(key: "controls", defaultPriority: .high) {
                HStack(spacing: options.spacing) {
                    Button { service.perform("previous track", app: app) } label: { Image(systemName: "backward.end.fill") }
                    Button { service.perform("playpause", app: app) } label: { Image(systemName: service.isPlaying ? "pause.fill" : "play.fill") }
                    Button { service.perform("next track", app: app) } label: { Image(systemName: "forward.end.fill") }
                }.disabled(service.busy)
            }
        }
    }
    private static func time(_ seconds: Double) -> String { let value = max(0, Int(seconds)); return String(format: "%d:%02d", value / 60, value % 60) }
}

private struct OpenMediaSpectrumView: View {
    let accent: Color
    @State private var snapshot = AudioSpectrumSnapshot()
    @State private var owner = UUID().uuidString
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            GeometryReader { proxy in
                let values = [snapshot.bass, snapshot.mids, snapshot.treble, snapshot.overall]
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        Capsule().fill(accent.opacity(0.78)).frame(maxWidth: .infinity, minHeight: 2, maxHeight: max(2, proxy.size.height * value))
                    }
                }
            }
        }
        .frame(height: 34)
        .onAppear { AudioSpectrumService.shared.setActive(true, owner: owner) }
        .onDisappear { AudioSpectrumService.shared.setActive(false, owner: owner) }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in snapshot = AudioSpectrumService.shared.snapshot() }
    }
}
'''
replace_struct('MediaModuleView', 'AudioModuleView', media_view)

system_start = s.index('struct SystemModuleView: View {')
system_end = s.index('\nstruct LauncherModuleView: View {', system_start)
system_view = r'''struct SystemModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @ObservedObject var service: SystemService
    private var options: WidgetContentOptions { style.resolvedContent }

    var body: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.systemBattery, let battery = service.battery {
                WidgetElement(key: "battery", defaultPriority: .high) { HStack { Label("\(battery)%", systemImage: service.charging ? "battery.100.bolt" : "battery.100"); Spacer(); Text(service.charging ? "Charging" : service.onBattery ? "Battery" : "AC power") } }
                if options.showProgress, presentation != .compact { WidgetElement(key: "batteryProgress", defaultPriority: .low) { ProgressView(value: Double(battery), total: 100) } }
            }
            WidgetElement(key: "cpu", defaultPriority: .alwaysVisible) { MetricRow(label: "CPU", value: service.cpuUsage, icon: "cpu") }
            WidgetElement(key: "memoryUsage", defaultPriority: .high) { MetricRow(label: "RAM", value: service.memoryUsage, icon: "memorychip") }
            if presentation != .compact {
                WidgetElement(key: "diskUsage", defaultPriority: .normal) { MetricRow(label: "Disk", value: service.diskUsage, icon: "internaldrive") }
                WidgetElement(key: "network", defaultPriority: .normal) { HStack { Label("Network", systemImage: "network"); Spacer(); Text("↓ \(Self.rate(service.networkDownPerSecond))  ↑ \(Self.rate(service.networkUpPerSecond))").monospacedDigit() } }
                WidgetElement(key: "power", defaultPriority: .normal) { HStack { Label(service.lowPower ? "Low Power Mode" : "Normal power", systemImage: service.lowPower ? "leaf.fill" : "bolt.fill"); Spacer(); Text(service.onBattery ? "On battery" : "External power") } }
            }
            if presentation == .expanded {
                WidgetElement(key: "graphs", defaultVisible: false, defaultPriority: .optional) {
                    VStack(spacing: 8) { MiniMetricGraph(title: "CPU", values: service.cpuHistory, accent: style.accentColor.color); MiniMetricGraph(title: "Memory", values: service.memoryHistory, accent: style.accentColor.color.opacity(0.75)); MiniMetricGraph(title: "Network", values: service.networkHistory, accent: style.accentColor.color.opacity(0.55)) }
                }
                WidgetElement(key: "swap", defaultVisible: false, defaultPriority: .low) { MetricRow(label: "Swap", value: service.swapUsage, icon: "arrow.triangle.swap") }
                WidgetElement(key: "thermal", defaultVisible: false, defaultPriority: .low) { HStack { Label("Thermal", systemImage: "thermometer.medium"); Spacer(); Text(service.thermalState) } }
                if options.systemMemory { WidgetElement(key: "memory", defaultPriority: .low) { Label(service.memory, systemImage: "memorychip") } }
                if options.systemStorage { WidgetElement(key: "storage", defaultPriority: .low) { Label(service.storage, systemImage: "internaldrive") } }
                if options.systemUptime { WidgetElement(key: "uptime", defaultPriority: .low) { Label(service.uptime, systemImage: "clock.arrow.circlepath") } }
                WidgetElement(key: "device", defaultVisible: false, defaultPriority: .optional) { VStack(alignment: options.alignment.horizontal, spacing: 3) { Text(ProcessInfo.processInfo.operatingSystemVersionString); Text("\(ProcessInfo.processInfo.processorCount) logical processors").foregroundStyle(.secondary) } }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
    private static func rate(_ value: Double) -> String { ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file) + "/s" }
}

private struct MetricRow: View {
    let label: String; let value: Double; let icon: String
    var body: some View { VStack(spacing: 4) { HStack { Label(label, systemImage: icon); Spacer(); Text(String(format: "%.0f%%", value)).monospacedDigit() }; ProgressView(value: value, total: 100) } }
}

private struct MiniMetricGraph: View {
    let title: String; let values: [Double]; let accent: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            GeometryReader { proxy in
                Path { path in
                    guard values.count > 1 else { return }
                    let step = proxy.size.width / CGFloat(values.count - 1)
                    for (index, value) in values.enumerated() {
                        let point = CGPoint(x: CGFloat(index) * step, y: proxy.size.height * (1 - CGFloat(min(100, max(0, value)) / 100)))
                        index == 0 ? path.move(to: point) : path.addLine(to: point)
                    }
                }.stroke(accent, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }.frame(height: 30)
        }
    }
}
'''
s = s[:system_start] + system_view.rstrip() + '\n' + s[system_end:]

# Lightweight presentation branching for Calendar/Clipboard/Launcher and generic activities/notes/stopwatch.
s = s.replace('struct CalendarModuleView: View {\n    @Environment(\\.widgetStyle) private var style\n', 'struct CalendarModuleView: View {\n    @Environment(\\.widgetStyle) private var style\n    @Environment(\\.openNotchPresentation) private var presentation\n', 1)
s = s.replace('''            WidgetElement(key: "summary") {\n                HStack { Text(Date(), style: .date); Spacer(); Text("\\(service.events.count) remaining") }\n            }\n''', '''            if presentation != .compact { WidgetElement(key: "summary") { HStack { Text(Date(), style: .date); Spacer(); Text("\\(service.events.count) remaining") } } }\n''', 1)
s = s.replace('''            if options.showStatus { WidgetElement(key: "status") { Text(service.status) } }\n            WidgetElement(key: "events") {\n''', '''            if options.showStatus && presentation == .expanded { WidgetElement(key: "status", defaultPriority: .low) { Text(service.status) } }\n            if presentation != .compact { WidgetElement(key: "events") {\n''', 1)
# Close newly conditional events wrapper immediately before calendar actions.
s = s.replace('''                }\n            }\n            if options.showQuickActions { WidgetElement(key: "actions") { Button("Enable / Refresh calendar") { service.requestAccess() } } }\n''', '''                }\n            } }\n            if options.showQuickActions && presentation == .expanded { WidgetElement(key: "actions", defaultPriority: .low) { Button("Enable / Refresh calendar") { service.requestAccess() } } }\n''', 1)

s = s.replace('struct ClipboardModuleView: View {\n    @Environment(\\.widgetStyle) private var style\n', 'struct ClipboardModuleView: View {\n    @Environment(\\.widgetStyle) private var style\n    @Environment(\\.openNotchPresentation) private var presentation\n', 1)
s = s.replace('''                if options.showSearch { WidgetElement(key: "search") { TextField("Search clipboard", text: $search) } }\n''', '''                if options.showSearch && presentation != .compact { WidgetElement(key: "search") { TextField("Search clipboard", text: $search) } }\n''', 1)
s = s.replace('''                WidgetElement(key: "entries") {\n                    VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {\n                        ForEach(Array(service.entries.filter { effectiveSearch.isEmpty || $0.text.localizedCaseInsensitiveContains(effectiveSearch) }.prefix(options.maxItems))) { entry in\n''', '''                WidgetElement(key: "entries") {\n                    VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {\n                        ForEach(Array(service.entries.filter { effectiveSearch.isEmpty || $0.text.localizedCaseInsensitiveContains(effectiveSearch) }.prefix(presentation == .compact ? 1 : options.maxItems))) { entry in\n''', 1)
s = s.replace('''                if options.showQuickActions { WidgetElement(key: "actions") { Button("Clear history") { service.reset() } } }\n                if options.showFooter { WidgetElement(key: "footer") { Text("Text only · up to 50 items · memory only") } }\n''', '''                if options.showQuickActions && presentation == .expanded { WidgetElement(key: "actions", defaultPriority: .low) { Button("Clear history") { service.reset() } } }\n                if options.showFooter && presentation == .expanded { WidgetElement(key: "footer", defaultPriority: .optional) { Text("Text only · up to 50 items · memory only") } }\n''', 1)

s = s.replace('struct LauncherModuleView: View {\n    @Environment(\\.widgetStyle) private var style\n', 'struct LauncherModuleView: View {\n    @Environment(\\.widgetStyle) private var style\n    @Environment(\\.openNotchPresentation) private var presentation\n', 1)
s = s.replace('''            if options.launcherPlugins {\n''', '''            if options.launcherPlugins && presentation != .compact {\n''', 1)
s = s.replace('''            if options.showQuickActions {\n''', '''            if options.showQuickActions && presentation == .expanded {\n''', 1)
write(p, s)

# Built-in Timer/Shelf also get explicit opened presentation variants.
p = 'Halo/Views/SurfaceView.swift'
s = read(p)
# Main actor visibility evaluation under Swift 6.
s = s.replace('private struct OpenNotchRuntimeContext {', '@MainActor\nprivate struct OpenNotchRuntimeContext {', 1)
# Reduce the enormous SurfaceView body type by extracting opened background/overlay helpers.
old_bg = '''        .background {\n            ZStack {\n                if state.expanded && activeContext == nil {\n                    OpenNotchBackgroundView(options: layout.resolvedOpenNotchLayout.appearance, fallback: layout.appearance, theme: theme, system: workspace.system)\n                } else {\n                    SurfaceBackground(appearance: layout.appearance, theme: theme, expanded: state.expanded, system: workspace.system)\n                }\n                if !state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true {\n                    AlbumNotchBackground(options: closedBackgroundOptions, media: workspace.media, system: workspace.system)\n                }\n            }\n        }\n'''
if old_bg in s: s = s.replace(old_bg, '        .background { surfaceBackgroundLayer }\n', 1)
old_ov = '''        .overlay {\n            contour.stroke(state.dropTargeted ? accent : .white.opacity(0.12), lineWidth: state.dropTargeted ? 1.6 : 1)\n            if state.expanded && activeContext == nil { OpenNotchSurfaceChrome(contour: contour, options: layout.resolvedOpenNotchLayout.appearance) }\n        }\n'''
if old_ov in s: s = s.replace(old_ov, '        .overlay { surfaceOverlayLayer }\n', 1)
helper_anchor = '    private var openDashboardContent: some View {\n'
helpers = '''    @ViewBuilder private var surfaceBackgroundLayer: some View {\n        ZStack {\n            if state.expanded && activeContext == nil {\n                OpenNotchBackgroundView(options: layout.resolvedOpenNotchLayout.appearance, fallback: layout.appearance, theme: theme, system: workspace.system)\n            } else {\n                SurfaceBackground(appearance: layout.appearance, theme: theme, expanded: state.expanded, system: workspace.system)\n            }\n            if !state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true {\n                AlbumNotchBackground(options: closedBackgroundOptions, media: workspace.media, system: workspace.system)\n            }\n        }\n    }\n\n    @ViewBuilder private var surfaceOverlayLayer: some View {\n        contour.stroke(state.dropTargeted ? accent : .white.opacity(0.12), lineWidth: state.dropTargeted ? 1.6 : 1)\n        if state.expanded && activeContext == nil {\n            OpenNotchSurfaceChrome(contour: contour, options: layout.resolvedOpenNotchLayout.appearance)\n        }\n    }\n\n'''
if 'private var surfaceBackgroundLayer' not in s:
    s = s.replace(helper_anchor, helpers + helper_anchor, 1)

# Presentation is already injected by OpenNotchItemView. Let built-ins trim content based on it.
s = s.replace('''struct BuiltinOrIntegrationWidget: View {\n    let module: ModuleID\n    @ObservedObject var store: AppStore\n    @Environment(\\.widgetStyle) private var style\n''', '''struct BuiltinOrIntegrationWidget: View {\n    let module: ModuleID\n    @ObservedObject var store: AppStore\n    @Environment(\\.widgetStyle) private var style\n    @Environment(\\.openNotchPresentation) private var presentation\n''', 1)
s = s.replace('''            WidgetElement(key: "progress") { ProgressView(value: progress) }\n''', '''            if presentation != .compact { WidgetElement(key: "progress", defaultPriority: .normal) { ProgressView(value: progress) } }\n''', 1)
s = s.replace('''            WidgetElement(key: "endTime", defaultVisible: false) {\n''', '''            if presentation == .expanded { WidgetElement(key: "endTime", defaultVisible: false, defaultPriority: .low) {\n''', 1)
s = s.replace('''                else { Text("Choose a duration to begin") }\n            }\n            if options.showSecondaryText {\n''', '''                else { Text("Choose a duration to begin") }\n            } }\n            if options.showSecondaryText && presentation != .compact {\n''', 1)
# Shelf: compact only summary/actions; expanded gets list detail. Regular keeps list.
s = s.replace('''            if store.files.isEmpty, options.showSecondaryText {\n''', '''            if presentation == .compact {\n                if options.showQuickActions { WidgetElement(key: "actions", defaultPriority: .high) { Button("Add files…") { store.chooseFiles() } } }\n            } else if store.files.isEmpty, options.showSecondaryText {\n''', 1)
s = s.replace('''            if options.showQuickActions {\n                WidgetElement(key: "actions") {\n''', '''            if options.showQuickActions && presentation == .expanded {\n                WidgetElement(key: "actions", defaultPriority: .normal) {\n''', 1)
write(p, s)

# -----------------------------------------------------------------------------
# Direct opened-notch documentation only.
# -----------------------------------------------------------------------------
p = 'Docs/WidgetCustomization.md'
s = read(p)
opened_doc = r'''

## Opened notch workspace

The normal opened notch is now a workspace model rather than a fixed list of cards. Existing saved layouts remain valid: when an older profile has no `OpenNotchLayout`, Halo resolves its existing enabled-module order into a compatible center group, and the existing Fixed Canvas, Scroll, and Pages modes remain available.

The visual opened-notch editor arranges content as regions → groups → items. Regions can occupy top/middle/bottom and left/center/right positions, each with independent padding. Groups choose horizontal or vertical flow, alignment, spacing, and padding. Items can be full modules or lightweight elements such as time/date, battery, active-app identity, volume, timer/stopwatch, media metadata/controls, CPU/RAM/storage/network metrics, custom text/icons/images/GIFs, buttons, spacers, and dividers. Items use one shared renderer and can be dragged between groups/regions, reordered, resized, hidden, duplicated, grouped, and configured with Fixed, Fit Content, Flexible, or Fill Remaining Space sizing plus min/preferred/max dimensions.

Opened modules support Automatic, Compact, Regular, and Expanded presentation. Automatic responds to available space. Under pressure the layout reduces spacing first, then removes lower-priority metadata, then switches to compact presentation, then truncates, and only scrolls as a final fallback. Items have Always Visible, High, Normal, Low, and Optional priorities plus generic visibility rules for battery level, charging, playback, timer/stopwatch state, CPU load, and Low Power Mode.

Per-item styling reuses Halo's widget/element style model and adds alignment, external spacing, offsets, font overrides, border/shadow/tint/icon sizing, and density. The opened surface also has independent background overrides for solid/gradient/image/video/material sources plus blur, saturation, brightness, contrast, tint, grain, warmth, border, inner highlight, shadow, and restrained glow. Opened presets (Minimal, Media, Productivity, System Monitor, Focus, Developer, Information Dense, Showcase) are ordinary `OpenNotchLayout` values and remain editable after applying them.

The opened media module exposes real artwork, richer metadata, seek/timing when the player exposes duration and position, optional measured system-audio visualization, and shuffle/repeat only when the player's Automation interface supports them. Unsupported controls stay hidden. The opened system monitor adds CPU, memory, swap, disk, network, battery/power and thermal information with optional compact history graphs. Detailed monitor sampling and opened-only media details run only while the normal opened notch is visible; when it closes, Halo falls back to the existing lower-frequency shared polling.
'''
if '## Opened notch workspace' not in s:
    s = s.replace('\n## Validation on a Mac\n', opened_doc + '\n## Validation on a Mac\n', 1)
write(p, s)

print('Opened-notch service integration and compiler fixes applied.')
