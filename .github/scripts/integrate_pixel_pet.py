from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    target = Path(path)
    text = target.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 anchor, found {count}")
    target.write_text(text.replace(old, new, 1))


replace_once(
    "Halo/Core/WorkspaceModels.swift",
    "case clock, timer, shelf, media, audio, calendar, clipboard, system, launcher, activities, developer, notes, capture, stopwatch",
    "case clock, timer, shelf, media, audio, calendar, clipboard, system, launcher, activities, pet, developer, notes, capture, stopwatch",
    "ModuleID cases",
)
replace_once(
    "Halo/Core/WorkspaceModels.swift",
    "static var allCases: [ModuleID] { [.clock, .timer, .shelf, .media, .audio, .calendar, .clipboard, .system, .launcher, .activities, .notes, .capture, .stopwatch] }",
    "static var allCases: [ModuleID] { [.clock, .timer, .shelf, .media, .audio, .calendar, .clipboard, .system, .launcher, .activities, .pet, .notes, .capture, .stopwatch] }",
    "ModuleID allCases",
)
replace_once(
    "Halo/Core/WorkspaceModels.swift",
    'var title: String { rawValue == "shelf" ? "File shelf" : rawValue.capitalized }',
    'var title: String { rawValue == "shelf" ? "File shelf" : (self == .pet ? "Halo Pet" : rawValue.capitalized) }',
    "ModuleID title",
)
replace_once(
    "Halo/Core/WorkspaceModels.swift",
    'case .developer: return "chevron.left.forwardslash.chevron.right"',
    'case .pet: return "pawprint.fill"\n        case .developer: return "chevron.left.forwardslash.chevron.right"',
    "ModuleID symbol",
)
replace_once(
    "Halo/Core/WorkspaceModels.swift",
    "if id == .clock { style.fontSize = 30; style.fontFamily = .rounded; style.weight = .light; style.showTitle = false }",
    "if id == .clock { style.fontSize = 30; style.fontFamily = .rounded; style.weight = .light; style.showTitle = false }\n        if id == .pet { style.showTitle = false }",
    "ModuleID default style",
)
replace_once(
    "Halo/Core/WorkspaceModels.swift",
    "case .media, .calendar, .system: return (3, 2)\n            case .shelf, .clipboard, .launcher, .activities, .notes: return (2, 2)",
    "case .media, .calendar, .system: return (3, 2)\n            case .pet: return (4, 2)\n            case .shelf, .clipboard, .launcher, .activities, .notes: return (2, 2)",
    "Pixel Pet default grid span",
)

replace_once(
    "Halo/Core/WidgetModels.swift",
    "case .developer:\n            return []",
    "case .pet, .developer:\n            return []",
    "widget elements",
)
replace_once(
    "Halo/Core/WidgetModels.swift",
    "case .activities, .developer: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 2, rows: 2), rich: .init(columns: 4, rows: 3))",
    "case .activities, .developer: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 2, rows: 2), rich: .init(columns: 4, rows: 3))\n        case .pet: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 4, rows: 2), rich: .init(columns: 8, rows: 4))",
    "widget size recommendation",
)
replace_once(
    "Halo/Core/WidgetModels.swift",
    "case .developer:\n            break",
    "case .pet, .developer:\n            break",
    "widget style seed",
)

replace_once(
    "Halo/Views/ModuleViews.swift",
    "        case .stopwatch:\n            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .stopwatch, store: store, workspace: workspace) }\n            else { stopwatchContent }\n        default: EmptyView()",
    "        case .stopwatch:\n            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .stopwatch, store: store, workspace: workspace) }\n            else { stopwatchContent }\n        case .pet:\n            HaloPixelPetWidget(store: store, workspace: workspace)\n        default: EmptyView()",
    "IntegrationModuleView content",
)

