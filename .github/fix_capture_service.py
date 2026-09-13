from pathlib import Path
p = Path('Halo/Services/CaptureService.swift')
s = p.read_text()
for sig in [
    'private static func analyze(url: URL)',
    'private static func detectValues(in text: String)',
    'private static func imageDimensions(url: URL)',
    'private static func transcode(input: URL, output: URL, format: HaloCaptureFormat, quality: Double)',
    'private static func largestRectangle(url: URL)',
    'private static func documentScan(url: URL)',
    'private static func cropLargestRectangle(url: URL)',
    'private static func write(cgImage: CGImage, to url: URL, type: CFString, quality: Double)',
]:
    s = s.replace(sig, 'nonisolated ' + sig, 1)
s = s.replace('registerExternalResult(output, mode: "Document Scan")\n                recognize(output)',
              'registerExternalResult(output, mode: "Document Scan")\n                busy = false\n                recognize(output)', 1)
s = s.replace('var analysis = HaloCaptureAnalysis()\n        register(url: url, mode: "Recording',
              'let analysis = HaloCaptureAnalysis()\n        register(url: url, mode: "Recording', 1)
p.write_text(s)
