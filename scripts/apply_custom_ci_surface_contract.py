from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"Missing anchor in {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1))

# ---- WorkspaceModels.swift: public Custom CI surface contract ----
path = "Halo/Core/WorkspaceModels.swift"
insert_before = "struct HaloCIManifest: Codable, Equatable {\n"
contract = r'''struct HaloCISizeRule: Codable, Equatable {
    var width: Double?
    var height: Double?
    var minWidth: Double?
    var preferredWidth: Double?
    var maxWidth: Double?
    var minHeight: Double?
    var preferredHeight: Double?
    var maxHeight: Double?

    init(width: Double? = nil, height: Double? = nil,
         minWidth: Double? = nil, preferredWidth: Double? = nil, maxWidth: Double? = nil,
         minHeight: Double? = nil, preferredHeight: Double? = nil, maxHeight: Double? = nil) {
        self.width = width; self.height = height
        self.minWidth = minWidth; self.preferredWidth = preferredWidth; self.maxWidth = maxWidth
        self.minHeight = minHeight; self.preferredHeight = preferredHeight; self.maxHeight = maxHeight
    }
}

struct HaloCISurfaceSizing: Codable, Equatable {
    /// `static` means exact declared dimensions. `dynamic` means Halo measures the rendered
    /// declarative tree and clamps it to the declared min/preferred/max bounds.
    var mode: String
    var closed: HaloCISizeRule?
    var expanded: HaloCISizeRule
}

struct HaloCIBackgroundStyle: Codable, Equatable {
    /// solid, gradient, glass, or clear
    var type: String
    var color: String?
    var secondaryColor: String?
    var opacity: Double?
    var blur: Double?

    init(type: String = "solid", color: String? = "#101014", secondaryColor: String? = nil,
         opacity: Double? = 1, blur: Double? = 0) {
        self.type = type; self.color = color; self.secondaryColor = secondaryColor
        self.opacity = opacity; self.blur = blur
    }
}

struct HaloCIBackgroundContract: Codable, Equatable {
    var closed: HaloCIBackgroundStyle?
    var expanded: HaloCIBackgroundStyle
}

struct HaloCISurfaceContract: Codable, Equatable {
    var sizing: HaloCISurfaceSizing
    var background: HaloCIBackgroundContract

    static let safeDefault = HaloCISurfaceContract(
        sizing: HaloCISurfaceSizing(
            mode: "static",
            closed: HaloCISizeRule(width: 190, height: 40),
            expanded: HaloCISizeRule(width: 560, height: 260)
        ),
        background: HaloCIBackgroundContract(
            closed: HaloCIBackgroundStyle(type: "solid", color: "#101014"),
            expanded: HaloCIBackgroundStyle(type: "solid", color: "#101014")
        )
    )
}

'''
replace_once(path, insert_before, contract + insert_before)

replace_once(path,
'''    var capabilities: [String]
    var supportedSurfaces: [String]
    var supportedStates: [String]
''',
'''    var capabilities: [String]
    var supportedSurfaces: [String]
    var supportedStates: [String]
    var surface: HaloCISurfaceContract
''')

replace_once(path,
'''         permissions: [String] = [], capabilities: [String] = [],
         supportedSurfaces: [String] = ["notch"], supportedStates: [String] = ["closed", "expanded"]) {
''',
'''         permissions: [String] = [], capabilities: [String] = [],
         supportedSurfaces: [String] = ["notch"], supportedStates: [String] = ["closed", "expanded"],
         surface: HaloCISurfaceContract = .safeDefault) {
''')
replace_once(path,
'''        self.capabilities = capabilities; self.supportedSurfaces = supportedSurfaces; self.supportedStates = supportedStates
''',
'''        self.capabilities = capabilities; self.supportedSurfaces = supportedSurfaces; self.supportedStates = supportedStates
        self.surface = surface
''')
replace_once(path,
'''             description, permissions, capabilities, supportedSurfaces, supportedStates
''',
'''             description, permissions, capabilities, supportedSurfaces, supportedStates, surface
''')
replace_once(path,
'''        supportedStates = try c.decodeIfPresent([String].self, forKey: .supportedStates) ?? ["expanded"]
''',
'''        supportedStates = try c.decodeIfPresent([String].self, forKey: .supportedStates) ?? ["expanded"]
        surface = try c.decodeIfPresent(HaloCISurfaceContract.self, forKey: .surface) ?? .safeDefault
''')

