import SwiftUI
import AppKit
import ImageIO

// MARK: - Canonical EI pet sprite content

/// Semantic companion motions shared by ambient EI, the owned EI surface and roaming pets.
/// The visual renderer below maps these behaviours onto the supplied canonical sprite artwork.
enum HaloCompanionMotion: String, CaseIterable, Identifiable {
    case hidden, peekEyes, peekEars, peek, peekLeft, peekRight, observe, idle, walk, look, greet, celebrate
    case sleep, snack, dance, stretch, groom, playful, affectionate, tired, excited, paw, tail
    case resting, curious, happy, coffee, working, umbrella, entering, leaving
    var id: String { rawValue }
}

enum HaloPetPose: String, CaseIterable, Identifiable, Hashable {
    case idle, sitting, standing, walking, lying, sleeping, stretching, grooming, lookingAround
    case peekBottom, peekLeft, peekRight, pawsOnEdge, headOnEdge, hiddenPeek
    case playful, curious, tired, happy, dance, working, umbrella

    var id: String { rawValue }
    var title: String {
        switch self {
        case .lookingAround: return "Looking Around"
        case .peekBottom: return "Peek Bottom"
        case .peekLeft: return "Peek Left"
        case .peekRight: return "Peek Right"
        case .pawsOnEdge: return "Paws on Edge"
        case .headOnEdge: return "Head on Edge"
        case .hiddenPeek: return "Hidden Peek"
        default:
            return rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
        }
    }

    var fallbacks: [HaloPetPose] {
        switch self {
        case .idle: return [.sitting, .standing]
        case .sitting: return [.idle, .standing]
        case .standing: return [.idle, .sitting]
        case .walking: return [.standing, .idle]
        case .lying: return [.sleeping, .idle]
        case .sleeping: return [.lying, .tired, .idle]
        case .stretching: return [.standing, .idle]
        case .grooming: return [.sitting, .idle]
        case .lookingAround: return [.curious, .idle]
        case .peekBottom: return [.headOnEdge, .hiddenPeek, .curious]
        case .peekLeft: return [.peekBottom, .headOnEdge]
        case .peekRight: return [.peekBottom, .headOnEdge]
        case .pawsOnEdge: return [.headOnEdge, .peekBottom]
        case .headOnEdge: return [.peekBottom, .hiddenPeek]
        case .hiddenPeek: return [.headOnEdge, .peekBottom]
        case .playful: return [.happy, .curious, .idle]
        case .curious: return [.lookingAround, .idle]
        case .tired: return [.lying, .sleeping, .idle]
        case .happy: return [.playful, .idle]
        case .dance: return [.happy, .playful, .idle]
        case .working: return [.sitting, .idle]
        case .umbrella: return [.standing, .idle]
        }
    }
}

/// Runtime manifest built from the canonical sprite sheet. The source sheet always wins; aliases
/// only provide graceful behaviour when a sheet genuinely lacks a requested state.
final class HaloPetAssetManifest: @unchecked Sendable {
    let species: String
    let resourceName: String
    let columns: Int
    let rows: Int
    let detectedAssetCount: Int
    let assets: [HaloPetPose: CGImage]
    let orderedAssets: [(HaloPetPose, CGImage)]

    init(species: String, resourceName: String, columns: Int, rows: Int,
         detectedAssetCount: Int, assets: [HaloPetPose: CGImage], orderedAssets: [(HaloPetPose, CGImage)]) {
        self.species = species
        self.resourceName = resourceName
        self.columns = columns
        self.rows = rows
        self.detectedAssetCount = detectedAssetCount
        self.assets = assets
        self.orderedAssets = orderedAssets
    }

    func image(for pose: HaloPetPose) -> CGImage? {
        if let exact = assets[pose] { return exact }
        for fallback in pose.fallbacks {
            if let image = assets[fallback] { return image }
        }
        return orderedAssets.first?.1
    }
}

@MainActor
final class HaloPetAssetStore: ObservableObject {
    static let shared = HaloPetAssetStore()

    @Published private(set) var revision = 0
    private var manifests: [String: HaloPetAssetManifest] = [:]
    private var loading = Set<String>()

    func manifest(for kind: EIPetKind) -> HaloPetAssetManifest? { manifests[kind.rawValue] }
    func image(for kind: EIPetKind, pose: HaloPetPose) -> CGImage? { manifests[kind.rawValue]?.image(for: pose) }

    func load(_ kind: EIPetKind) {
        let key = kind.rawValue
        guard manifests[key] == nil, !loading.contains(key) else { return }
        let resource: (String, String)
        switch kind {
        case .cat: resource = ("Cat", "png")
        case .dog: resource = ("Dog", "jpg")
        case .fox: resource = ("Fox", "jpg")
        }
        guard let url = Bundle.main.url(forResource: resource.0, withExtension: resource.1) else { return }
        loading.insert(key)
        Task { [weak self] in
            let manifest = await Task.detached(priority: .utility) {
                HaloPetSpriteSheetDecoder.decode(url: url, species: key, resourceName: "\(resource.0).\(resource.1)")
            }.value
            guard let self else { return }
            self.loading.remove(key)
            if let manifest { self.manifests[key] = manifest }
            self.revision &+= 1
        }
    }
}

private enum HaloPetSpriteSheetDecoder {
    private struct RGB {
        var r: Int
        var g: Int
        var b: Int
    }

    private struct GridChoice {
        var columns: Int
        var rows: Int
        var activeCells: [Int]
        var score: Double
    }

    private struct PixelBuffer {
        let width: Int
        let height: Int
        var pixels: [UInt8]
        let hasUsefulAlpha: Bool
        let background: RGB

