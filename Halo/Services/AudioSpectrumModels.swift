import Foundation

/// Shared spectrum data consumed by Halo UI and CI components.
///
/// This model is distribution-agnostic: direct builds populate it from
/// system-wide audio capture, while App Store builds return an unavailable
/// snapshot from the disabled provider.
struct AudioSpectrumSnapshot: Equatable {
    var bass: Double = 0
    var mids: Double = 0
    var treble: Double = 0
    var overall: Double = 0

    var reactiveBass: Double = 0
    var reactiveMids: Double = 0
    var reactiveTreble: Double = 0
    var reactiveOverall: Double = 0

    var liveness: Double = 0
    var available = false
}

struct AudioRecognitionMatch: Equatable {
    let title: String
    let artist: String
    let artworkURL: URL?
    let isrc: String?
}
