from pathlib import Path
import re
p = Path('Halo/Views/VisualWorkspaceAdaptiveWidgets.swift')
s = p.read_text()

# Delete the separate lightweight spectrum implementation. Media will use the exact CI visualizer.
s, n = re.subn(r'\nprivate struct AdaptiveSpectrumView: View \{.*?\n\}\n\nstruct VisualWorkspaceAdaptiveModuleView',
                 '\nstruct VisualWorkspaceAdaptiveModuleView', s, count=1, flags=re.S)
if n != 1 and 'private struct AdaptiveSpectrumView' in s:
    raise SystemExit('Could not remove AdaptiveSpectrumView')

s = s.replace(
'''        case .media:\n            VisualAdaptiveMediaView(service: workspace.media, app: workspace.settings.mediaApp)''',
'''        case .media:\n            VisualAdaptiveMediaView(service: workspace.media,\n                                    app: workspace.settings.mediaApp,\n                                    contextOptions: workspace.effectiveLayout.contextMusic ?? ContextMusicOptions(),\n                                    visualizerOptions: workspace.effectiveLayout.closedNotch?.visualizer ?? VisualizerOptions())''', 1)

s = s.replace(
'''    @ObservedObject var service: MediaService\n    let app: String\n    @Namespace private var namespace''',
'''    @ObservedObject var service: MediaService\n    let app: String\n    let contextOptions: ContextMusicOptions\n    let visualizerOptions: VisualizerOptions\n    @Namespace private var namespace''', 1)

old_body = '''    var body: some View {\n        ZStack {\n            if settings.mediaArtworkBackground, let image = service.artworkImage, context.family != .micro {\n                Image(nsImage: image).resizable().scaledToFill().blur(radius: settings.mediaArtworkBlur).opacity(0.28)\n                    .overlay(Color.black.opacity(0.32)).clipped().transition(.opacity)\n            }\n            Group {\n                switch context.family {\n                case .micro: micro\n                case .compact: compact\n                case .horizontal: horizontal\n                case .vertical: vertical\n                case .standard: standard\n                case .expanded: expanded\n                case .dashboard, .hero: hero\n                }\n            }.padding(settings.mediaArtworkBackground && context.family != .micro ? 6 : 0)\n        }\n        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)'''
new_body = '''    var body: some View {\n        ZStack {\n            if settings.mediaArtworkBackground, let image = service.artworkImage, context.family != .micro {\n                GeometryReader { proxy in\n                    Image(nsImage: image)\n                        .resizable()\n                        .scaledToFill()\n                        .frame(width: proxy.size.width, height: proxy.size.height)\n                        .clipped()\n                        .blur(radius: settings.mediaArtworkBlur)\n                        .overlay(Color.black.opacity(0.32))\n                        .opacity(0.28)\n                }\n                .allowsHitTesting(false)\n                .transition(.opacity)\n            }\n            Group {\n                switch context.family {\n                case .micro: micro\n                case .compact: compact\n                case .horizontal: horizontal\n                case .vertical: vertical\n                case .standard: standard\n                case .expanded: expanded\n                case .dashboard, .hero: hero\n                }\n            }\n        }\n        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)\n        .clipped()'''
if old_body not in s:
    raise SystemExit('Media body anchor missing')
s = s.replace(old_body, new_body, 1)

s = s.replace('AdaptiveSpectrumView(accent: artworkAccent).frame(height: settings.mediaVisualizerPosition == .bottom ? 38 : 28)',
              'ciVisualizer(height: settings.mediaVisualizerPosition == .bottom ? 38 : 28)', 1)
s = s.replace('AdaptiveSpectrumView(accent: artworkAccent).frame(width: 90, height: 24)',
              'ciVisualizer(width: 90, height: 24)', 1)

anchor = '''    private var artworkAccent: Color {\n        settings.mediaUseArtworkColors ? (service.artworkColors.first?.color ?? style.accentColor.color) : style.accentColor.color\n    }'''
replacement = '''    private var artworkAccent: Color {\n        settings.mediaUseArtworkColors ? (service.artworkColors.first?.color ?? style.accentColor.color) : style.accentColor.color\n    }\n\n    private func configuredVisualizer(width: CGFloat?, height: CGFloat) -> VisualizerOptions {\n        var value = visualizerOptions\n        value.dynamicColors = settings.mediaUseArtworkColors || contextOptions.usesSongVisualizerColors\n        value.width = Double(width ?? max(96, min(360, (availableWidth ?? 220) * 0.70)))\n        value.height = Double(height)\n        return value\n    }\n\n    @ViewBuilder private func ciVisualizer(width: CGFloat? = nil, height: CGFloat) -> some View {\n        let configured = configuredVisualizer(width: width, height: height)\n        PlaybackVisualizer(kind: contextOptions.resolvedVisualizerStyle,\n                           playing: service.isPlaying,\n                           enabled: true,\n                           options: configured,\n                           palette: service.artworkColors,\n                           fallback: artworkAccent)\n            .frame(maxWidth: width == nil ? .infinity : CGFloat(configured.width))\n            .frame(height: height)\n    }'''
if anchor not in s:
    raise SystemExit('Artwork accent anchor missing')
s = s.replace(anchor, replacement, 1)
p.write_text(s)