replace_once(path,
'''        "entryInterface", "description", "permissions", "capabilities", "supportedSurfaces", "supportedStates"
    ]
''',
'''        "entryInterface", "description", "permissions", "capabilities", "supportedSurfaces", "supportedStates", "surface"
    ]
    private static let surfaceKeys: Set<String> = ["sizing", "background"]
    private static let sizingKeys: Set<String> = ["mode", "closed", "expanded"]
    private static let sizeRuleKeys: Set<String> = [
        "width", "height", "minWidth", "preferredWidth", "maxWidth",
        "minHeight", "preferredHeight", "maxHeight"
    ]
    private static let backgroundKeys: Set<String> = ["closed", "expanded"]
    private static let backgroundStyleKeys: Set<String> = ["type", "color", "secondaryColor", "opacity", "blur"]
''')

replace_once(path,
'''        validateManifest(manifest, issues: &issues)

        guard safeRelativePath(manifest.entryInterface) else {
''',
'''        validateManifest(manifest, issues: &issues)
        if let surfaceObject = manifestObject["surface"] as? [String: Any] {
            validateSurfaceRaw(surfaceObject, manifest: manifest, issues: &issues)
        } else {
            issues.append(.init(.error, "manifest.json.surface", "Every Custom CI must declare its notch sizing and background contract."))
        }

        guard safeRelativePath(manifest.entryInterface) else {
''')

anchor = '''    private static func validateManifest(_ manifest: HaloCIManifest, issues: inout [HaloCIValidationIssue]) {
'''
validation = r'''    private static func validateSurfaceRaw(_ object: [String: Any], manifest: HaloCIManifest,
                                           issues: inout [HaloCIValidationIssue]) {
        rejectUnknownKeys(in: object, allowed: surfaceKeys, path: "manifest.json.surface", issues: &issues)
        guard let sizing = object["sizing"] as? [String: Any] else {
            issues.append(.init(.error, "manifest.json.surface.sizing", "sizing is required.")); return
        }
        rejectUnknownKeys(in: sizing, allowed: sizingKeys, path: "manifest.json.surface.sizing", issues: &issues)
        let mode = sizing["mode"] as? String ?? ""
        guard ["static", "dynamic"].contains(mode) else {
            issues.append(.init(.error, "manifest.json.surface.sizing.mode", "Sizing mode must be static or dynamic.")); return
        }

        func validateRule(_ raw: Any?, state: String, required: Bool) {
            let path = "manifest.json.surface.sizing.\(state)"
            guard let rule = raw as? [String: Any] else {
                if required { issues.append(.init(.error, path, "A \(state) size contract is required.")) }
                return
            }
            rejectUnknownKeys(in: rule, allowed: sizeRuleKeys, path: path, issues: &issues)
            let closed = state == "closed"
            let widthRange: ClosedRange<Double> = closed ? 48...720 : 160...1100
            let heightRange: ClosedRange<Double> = closed ? 16...160 : 96...820
            func checked(_ key: String, range: ClosedRange<Double>) -> Double? {
                guard let value = number(rule[key]), value.isFinite, range.contains(value) else {
                    issues.append(.init(.error, path + "." + key, "Missing or outside the supported \(state) size range.")); return nil
                }
                return value
            }
            if mode == "static" {
                _ = checked("width", range: widthRange); _ = checked("height", range: heightRange)
                for key in ["minWidth", "preferredWidth", "maxWidth", "minHeight", "preferredHeight", "maxHeight"] where rule[key] != nil {
                    issues.append(.init(.error, path + "." + key, "Dynamic bounds are not allowed when sizing.mode is static."))
                }
            } else {
                if rule["width"] != nil || rule["height"] != nil {
                    issues.append(.init(.error, path, "Dynamic sizing uses min/preferred/max bounds instead of width/height."))
                }
                let minW = checked("minWidth", range: widthRange), prefW = checked("preferredWidth", range: widthRange), maxW = checked("maxWidth", range: widthRange)
                let minH = checked("minHeight", range: heightRange), prefH = checked("preferredHeight", range: heightRange), maxH = checked("maxHeight", range: heightRange)
                if let minW, let prefW, let maxW, !(minW <= prefW && prefW <= maxW) { issues.append(.init(.error, path, "Width bounds must satisfy minWidth <= preferredWidth <= maxWidth.")) }
                if let minH, let prefH, let maxH, !(minH <= prefH && prefH <= maxH) { issues.append(.init(.error, path, "Height bounds must satisfy minHeight <= preferredHeight <= maxHeight.")) }
            }
        }
        let states = Set(manifest.supportedStates)
        validateRule(sizing["expanded"], state: "expanded", required: true)
        validateRule(sizing["closed"], state: "closed", required: states.contains("closed"))

        guard let background = object["background"] as? [String: Any] else {
            issues.append(.init(.error, "manifest.json.surface.background", "Every Custom CI must own its background.")); return
        }
        rejectUnknownKeys(in: background, allowed: backgroundKeys, path: "manifest.json.surface.background", issues: &issues)
        func validateBackground(_ raw: Any?, state: String, required: Bool) {
            let path = "manifest.json.surface.background.\(state)"
            guard let style = raw as? [String: Any] else {
                if required { issues.append(.init(.error, path, "A \(state) background is required.")) }
                return
            }
            rejectUnknownKeys(in: style, allowed: backgroundStyleKeys, path: path, issues: &issues)
            guard let type = style["type"] as? String, ["solid", "gradient", "glass", "clear"].contains(type) else {
                issues.append(.init(.error, path + ".type", "Background type must be solid, gradient, glass, or clear.")); return
            }
            if let opacity = number(style["opacity"]), !(0...1).contains(opacity) { issues.append(.init(.error, path + ".opacity", "Opacity must be 0...1.")) }
            if let blur = number(style["blur"]), !(0...40).contains(blur) { issues.append(.init(.error, path + ".blur", "Blur must be 0...40.")) }
            func validColor(_ key: String, required: Bool) {
                guard let raw = style[key] as? String else { if required { issues.append(.init(.error, path + "." + key, "A color is required.")) }; return }
                let named = ["accent", "white", "black", "clear", "secondary", "green", "orange", "red", "blue"].contains(raw.lowercased())
                let hex = matches(raw, #"^#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?$"#)
                if !named && !hex { issues.append(.init(.error, path + "." + key, "Use a supported named color or #RRGGBB/#RRGGBBAA.")) }
            }
            validColor("color", required: type == "solid" || type == "gradient" || type == "glass")
            validColor("secondaryColor", required: type == "gradient")
        }
        validateBackground(background["expanded"], state: "expanded", required: true)
        validateBackground(background["closed"], state: "closed", required: states.contains("closed"))
    }

'''
replace_once(path, anchor, validation + anchor)

