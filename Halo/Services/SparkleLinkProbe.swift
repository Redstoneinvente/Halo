import Foundation
import Sparkle

/// Gate 1 only: proves Halo can compile and link against Sparkle without
/// constructing an updater or starting any update behavior.
enum SparkleLinkProbe {
    static var linkedFrameworkVersion: String {
        let bundle = Bundle(for: SPUUpdater.self)
        return bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }
}
