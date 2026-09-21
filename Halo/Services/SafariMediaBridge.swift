import AppKit
import Combine
import Foundation
import SafariServices

struct SafariMediaState: Codable, Equatable {
    let version: Int
    let hasMedia: Bool
    let pageURL: String
    let host: String
    let title: String
    let artist: String
    let album: String
    let artworkURL: String?
    let sourceLabel: String
    let playing: Bool
    let duration: Double?
    let position: Double?
    let playbackRate: Double
    let canPlayPause: Bool
    let canSeek: Bool
    let canNext: Bool
    let canPrevious: Bool
    let visibility: String
    let updatedAt: Double

    var updatedDate: Date {
        Date(timeIntervalSince1970: updatedAt / 1_000)
    }

    func isFresh(maxAge: TimeInterval = 4.0, now: Date = Date()) -> Bool {
        let age = now.timeIntervalSince(updatedDate)
        return hasMedia && age >= -1 && age <= maxAge
    }
}

@MainActor
final class SafariMediaBridge: ObservableObject {
    static let shared = SafariMediaBridge()

    static let appGroupIdentifier = "group.com.redstoneinvente.Halo"
    static let extensionBundleIdentifier = "com.redstoneinvente.Halo.SafariMedia"
    static let stateDefaultsKey = "HaloSafariMediaStateV1"

    @Published private(set) var current: SafariMediaState?
    @Published private(set) var extensionEnabled: Bool?
    @Published private(set) var lastError: String?

    private let defaults = UserDefaults(suiteName: appGroupIdentifier)

    private init() {}

    @discardableResult
    func refreshState() -> SafariMediaState? {
        guard let data = defaults?.data(forKey: Self.stateDefaultsKey),
              let decoded = try? JSONDecoder().decode(SafariMediaState.self, from: data) else {
            if current != nil { current = nil }
            return nil
        }

        if current != decoded { current = decoded }
        return decoded
    }

    func currentState(maxAge: TimeInterval = 4.0) -> SafariMediaState? {
        guard let state = refreshState(), state.isFresh(maxAge: maxAge) else { return nil }
        return state
    }

    func refreshExtensionState() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: Self.extensionBundleIdentifier) { [weak self] state, error in
            Task { @MainActor in
                guard let self else { return }
                self.extensionEnabled = state?.isEnabled
                self.lastError = error?.localizedDescription
            }
        }
    }

    func openExtensionPreferences() {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: Self.extensionBundleIdentifier) { [weak self] error in
            Task { @MainActor in
                self?.lastError = error?.localizedDescription
                self?.refreshExtensionState()
            }
        }
    }

    @discardableResult
    func perform(command: String) -> Bool {
        guard let state = currentState(maxAge: 3.5), state.playing else { return false }

        let normalized: String
        switch command {
        case "playpause": normalized = "playpause"
        case "next track": normalized = "next"
        case "previous track": normalized = "previous"
        default: return false
        }

        dispatch(command: normalized, position: nil)
        return true
    }

    @discardableResult
    func seek(to position: Double) -> Bool {
        guard position.isFinite,
              position >= 0,
              let state = currentState(maxAge: 3.5),
              state.playing,
              state.canSeek else { return false }

        dispatch(command: "seek", position: position)
        return true
    }

    private func dispatch(command: String, position: Double?) {
        var payload: [String: Any] = [
            "type": "haloMediaCommand",
            "command": command,
            "requestID": UUID().uuidString,
            "sentAt": Date().timeIntervalSince1970 * 1_000
        ]
        if let position { payload["position"] = position }

        SFSafariApplication.dispatchMessage(
            withName: "HaloSafariMediaCommand",
            toExtensionWithIdentifier: Self.extensionBundleIdentifier,
            userInfo: payload
        ) { [weak self] error in
            Task { @MainActor in
                self?.lastError = error?.localizedDescription
            }
        }
    }
}