# ---- WorkspaceStore.swift: priority-gated arbitration ----
path = "Halo/Core/WorkspaceStore.swift"
old = r'''    func activeCandidate(workspace: WorkspaceStore, globalDisabled: Bool) -> HaloCustomCICandidate? {
        guard !globalDisabled else { return nil }
        if let id = manualActivationID, let package = package(id: id), isEnabled(id) {
            return HaloCustomCICandidate(package: package, priority: 1001, manual: true)
        }
        let snapshot = triggerSnapshot(workspace: workspace)
        return packages.filter { package in
            let id = package.manifest.id
            return isEnabled(id) && !suppressedPackageIDs.contains(id) &&
                HaloCITriggerEvaluator.matches(package.triggers, snapshot: snapshot, grantedPermissions: grantedPermissions(id))
        }.map { HaloCustomCICandidate(package: $0, priority: priority($0.manifest.id), manual: false) }
         .max { lhs, rhs in lhs.priority == rhs.priority ? lhs.package.manifest.id > rhs.package.manifest.id : lhs.priority < rhs.priority }
    }
'''
new = r'''    func activeCandidate(workspace: WorkspaceStore, globalDisabled: Bool,
                         blockingPriority: Double? = nil) -> HaloCustomCICandidate? {
        guard !globalDisabled else { return nil }
        let floor = blockingPriority ?? -Double.infinity
        let snapshot = triggerSnapshot(workspace: workspace)
        let ordered = packages.filter { package in
            let id = package.manifest.id
            return isEnabled(id) && priority(id) >= floor &&
                (!suppressedPackageIDs.contains(id) || manualActivationID == id)
        }.sorted { lhs, rhs in
            let lp = priority(lhs.manifest.id), rp = priority(rhs.manifest.id)
            if lp != rp { return lp > rp }
            let lm = manualActivationID == lhs.manifest.id, rm = manualActivationID == rhs.manifest.id
            if lm != rm { return lm }
            return lhs.manifest.id < rhs.manifest.id
        }

        // Arbitration happens before trigger evaluation. Once a higher-priority package
        // claims the surface, lower-priority packages are not evaluated at all.
        for package in ordered {
            let id = package.manifest.id
            if manualActivationID == id {
                return HaloCustomCICandidate(package: package, priority: priority(id), manual: true)
            }
            if HaloCITriggerEvaluator.matches(package.triggers, snapshot: snapshot,
                                              grantedPermissions: grantedPermissions(id)) {
                return HaloCustomCICandidate(package: package, priority: priority(id), manual: false)
            }
        }
        return nil
    }
'''
replace_once(path, old, new)

