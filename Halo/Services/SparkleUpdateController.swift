import AppKit
import Sparkle

@MainActor
final class HaloUpdateController: NSObject {
    static let shared = HaloUpdateController()

    private let controller: SPUStandardUpdaterController
    private var updaterStarted = false

    private override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    var isConfigured: Bool {
        guard
            let feedValue = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            !feedValue.isEmpty,
            !feedValue.contains("$("),
            let feedURL = URL(string: feedValue),
            feedURL.scheme?.lowercased() == "https",
            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !publicKey.contains("$(")
        else {
            return false
        }
        return true
    }

    func checkForUpdates() {
        guard isConfigured else {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Updates are not configured yet"
            alert.informativeText = "Sparkle is linked correctly, but Halo still needs an HTTPS appcast URL and its Ed25519 public signing key. Configure those locally for Gate 3 before starting the updater."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        if !updaterStarted {
            controller.startUpdater()
            updaterStarted = true
        }
        controller.checkForUpdates(nil)
    }
}