        init?(image: CGImage) {
            width = image.width
            height = image.height
            guard width > 0, height > 0 else { return nil }
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            guard let context = CGContext(data: &bytes, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            pixels = bytes

            var alphaSeen = false
            let alphaStep = max(1, (width * height) / 4096)
            for pixel in stride(from: 0, to: width * height, by: alphaStep) {
                if Int(bytes[pixel * 4 + 3]) < 245 { alphaSeen = true; break }
            }
            hasUsefulAlpha = alphaSeen

            let samples = [
                (0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1),
                (width / 2, 0), (width / 2, height - 1), (0, height / 2), (width - 1, height / 2)
            ]
            var rs = 0, gs = 0, bs = 0, count = 0
            for (x, y) in samples {
                let i = (y * width + x) * 4
                if bytes[i + 3] > 8 {
                    rs += Int(bytes[i]); gs += Int(bytes[i + 1]); bs += Int(bytes[i + 2]); count += 1
                }
            }
            background = count > 0 ? RGB(r: rs / count, g: gs / count, b: bs / count) : RGB(r: 255, g: 255, b: 255)
        }

        func isForeground(x: Int, y: Int) -> Bool {
            guard x >= 0, y >= 0, x < width, y < height else { return false }
            let i = (y * width + x) * 4
            let a = Int(pixels[i + 3])
            if hasUsefulAlpha { return a > 24 }
            let dr = Int(pixels[i]) - background.r
            let dg = Int(pixels[i + 1]) - background.g
            let db = Int(pixels[i + 2]) - background.b
            return dr * dr + dg * dg + db * db > 34 * 34
        }

        func occupancy(x: Int, y: Int, width cellWidth: Int, height cellHeight: Int) -> Double {
            let strideBy = max(1, min(cellWidth, cellHeight) / 42)
            var foreground = 0
            var total = 0
            let maxY = min(height, y + cellHeight)
            let maxX = min(width, x + cellWidth)
            var yy = max(0, y)
            while yy < maxY {
                var xx = max(0, x)
                while xx < maxX {
                    total += 1
                    if isForeground(x: xx, y: yy) { foreground += 1 }
                    xx += strideBy
                }
                yy += strideBy
            }
            return total == 0 ? 0 : Double(foreground) / Double(total)
        }

        func extractedSprite(x: Int, y: Int, width cellWidth: Int, height cellHeight: Int) -> CGImage? {
            let insetX = max(1, Int(Double(cellWidth) * 0.018))
            let insetY = max(1, Int(Double(cellHeight) * 0.018))
            let x0 = max(0, x + insetX)
            let y0 = max(0, y + insetY)
            let x1 = min(width, x + cellWidth - insetX)
            let y1 = min(height, y + cellHeight - insetY)
            guard x1 > x0, y1 > y0 else { return nil }
            let w = x1 - x0, h = y1 - y0
            var out = [UInt8](repeating: 0, count: w * h * 4)
            for row in 0..<h {
                let sourceStart = ((y0 + row) * width + x0) * 4
                let destinationStart = row * w * 4
                out[destinationStart..<(destinationStart + w * 4)] = pixels[sourceStart..<(sourceStart + w * 4)]
            }

            if !hasUsefulAlpha {
                removeBorderConnectedBackground(&out, width: w, height: h, reference: background)
            }

            guard let main = mainContentRect(out, width: w, height: h) else { return nil }
            let padX = max(2, Int(Double(main.width) * 0.045))
            let padY = max(2, Int(Double(main.height) * 0.045))
            let left = max(0, main.x - padX)
            let top = max(0, main.y - padY)
            let right = min(w, main.x + main.width + padX)
            let bottom = min(h, main.y + main.height + padY)
            return makeImage(out, sourceWidth: w, x: left, y: top, width: right - left, height: bottom - top)
        }

        private func removeBorderConnectedBackground(_ bytes: inout [UInt8], width w: Int, height h: Int, reference: RGB) {
            guard w > 2, h > 2 else { return }
            var visited = [Bool](repeating: false, count: w * h)
            var queue = [Int]()
            queue.reserveCapacity(w * 2 + h * 2)

            func nearBackground(_ index: Int) -> Bool {
                let p = index * 4
                let dr = Int(bytes[p]) - reference.r
                let dg = Int(bytes[p + 1]) - reference.g
                let db = Int(bytes[p + 2]) - reference.b
                return dr * dr + dg * dg + db * db <= 48 * 48
            }
            func seed(_ index: Int) {
                guard !visited[index], nearBackground(index) else { return }
                visited[index] = true; queue.append(index)
            }
            for x in 0..<w { seed(x); seed((h - 1) * w + x) }
            for y in 0..<h { seed(y * w); seed(y * w + w - 1) }

            var head = 0
            while head < queue.count {
                let index = queue[head]; head += 1
                let x = index % w, y = index / w
                let neighbours = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                for (nx, ny) in neighbours where nx >= 0 && ny >= 0 && nx < w && ny < h {
                    let next = ny * w + nx
                    guard !visited[next], nearBackground(next) else { continue }
                    visited[next] = true; queue.append(next)
                }
            }
            for index in 0..<(w * h) where visited[index] { bytes[index * 4 + 3] = 0 }

            var fringe = [Int]()
            for index in 0..<(w * h) where !visited[index] {
                let x = index % w, y = index / w
                if (x > 0 && visited[index - 1]) || (x + 1 < w && visited[index + 1]) ||
                   (y > 0 && visited[index - w]) || (y + 1 < h && visited[index + w]) {
                    fringe.append(index)
                }
            }
            for index in fringe { bytes[index * 4 + 3] = min(bytes[index * 4 + 3], 190) }
        }

        private func mainContentRect(_ bytes: [UInt8], width w: Int, height h: Int) -> (x: Int, y: Int, width: Int, height: Int)? {
            let minimumRowPixels = max(2, w / 180)
            var rowCounts = [Int](repeating: 0, count: h)
            for y in 0..<h {
                var count = 0
                for x in 0..<w where bytes[(y * w + x) * 4 + 3] > 20 { count += 1 }
                rowCounts[y] = count
            }

            var best: (start: Int, end: Int, score: Double)?
            var start: Int? = nil
            var gap = 0
            var running = 0
            for y in 0...h {
                let active = y < h && rowCounts[y] >= minimumRowPixels
                if active {
                    if start == nil { start = y }
                    gap = 0; running += rowCounts[y]
                } else if start != nil {
                    gap += 1
                    if gap <= 2 && y < h { continue }
                    let end = max(start!, y - gap)
                    let span = max(1, end - start! + 1)
                    let score = Double(running) * sqrt(Double(span))
                    if best == nil || score > best!.score { best = (start!, end, score) }
                    start = nil; gap = 0; running = 0
                }
            }
            guard let run = best else { return nil }
            let y0 = max(0, run.start - 2), y1 = min(h - 1, run.end + 2)
            var minX = w, maxX = -1
            for y in y0...y1 {
                for x in 0..<w where bytes[(y * w + x) * 4 + 3] > 20 {
                    minX = min(minX, x); maxX = max(maxX, x)
                }
            }
            guard maxX >= minX else { return nil }
            return (minX, y0, maxX - minX + 1, y1 - y0 + 1)
        }

        private func makeImage(_ bytes: [UInt8], sourceWidth: Int, x: Int, y: Int, width w: Int, height h: Int) -> CGImage? {
            guard w > 0, h > 0 else { return nil }
            var cropped = [UInt8](repeating: 0, count: w * h * 4)
            for row in 0..<h {
                let sourceStart = ((y + row) * sourceWidth + x) * 4
                let destinationStart = row * w * 4
                cropped[destinationStart..<(destinationStart + w * 4)] = bytes[sourceStart..<(sourceStart + w * 4)]
            }
            guard let provider = CGDataProvider(data: Data(cropped) as CFData) else { return nil }
            return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                           space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                           provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        }
    }

