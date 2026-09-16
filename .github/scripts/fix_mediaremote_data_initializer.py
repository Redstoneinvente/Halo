from pathlib import Path

workspace = Path('Halo/Core/WorkspaceStore.swift')
text = workspace.read_text()

old = 'let artworkData = payload.artworkDataBase64.flatMap(Data.init(base64Encoded:))'
new = 'let artworkData = payload.artworkDataBase64.flatMap { Foundation.Data(base64Encoded: $0) }'
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit('MediaRemote artwork decode expression not found')

marker = '// MARK: - Embedded MediaRemote bridge'
if marker not in text:
    raise SystemExit('Embedded MediaRemote bridge marker not found')
head, tail = text.split(marker, 1)

# Keep the embedded bridge unambiguous under newer Swift compilers and in the
# presence of any project-local Data symbols.
tail = tail.replace('let data = Data(base64Encoded: base64String)',
                    'let data = Foundation.Data(base64Encoded: base64String)')
tail = tail.replace('private var dataBuffer = Data()',
                    'private var dataBuffer = Foundation.Data()')
tail = tail.replace('((Error, Data) -> Void)?',
                    '((Error, Foundation.Data) -> Void)?')
tail = tail.replace('var outputBuffer = Data()',
                    'var outputBuffer = Foundation.Data()')
tail = tail.replace('var errorBuffer = Data()',
                    'var errorBuffer = Foundation.Data()')
tail = tail.replace('var getDataBuffer = Data()',
                    'var getDataBuffer = Foundation.Data()')

workspace.write_text(head + marker + tail)

# Patch the vendored source too so a future bridge regeneration cannot
# reintroduce the ambiguity.
track = Path('Vendor/MediaRemoteAdapter/Sources/MediaRemoteAdapter/TrackInfo.swift')
track_text = track.read_text().replace(
    'let data = Data(base64Encoded: base64String)',
    'let data = Foundation.Data(base64Encoded: base64String)'
)
track.write_text(track_text)

controller = Path('Vendor/MediaRemoteAdapter/Sources/MediaRemoteAdapter/MediaController.swift')
controller_text = controller.read_text()
controller_text = controller_text.replace('private var dataBuffer = Data()', 'private var dataBuffer = Foundation.Data()')
controller_text = controller_text.replace('((Error, Data) -> Void)?', '((Error, Foundation.Data) -> Void)?')
controller_text = controller_text.replace('var outputBuffer = Data()', 'var outputBuffer = Foundation.Data()')
controller_text = controller_text.replace('var errorBuffer = Data()', 'var errorBuffer = Foundation.Data()')
controller_text = controller_text.replace('var getDataBuffer = Data()', 'var getDataBuffer = Foundation.Data()')
controller.write_text(controller_text)

print('Patched MediaRemote Data initializers for Swift compiler compatibility.')
