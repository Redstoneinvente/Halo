from pathlib import Path

# Replace the Gate-1 link probe with the minimal Gate-2 updater controller.
probe = Path('Halo/Services/SparkleLinkProbe.swift')
if not probe.exists():
    raise SystemExit('SparkleLinkProbe.swift not found')
probe.unlink()

controller = Path('Halo/Services/SparkleUpdateController.swift')
controller.write_text('''import AppKit\nimport Sparkle\n\n@MainActor\nfinal class HaloUpdateController: NSObject {\n    static let shared = HaloUpdateController()\n\n    private let controller: SPUStandardUpdaterController\n    private var updaterStarted = false\n\n    private override init() {\n        controller = SPUStandardUpdaterController(\n            startingUpdater: false,\n            updaterDelegate: nil,\n            userDriverDelegate: nil\n        )\n        super.init()\n    }\n\n    var isConfigured: Bool {\n        guard\n            let feedValue = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,\n            let feedURL = URL(string: feedValue),\n            let scheme = feedURL.scheme?.lowercased(),\n            scheme == "https" || scheme == "http",\n            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,\n            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty\n        else {\n            return false\n        }\n        return true\n    }\n\n    func checkForUpdates() {\n        guard isConfigured else {\n            let alert = NSAlert()\n            alert.alertStyle = .informational\n            alert.messageText = "Updates are not configured yet"\n            alert.informativeText = "Sparkle is linked correctly, but Halo does not have a release appcast and public signing key yet. Those are added in the next update-integration gate."\n            alert.addButton(withTitle: "OK")\n            alert.runModal()\n            return\n        }\n\n        if !updaterStarted {\n            controller.startUpdater()\n            updaterStarted = true\n        }\n        controller.checkForUpdates(nil)\n    }\n}\n''')

# Keep the existing PBX ids but rename the source reference/build entry.
pbx = Path('Halo.xcodeproj/project.pbxproj')
s = pbx.read_text()
old_build = 'A11C0F1A0000000000000351 /* Services/SparkleLinkProbe.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000352 /* Services/SparkleLinkProbe.swift */; };'
new_build = 'A11C0F1A0000000000000351 /* Services/SparkleUpdateController.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000352 /* Services/SparkleUpdateController.swift */; };'
old_ref = 'A11C0F1A0000000000000352 /* Services/SparkleLinkProbe.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Services/SparkleLinkProbe.swift; sourceTree = "<group>"; };'
new_ref = 'A11C0F1A0000000000000352 /* Services/SparkleUpdateController.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Services/SparkleUpdateController.swift; sourceTree = "<group>"; };'
if s.count(old_build) != 1 or s.count(old_ref) != 1:
    raise SystemExit('Gate-1 probe project entries not found exactly once')
s = s.replace(old_build, new_build, 1).replace(old_ref, new_ref, 1)
s = s.replace('A11C0F1A0000000000000352 /* Services/SparkleLinkProbe.swift */,', 'A11C0F1A0000000000000352 /* Services/SparkleUpdateController.swift */,', 1)
s = s.replace('A11C0F1A0000000000000351 /* Services/SparkleLinkProbe.swift in Sources */,', 'A11C0F1A0000000000000351 /* Services/SparkleUpdateController.swift in Sources */,', 1)
pbx.write_text(s)

# Wire a manual menu action only. No automatic updater start/checks.
app = Path('Halo/App/HaloApp.swift')
a = app.read_text()
prop_anchor = '    private var setupShownThisLaunch = false\n'
if 'private let updater = HaloUpdateController.shared' not in a:
    if a.count(prop_anchor) != 1:
        raise SystemExit('AppDelegate property anchor not found')
    a = a.replace(prop_anchor, prop_anchor + '    private let updater = HaloUpdateController.shared\n', 1)

menu_anchor = '''        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")\n        settingsItem.target = self\n        menu.addItem(settingsItem)\n'''
menu_repl = menu_anchor + '''\n        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")\n        updateItem.target = self\n        menu.addItem(updateItem)\n'''
if 'title: "Check for Updates…"' not in a:
    if a.count(menu_anchor) != 1:
        raise SystemExit('Settings menu anchor not found')
    a = a.replace(menu_anchor, menu_repl, 1)

method_anchor = '    @objc private func toggle() { engine?.toggleAll() }\n'
if '@objc private func checkForUpdates()' not in a:
    if a.count(method_anchor) != 1:
        raise SystemExit('AppDelegate action anchor not found')
    a = a.replace(method_anchor, method_anchor + '    @objc private func checkForUpdates() { updater.checkForUpdates() }\n', 1)

app.write_text(a)
print('Applied Sparkle Gate 2: dormant controller + manual Check for Updates action.')