    static func decode(url: URL, species: String, resourceName: String) -> HaloPetAssetManifest? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary),
              let buffer = PixelBuffer(image: image) else { return nil }

        let poses = HaloPetPose.allCases
        guard let grid = chooseGrid(buffer: buffer, expected: poses.count) else { return nil }
        let cellWidth = buffer.width / grid.columns
        let cellHeight = buffer.height / grid.rows
        var mapped: [HaloPetPose: CGImage] = [:]
        var ordered: [(HaloPetPose, CGImage)] = []

        for (pose, cellIndex) in zip(poses, grid.activeCells.prefix(poses.count)) {
            let column = cellIndex % grid.columns
            let row = cellIndex / grid.columns
            guard let sprite = buffer.extractedSprite(x: column * cellWidth, y: row * cellHeight,
                                                      width: cellWidth, height: cellHeight) else { continue }
            mapped[pose] = sprite
            ordered.append((pose, sprite))
        }
        guard !ordered.isEmpty else { return nil }
        return HaloPetAssetManifest(species: species, resourceName: resourceName,
                                    columns: grid.columns, rows: grid.rows,
                                    detectedAssetCount: grid.activeCells.count,
                                    assets: mapped, orderedAssets: ordered)
    }

    private static func chooseGrid(buffer: PixelBuffer, expected: Int) -> GridChoice? {
        var best: GridChoice?
        for columns in 3...7 {
            for rows in 3...7 {
                let cellWidth = buffer.width / columns
                let cellHeight = buffer.height / rows
                guard cellWidth >= 80, cellHeight >= 80 else { continue }
                var active: [Int] = []
                var occupancies: [Double] = []
                for row in 0..<rows {
                    for column in 0..<columns {
                        let ratio = buffer.occupancy(x: column * cellWidth, y: row * cellHeight,
                                                     width: cellWidth, height: cellHeight)
                        if ratio > 0.018 && ratio < 0.92 {
                            active.append(row * columns + column)
                            occupancies.append(ratio)
                        }
                    }
                }
                guard active.count >= 8 else { continue }
                let countPenalty = Double(abs(active.count - expected)) * 30
                let aspect = Double(cellWidth) / Double(cellHeight)
                let aspectPenalty = abs(log(max(0.05, aspect))) * 9
                let overDense = occupancies.reduce(0.0) { $0 + max(0, $1 - 0.72) * 30 }
                let score = 1000 - countPenalty - aspectPenalty - overDense
                if best == nil || score > best!.score {
                    best = GridChoice(columns: columns, rows: rows, activeCells: active, score: score)
                }
            }
        }
        return best
    }
}

@MainActor
final class HaloPetDebugState: ObservableObject {
    static let shared = HaloPetDebugState()
    @Published var forcedMotion: HaloCompanionMotion?
    @Published var showAssets = false
    private var playTask: Task<Void, Never>?

    func force(_ motion: HaloCompanionMotion?) {
        playTask?.cancel(); playTask = nil; forcedMotion = motion
    }

    func playAll() {
        playTask?.cancel()
        playTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for motion in HaloCompanionMotion.allCases where motion != .hidden {
                guard !Task.isCancelled else { return }
                self.forcedMotion = motion
                try? await Task.sleep(nanoseconds: 1_150_000_000)
            }
            if !Task.isCancelled { self.forcedMotion = nil }
        }
    }
}

/// Asset-backed pet renderer. The supplied Cat/Dog/Fox sheets are the source of truth; this view
/// only adds transforms, masking, timing and subtle secondary motion to make those drawings live.
struct HaloCompanionSprite: View {
    let kind: EIPetKind
    let style: EIPetVisualStyle
    var size: CGFloat
    var primary: Color
    var accent: Color
    var motion: HaloCompanionMotion = .idle
    var facingRight = true

    // Legacy call-site compatibility. Canonical pets intentionally ignore old pixel/vector styling.
    var displayPreset: EIPixelDisplayPreset = .clean
    var pixelGrid = false
    var pixelGlow = true
    var scanlines = false
    var ghosting = false
    var brightnessVariation = false

    @ObservedObject private var assets = HaloPetAssetStore.shared
    @ObservedObject private var debug = HaloPetDebugState.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activePose: HaloPetPose = .idle
    @State private var previousPose: HaloPetPose?
    @State private var blend = 1.0
    @State private var hoverPoint: CGPoint?

    private var resolvedMotion: HaloCompanionMotion { debug.forcedMotion ?? motion }
    private var targetPose: HaloPetPose {
        switch resolvedMotion {
        case .hidden: return .hiddenPeek
        case .peekEyes, .peekEars: return .hiddenPeek
        case .peek: return .peekBottom
        case .peekLeft: return .peekLeft
        case .peekRight: return .peekRight
        case .observe, .look: return .lookingAround
        case .idle: return .idle
        case .walk, .entering, .leaving: return .walking
        case .greet, .celebrate, .affectionate, .excited, .happy: return .happy
        case .sleep: return .sleeping
        case .snack, .playful: return .playful
        case .dance: return .dance
        case .stretch: return .stretching
        case .groom: return .grooming
        case .tired: return .tired
        case .paw: return .pawsOnEdge
        case .tail, .curious: return .curious
        case .resting: return .lying
        case .coffee, .working: return .working
        case .umbrella: return .umbrella
        }
    }