# ---- WindowManager.swift: closed Custom CI height is authoritative too ----
path = "Halo/NotchEngine/WindowManager.swift"
replace_once(path,
'''    @Published var contextPreferredSize: CGSize?
    @Published var contextPreferredCompactWidth: CGFloat?
    @Published var contextMinimumExpandedWidth: CGFloat?
''',
'''    @Published var contextPreferredSize: CGSize?
    @Published var contextPreferredCompactWidth: CGFloat?
    @Published var contextPreferredCompactHeight: CGFloat?
    @Published var contextMinimumExpandedWidth: CGFloat?
''')
replace_once(path,
'''        var contextSizeSubscription: AnyCancellable?
        var contextCompactSizeSubscription: AnyCancellable?
''',
'''        var contextSizeSubscription: AnyCancellable?
        var contextCompactSizeSubscription: AnyCancellable?
        var contextCompactHeightSubscription: AnyCancellable?
''')
replace_once(path,
'''            subscription?.cancel(); contextSizeSubscription?.cancel(); contextCompactSizeSubscription?.cancel(); panel.close(); ambientPanel.close()
''',
'''            subscription?.cancel(); contextSizeSubscription?.cancel(); contextCompactSizeSubscription?.cancel(); contextCompactHeightSubscription?.cancel(); panel.close(); ambientPanel.close()
''')
replace_once(path,
'''    private func adjustedClosedFrame(host: Host, requestedWidth: CGFloat?) -> CGRect {
        guard let geometry = host.geometry else { return .zero }
        let base = geometry.frame(expanded: false)
        guard let requestedWidth, requestedWidth.isFinite else { return base }

        let margin: CGFloat = 8
        let physicalFloor = geometry.attachedToNotch && geometry.physicalNotchWidth > 0
            ? geometry.physicalNotchWidth + 16 : 64
        let maximum = max(physicalFloor, geometry.visible.width - margin * 2)
        let width = min(maximum, max(physicalFloor, requestedWidth))
        var frame = CGRect(x: base.midX - width / 2, y: base.minY, width: width, height: base.height)
        if frame.minX < geometry.visible.minX + margin { frame.origin.x = geometry.visible.minX + margin }
        if frame.maxX > geometry.visible.maxX - margin { frame.origin.x = geometry.visible.maxX - margin - width }
        return frame
    }

    private func targetFrame(host: Host, expanded: Bool) -> CGRect {
        guard host.geometry != nil else { return .zero }
        return expanded
            ? adjustedExpandedFrame(host: host, requested: host.state.contextPreferredSize)
            : adjustedClosedFrame(host: host, requestedWidth: host.state.contextPreferredCompactWidth)
    }
''',
'''    private func adjustedClosedFrame(host: Host, requestedWidth: CGFloat?, requestedHeight: CGFloat?) -> CGRect {
        guard let geometry = host.geometry else { return .zero }
        let base = geometry.frame(expanded: false)
        guard requestedWidth != nil || requestedHeight != nil else { return base }

        let margin: CGFloat = 8
        let physicalWidthFloor = geometry.attachedToNotch && geometry.physicalNotchWidth > 0
            ? geometry.physicalNotchWidth + 16 : 48
        let physicalHeightFloor = geometry.attachedToNotch && geometry.physicalNotchHeight > 0
            ? geometry.physicalNotchHeight : 16
        let maximumWidth = max(physicalWidthFloor, geometry.visible.width - margin * 2)
        let maximumHeight = min(220, max(physicalHeightFloor, geometry.visible.height - margin * 2))
        let desiredWidth = requestedWidth?.isFinite == true ? requestedWidth! : base.width
        let desiredHeight = requestedHeight?.isFinite == true ? requestedHeight! : base.height
        let width = min(maximumWidth, max(physicalWidthFloor, desiredWidth))
        let height = min(maximumHeight, max(physicalHeightFloor, desiredHeight))
        var frame: CGRect
        if geometry.style == .bottom {
            frame = CGRect(x: base.midX - width / 2, y: base.minY, width: width, height: height)
        } else {
            frame = CGRect(x: base.midX - width / 2, y: base.maxY - height, width: width, height: height)
        }
        if geometry.style == .left { frame.origin.x = base.minX }
        if geometry.style == .right { frame.origin.x = base.maxX - width }
        if frame.minX < geometry.visible.minX + margin { frame.origin.x = geometry.visible.minX + margin }
        if frame.maxX > geometry.visible.maxX - margin { frame.origin.x = geometry.visible.maxX - margin - width }
        return frame
    }

    private func targetFrame(host: Host, expanded: Bool) -> CGRect {
        guard host.geometry != nil else { return .zero }
        return expanded
            ? adjustedExpandedFrame(host: host, requested: host.state.contextPreferredSize)
            : adjustedClosedFrame(host: host, requestedWidth: host.state.contextPreferredCompactWidth,
                                  requestedHeight: host.state.contextPreferredCompactHeight)
    }
''')