replace_once(
    "Halo/Views/PixelPetWidget.swift",
    "    static func resolve(store: AppStore, media: MediaService, system: SystemService, pet: HaloPixelPetStore, date: Date) -> Self {",
    "    @MainActor\n    static func resolve(store: AppStore, media: MediaService, system: SystemService, pet: HaloPixelPetStore, date: Date) -> Self {",
    "Pixel Pet context actor isolation",
)

replace_once(
    "Halo/Views/WidgetSettingsView.swift",
    "        case .developer:\n            EmptyView()\n        }\n    }\n\n    private func applyVisualPreset",
    "        case .pet, .developer:\n            EmptyView()\n        }\n    }\n\n    private func applyVisualPreset",
    "Pixel Pet widget settings exhaustiveness",
)

replace_once(
    "Halo/Views/CompanionSprite.swift",
    '''    private func club(_ size: CGSize, _ phase: Double) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(accent.opacity(0.16 + abs(sin(phase * 2.0)) * 0.14))
            .frame(width: max(28, size.width * 0.07), height: max(18, size.height * 0.10))
            .overlay(Image(systemName: "music.note").font(.system(size: 8, weight: .bold)).foregroundStyle(accent.opacity(0.8)))
            .position(x: size.width * 0.82, y: size.height * 0.55)
    }''',
    '''    private func club(_ size: CGSize, _ phase: Double) -> some View {
        let pulseOpacity: Double = 0.16 + abs(sin(phase * 2.0)) * 0.14
        let clubWidth: CGFloat = max(28, size.width * 0.07)
        let clubHeight: CGFloat = max(18, size.height * 0.10)
        let note = Image(systemName: "music.note")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(accent.opacity(0.8))
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(accent.opacity(pulseOpacity))
            .frame(width: clubWidth, height: clubHeight)
            .overlay(note)
            .position(x: size.width * 0.82, y: size.height * 0.55)
    }''',
    "CompanionSprite club type-check complexity",
)

project_path = Path("Halo.xcodeproj/project.pbxproj")
project = project_path.read_text()
build_id = "A11C0F1A0000000000000371"
ref_id = "A11C0F1A0000000000000372"
anchors = [
    (
        "\t\t0000000000000000000002E4 /* Views/CompanionSprite.swift in Sources */ = {isa = PBXBuildFile; fileRef = 0000000000000000000002E5 /* Views/CompanionSprite.swift */; };",
        "\t\t0000000000000000000002E4 /* Views/CompanionSprite.swift in Sources */ = {isa = PBXBuildFile; fileRef = 0000000000000000000002E5 /* Views/CompanionSprite.swift */; };\n\t\t" + build_id + " /* Views/PixelPetWidget.swift in Sources */ = {isa = PBXBuildFile; fileRef = " + ref_id + " /* Views/PixelPetWidget.swift */; };",
    ),
    (
        "\t\t0000000000000000000002E5 /* Views/CompanionSprite.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Views/CompanionSprite.swift; sourceTree = \"<group>\"; };",
        "\t\t0000000000000000000002E5 /* Views/CompanionSprite.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Views/CompanionSprite.swift; sourceTree = \"<group>\"; };\n\t\t" + ref_id + " /* Views/PixelPetWidget.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Views/PixelPetWidget.swift; sourceTree = \"<group>\"; };",
    ),
    (
        "\t\t\t\t0000000000000000000002E5 /* Views/CompanionSprite.swift */,",
        "\t\t\t\t0000000000000000000002E5 /* Views/CompanionSprite.swift */,\n\t\t\t\t" + ref_id + " /* Views/PixelPetWidget.swift */,",
    ),
    (
        "\t\t\t\t0000000000000000000002E4 /* Views/CompanionSprite.swift in Sources */,",
        "\t\t\t\t0000000000000000000002E4 /* Views/CompanionSprite.swift in Sources */,\n\t\t\t\t" + build_id + " /* Views/PixelPetWidget.swift in Sources */,",
    ),
]
for old, new in anchors:
    if project.count(old) != 1:
        raise SystemExit(f"Xcode project anchor expected once, found {project.count(old)}")
    project = project.replace(old, new, 1)
project_path.write_text(project)