    var body: some View {
        Group {
            if resolvedMotion == .hidden {
                Color.clear
            } else if assets.image(for: kind, pose: activePose) == nil {
                Color.clear
            } else {
                TimelineView(.animation(minimumInterval: updateInterval, paused: reduceMotion)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        if let previousPose, let image = assets.image(for: kind, pose: previousPose) {
                            sprite(image, phase: phase).opacity(1 - blend)
                        }
                        if let image = assets.image(for: kind, pose: activePose) {
                            sprite(image, phase: phase).opacity(blend)
                        }
                    }
                }
            }
        }
        .frame(width: size, height: size * 0.90)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): hoverPoint = point
            case .ended: hoverPoint = nil
            }
        }
        .task(id: kind.rawValue) { assets.load(kind) }
        .onAppear { activePose = targetPose }
        .onChange(of: targetPose) { transition(to: $0) }
        .accessibilityLabel("\(kind.rawValue) companion")
    }

    private var updateInterval: Double {
        if reduceMotion { return 0.28 }
        switch resolvedMotion {
        case .walk, .dance, .playful, .excited, .entering, .leaving: return 1.0 / 36.0
        case .sleep, .resting: return 1.0 / 10.0
        default: return 1.0 / 24.0
        }
    }

    private func sprite(_ image: CGImage, phase: Double) -> some View {
        let breathing = reduceMotion ? 1.0 : 1.0 + sin(phase * breathingSpeed) * breathingAmount
        let bob = reduceMotion ? 0.0 : bobOffset(phase)
        let hover = cursorOffset
        return Image(decorative: image, scale: 1, orientation: .up)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .scaleEffect(x: facingRight ? 1 : -1, y: breathing, anchor: .bottom)
            .offset(x: hover.width, y: bob + hover.height + revealOffset)
            .mask(alignment: .top) {
                Rectangle().frame(height: max(1, size * 0.90 * revealAmount), alignment: .top)
            }
            .shadow(color: Color.black.opacity(resolvedMotion == .sleep ? 0.14 : 0.20), radius: max(1, size * 0.018), y: max(1, size * 0.012))
    }

    private var revealAmount: CGFloat {
        switch resolvedMotion {
        case .peekEyes: return 0.25
        case .peekEars: return 0.18
        case .peek, .peekLeft, .peekRight: return 0.62
        case .paw: return 0.72
        case .entering: return 0.84
        case .leaving: return 0.70
        default: return 1
        }
    }

    private var revealOffset: CGFloat {
        let hidden = 1 - revealAmount
        return hidden > 0 ? hidden * size * 0.32 : 0
    }

    private var breathingSpeed: Double {
        resolvedMotion == .sleep ? 0.72 : (kind == .dog ? 1.32 : kind == .fox ? 0.92 : 1.06)
    }

    private var breathingAmount: CGFloat {
        if resolvedMotion == .sleep { return 0.009 }
        return kind == .dog ? 0.006 : 0.0045
    }

    private func bobOffset(_ phase: Double) -> CGFloat {
        switch resolvedMotion {
        case .walk, .entering, .leaving:
            return -CGFloat(abs(sin(phase * (kind == .dog ? 8.8 : 7.6)))) * (kind == .dog ? 2.2 : 1.6)
        case .dance:
            return -CGFloat(abs(sin(phase * (kind == .dog ? 6.8 : 5.3)))) * (kind == .dog ? 3.0 : 1.8)
        case .excited, .greet:
            return -CGFloat(abs(sin(phase * 5.8))) * (kind == .dog ? 2.4 : 1.1)
        case .sleep, .resting:
            return CGFloat(sin(phase * 0.72)) * 0.35
        default:
            return CGFloat(sin(phase * 0.92)) * 0.45
        }
    }

    private var cursorOffset: CGSize {
        guard let point = hoverPoint,
              [.observe, .look, .curious, .peek, .peekLeft, .peekRight].contains(resolvedMotion) else { return .zero }
        let nx = min(1, max(-1, (point.x / max(1, size) - 0.5) * 2))
        let ny = min(1, max(-1, (point.y / max(1, size * 0.90) - 0.5) * 2))
        return CGSize(width: nx * min(2.4, size * 0.018), height: ny * min(1.3, size * 0.010))
    }

    private func transition(to pose: HaloPetPose) {
        guard pose != activePose else { return }
        if reduceMotion {
            previousPose = nil; activePose = pose; blend = 1
            return
        }
        previousPose = activePose
        activePose = pose
        blend = 0
        withAnimation(.easeInOut(duration: transitionDuration)) { blend = 1 }
        let expectedPrevious = previousPose
        DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration + 0.05) {
            if previousPose == expectedPrevious && blend >= 0.99 { previousPose = nil }
        }
    }

    private var transitionDuration: Double {
        switch resolvedMotion {
        case .peek, .peekLeft, .peekRight, .peekEyes, .peekEars: return 0.28
        case .sleep, .resting, .stretch: return 0.42
        case .walk, .entering, .leaving: return 0.20
        default: return 0.24
        }
    }
}

#if DEBUG
@MainActor
struct HaloPetDebugPanel: View {
    @ObservedObject private var settings = EISettingsStore.shared
    @ObservedObject private var debug = HaloPetDebugState.shared
    @ObservedObject private var assets = HaloPetAssetStore.shared

    private let primaryMotions: [HaloCompanionMotion] = [
        .hidden, .peek, .idle, .walk, .sleep, .playful, .curious, .tired, .happy,
        .dance, .coffee, .working, .umbrella
    ]

