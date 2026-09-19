import Foundation

struct CIKeyboardShortcutConfiguration: Codable, Hashable, Sendable {
    var keyCode: UInt32?
    var modifiers: UInt32?

    var isAssigned: Bool { keyCode != nil && modifiers != nil }
}

struct CITriggerConfiguration: Codable, Hashable, Sendable {
    var enabled: Bool = true
    var autoOpen: Bool = true
    var keyboardShortcut = CIKeyboardShortcutConfiguration()
}

struct CIActionConfiguration: Codable, Hashable, Sendable {
    var enabled: Bool = true
    var optionDefaults: [String: CIValue] = [:]
}

struct CIPresentationConfiguration: Codable, Hashable, Sendable {
    var usesFullSurface: Bool?
    var keepsClosedContents: Bool?
}

struct CIConfiguration: Codable, Hashable, Sendable {
    var enabled: Bool = true
    var priority: Double = 50
    var grantedPermissions: Set<String> = []
    var actions: [String: CIActionConfiguration] = [:]
    var triggers: [String: CITriggerConfiguration] = [:]
    var presentation = CIPresentationConfiguration()

    func actionEnabled(_ id: String) -> Bool { actions[id]?.enabled ?? true }
    func triggerEnabled(_ id: String) -> Bool { triggers[id]?.enabled ?? true }
}

/// Persistent user-owned configuration. Manifest refreshes only add defaults for newly
/// advertised stable IDs; compatible existing choices are never overwritten by discovery.
final class CIConfigurationStore {
    static let shared = CIConfigurationStore()

    private let defaults: UserDefaults
    private let storageKey: String
    private var values: [String: CIConfiguration]
    private let lock = NSLock()
    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard, storageKey: String = "HaloCI.configuration.v3") {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: CIConfiguration].self, from: data) {
            values = decoded
        } else {
            values = [:]
        }
    }

    func configuration(for registration: CIRegistration) -> CIConfiguration {
        lock.lock(); defer { lock.unlock() }
        var value = values[registration.id] ?? CIConfiguration()
        value = Self.reconciled(value, with: registration)
        if values[registration.id] != value {
            values[registration.id] = value
            persistLocked()
        }
        return value
    }

    func existingConfiguration(ciID: String) -> CIConfiguration? {
        lock.lock(); defer { lock.unlock() }
        return values[ciID]
    }

    func setConfiguration(_ configuration: CIConfiguration, for registration: CIRegistration) {
        lock.lock()
        var next = Self.reconciled(configuration, with: registration)
        next.priority = min(100, max(0, next.priority.isFinite ? next.priority : 50))
        next.grantedPermissions = next.grantedPermissions.intersection(registration.requiredPermissions)
        values[registration.id] = next
        persistLocked()
        lock.unlock()
        onChange?()
    }

    func update(_ registration: CIRegistration, _ mutate: (inout CIConfiguration) -> Void) {
        var value = configuration(for: registration)
        mutate(&value)
        setConfiguration(value, for: registration)
    }

    func setEnabled(_ enabled: Bool, registration: CIRegistration) {
        update(registration) { $0.enabled = enabled }
    }

    func setPriority(_ priority: Double, registration: CIRegistration) {
        update(registration) { $0.priority = min(100, max(0, priority.isFinite ? priority : 50)) }
    }

    func setPermission(_ permission: String, granted: Bool, registration: CIRegistration) {
        guard registration.requiredPermissions.contains(permission) else { return }
        update(registration) { value in
            if granted { value.grantedPermissions.insert(permission) }
            else { value.grantedPermissions.remove(permission) }
        }
    }

    func setActionEnabled(_ enabled: Bool, actionID: String, registration: CIRegistration) {
        guard registration.supportedActions.contains(where: { $0.id == actionID }) else { return }
        update(registration) { value in
            var action = value.actions[actionID] ?? CIActionConfiguration()
            action.enabled = enabled
            value.actions[actionID] = action
        }
    }

    func setTriggerEnabled(_ enabled: Bool, triggerID: String, registration: CIRegistration) {
        guard registration.supportedTriggers.contains(where: { $0.id == triggerID }) else { return }
        update(registration) { value in
            var trigger = value.triggers[triggerID] ?? CITriggerConfiguration()
            trigger.enabled = enabled
            value.triggers[triggerID] = trigger
        }
    }

    func setTriggerAutoOpen(_ enabled: Bool, triggerID: String, registration: CIRegistration) {
        guard registration.supportedTriggers.contains(where: { $0.id == triggerID }) else { return }
        update(registration) { value in
            var trigger = value.triggers[triggerID] ?? CITriggerConfiguration()
            trigger.autoOpen = enabled
            value.triggers[triggerID] = trigger
        }
    }

    func setKeyboardShortcut(_ shortcut: CIKeyboardShortcutConfiguration, triggerID: String, registration: CIRegistration) {
        guard registration.supportedTriggers.contains(where: { $0.id == triggerID && $0.type == .keyboardShortcut }) else { return }
        update(registration) { value in
            var trigger = value.triggers[triggerID] ?? CITriggerConfiguration()
            trigger.keyboardShortcut = shortcut
            value.triggers[triggerID] = trigger
        }
    }

    func setActionDefault(_ optionValue: CIValue?, actionID: String, optionKey: String, registration: CIRegistration) {
        guard let action = registration.supportedActions.first(where: { $0.id == actionID }),
              let option = action.options.first(where: { $0.key == optionKey }),
              optionValue.map({ IntegrationManifestCodec.optionValueIsValid($0, for: option) }) ?? true else { return }
        update(registration) { value in
            var actionConfiguration = value.actions[actionID] ?? CIActionConfiguration()
            if let optionValue { actionConfiguration.optionDefaults[optionKey] = optionValue }
            else { actionConfiguration.optionDefaults.removeValue(forKey: optionKey) }
            value.actions[actionID] = actionConfiguration
        }
    }

    func reset(ciID: String) {
        lock.lock(); values.removeValue(forKey: ciID); persistLocked(); lock.unlock()
        onChange?()
    }

    static func reconciled(_ existing: CIConfiguration, with registration: CIRegistration) -> CIConfiguration {
        var result = existing
        if !result.priority.isFinite { result.priority = 50 }
        result.priority = min(100, max(0, result.priority))
        result.grantedPermissions = result.grantedPermissions.intersection(registration.requiredPermissions)
        for action in registration.supportedActions where result.actions[action.id] == nil {
            var defaults: [String: CIValue] = [:]
            for option in action.options {
                if let value = option.defaultValue { defaults[option.key] = value }
            }
            result.actions[action.id] = CIActionConfiguration(enabled: true, optionDefaults: defaults)
        }
        for trigger in registration.supportedTriggers where result.triggers[trigger.id] == nil {
            result.triggers[trigger.id] = CITriggerConfiguration()
        }
        return result
    }

    private func persistLocked() {
        if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: storageKey) }
    }
}
