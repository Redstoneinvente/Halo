import SwiftUI
import AppKit

@MainActor enum GeometryPreview {
    static func update(expanded: Bool, editing: Bool, display: NSScreen? = nil) {
        var info: [String: Any] = ["expanded": expanded, "editing": editing]
        if let display { info["display"] = WindowManager.displayID(display) }
        NotificationCenter.default.post(name: .init("HaloGeometryPreview"), object: nil, userInfo: info)
    }
}

struct HaloContour: Shape {
    var kind: SurfaceShapeKind
    var radius: CGFloat
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var shoulder: CGFloat
    func path(in rect: CGRect) -> Path {
        let r = min(max(0, radius), min(rect.width, rect.height) / 2)
        switch kind {
        case .rounded: return RoundedRectangle(cornerRadius: r).path(in: rect)
        case .capsule: return Capsule().path(in: rect)
        case .squircle: return RoundedRectangle(cornerRadius: min(rect.width, rect.height) * 0.4, style: .continuous).path(in: rect)
        case .asymmetric: return corners(in: rect, top: topRadius, bottom: bottomRadius)
        case .notch: return corners(in: rect, top: min(4, r), bottom: r)
        case .scoop:
            let s = min(shoulder, min(rect.width / 4, rect.height / 2))
            let bottom = min(r, min((rect.width - 2 * s) / 2, (rect.height - s) / 2))
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - s, y: rect.minY + s), control: CGPoint(x: rect.maxX - s, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - s, y: rect.maxY - bottom))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - s - bottom, y: rect.maxY), control: CGPoint(x: rect.maxX - s, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + s + bottom, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.minX + s, y: rect.maxY - bottom), control: CGPoint(x: rect.minX + s, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + s, y: rect.minY + s))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.minX + s, y: rect.minY))
            p.closeSubpath(); return p
        case .chamfer, .tapered:
            let s = min(max(0, shoulder), min(rect.width / 4, rect.height / 2))
            let points: [CGPoint] = kind == .tapered ? [
                CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX - s, y: rect.maxY), CGPoint(x: rect.minX + s, y: rect.maxY)
            ] : [
                CGPoint(x: rect.minX + s, y: rect.minY), CGPoint(x: rect.maxX - s, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY + s), CGPoint(x: rect.maxX, y: rect.maxY - s),
                CGPoint(x: rect.maxX - s, y: rect.maxY), CGPoint(x: rect.minX + s, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY - s), CGPoint(x: rect.minX, y: rect.minY + s)
            ]
            var p = Path(); p.addLines(points); p.closeSubpath(); return p
        }
    }
    private func corners(in rect: CGRect, top: CGFloat, bottom: CGFloat) -> Path {
        let t = min(max(0, top), min(rect.width, rect.height) / 2)
        let b = min(max(0, bottom), min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + t), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - b))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - b, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + b, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - b), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + t))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath(); return p
    }
}

@MainActor struct SurfaceAppearanceControls: View {
    @Binding var appearance: Appearance
    let theme: Theme
    var screen: NSScreen?
    var body: some View {
        Section("Closed size") {
            HStack { Text("Width"); Spacer(); Text("\(Int(appearance.compactWidth)) pt").monospacedDigit() }
            Slider(value: $appearance.compactWidth, in: 16...640, step: 1, onEditingChanged: { GeometryPreview.update(expanded: false, editing: $0, display: screen) }).accessibilityLabel("Closed width")
            HStack { Text("Height"); Spacer(); Text("\(Int(appearance.surface.compactHeight)) pt").monospacedDigit() }
            Slider(value: $appearance.surface.compactHeight, in: 16...100, step: 1, onEditingChanged: { GeometryPreview.update(expanded: false, editing: $0, display: screen) }).accessibilityLabel("Closed height")
            if let screen {
                let geometry = WindowManager.geometry(screen: screen, theme: theme, appearance: appearance)
                Text("Effective closed size: \(Int(geometry.compactWidth)) × \(Int(geometry.compactHeight)) pt.").font(.caption)
                if geometry.attachedToNotch {
                    Text("16 × 16 pt is allowed. The physical camera cutout stays unchanged; a positive vertical offset moves Halo below it.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        Section("Position offsets") {
            Text("Positive X moves right; positive Y moves down. Each state has independent offsets.").font(.caption)
            offsetControl("Opened X", key: \.openedX, expanded: true)
            offsetControl("Opened Y", key: \.openedY, expanded: true)
            offsetControl("Closed X", key: \.closedX, expanded: false)
            offsetControl("Closed Y", key: \.closedY, expanded: false)
            Button("Reset offsets") { appearance.surface.offsets = SurfaceOffsets() }
        }
        Section("Shape") {
            Picker("Contour", selection: $appearance.surface.shape) { ForEach(SurfaceShapeKind.allCases) { Text($0.rawValue).tag($0) } }
            if appearance.surface.shape == .asymmetric {
                Slider(value: $appearance.surface.topRadius, in: 0...64) { Text("Top corners") }
                Slider(value: $appearance.surface.bottomRadius, in: 0...64) { Text("Bottom corners") }
            }
            if [.scoop, .chamfer, .tapered].contains(appearance.surface.shape) {
                Slider(value: $appearance.surface.shoulder, in: 0...48) { Text("Shoulder / cut depth") }
            }
            HaloContour(kind: appearance.surface.shape, radius: theme.cornerRadius, topRadius: appearance.surface.topRadius,
                        bottomRadius: appearance.surface.bottomRadius, shoulder: appearance.surface.shoulder)
                .fill(Color(hue: theme.tint, saturation: 0.6, brightness: 0.5)).frame(height: 80)
                .accessibilityLabel("\(appearance.surface.shape.rawValue) preview")
        }
        Section("Transitions") {
            Picker("Opening", selection: $appearance.surface.opening) { ForEach(SurfaceTransition.allCases) { Text($0.rawValue).tag($0) } }
            Picker("Closing", selection: $appearance.surface.closing) { ForEach(SurfaceTransition.allCases) { Text($0.rawValue).tag($0) } }
            HStack { Text("Duration"); Spacer(); Text(String(format: "%.2f s", appearance.surface.duration)).monospacedDigit() }
            Slider(value: $appearance.surface.duration, in: 0.1...1.2, step: 0.05).accessibilityLabel("Transition duration")
            if appearance.surface.opening == .spring || appearance.surface.closing == .spring {
                Slider(value: $appearance.surface.damping, in: 0.4...1) { Text("Spring damping") }
                Text("Lower damping adds bounce; higher damping settles sooner.").font(.caption)
            }
            Text("Reduce Motion and the animation-off setting make transitions immediate.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func offsetControl(_ title: String, key: WritableKeyPath<SurfaceOffsets, Double>, expanded: Bool) -> some View {
        let value = Binding<Double>(get: { (appearance.surface.offsets ?? SurfaceOffsets())[keyPath: key] }, set: {
            var offsets = appearance.surface.offsets ?? SurfaceOffsets(); offsets[keyPath: key] = $0; appearance.surface.offsets = offsets
        })
        return VStack(alignment: .leading) {
            HStack { Text(title); Spacer(); Text("\(Int(value.wrappedValue)) pt").monospacedDigit() }
            Slider(value: value, in: -1000...1000, step: 1, onEditingChanged: { GeometryPreview.update(expanded: expanded, editing: $0, display: screen) }).accessibilityLabel(title)
        }
    }
}