    var body: some View {
        DisclosureGroup("Pet Debug") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Pet", selection: $settings.settings.petKind) {
                    ForEach(EIPetKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 5)], spacing: 5) {
                    ForEach(primaryMotions) { motion in
                        Button(motion.rawValue) { debug.force(motion) }
                            .font(.caption2)
                    }
                }
                HStack {
                    Button("Play All Behaviours") { debug.playAll() }
                    Button("Release") { debug.force(nil) }
                }
                HStack {
                    Button("User Return") { debug.force(.greet) }
                    Button("Long Work") { debug.force(.coffee) }
                    Button("Late Night") { debug.force(.sleep) }
                    Button("Music") { debug.force(.dance) }
                    Button("Rain") { debug.force(.umbrella) }
                }
                .font(.caption2)

                if let manifest = assets.manifest(for: settings.settings.petKind) {
                    Text("\(manifest.resourceName) · detected \(manifest.detectedAssetCount) · grid \(manifest.columns)×\(manifest.rows) · mapped \(manifest.assets.count)")
                        .font(.caption2).foregroundStyle(.secondary)
                    Toggle("Inspect extracted poses", isOn: $debug.showAssets)
                    if debug.showAssets {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 5)], spacing: 7) {
                            ForEach(HaloPetPose.allCases) { pose in
                                if let image = manifest.image(for: pose) {
                                    VStack(spacing: 2) {
                                        Image(decorative: image, scale: 1, orientation: .up)
                                            .resizable().scaledToFit().frame(height: 52)
                                        Text(pose.title).font(.system(size: 7)).lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("Loading canonical pet sheet…").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
            .task(id: settings.settings.petKind.rawValue) { assets.load(settings.settings.petKind) }
        }
    }
}
#endif

// MARK: - Premium plant renderer

struct HaloPlantRenderer: View {
    let kind: EIPlantKind
    var size: CGFloat
    var plantColor: Color
    var potColor: Color
    var growth: Double
    var environment: EIEnvironment
    var reaction: EIReactionKind?
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.30 : 1.0 / 24.0, paused: false)) { timeline in
            plant(phase: timeline.date.timeIntervalSinceReferenceDate)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(kind.rawValue) environmental plant")
    }

    private func plant(phase: Double) -> some View {
        let g = CGFloat(min(1, max(0.06, growth)))
        let night = environment.timeOfDay == .night || reaction == .plantNight
        let rain = environment.weather?.isRaining == true || reaction == .plantRain
        let music = environment.isMusicPlaying
        let wind = reduceMotion ? 0.0 : sin(phase * (music ? 1.8 : 0.75)) * (music ? 3.2 : 1.4)
        let ambient = night ? 0.80 : 1.0

        return ZStack(alignment: .bottom) {
            Ellipse().fill(Color.black.opacity(0.20)).frame(width: size * 0.54, height: size * 0.10)
                .blur(radius: size * 0.015).offset(y: size * 0.025)
            pot(size)

            switch kind {
            case .bonsai: bonsai(size, g, wind, ambient, phase)
            case .flower: flowering(size, g, wind, ambient, phase)
            case .vine: vine(size, g, wind, ambient, phase)
            case .succulent: succulent(size, g, ambient)
            case .fern: fern(size, g, wind, ambient)
            }

            if rain { rainDrops(size, phase) }
        }
        .frame(width: size, height: size)
        .drawingGroup(opaque: false, colorMode: .linear)
    }

    private func pot(_ s: CGFloat) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: s * 0.025, style: .continuous)
                .fill(potColor.mixed(with: .white, amount: 0.12)).frame(width: s * 0.40, height: s * 0.075)
            PlantPotShape().fill(LinearGradient(colors: [potColor, potColor.mixed(with: .black, amount: 0.28)], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.34, height: s * 0.22)
        }
        .shadow(color: Color.black.opacity(0.20), radius: s * 0.025, y: s * 0.018)
    }

    private func bonsai(_ s: CGFloat, _ g: CGFloat, _ wind: Double, _ ambient: Double, _ phase: Double) -> some View {
        ZStack(alignment: .bottom) {
            BonsaiTrunkShape().stroke(potColor.mixed(with: .black, amount: 0.36), style: StrokeStyle(lineWidth: max(3, s * 0.055), lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.48, height: s * 0.60).offset(y: -s * 0.18)
            ForEach(0..<9, id: \.self) { index in
                if CGFloat(index + 1) / 9 <= max(0.22, g + 0.14) {
                    let xs: [CGFloat] = [-0.20, 0.10, -0.03, 0.22, -0.17, 0.05, 0.25, -0.06, 0.15]
                    let ys: [CGFloat] = [-0.48, -0.43, -0.55, -0.37, -0.31, -0.28, -0.23, -0.18, -0.15]
                    leafCluster(s * (0.20 + CGFloat(index % 3) * 0.018), phase + Double(index), ambient)
                        .rotationEffect(.degrees(wind * (index.isMultiple(of: 2) ? 1 : -0.7)), anchor: .bottom)
                        .offset(x: xs[index] * s, y: ys[index] * s)
                }
            }
        }
    }

    private func flowering(_ s: CGFloat, _ g: CGFloat, _ wind: Double, _ ambient: Double, _ phase: Double) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<5, id: \.self) { index in
                let angle = Double(index - 2) * 12
                Capsule(style: .continuous).fill(plantColor.mixed(with: .black, amount: 0.18).opacity(ambient))
                    .frame(width: s * 0.025, height: s * (0.38 + g * 0.20))
                    .rotationEffect(.degrees(angle + wind * 0.45), anchor: .bottom).offset(y: -s * 0.18)
                leaf(s * 0.17, ambient)
                    .rotationEffect(.degrees(angle - 32 + wind), anchor: .trailing)
                    .offset(x: CGFloat(index - 2) * s * 0.055, y: -s * (0.30 + CGFloat(index % 2) * 0.08))
            }
            if g > 0.34 || reaction == .plantBloom {
                ForEach(0..<3, id: \.self) { index in
                    let openness: Double = reaction == .plantBloom ? 1 : Double(min(1, max(0, (g - 0.30) * 1.8)))
                    flower(s * 0.16, openness, phase + Double(index))
                        .offset(x: CGFloat(index - 1) * s * 0.13, y: -s * (0.61 + CGFloat(index % 2) * 0.055))
                        .rotationEffect(.degrees(wind * 0.65))
                }
            }
        }
    }

    private func vine(_ s: CGFloat, _ g: CGFloat, _ wind: Double, _ ambient: Double, _ phase: Double) -> some View {
        ZStack(alignment: .bottom) {
            VineStemShape().trim(from: 0, to: g)
                .stroke(plantColor.mixed(with: .black, amount: 0.22).opacity(ambient), style: StrokeStyle(lineWidth: max(2, s * 0.025), lineCap: .round))
                .frame(width: s * 0.64, height: s * 0.70).offset(y: -s * 0.16)
            ForEach(0..<10, id: \.self) { index in
                if CGFloat(index) / 10 < g {
                    leaf(s * 0.13, ambient)
                        .rotationEffect(.degrees(Double(index.isMultiple(of: 2) ? -38 : 38) + wind * 0.6))
                        .offset(x: CGFloat(sin(Double(index) * 1.17)) * s * 0.22,
                                y: -s * (0.24 + CGFloat(index) * 0.047))
                }
            }
            if reaction == .plantBloom && g > 0.45 {
                flower(s * 0.12, 1, phase).offset(x: s * 0.20, y: -s * 0.62)
            }
        }
    }

    private func succulent(_ s: CGFloat, _ g: CGFloat, _ ambient: Double) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<11, id: \.self) { index in
                let angle = Double(index) / 11 * 320 - 160
                let inner = index >= 7
                PlantSucculentLeaf().fill(LinearGradient(colors: [plantColor.mixed(with: .white, amount: 0.20).opacity(ambient), plantColor.mixed(with: .black, amount: 0.20).opacity(ambient)], startPoint: .top, endPoint: .bottom))
                    .frame(width: s * (inner ? 0.15 : 0.19), height: s * (inner ? 0.28 : 0.36) * max(0.58, g))
                    .rotationEffect(.degrees(angle * (inner ? 0.38 : 0.58)), anchor: .bottom).offset(y: -s * 0.17)
            }
        }
    }

    private func fern(_ s: CGFloat, _ g: CGFloat, _ wind: Double, _ ambient: Double) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<7, id: \.self) { index in
                FernFrondShape().stroke(plantColor.opacity(ambient), style: StrokeStyle(lineWidth: max(2, s * 0.022), lineCap: .round))
                    .overlay(FernLeaflets().stroke(plantColor.mixed(with: .white, amount: 0.10).opacity(ambient), lineWidth: max(1, s * 0.012)))
                    .frame(width: s * 0.22, height: s * (0.42 + g * 0.18))
                    .rotationEffect(.degrees(Double(index - 3) * 13 + wind), anchor: .bottom).offset(y: -s * 0.18)
            }
        }
    }

    private func leaf(_ size: CGFloat, _ ambient: Double) -> some View {
        PlantLeafShape().fill(LinearGradient(colors: [plantColor.mixed(with: .white, amount: 0.18).opacity(ambient), plantColor.mixed(with: .black, amount: 0.16).opacity(ambient)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size * 0.58)
            .overlay(PlantLeafVein().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
    }

    private func leafCluster(_ size: CGFloat, _ phase: Double, _ ambient: Double) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                leaf(size * 0.72, ambient)
                    .rotationEffect(.degrees(Double(index) * 55 - 105 + sin(phase * 0.6 + Double(index)) * 2.2), anchor: .trailing)
                    .offset(x: CGFloat(index - 2) * size * 0.09)
            }
        }
    }

    private func flower(_ size: CGFloat, _ open: Double, _ phase: Double) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Ellipse().fill(Color.pink.mixed(with: plantColor, amount: 0.18).opacity(0.92))
                    .frame(width: size * 0.58, height: size)
                    .rotationEffect(.degrees(Double(index) * 72))
                    .scaleEffect(CGFloat(0.40 + open * 0.60))
            }
            Circle().fill(Color.yellow.opacity(0.88)).frame(width: size * 0.25, height: size * 0.25)
        }
        .rotationEffect(.degrees(sin(phase * 0.5) * 2))
    }

    @ViewBuilder
    private func rainDrops(_ s: CGFloat, _ phase: Double) -> some View {
        ForEach(0..<6, id: \.self) { index in
            let travel = (phase * 0.48 + Double(index) * 0.17).truncatingRemainder(dividingBy: 1)
            Capsule().fill(Color.cyan.opacity(0.40)).frame(width: 1.5, height: s * 0.055)
                .offset(x: CGFloat(index - 3) * s * 0.12, y: -s * 0.72 + CGFloat(travel) * s * 0.56)
        }
    }
}

