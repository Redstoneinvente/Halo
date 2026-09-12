from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one match, got {count}')
    p.write_text(text.replace(old, new, 1))


# Make the shared Drop CI background renderer available to SurfaceView.
replace_once(
    'Halo/NotchEngine/DisplayClock.swift',
    '@MainActor\nprivate struct HaloDropCIBackgroundView: View {',
    '@MainActor\nstruct HaloDropCIBackgroundView: View {',
    'background renderer visibility',
)

# The embedded layer should contain only controls/zones, not another CI background.
replace_once(
    'Halo/NotchEngine/DisplayClock.swift',
    '''            ZStack(alignment: .topLeading) {
                HaloDropCIBackgroundView(configuration: configuration)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .allowsHitTesting(false)

                LinearGradient(
                    colors: [Color.white.opacity(0.045), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .allowsHitTesting(false)

                header(configuration: configuration)
''',
    '''            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())

                header(configuration: configuration)
''',
    'embedded board background',
)

replace_once(
    'Halo/NotchEngine/DisplayClock.swift',
    '''            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
            .foregroundStyle(.white)
''',
    '''            .foregroundStyle(.white)
''',
    'embedded board outer stroke',
)

# Replace the old Drop artwork/instructions with a pure customizable background canvas.
surface = Path('Halo/Views/SurfaceView.swift')
text = surface.read_text()
start = text.find('private struct DropContextView: View {')
end = text.find('\nstruct BuiltinOrIntegrationWidget: View {', start)
if start < 0 or end < 0:
    raise SystemExit('DropContextView markers not found')

replacement = r'''private struct DropContextView: View {
    let itemCount: Int
    @ObservedObject var surfaceState: SurfaceState
    @ObservedObject private var dropZones = HaloDropZoneSettingsStore.shared
    @AppStorage("HaloContextDropUseFullNotchArea") private var usesFullNotchArea = true
    @AppStorage("HaloContextDropKeepClosedNotchContents") private var keepsClosedNotchContents = false

    private var count: Int { max(1, itemCount) }
    private var topInset: Double {
        if usesFullNotchArea && keepsClosedNotchContents { return max(24, surfaceState.compactHeight + 14) }
        if usesFullNotchArea { return max(22, surfaceState.compactHeight * 0.72) }
        return 22
    }
    private var preferredSize: CGSize {
        let configuration = dropZones.configuration
        let count = max(1, configuration.zones.count)
        let columns: Int
        switch configuration.layout {
        case .vertical: columns = 1
        case .horizontal: columns = count
        case .twoColumns: columns = 2
        case .threeColumns: columns = 3
        case .fourColumns: columns = 4
        case .spotlight: columns = 2
        case .adaptive: columns = count <= 2 ? count : count <= 4 ? 2 : count <= 6 ? 3 : 4
        }
        let rows = max(1, Int(ceil(Double(count) / Double(max(1, columns)))))
        let width: Double
        switch configuration.layout {
        case .vertical: width = 520
        case .horizontal: width = min(760, max(560, 118 * Double(count)))
        case .spotlight: width = 680
        default: width = count >= 5 ? 680 : 600
        }
        let rowHeight = count > 4 ? 76.0 : 92.0
        let height = 112 + Double(rows) * rowHeight + Double(max(0, rows - 1)) * configuration.zoneSpacing + max(0, topInset - 22)
        return CGSize(width: width, height: min(700, max(270, height)))
    }

    var body: some View {
        HaloDropCIBackgroundView(configuration: dropZones.configuration)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: usesFullNotchArea ? 0 : 20, style: .continuous))
            .task { publishPreferredSize() }
            .onChange(of: itemCount) { _ in publishPreferredSize() }
            .onChange(of: dropZones.configuration) { _ in publishPreferredSize() }
            .onDisappear { surfaceState.contextPreferredSize = nil }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Drop CI background for \(count) item\(count == 1 ? "" : "s")")
    }

    private func publishPreferredSize() {
        let next = preferredSize
        DispatchQueue.main.async { [surfaceState] in
            if let current = surfaceState.contextPreferredSize,
               abs(current.width - next.width) < 1, abs(current.height - next.height) < 1 { return }
            surfaceState.contextPreferredSize = next
        }
    }
}
'''

surface.write_text(text[:start] + replacement + text[end:])
