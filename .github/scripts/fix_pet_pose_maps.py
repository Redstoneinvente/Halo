from pathlib import Path

path = Path('Halo/Views/CompanionSprite.swift')
text = path.read_text()

text = text.replace(
'''    case idle, sitting, standing, walking, lying, sleeping, stretching, grooming, lookingAround
    case peekBottom, peekLeft, peekRight, pawsOnEdge, headOnEdge, hiddenPeek
    case playful, curious, tired, happy, dance, working, umbrella
''',
'''    case idle, sitting, standing, walking, lying, sleeping, stretching, grooming, lookingAround
    case peekBottom, peekLeft, peekRight, pawsOnEdge, headOnEdge, hiddenPeek
    case playful, curious, tired, happy, excited, dance, working, coffee, umbrella
''')

text = text.replace(
'''        case .happy: return [.playful, .idle]
        case .dance: return [.happy, .playful, .idle]
        case .working: return [.sitting, .idle]
        case .umbrella: return [.standing, .idle]
''',
'''        case .happy: return [.playful, .idle]
        case .excited: return [.happy, .playful, .idle]
        case .dance: return [.excited, .happy, .playful, .idle]
        case .working: return [.sitting, .idle]
        case .coffee: return [.tired, .sitting, .idle]
        case .umbrella: return [.standing, .idle]
''')

start = text.index('private enum HaloPetSpriteSheetDecoder {')
end = text.index('\n@MainActor\nfinal class HaloPetDebugState', start)

