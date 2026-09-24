import AppKit
import Foundation
import UniformTypeIdentifiers

struct HaloWebRepresentationManifest: Codable {
    struct Capture: Codable {
        let id: String
        let file: String
        let width: Int
        let height: Int
        let scale: Double
        let expanded: Bool
        let displayID: String
    }

    let schemaVersion: Int
    let generatedAt: String
    let appVersion: String
    let build: String
    let captures: [Capture]
}

@MainActor
final class HaloWebRepresentationExporter {
    static let shared = HaloWebRepresentationExporter()

    private init() {}

    private static let notificationName = Notification.Name("HaloWebRepresentationCaptureRequest")

    static func requestedOutputURL(arguments: [String] = ProcessInfo.processInfo.arguments) -> URL? {
        guard let index = arguments.firstIndex(of: "--export-web-representation") else { return nil }
        if arguments.indices.contains(index + 1), !arguments[index + 1].hasPrefix("--") {
            return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/Halo-Web-Representation", isDirectory: true)
    }

    func export(to rootURL: URL, engine: WindowManager, completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        } catch {
            completion(.failure(error))
            return
        }

        let captures = engine.webRepresentationCaptureTargets()
        guard !captures.isEmpty else {
            completion(.failure(NSError(domain: "HaloWebRepresentationExporter", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Halo has no active render surface to export."
            ])))
            return
        }

        exportSequentially(captures, index: 0, rootURL: rootURL, manifestCaptures: []) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let manifestCaptures):
                do {
                    let info = Bundle.main.infoDictionary ?? [:]
                    let manifest = HaloWebRepresentationManifest(
                        schemaVersion: 1,
                        generatedAt: ISO8601DateFormatter().string(from: Date()),
                        appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
                        build: info["CFBundleVersion"] as? String ?? "unknown",
                        captures: manifestCaptures
                    )
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(manifest)
                    try data.write(to: rootURL.appendingPathComponent("manifest.json"), options: .atomic)
                    completion(.success(rootURL))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    private func exportSequentially(
        _ captures: [WindowManager.WebRepresentationCaptureTarget],
        index: Int,
        rootURL: URL,
        manifestCaptures: [HaloWebRepresentationManifest.Capture],
        completion: @escaping (Result<[HaloWebRepresentationManifest.Capture], Error>) -> Void
    ) {
        guard captures.indices.contains(index) else {
            completion(.success(manifestCaptures))
            return
        }

        let target = captures[index]
        target.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            do {
                let capture = try self.capture(target: target, rootURL: rootURL)
                var updatedCaptures = manifestCaptures
                updatedCaptures.append(capture)
                self.exportSequentially(
                    captures,
                    index: index + 1,
                    rootURL: rootURL,
                    manifestCaptures: updatedCaptures,
                    completion: completion
                )
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func capture(
        target: WindowManager.WebRepresentationCaptureTarget,
        rootURL: URL
    ) throws -> HaloWebRepresentationManifest.Capture {
        guard let contentView = target.panel.contentView else {
            throw NSError(domain: "HaloWebRepresentationExporter", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Halo surface has no content view."
            ])
        }

        contentView.layoutSubtreeIfNeeded()
        let bounds = contentView.bounds.integral
        guard bounds.width > 0, bounds.height > 0 else {
            throw NSError(domain: "HaloWebRepresentationExporter", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Halo surface has invalid capture bounds."
            ])
        }

        guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
            throw NSError(domain: "HaloWebRepresentationExporter", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Could not allocate Halo surface bitmap."
            ])
        }
        contentView.cacheDisplay(in: bounds, to: rep)

        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "HaloWebRepresentationExporter", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Could not encode Halo surface as PNG."
            ])
        }

        let filename = target.id + ".png"
        try png.write(to: rootURL.appendingPathComponent(filename), options: .atomic)

        let backingScale = target.panel.backingScaleFactor
        return HaloWebRepresentationManifest.Capture(
            id: target.id,
            file: filename,
            width: rep.pixelsWide,
            height: rep.pixelsHigh,
            scale: backingScale,
            expanded: target.expanded,
            displayID: target.displayID
        )
    }
}
