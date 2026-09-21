import Foundation
import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private let defaults = UserDefaults(suiteName: "group.com.redstoneinvente.Halo")
    private let stateKey = "HaloSafariMediaStateV1"

    func beginRequest(with context: NSExtensionContext) {
        guard let item = context.inputItems.first as? NSExtensionItem,
              let message = item.userInfo?[SFExtensionMessageKey] as? [String: Any] else {
            complete(context, ok: false)
            return
        }

        if message["type"] as? String == "mediaState",
           let payload = message["payload"] as? [String: Any],
           JSONSerialization.isValidJSONObject(payload),
           let data = try? JSONSerialization.data(withJSONObject: payload) {
            defaults?.set(data, forKey: stateKey)
            defaults?.set(Date().timeIntervalSince1970, forKey: "HaloSafariMediaHeartbeatV1")
            complete(context, ok: true)
            return
        }

        complete(context, ok: true)
    }

    private func complete(_ context: NSExtensionContext, ok: Bool) {
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["ok": ok]]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