compact_subscription_anchor = '''                host.panel.orderFrontRegardless()
'''
height_subscription = r'''                host.contextCompactHeightSubscription = host.state.$contextPreferredCompactHeight.dropFirst().removeDuplicates(by: { lhs, rhs in
                    switch (lhs, rhs) {
                    case (nil, nil): return true
                    case let (a?, b?): return abs(a - b) < 1
                    default: return false
                    }
                }).receive(on: DispatchQueue.main).sink { [weak self, weak host] _ in
                    guard let self, let host, let geometry = host.geometry, !host.state.expanded else { return }
                    let target = self.targetFrame(host: host, expanded: false)
                    guard host.targetFrame != target else { return }
                    host.targetFrame = target
                    var motion = geometry.appearance.surface
                    motion.opening = .resize; motion.closing = .resize
                    motion.duration = min(0.30, max(0.14, motion.duration))
                    host.animator.move(panel: host.panel, state: host.state, target: target, options: motion,
                                       preset: .smooth, animations: host.state.theme.animations && !host.state.editingGeometry,
                                       opening: true, style: geometry.style, liveViewportResize: true,
                                       synchronizeClosedGeometry: true,
                                       closedCameraFrame: self.physicalCameraFrame(for: geometry))
                }
'''
replace_once(path, compact_subscription_anchor, height_subscription + compact_subscription_anchor)

replace_once(path,
'''            var target = geometry.frame(expanded: false)
''',
'''            var target = (host.state.contextPreferredCompactWidth != nil || host.state.contextPreferredCompactHeight != nil)
                ? targetFrame(host: host, expanded: false)
                : geometry.frame(expanded: false)
''')

# ---- SurfaceView.swift: ownership, background, size enforcement and priority gate ----
path = "Halo/Views/SurfaceView.swift"
old = r'''    private var activeCustomCandidate: HaloCustomCICandidate? {
        customCI.activeCandidate(workspace: workspace, globalDisabled: disableCustomCI)
    }
    private var activeContext: ActiveContextInterface? {
        var candidates: [(interface: ActiveContextInterface, priority: Double, tieRank: Int)] = []
        if dropCIEnabled && state.dropTargeted {
            candidates.append((.drop, dropPriority, 4))
        }
        if retroCIEnabled && retroGameRequested {
            candidates.append((.retro, retroPriority, 4))
        }
        if teleprompterCIEnabled && teleprompterActive {
            candidates.append((.teleprompter, teleprompterPriority, 3))
        }
        if transferCIEnabled && transfer.isActive {
            candidates.append((.transfer, transferPriority, 3))
        }
        if clipboardCIEnabled && clipboardCI.isActive {
            candidates.append((.clipboard, clipboardCI.manualPresentation ? 1000 : clipboardPriority, 3))
        }
        if let custom = activeCustomCandidate {
            candidates.append((.custom, custom.priority, custom.manual ? 100 : 3))
        }
        if contextOptions.enabled && workspace.media.isPlaying {
            candidates.append((.music, contextMusicPriority, 2))
        }
        if bluetoothEligible {
            candidates.append((.bluetooth, bluetoothPriority, 1))
        }
        return candidates.max { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.tieRank < rhs.tieRank
        }?.interface
    }
'''
new = r'''    private var builtInContextCandidates: [(interface: ActiveContextInterface, priority: Double, tieRank: Int)] {
        var candidates: [(interface: ActiveContextInterface, priority: Double, tieRank: Int)] = []
        if dropCIEnabled && state.dropTargeted { candidates.append((.drop, dropPriority, 4)) }
        if retroCIEnabled && retroGameRequested { candidates.append((.retro, retroPriority, 4)) }
        if teleprompterCIEnabled && teleprompterActive { candidates.append((.teleprompter, teleprompterPriority, 3)) }
        if transferCIEnabled && transfer.isActive { candidates.append((.transfer, transferPriority, 3)) }
        if clipboardCIEnabled && clipboardCI.isActive { candidates.append((.clipboard, clipboardCI.manualPresentation ? 1000 : clipboardPriority, 3)) }
        if contextOptions.enabled && workspace.media.isPlaying { candidates.append((.music, contextMusicPriority, 2)) }
        if bluetoothEligible { candidates.append((.bluetooth, bluetoothPriority, 1)) }
        return candidates
    }
    private var highestBuiltInContextPriority: Double? { builtInContextCandidates.map { $0.priority }.max() }
    private var activeCustomCandidate: HaloCustomCICandidate? {
        customCI.activeCandidate(workspace: workspace, globalDisabled: disableCustomCI,
                                 blockingPriority: highestBuiltInContextPriority)
    }
    private var activeContext: ActiveContextInterface? {
        var candidates = builtInContextCandidates
        if let custom = activeCustomCandidate { candidates.append((.custom, custom.priority, custom.manual ? 100 : 3)) }
        return candidates.max { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.tieRank < rhs.tieRank
        }?.interface
    }
'''
replace_once(path, old, new)
replace_once(path, '''        case .custom: return false
''', '''        case .custom: return true
''')

