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
            let feedURL = URL(string: feedValue),
            let scheme = feedURL.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            alert.informativeText = "Sparkle is linked correctly, but Halo does not have a release appcast and public signing key yet. Those are added in the next update-integration gate."
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
