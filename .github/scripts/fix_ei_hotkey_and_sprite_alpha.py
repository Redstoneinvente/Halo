from pathlib import Path

# 1) Fix Carbon hotkey dispatch: handlers must not consume hotkeys belonging to another Halo service.
integrations = Path('Halo/Services/Integrations.swift')
text = integrations.read_text()
old = '''            guard let event, let userData else { return noErr }
            let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
            var identifier = EventHotKeyID()
            var actualSize = 0
            let read = GetEventParameter(event,
                                         EventParamName(kEventParamDirectObject),
                                         EventParamType(typeEventHotKeyID),
                                         nil,
                                         MemoryLayout<EventHotKeyID>.size,
                                         &actualSize,
                                         &identifier)
            guard read == noErr, identifier.id == service.identifierID else { return noErr }
            let name = service.notificationName
            DispatchQueue.main.async { NotificationCenter.default.post(name: name, object: nil) }
            return noErr
'''
new = '''            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
            var identifier = EventHotKeyID()
            var actualSize = 0
            let read = GetEventParameter(event,
                                         EventParamName(kEventParamDirectObject),
                                         EventParamType(typeEventHotKeyID),
                                         nil,
                                         MemoryLayout<EventHotKeyID>.size,
                                         &actualSize,
                                         &identifier)
            // Multiple Halo shortcuts install handlers on the same application event target.
            // Returning noErr for somebody else's ID swallows the event before the owner sees it.
            guard read == noErr else { return OSStatus(eventNotHandledErr) }
            guard identifier.signature == 0x48414C4F, identifier.id == service.identifierID else {
                return OSStatus(eventNotHandledErr)
            }
            let name = service.notificationName
            DispatchQueue.main.async { NotificationCenter.default.post(name: name, object: nil) }
            return noErr
'''
if old not in text:
    raise SystemExit('Hotkey callback block not found')
integrations.write_text(text.replace(old, new, 1))

# 2) Replace fragile two-colour checker removal with connected neutral-checker segmentation.
companion = Path('Halo/Views/CompanionSprite.swift')
text = companion.read_text()
start = text.index('        private func removeCheckerboardBackground(')
end = text.index('        private func rgb(', start)
replacement = r'''        private func removeCheckerboardBackground(_ bytes: inout [UInt8], width w: Int, height h: Int) {
            guard w > 2, h > 2 else { return }

            // All supplied source sheets contain a *baked* grey checkerboard (including Cat.png;
            // its alpha channel is fully opaque). JPEG compression also creates many shades around
            // the nominal two checker tones, so exact two-colour matching leaves ugly squares.
            // Instead learn the neutral luminance range from the crop border, then remove only the
            // connected neutral field. The pet's outline acts as a hard boundary, protecting pale fur.
            var border: [RGB] = []
            let step = max(1, min(w, h) / 48)
            for x in stride(from: 0, to: w, by: step) {
                border.append(rgb(bytes, width: w, x: x, y: 0))
                border.append(rgb(bytes, width: w, x: x, y: h - 1))
            }
            for y in stride(from: 0, to: h, by: step) {
                border.append(rgb(bytes, width: w, x: 0, y: y))
                border.append(rgb(bytes, width: w, x: w - 1, y: y))
            }

            let neutralBorder = border.filter { chroma($0) <= 28 }
            let luminances = neutralBorder.map(luma).sorted()
            let low: Double
            let high: Double
            if luminances.count >= 8 {
                let p08 = luminances[Int(Double(luminances.count - 1) * 0.08)]
                let p92 = luminances[Int(Double(luminances.count - 1) * 0.92)]
                low = max(105, p08 - 24)
                high = min(238, p92 + 24)
            } else {
                low = 120
                high = 230
            }

            // Keep sampled tone centres as an additional JPEG-safe test, but don't depend on them.
            let tones = checkerTones(neutralBorder.isEmpty ? border : neutralBorder)
            func isBackground(_ index: Int) -> Bool {
                let p = index * 4
                let value = RGB(r: Int(bytes[p]), g: Int(bytes[p + 1]), b: Int(bytes[p + 2]))
                let lum = luma(value)
                let neutralChecker = chroma(value) <= 30 && lum >= low && lum <= high
                let nearLearnedTone = tones.contains { distanceSquared(value, $0) <= 52 * 52 }
                return neutralChecker || nearLearnedTone
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

            for i in 0..<(w * h) where visited[i] {
                bytes[i * 4 + 3] = 0
            }

            // Remove JPEG/checker contamination at the silhouette boundary. Only neutral pixels
            // adjacent to removed background are affected; coloured fur/eyes/outlines remain intact.
            // Two passes are deliberate because JPEG ringing can be ~2 px wide at this source size.
            for _ in 0..<2 {
                var remove: [Int] = []
                for i in 0..<(w * h) where bytes[i * 4 + 3] > 0 {
                    let x = i % w, y = i / w
                    let touchesTransparent =
                        (x > 0 && bytes[(i - 1) * 4 + 3] == 0) ||
                        (x + 1 < w && bytes[(i + 1) * 4 + 3] == 0) ||
                        (y > 0 && bytes[(i - w) * 4 + 3] == 0) ||
                        (y + 1 < h && bytes[(i + w) * 4 + 3] == 0)
                    guard touchesTransparent else { continue }
                    let p = i * 4
                    let value = RGB(r: Int(bytes[p]), g: Int(bytes[p + 1]), b: Int(bytes[p + 2]))
                    let lum = luma(value)
                    if chroma(value) <= 34 && lum >= low - 10 && lum <= high + 10 {
                        remove.append(i)
                    }
                }
                if remove.isEmpty { break }
                for i in remove { bytes[i * 4 + 3] = 0 }
            }

            // A tiny alpha feather on the remaining edge avoids a cut-out look without reintroducing
            // checker colour. This affects only the immediate non-neutral silhouette boundary.
            var feather: [Int] = []
            for i in 0..<(w * h) where bytes[i * 4 + 3] > 0 {
                let x = i % w, y = i / w
                if (x > 0 && bytes[(i - 1) * 4 + 3] == 0) ||
                   (x + 1 < w && bytes[(i + 1) * 4 + 3] == 0) ||
                   (y > 0 && bytes[(i - w) * 4 + 3] == 0) ||
                   (y + 1 < h && bytes[(i + w) * 4 + 3] == 0) {
                    feather.append(i)
                }
            }
            for i in feather { bytes[i * 4 + 3] = min(bytes[i * 4 + 3], 235) }
        }

        private func chroma(_ value: RGB) -> Int {
            max(value.r, max(value.g, value.b)) - min(value.r, min(value.g, value.b))
        }

        private func luma(_ value: RGB) -> Double {
            0.2126 * Double(value.r) + 0.7152 * Double(value.g) + 0.0722 * Double(value.b)
        }

'''
text = text[:start] + replacement + text[end:]
companion.write_text(text)