replace_once(path,
'''        .onReceive(NotificationCenter.default.publisher(for: .init("HaloCustomCIOpenRequested"))) { _ in
            guard !disableCustomCI else { return }
            state.collapseTask?.cancel()
            state.expanded = true
        }
''',
'''        .onReceive(NotificationCenter.default.publisher(for: .init("HaloCustomCIOpenRequested"))) { note in
            guard !disableCustomCI, let requestedID = note.object as? String else { return }
            guard customContextActive, activeCustomCandidate?.package.manifest.id == requestedID else {
                customCI.clearManualActivation()
                customCI.notice = "Custom CI did not open because a higher-priority CI currently owns the notch."
                return
            }
            state.collapseTask?.cancel()
            state.expanded = true
        }
''')
replace_once(path,
'''            state.contextPreferredCompactWidth = nil
            state.contextMinimumExpandedWidth = nil
''',
'''            state.contextPreferredCompactWidth = nil
            state.contextPreferredCompactHeight = nil
            state.contextMinimumExpandedWidth = nil
''')
# There is another sizing-clear block later; make it include compact height too.
replace_once(path,
'''                state.contextPreferredCompactWidth = nil
                state.contextMinimumExpandedWidth = nil
                if activeContext != nil { state.contextPreferredSize = nil }
''',
'''                state.contextPreferredCompactWidth = nil
                state.contextPreferredCompactHeight = nil
                state.contextMinimumExpandedWidth = nil
                if activeContext != nil { state.contextPreferredSize = nil }
''')

replace_once(path,
'''            if transferContextActive {
                TransferSurfaceBackground(monitor: transfer)
            } else if clipboardContextActive {
                ClipboardSurfaceBackground(monitor: clipboardCI)
            } else if state.expanded && activeContext == nil && usesVisualWorkspace {
''',
'''            if transferContextActive {
                TransferSurfaceBackground(monitor: transfer)
            } else if clipboardContextActive {
                ClipboardSurfaceBackground(monitor: clipboardCI)
            } else if customContextActive, let candidate = activeCustomCandidate {
                HaloCustomCIBackgroundView(contract: candidate.package.manifest.surface.background, expanded: state.expanded)
            } else if state.expanded && activeContext == nil && usesVisualWorkspace {
''')
replace_once(path,
'''            if !transferContextActive && !clipboardContextActive && (!state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true) {
''',
'''            if !transferContextActive && !clipboardContextActive && !customContextActive && (!state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true) {
''')