// MARK: - Tiny City vector simulation

struct HaloCityRenderer: View {
    var accent: Color
    var environment: EIEnvironment
    var reaction: EIReactionKind?
    var seed: Int
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : 1.0 / 30.0, paused: false)) { timeline in
            GeometryReader { proxy in city(proxy.size, timeline.date.timeIntervalSinceReferenceDate) }
        }
        .accessibilityLabel("Tiny City environmental simulation")
    }

    private func city(_ size: CGSize, _ phase: Double) -> some View {
        let night = environment.timeOfDay == .night || reaction == .cityNight
        let evening = environment.timeOfDay == .evening
        let rain = environment.weather?.isRaining == true || reaction == .cityRain || reaction == .cityStorm
        let busy = reaction == .cityBusy || environment.timeOfDay == .day
        let music = environment.isMusicPlaying || reaction == .cityMusic
        let roadY = size.height * 0.76
        let speed: Double = reduceMotion ? 0 : (busy ? 34 : night ? 12 : 24)
        let travelWidth = Double(max(1, size.width + 70))
        let taxiWidth = Double(max(1, size.width + 80))
        let carX = CGFloat((phase * speed).truncatingRemainder(dividingBy: travelWidth)) - 35
        let taxiX = size.width - CGFloat((phase * speed * 0.68 + 96).truncatingRemainder(dividingBy: taxiWidth)) + 40
        let sky: [Color] = night
            ? [Color(red: 0.025, green: 0.035, blue: 0.09), Color(red: 0.07, green: 0.09, blue: 0.17)]
            : evening
                ? [Color(red: 0.20, green: 0.12, blue: 0.22), Color(red: 0.54, green: 0.25, blue: 0.20)]
                : [Color(red: 0.08, green: 0.14, blue: 0.22), Color(red: 0.13, green: 0.24, blue: 0.32)]

        return ZStack(alignment: .bottom) {
            LinearGradient(colors: sky, startPoint: .top, endPoint: .bottom)

            RoundedRectangle(cornerRadius: min(22, size.height * 0.16), style: .continuous)
                .fill(Color.black.opacity(0.88))
                .frame(width: min(size.width * 0.26, 150), height: size.height * 0.55)
                .overlay(alignment: .bottom) {
                    Capsule().fill(accent.opacity(0.32)).frame(width: min(64, size.width * 0.12), height: 3).padding(.bottom, 7)
                }
                .offset(y: -size.height * 0.19)

            buildings(size, night, music, phase)
            Rectangle().fill(Color.black.opacity(0.48)).frame(height: size.height * 0.22)
            Rectangle().fill(Color.white.opacity(0.055)).frame(height: 1).offset(y: -size.height * 0.20)

            cityCar(accent, false).frame(width: 32, height: 15).position(x: carX, y: roadY)
            cityCar(Color.yellow.opacity(0.86), true).frame(width: 34, height: 15)
                .scaleEffect(x: -1, y: 1).position(x: taxiX, y: roadY + size.height * 0.075)

            pedestrians(size, phase, busy, night, rain)
            if music { club(size, phase) }
            if rain { rainLayer(size, phase) }
            randomMoment(size, phase)
        }
        .drawingGroup(opaque: false, colorMode: .linear)
    }

    private func buildings(_ size: CGSize, _ night: Bool, _ music: Bool, _ phase: Double) -> some View {
        let heights: [CGFloat] = [0.35, 0.49, 0.31, 0.44, 0.38, 0.52, 0.34, 0.42]
        return HStack(alignment: .bottom, spacing: max(2, size.width * 0.008)) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, ratio in
                if index == 3 || index == 4 {
                    Color.clear.frame(width: size.width * 0.12)
                } else {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.12), Color.black.opacity(0.32)], startPoint: .top, endPoint: .bottom))
                        .frame(width: max(18, size.width * 0.075), height: size.height * ratio)
                        .overlay(windowGrid(index, night, music, phase).padding(5))
                }
            }
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 8).offset(y: -size.height * 0.20)
    }

    private func windowGrid(_ index: Int, _ night: Bool, _ music: Bool, _ phase: Double) -> some View {
        let active = night || environment.timeOfDay == .evening
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
            ForEach(0..<8, id: \.self) { window in
                let lit = active && ((window + index + seed) % 3 != 0)
                RoundedRectangle(cornerRadius: 1)
                    .fill(lit ? Color.yellow.opacity(0.45 + (music && index == 6 ? abs(sin(phase * 2.2)) * 0.28 : 0)) : Color.white.opacity(0.055))
                    .frame(height: 4)
            }
        }
    }

    private func cityCar(_ color: Color, _ taxi: Bool) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(color).frame(width: 30, height: 10)
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(color.mixed(with: .white, amount: 0.14))
                .frame(width: 17, height: 8).offset(x: 2, y: -5)
            HStack(spacing: 14) {
                Circle().fill(Color.black.opacity(0.88)).frame(width: 6, height: 6)
                Circle().fill(Color.black.opacity(0.88)).frame(width: 6, height: 6)
            }.offset(y: 2)
            if taxi { Capsule().fill(Color.white.opacity(0.55)).frame(width: 8, height: 2).offset(y: -10) }
        }
    }

    @ViewBuilder
    private func pedestrians(_ size: CGSize, _ phase: Double, _ busy: Bool, _ night: Bool, _ rain: Bool) -> some View {
        let count = night ? 2 : busy ? 7 : 4
        ForEach(0..<count, id: \.self) { index in
            let lane = CGFloat(index % 2)
            let speed = reduceMotion ? 0.0 : Double(6 + (index * 3) % 7)
            let travel = CGFloat((phase * speed + Double(index * 53)).truncatingRemainder(dividingBy: Double(max(1, size.width + 40)))) - 20
            CityPerson(umbrella: rain && index.isMultiple(of: 2), accent: index.isMultiple(of: 3) ? accent : Color.white.opacity(0.68))
                .frame(width: 12, height: 22)
                .position(x: index.isMultiple(of: 2) ? travel : size.width - travel,
                          y: size.height * (0.68 + lane * 0.09))
        }
    }

    private func club(_ size: CGSize, _ phase: Double) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(accent.opacity(0.16 + abs(sin(phase * 2.0)) * 0.14))
            .frame(width: max(28, size.width * 0.07), height: max(18, size.height * 0.10))
            .overlay(Image(systemName: "music.note").font(.system(size: 8, weight: .bold)).foregroundStyle(accent.opacity(0.8)))
            .position(x: size.width * 0.82, y: size.height * 0.55)
    }

    @ViewBuilder
    private func rainLayer(_ size: CGSize, _ phase: Double) -> some View {
        ForEach(0..<18, id: \.self) { index in
            let travel = (phase * 0.58 + Double(index) * 0.071).truncatingRemainder(dividingBy: 1)
            Capsule().fill(Color.cyan.opacity(0.20 + Double(index % 3) * 0.04))
                .frame(width: 1, height: 9).rotationEffect(.degrees(8))
                .position(x: CGFloat(index) / 18 * size.width, y: CGFloat(travel) * size.height)
        }
        Rectangle().fill(Color.cyan.opacity(0.07)).frame(height: 2).blur(radius: 2).offset(y: -size.height * 0.18)
    }

    @ViewBuilder
    private func randomMoment(_ size: CGSize, _ phase: Double) -> some View {
        let slot = (Int(phase / 19) + seed) % 11
        switch slot {
        case 2:
            Circle().fill(Color.red.opacity(0.76)).frame(width: 9, height: 9)
                .overlay(Rectangle().fill(Color.white.opacity(0.5)).frame(width: 1, height: 18).offset(y: 11))
                .position(x: size.width * 0.18, y: size.height * 0.23)
        case 5:
            Image(systemName: "bird.fill").font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.42))
                .position(x: CGFloat((phase * 8).truncatingRemainder(dividingBy: Double(max(1, size.width)))), y: size.height * 0.19)
        case 8:
            RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.72)).frame(width: 38, height: 15)
                .overlay(Text("DELIVERY").font(.system(size: 4, weight: .bold)).foregroundStyle(.white.opacity(0.8)))
                .position(x: size.width * 0.70, y: size.height * 0.76)
        default:
            EmptyView()
        }
    }
}

