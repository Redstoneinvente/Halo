from pathlib import Path

path = Path('Halo/Views/SurfaceView.swift')
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: anchor count={count}, expected 1')
    text = text.replace(old, new, 1)


# 1) Music metadata is allowed to wrap the title to two lines. Reserve that exact maximum
# footprint in the size model so a long title cannot push the visualizer below the clipped panel.
replace_once(
'''    private var activeArtwork: NSImage? { media.artworkImage ?? artwork }
''',
'''    private var metadataReservedHeight: Double {
        let titleLineHeight = options.fontSize * 1.22
        let titleHeight = options.showTitle ? titleLineHeight * 2 : 0
        let artistFontSize = max(10, options.fontSize * 0.68)
        let artistHeight = options.showArtist ? artistFontSize * 1.22 : 0
        let gap = options.showTitle && options.showArtist ? max(2, options.resolvedSpacing * 0.28) : 0
        return titleHeight + artistHeight + gap
    }
    private var activeArtwork: NSImage? { media.artworkImage ?? artwork }
''',
'metadata reserved height helper')

replace_once(
'''        let metadataHeight = (options.showTitle ? options.fontSize * 1.35 : 0) + (options.showArtist ? max(12, options.fontSize * 0.72) : 0)
''',
'''        let metadataHeight = metadataReservedHeight
''',
'use deterministic metadata height')

replace_once(
'''        .foregroundStyle(effectiveTextColor)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
''',
'''        .foregroundStyle(effectiveTextColor)
        .frame(maxWidth: .infinity,
               minHeight: CGFloat(metadataReservedHeight),
               maxHeight: CGFloat(metadataReservedHeight),
               alignment: frameAlignment)
''',
'lock metadata block height')

# 2) If another CI's cleanup clears the shared preferred size while Music is still mounted,
# immediately restore Music's deterministic geometry. Otherwise WindowManager falls back to the
# generic expanded notch size (often wider and shorter), which clips the visualizer.
replace_once(
'''        .task(id: sizingKey) { publishPreferredSize() }
        .onChange(of: playbackDuration) { _ in publishPreferredSize() }
        .onDisappear { surfaceState.contextPreferredSize = nil }
''',
'''        .task(id: sizingKey) { publishPreferredSize() }
        .onChange(of: surfaceState.contextPreferredSize) { requested in
            guard surfaceState.expanded, requested == nil else { return }
            publishPreferredSize()
        }
        .onDisappear {
            let owned = preferredSurfaceSize
            if let current = surfaceState.contextPreferredSize,
               abs(current.width - owned.width) < 1,
               abs(current.height - owned.height) < 1 {
                surfaceState.contextPreferredSize = nil
            }
        }
''',
'self-heal music geometry and safe cleanup')

# 3) Transfer CI ending must not clear Music CI's preferred expanded size. Compact Transfer
# geometry can still be reset safely.
replace_once(
'''        .onReceive(transfer.$isActive.removeDuplicates()) { active in
            if !active {
                state.contextPreferredSize = nil
                state.contextPreferredCompactWidth = nil
                state.contextMinimumExpandedWidth = nil
            }
        }
''',
'''        .onReceive(transfer.$isActive.removeDuplicates()) { active in
            if !active {
                if !contextMusicActive { state.contextPreferredSize = nil }
                state.contextPreferredCompactWidth = nil
                state.contextMinimumExpandedWidth = nil
            }
        }
''',
'preserve music size when transfer ends')

# 4) Context arbitration used to explicitly nil the expanded preferred size for Music right as
# Music became the active CI. Preserve Music's size instead of bouncing through the generic frame.
replace_once(
'''            if !transferContextActive && !clipboardContextActive && !customContextActive {
                state.contextPreferredCompactWidth = nil
                state.contextPreferredCompactHeight = nil
                state.contextMinimumExpandedWidth = nil
                if activeContext != nil { state.contextPreferredSize = nil }
            }
''',
'''            if !transferContextActive && !clipboardContextActive && !customContextActive {
                state.contextPreferredCompactWidth = nil
                state.contextPreferredCompactHeight = nil
                state.contextMinimumExpandedWidth = nil
                if activeContext != nil && !contextMusicActive { state.contextPreferredSize = nil }
            }
''',
'do not clear music size during context arbitration')

path.write_text(text)
print('Applied Audio CI geometry ownership and title-height stability fix')