old_custom = r'''private struct HaloCustomCISurfaceView: View {
    let package: HaloCIParsedPackage
    @ObservedObject var surfaceState: SurfaceState
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject private var runtime = HaloCustomCIRuntimeStore.shared

    private var expanded: Bool { surfaceState.expanded }
    private var root: HaloCIComponent? { expanded ? package.interface.expanded : package.interface.closed }
    private var data: [String: String] { runtime.dataBus(for: package, workspace: workspace, expanded: expanded) }

    var body: some View {
        Group {
            if let root {
                HaloCustomCIComponentRenderer(package: package, workspace: workspace, runtime: runtime, data: data).render(root)
            } else {
                HStack(spacing: 7) {
                    Image(systemName: "rectangle.3.group.bubble.left.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(package.manifest.name)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { publishSizing() }
        .onChange(of: expanded) { _ in publishSizing() }
        .onChange(of: runtime.contextRevision) { _ in publishSizing() }
    }

    private func publishSizing() {
        let expandedRoot = package.interface.expanded
        let expandedWidth = min(1100, max(260, expandedRoot.width ?? 560))
        let expandedHeight = min(820, max(110, expandedRoot.height ?? 260))
        surfaceState.contextMinimumExpandedWidth = min(expandedWidth, max(220, surfaceState.physicalNotchWidth + 32))
        surfaceState.contextPreferredSize = CGSize(width: expandedWidth, height: expandedHeight)
        if let closed = package.interface.closed {
            surfaceState.contextPreferredCompactWidth = min(720, max(48, closed.width ?? max(surfaceState.physicalNotchWidth + 28, 190)))
        } else {
            surfaceState.contextPreferredCompactWidth = min(720, max(90, surfaceState.physicalNotchWidth + 28))
        }
    }
}
'''
new_custom = r'''private struct HaloCustomCIContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0 && next.height > 0 { value = next }
    }
}

private struct HaloCustomCISurfaceView: View {
    let package: HaloCIParsedPackage
    @ObservedObject var surfaceState: SurfaceState
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject private var runtime = HaloCustomCIRuntimeStore.shared
    @State private var measuredClosed: CGSize = .zero
    @State private var measuredExpanded: CGSize = .zero

    private var expanded: Bool { surfaceState.expanded }
    private var root: HaloCIComponent? { expanded ? package.interface.expanded : package.interface.closed }
    private var data: [String: String] { runtime.dataBus(for: package, workspace: workspace, expanded: expanded) }
    private var dynamicSizing: Bool { package.manifest.surface.sizing.mode == "dynamic" }

    @ViewBuilder private var renderedContent: some View {
        if let root {
            HaloCustomCIComponentRenderer(package: package, workspace: workspace, runtime: runtime, data: data).render(root)
        } else {
            HStack(spacing: 7) {
                Image(systemName: "rectangle.3.group.bubble.left.fill").font(.system(size: 10, weight: .semibold))
                Text(package.manifest.name).font(.system(size: 10, weight: .semibold, design: .rounded)).lineLimit(1)
            }.padding(.horizontal, 10)
        }
    }

    var body: some View {
        Group {
            if dynamicSizing {
                renderedContent
                    .fixedSize(horizontal: true, vertical: true)
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: HaloCustomCIContentSizePreferenceKey.self, value: proxy.size)
                    })
            } else {
                renderedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .onPreferenceChange(HaloCustomCIContentSizePreferenceKey.self) { size in
            guard dynamicSizing, size.width > 0, size.height > 0 else { return }
            if expanded { measuredExpanded = size } else { measuredClosed = size }
            publishSizing()
        }
        .onAppear { publishSizing() }
        .onChange(of: expanded) { _ in publishSizing() }
        .onChange(of: runtime.contextRevision) { _ in publishSizing() }
    }

    private func resolved(_ rule: HaloCISizeRule, measured: CGSize, closed: Bool) -> CGSize {
        let sizing = package.manifest.surface.sizing
        if sizing.mode == "static" {
            return CGSize(width: rule.width ?? (closed ? 190 : 560), height: rule.height ?? (closed ? 40 : 260))
        }
        let preferred = CGSize(width: rule.preferredWidth ?? (closed ? 190 : 560),
                               height: rule.preferredHeight ?? (closed ? 40 : 260))
        let source = measured.width > 0 && measured.height > 0 ? measured : preferred
        return CGSize(width: min(rule.maxWidth ?? source.width, max(rule.minWidth ?? source.width, source.width)),
                      height: min(rule.maxHeight ?? source.height, max(rule.minHeight ?? source.height, source.height)))
    }

    private func publishSizing() {
        let sizing = package.manifest.surface.sizing
        let expandedSize = resolved(sizing.expanded, measured: measuredExpanded, closed: false)
        surfaceState.contextMinimumExpandedWidth = sizing.mode == "dynamic"
            ? (sizing.expanded.minWidth ?? expandedSize.width)
            : expandedSize.width
        surfaceState.contextPreferredSize = expandedSize
        if let closed = sizing.closed {
            let closedSize = resolved(closed, measured: measuredClosed, closed: true)
            surfaceState.contextPreferredCompactWidth = closedSize.width
            surfaceState.contextPreferredCompactHeight = closedSize.height
        } else {
            surfaceState.contextPreferredCompactWidth = nil
            surfaceState.contextPreferredCompactHeight = nil
        }
    }
}

private struct HaloCustomCIBackgroundView: View {
    let contract: HaloCIBackgroundContract
    let expanded: Bool
    private var style: HaloCIBackgroundStyle { expanded ? contract.expanded : (contract.closed ?? contract.expanded) }
    var body: some View {
        let opacity = min(1, max(0, style.opacity ?? 1))
        ZStack {
            switch style.type {
            case "gradient":
                LinearGradient(colors: [color(style.color ?? "#101014"), color(style.secondaryColor ?? style.color ?? "#101014")],
                               startPoint: .topLeading, endPoint: .bottomTrailing).opacity(opacity)
            case "glass":
                color(style.color ?? "#101014").opacity(min(1, opacity * 0.72))
                Rectangle().fill(.ultraThinMaterial).opacity(min(1, 0.30 + (style.blur ?? 0) / 60))
            case "clear":
                Color.clear
            default:
                color(style.color ?? "#101014").opacity(opacity)
            }
        }.allowsHitTesting(false)
    }

    private func color(_ raw: String) -> Color {
        switch raw.lowercased() {
        case "accent": return .accentColor; case "white": return .white; case "black": return .black
        case "clear": return .clear; case "secondary": return .white.opacity(0.62); case "green": return .green
        case "orange": return .orange; case "red": return .red; case "blue": return .blue
        default:
            var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if hex.hasPrefix("#") { hex.removeFirst() }
            guard (hex.count == 6 || hex.count == 8), let value = UInt64(hex, radix: 16) else { return .black }
            if hex.count == 6 {
                return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
            }
            return Color(red: Double((value >> 24) & 255) / 255, green: Double((value >> 16) & 255) / 255,
                         blue: Double((value >> 8) & 255) / 255, opacity: Double(value & 255) / 255)
        }
    }
}
'''
replace_once(path, old_custom, new_custom)