private struct CityPerson: View {
    let umbrella: Bool
    let accent: Color
    var body: some View {
        ZStack(alignment: .top) {
            if umbrella { ArcShape().stroke(accent.opacity(0.65), lineWidth: 1.5).frame(width: 12, height: 7).offset(y: -3) }
            Circle().fill(accent).frame(width: 4.5, height: 4.5)
            Capsule().fill(accent.opacity(0.88)).frame(width: 4, height: 10).offset(y: 4)
            HStack(spacing: 2) {
                Capsule().fill(accent.opacity(0.70)).frame(width: 1.5, height: 7).rotationEffect(.degrees(10))
                Capsule().fill(accent.opacity(0.70)).frame(width: 1.5, height: 7).rotationEffect(.degrees(-10))
            }.offset(y: 13)
        }
    }
}

// MARK: - Vector shapes

private struct CompanionEarShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.maxY), control1: CGPoint(x: r.width * 0.72, y: r.height * 0.22), control2: CGPoint(x: r.width * 0.95, y: r.height * 0.70))
        p.addCurve(to: CGPoint(x: r.minX, y: r.maxY), control1: CGPoint(x: r.width * 0.72, y: r.height * 0.95), control2: CGPoint(x: r.width * 0.28, y: r.height * 0.95))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.width * 0.05, y: r.height * 0.70), control2: CGPoint(x: r.width * 0.28, y: r.height * 0.22)); return p
    }
}
private struct CompanionFloppyEarShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.height * 0.64), control1: CGPoint(x: r.maxX, y: r.height * 0.10), control2: CGPoint(x: r.maxX, y: r.height * 0.38))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.width * 0.92, y: r.maxY), control2: CGPoint(x: r.width * 0.66, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.height * 0.36), control1: CGPoint(x: r.width * 0.08, y: r.height * 0.84), control2: CGPoint(x: r.minX, y: r.height * 0.58)); p.closeSubpath(); return p
    }
}
private struct CompanionTailShape: Shape {
    let kind: EIPetKind
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.width * 0.10, y: r.height * 0.92))
        if kind == .dog {
            p.addCurve(to: CGPoint(x: r.width * 0.74, y: r.height * 0.26), control1: CGPoint(x: r.width * 0.36, y: r.height * 0.80), control2: CGPoint(x: r.width * 0.46, y: r.height * 0.20))
        } else {
            p.addCurve(to: CGPoint(x: r.width * 0.82, y: r.height * 0.20), control1: CGPoint(x: r.width * 0.42, y: r.height * 0.92), control2: CGPoint(x: r.width * 0.88, y: r.height * 0.76))
            p.addCurve(to: CGPoint(x: r.width * 0.60, y: r.height * 0.06), control1: CGPoint(x: r.width * 0.94, y: r.height * 0.10), control2: CGPoint(x: r.width * 0.77, y: r.minY))
        }; return p
    }
}
private struct CompanionMouthShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.maxY), control1: CGPoint(x: r.midX, y: r.height * 0.62), control2: CGPoint(x: r.width * 0.20, y: r.maxY))
        p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addCurve(to: CGPoint(x: r.maxX, y: r.maxY), control1: CGPoint(x: r.midX, y: r.height * 0.62), control2: CGPoint(x: r.width * 0.80, y: r.maxY)); return p
    }
}
private struct CompanionChestShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.height * 0.52), control1: CGPoint(x: r.width * 0.88, y: r.height * 0.13), control2: CGPoint(x: r.maxX, y: r.height * 0.34))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.width * 0.82, y: r.height * 0.78), control2: CGPoint(x: r.width * 0.62, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.height * 0.52), control1: CGPoint(x: r.width * 0.38, y: r.maxY), control2: CGPoint(x: r.width * 0.12, y: r.height * 0.78)); p.closeSubpath(); return p
    }
}
private struct FoxCheekShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.width * 0.18, y: r.maxY), control2: CGPoint(x: r.width * 0.36, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.midY), control1: CGPoint(x: r.width * 0.64, y: r.maxY), control2: CGPoint(x: r.width * 0.82, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.width * 0.82, y: r.height * 0.18), control2: CGPoint(x: r.width * 0.63, y: r.minY)); p.closeSubpath(); return p
    }
}
private struct CupShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: CGRect(x: r.minX, y: r.minY, width: r.width * 0.72, height: r.height), cornerRadius: r.height * 0.16)
        p.addEllipse(in: CGRect(x: r.width * 0.62, y: r.height * 0.22, width: r.width * 0.34, height: r.height * 0.48)); return p
    }
}
private struct PlantPotShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.width * 0.08, y: r.minY)); p.addLine(to: CGPoint(x: r.width * 0.92, y: r.minY)); p.addLine(to: CGPoint(x: r.width * 0.78, y: r.maxY)); p.addLine(to: CGPoint(x: r.width * 0.22, y: r.maxY)); p.closeSubpath(); return p
    }
}
private struct BonsaiTrunkShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.width * 0.42, y: r.height * 0.52), control1: CGPoint(x: r.width * 0.48, y: r.height * 0.82), control2: CGPoint(x: r.width * 0.28, y: r.height * 0.68))
        p.addCurve(to: CGPoint(x: r.width * 0.58, y: r.height * 0.14), control1: CGPoint(x: r.width * 0.58, y: r.height * 0.40), control2: CGPoint(x: r.width * 0.65, y: r.height * 0.28))
        p.move(to: CGPoint(x: r.width * 0.44, y: r.height * 0.54)); p.addCurve(to: CGPoint(x: r.width * 0.18, y: r.height * 0.34), control1: CGPoint(x: r.width * 0.31, y: r.height * 0.48), control2: CGPoint(x: r.width * 0.24, y: r.height * 0.38))
        p.move(to: CGPoint(x: r.width * 0.52, y: r.height * 0.34)); p.addCurve(to: CGPoint(x: r.width * 0.82, y: r.height * 0.25), control1: CGPoint(x: r.width * 0.64, y: r.height * 0.30), control2: CGPoint(x: r.width * 0.72, y: r.height * 0.25)); return p
    }
}
private struct VineStemShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.width * 0.26, y: r.height * 0.63), control1: CGPoint(x: r.width * 0.70, y: r.height * 0.86), control2: CGPoint(x: r.width * 0.18, y: r.height * 0.76))
        p.addCurve(to: CGPoint(x: r.width * 0.70, y: r.height * 0.31), control1: CGPoint(x: r.width * 0.35, y: r.height * 0.51), control2: CGPoint(x: r.width * 0.78, y: r.height * 0.48))
        p.addCurve(to: CGPoint(x: r.width * 0.48, y: r.minY), control1: CGPoint(x: r.width * 0.61, y: r.height * 0.20), control2: CGPoint(x: r.width * 0.38, y: r.height * 0.12)); return p
    }
}
private struct PlantLeafShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addCurve(to: CGPoint(x: r.maxX, y: r.midY), control1: CGPoint(x: r.width * 0.30, y: r.minY), control2: CGPoint(x: r.width * 0.72, y: r.minY)); p.addCurve(to: CGPoint(x: r.minX, y: r.midY), control1: CGPoint(x: r.width * 0.70, y: r.maxY), control2: CGPoint(x: r.width * 0.28, y: r.maxY)); return p
    }
}
private struct PlantLeafVein: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY)); return p }
}
private struct PlantSucculentLeaf: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addCurve(to: CGPoint(x: r.maxX, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.height * 0.34), control2: CGPoint(x: r.maxX, y: r.height * 0.77)); p.addCurve(to: CGPoint(x: r.minX, y: r.maxY), control1: CGPoint(x: r.width * 0.72, y: r.height * 0.91), control2: CGPoint(x: r.width * 0.28, y: r.height * 0.91)); p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.minX, y: r.height * 0.77), control2: CGPoint(x: r.minX, y: r.height * 0.34)); return p
    }
}
private struct FernFrondShape: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.maxY)); p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.width * 0.18, y: r.height * 0.62), control2: CGPoint(x: r.width * 0.82, y: r.height * 0.34)); return p }
}
private struct FernLeaflets: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); for i in 1..<7 { let y = r.maxY - CGFloat(i) / 7 * r.height; let x = r.midX + CGFloat(sin(Double(i) * 0.9)) * r.width * 0.10; p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: r.minX, y: y - r.height * 0.06)); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: r.maxX, y: y - r.height * 0.06)) }; return p
    }
}
private struct ArcShape: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.addArc(center: CGPoint(x: r.midX, y: r.maxY), radius: r.width * 0.48, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false); return p }
}

private extension Color {
    func mixed(with other: Color, amount: CGFloat) -> Color {
        let fraction = max(0, min(1, amount))
        let lhs = NSColor(self).usingColorSpace(.deviceRGB) ?? .white
        let rhs = NSColor(other).usingColorSpace(.deviceRGB) ?? .white
        return Color(nsColor: lhs.blended(withFraction: fraction, of: rhs) ?? lhs)
    }
}
