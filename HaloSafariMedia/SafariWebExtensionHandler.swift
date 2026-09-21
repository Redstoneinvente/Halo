import Foundation
import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private let appGroupIdentifier = "group.com.redstoneinvente.Halo"
    private let stateKey = "HaloSafariMediaStateV1"

    func beginRequest(with context: NSExtensionContext) {
        guard let item = context.inputItems.first as? NSExtensionItem,
              let message = item.userInfo?[SFExtensionMessageKey] as? [String: Any] else {
            NSLog("Halo Safari Media: native message arrived without SFExtensionMessageKey payload")
            complete(context, ok: false, error: "Missing native message payload")
            return
        }

        guard message["type"] as? String == "mediaState",
              let payload = message["payload"] as? [String: Any],
              JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload) else {
            NSLog("Halo Safari Media: unsupported or invalid native message: %@", String(describing: message))
            complete(context, ok: false, error: "Invalid media state")
            return
        }

        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil else {
            NSLog("Halo Safari Media: App Group %@ is unavailable. Check signing/provisioning.", appGroupIdentifier)
            complete(context, ok: false, error: "App Group unavailable")
            return
        }

        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            NSLog("Halo Safari Media: could not open shared UserDefaults suite %@", appGroupIdentifier)
            complete(context, ok: false, error: "Shared preferences unavailable")
            return
        }

        defaults.set(data, forKey: stateKey)
        defaults.set(Date().timeIntervalSince1970, forKey: "HaloSafariMediaHeartbeatV1")
        defaults.synchronize()

        let title = payload["title"] as? String ?? ""
        let playing = payload["playing"] as? Bool ?? false
        NSLog("Halo Safari Media: wrote state to App Group (playing=%@ title=%@)", playing ? "yes" : "no", title)

        complete(context, ok: true, error: nil)
    }

    private func complete(_ context: NSExtensionContext, ok: Bool, error: String?) {
        var reply: [String: Any] = ["ok": ok]
        if let error { reply["error"] = error }

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: reply]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