# ---- Example package: make the surface contract explicit ----
path = "Examples/HelloWorld.haloCI/manifest.json"
text = Path(path).read_text()
import json
manifest = json.loads(text)
manifest["surface"] = {
    "sizing": {
        "mode": "static",
        "closed": {"width": 250, "height": 40},
        "expanded": {"width": 560, "height": 250}
    },
    "background": {
        "closed": {"type": "solid", "color": "#0C0D10", "opacity": 1},
        "expanded": {"type": "gradient", "color": "#0C0D10", "secondaryColor": "#161A24", "opacity": 1}
    }
}
Path(path).write_text(json.dumps(manifest, indent=2) + "\n")

# ---- Docs: author contract ----
path = "Docs/CISDK.md"
docs = Path(path).read_text()
addition = r'''

## Surface ownership contract: sizing, background, and priority

Every `.haloCI` package must declare `manifest.json.surface`. A Custom CI is rejected at import time if this contract is missing.

```json
"surface": {
  "sizing": {
    "mode": "static",
    "closed": { "width": 250, "height": 40 },
    "expanded": { "width": 560, "height": 250 }
  },
  "background": {
    "closed": { "type": "solid", "color": "#0C0D10", "opacity": 1 },
    "expanded": { "type": "gradient", "color": "#0C0D10", "secondaryColor": "#161A24", "opacity": 1 }
  }
}
```

`static` sizing makes the declared dimensions authoritative. `dynamic` sizing measures Halo's declarative render tree and clamps it to required `minWidth`, `preferredWidth`, `maxWidth`, `minHeight`, `preferredHeight`, and `maxHeight` values for each supported state. The physical camera/notch remains a hard safety floor on notched Macs, and the visible display bounds remain a hard ceiling.

A Custom CI always owns its background while it owns the notch. Backgrounds are state-specific and currently support `solid`, `gradient`, `glass`, and `clear`. Halo's normal workspace/album-art background is not composited behind an active Custom CI.

CI arbitration occurs before trigger evaluation. Halo evaluates eligible CIs from highest priority downward and stops at the first owner. If a built-in or Custom CI with a higher priority already owns/claims the notch, a lower-priority Custom CI is not trigger-evaluated, does not animate, and does not open. Manual Open requests use the CI's configured priority; they do not bypass a higher-priority owner.
'''
if "## Surface ownership contract: sizing, background, and priority" not in docs:
    Path(path).write_text(docs + addition)

print("Applied Custom CI size/background/priority surface contract")