replacement = r'''private enum HaloPetSpriteSheetDecoder {
    private struct RGB {
        var r: Int
        var g: Int
        var b: Int
    }

    /// Crop rectangles are authored against the exact supplied source sheets and then scaled to
    /// the decoded image size. This is intentionally deterministic: these sheets are illustrations,
    /// not uniform frame grids, and Dog/Fox contain text labels that must never enter a sprite crop.
    private struct CropSpec {
        let pose: HaloPetPose
        let rect: CGRect
    }

    private struct SheetSpec {
        let referenceSize: CGSize
        let crops: [CropSpec]
    }

    private struct PixelBuffer {
        let width: Int
        let height: Int
        var pixels: [UInt8]
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

            // The provided sheets have a baked checkerboard rather than useful transparency.
            // Averaging many border samples lands between the two checker tones, allowing the
            // flood-fill tolerance below to remove both without eating the illustrated animal.
            var rs = 0, gs = 0, bs = 0, count = 0
            let samples = 28
            for i in 0..<samples {
                let tx = Int(Double(i) / Double(samples - 1) * Double(width - 1))
                let ty = Int(Double(i) / Double(samples - 1) * Double(height - 1))
                for (x, y) in [(tx, 0), (tx, height - 1), (0, ty), (width - 1, ty)] {
                    let p = (y * width + x) * 4
                    rs += Int(bytes[p]); gs += Int(bytes[p + 1]); bs += Int(bytes[p + 2]); count += 1
                }
            }
            background = count > 0 ? RGB(r: rs / count, g: gs / count, b: bs / count) : RGB(r: 190, g: 190, b: 192)
        }

        func extractedSprite(rect sourceRect: CGRect, referenceSize: CGSize) -> CGImage? {
            guard referenceSize.width > 0, referenceSize.height > 0 else { return nil }
            let sx = CGFloat(width) / referenceSize.width
            let sy = CGFloat(height) / referenceSize.height
            let x0 = max(0, min(width - 1, Int((sourceRect.minX * sx).rounded(.down))))
            let y0 = max(0, min(height - 1, Int((sourceRect.minY * sy).rounded(.down))))
            let x1 = max(x0 + 1, min(width, Int((sourceRect.maxX * sx).rounded(.up))))
            let y1 = max(y0 + 1, min(height, Int((sourceRect.maxY * sy).rounded(.up))))
            let w = x1 - x0
            let h = y1 - y0
            guard w > 1, h > 1 else { return nil }

            var out = [UInt8](repeating: 0, count: w * h * 4)
            for row in 0..<h {
                let src = ((y0 + row) * width + x0) * 4
                let dst = row * w * 4
                out[dst..<(dst + w * 4)] = pixels[src..<(src + w * 4)]
            }

            removeCheckerboardBackground(&out, width: w, height: h)
            guard let content = mainContentRect(out, width: w, height: h) else { return nil }
            let padX = max(2, Int(Double(content.width) * 0.035))
            let padY = max(2, Int(Double(content.height) * 0.035))
            let left = max(0, content.x - padX)
            let top = max(0, content.y - padY)
            let right = min(w, content.x + content.width + padX)
            let bottom = min(h, content.y + content.height + padY)
            return makeImage(out, sourceWidth: w, x: left, y: top, width: right - left, height: bottom - top)
        }

        private func removeCheckerboardBackground(_ bytes: inout [UInt8], width w: Int, height h: Int) {
            guard w > 2, h > 2 else { return }

            // Capture actual checker colours from the crop border. Two clusters are enough for all
            // three supplied sheets and are safer than treating every light pixel as background.
            var border: [RGB] = []
            let step = max(1, min(w, h) / 35)
            for x in stride(from: 0, to: w, by: step) {
                border.append(rgb(bytes, width: w, x: x, y: 0))
                border.append(rgb(bytes, width: w, x: x, y: h - 1))
            }
            for y in stride(from: 0, to: h, by: step) {
                border.append(rgb(bytes, width: w, x: 0, y: y))
                border.append(rgb(bytes, width: w, x: w - 1, y: y))
            }
            let tones = checkerTones(border)

            func isBackground(_ index: Int) -> Bool {
                let p = index * 4
                let value = RGB(r: Int(bytes[p]), g: Int(bytes[p + 1]), b: Int(bytes[p + 2]))
                return tones.contains { distanceSquared(value, $0) <= 32 * 32 }
                    || distanceSquared(value, background) <= 40 * 40
            }

            var visited = [Bool](repeating: false, count: w * h)
            var queue: [Int] = []
            queue.reserveCapacity(w * 2 + h * 2)
            func seed(_ index: Int) {
                guard !visited[index], isBackground(index) else { return }
                visited[index] = true
                queue.append(index)
            }
            for x in 0..<w { seed(x); seed((h - 1) * w + x) }
            for y in 0..<h { seed(y * w); seed(y * w + w - 1) }

            var head = 0
            while head < queue.count {
                let index = queue[head]; head += 1
                let x = index % w, y = index / w
                if x > 0 { seed(index - 1) }
                if x + 1 < w { seed(index + 1) }
                if y > 0 { seed(index - w) }
                if y + 1 < h { seed(index + w) }
            }
            for i in 0..<(w * h) where visited[i] { bytes[i * 4 + 3] = 0 }

            // Anti-alias one-pixel checker fringe without altering pale fur inside the silhouette.
            var fringe: [Int] = []
            for i in 0..<(w * h) where !visited[i] {
                let x = i % w, y = i / w
                if (x > 0 && visited[i - 1]) || (x + 1 < w && visited[i + 1]) ||
                   (y > 0 && visited[i - w]) || (y + 1 < h && visited[i + w]) {
                    fringe.append(i)
                }
            }
            for i in fringe { bytes[i * 4 + 3] = min(bytes[i * 4 + 3], 205) }
        }

        private func rgb(_ bytes: [UInt8], width: Int, x: Int, y: Int) -> RGB {
            let p = (y * width + x) * 4
            return RGB(r: Int(bytes[p]), g: Int(bytes[p + 1]), b: Int(bytes[p + 2]))
        }

        private func checkerTones(_ samples: [RGB]) -> [RGB] {
            guard !samples.isEmpty else { return [background] }
            let sorted = samples.sorted { brightness($0) < brightness($1) }
            let third = max(1, sorted.count / 3)
            return [average(Array(sorted.prefix(third))), average(Array(sorted.suffix(third)))]
        }

        private func average(_ values: [RGB]) -> RGB {
            guard !values.isEmpty else { return background }
            return RGB(r: values.reduce(0) { $0 + $1.r } / values.count,
                       g: values.reduce(0) { $0 + $1.g } / values.count,
                       b: values.reduce(0) { $0 + $1.b } / values.count)
        }

        private func brightness(_ value: RGB) -> Int { value.r + value.g + value.b }
        private func distanceSquared(_ a: RGB, _ b: RGB) -> Int {
            let dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b
            return dr * dr + dg * dg + db * db
        }

        private func mainContentRect(_ bytes: [UInt8], width w: Int, height h: Int) -> (x: Int, y: Int, width: Int, height: Int)? {
            var minX = w, minY = h, maxX = -1, maxY = -1
            for y in 0..<h {
                for x in 0..<w where bytes[(y * w + x) * 4 + 3] > 24 {
                    minX = min(minX, x); minY = min(minY, y)
                    maxX = max(maxX, x); maxY = max(maxY, y)
                }
            }
            guard maxX >= minX, maxY >= minY else { return nil }
            return (minX, minY, maxX - minX + 1, maxY - minY + 1)
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
              let buffer = PixelBuffer(image: image),
              let spec = sheetSpec(for: species) else { return nil }

        var mapped: [HaloPetPose: CGImage] = [:]
        var ordered: [(HaloPetPose, CGImage)] = []
        for crop in spec.crops {
            guard let sprite = buffer.extractedSprite(rect: crop.rect, referenceSize: spec.referenceSize) else { continue }
            mapped[crop.pose] = sprite
            ordered.append((crop.pose, sprite))
        }
        guard !ordered.isEmpty else { return nil }
        return HaloPetAssetManifest(species: species,
                                    resourceName: resourceName,
                                    columns: 0,
                                    rows: 0,
                                    detectedAssetCount: mapped.count,
                                    assets: mapped,
                                    orderedAssets: ordered)
    }

    private static func c(_ pose: HaloPetPose, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CropSpec {
        CropSpec(pose: pose, rect: CGRect(x: x, y: y, width: w, height: h))
    }

    private static func sheetSpec(for species: String) -> SheetSpec? {
        switch species.lowercased() {
        case "cat":
            // Cat.png · 1697×927 · unlabelled canonical art supplied by the user.
            return SheetSpec(referenceSize: CGSize(width: 1697, height: 927), crops: [
                c(.idle, 62, 45, 165, 255),
                c(.sitting, 820, 58, 155, 240),
                c(.standing, 975, 62, 235, 235),
                c(.walking, 1185, 55, 270, 245),
                c(.lying, 1430, 145, 260, 145),
                c(.sleeping, 735, 374, 215, 155),
                c(.stretching, 950, 330, 240, 215),
                c(.grooming, 1215, 335, 205, 210),
                c(.lookingAround, 1450, 325, 195, 225),
                c(.peekBottom, 75, 555, 180, 115),
                c(.peekLeft, 300, 550, 155, 135),
                c(.peekRight, 525, 545, 150, 140),
                c(.pawsOnEdge, 900, 545, 195, 135),
                c(.headOnEdge, 1145, 550, 215, 125),
                c(.hiddenPeek, 1450, 550, 205, 125),
                c(.playful, 28, 690, 300, 220),
                c(.curious, 340, 680, 175, 225),
                c(.tired, 545, 720, 260, 175),
                c(.happy, 805, 690, 220, 215),
                c(.excited, 1010, 680, 200, 225),
                c(.dance, 1010, 680, 200, 225),
                c(.working, 1220, 690, 275, 220),
                c(.umbrella, 1490, 675, 200, 240)
            ])

        case "dog":
            // Dog.jpg · 2048×1117 · crop bottoms stop above every baked label.
            return SheetSpec(referenceSize: CGSize(width: 2048, height: 1117), crops: [
                c(.idle, 1000, 55, 175, 245),
                c(.sitting, 1000, 55, 175, 245),
                c(.standing, 1190, 55, 235, 245),
                c(.walking, 1450, 52, 285, 250),
                c(.lying, 1740, 125, 300, 170),
                c(.sleeping, 925, 420, 230, 160),
                c(.stretching, 1180, 350, 265, 235),
                c(.grooming, 1495, 382, 225, 200),
                c(.lookingAround, 1785, 370, 205, 215),
                c(.peekBottom, 92, 905, 215, 145),
                c(.peekLeft, 435, 895, 120, 165),
                c(.peekRight, 700, 895, 115, 165),
                c(.pawsOnEdge, 1000, 900, 180, 160),
                c(.headOnEdge, 1260, 920, 180, 120),
                c(.hiddenPeek, 1560, 925, 185, 120),
                c(.playful, 45, 640, 320, 175),
                c(.curious, 425, 625, 165, 190),
                c(.tired, 620, 680, 285, 135),
                c(.happy, 915, 660, 225, 155),
                c(.excited, 1160, 650, 180, 165),
                c(.dance, 1360, 635, 165, 185),
                c(.working, 1540, 655, 230, 165),
                c(.coffee, 1785, 655, 255, 165),
                c(.umbrella, 1840, 870, 190, 220)
            ])

        case "fox":
            // Fox.jpg · 2048×1117 · explicit crops preserve the richer fox-only expressions.
            return SheetSpec(referenceSize: CGSize(width: 2048, height: 1117), crops: [
                c(.idle, 1000, 50, 180, 250),
                c(.sitting, 1000, 50, 180, 250),
                c(.standing, 1185, 50, 265, 245),
                c(.walking, 1450, 55, 285, 245),
                c(.lying, 1740, 120, 300, 175),
                c(.sleeping, 915, 410, 250, 175),
                c(.stretching, 1170, 335, 220, 250),
                c(.lookingAround, 1785, 375, 190, 210),
                c(.peekBottom, 315, 430, 190, 125),
                c(.peekLeft, 580, 405, 130, 165),
                c(.peekRight, 785, 405, 130, 165),
                c(.pawsOnEdge, 1370, 430, 170, 125),
                c(.headOnEdge, 1370, 430, 170, 125),
                c(.hiddenPeek, 78, 425, 180, 130),
                c(.playful, 340, 655, 205, 160),
                c(.curious, 55, 645, 160, 170),
                c(.tired, 670, 680, 230, 135),
                c(.happy, 560, 645, 135, 170),
                c(.excited, 1390, 930, 95, 120),
                c(.dance, 480, 890, 135, 190),
                c(.working, 1420, 655, 205, 165),
                c(.coffee, 1850, 650, 185, 170),
                c(.umbrella, 785, 885, 135, 205)
            ])
        default:
            return nil
        }
    }
}'''

text = text[:start] + replacement + text[end:]

text = text.replace(
'''        case .greet, .celebrate, .affectionate, .excited, .happy: return .happy
''',
'''        case .greet, .affectionate, .happy: return .happy
        case .celebrate, .excited: return .excited
''')
text = text.replace('''        case .coffee, .working: return .working
''', '''        case .coffee: return .coffee
        case .working: return .working
''')

# DEBUG copy no longer describes a synthetic grid.
text = text.replace(
'''                    Text("\\(manifest.resourceName) · detected \\(manifest.detectedAssetCount) · grid \\(manifest.columns)×\\(manifest.rows) · mapped \\(manifest.assets.count)")
''',
'''                    Text("\\(manifest.resourceName) · explicit pose map · mapped \\(manifest.assets.count)")
''')

path.write_text(text)
