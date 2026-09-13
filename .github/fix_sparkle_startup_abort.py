from pathlib import Path

p = Path('Halo/Services/UpdateManager.swift')
s = p.read_text()
s = s.replace('''    private let controller: SPUStandardUpdaterController\n    private var started = false\n\n    private override init() {\n        controller = SPUStandardUpdaterController(\n            startingUpdater: false,\n            updaterDelegate: nil,\n            userDriverDelegate: nil\n        )\n        super.init()\n        evaluateConfiguration()\n    }\n''','''    private var controller: SPUStandardUpdaterController?\n    private var started = false\n\n    private override init() {\n        super.init()\n        evaluateConfiguration()\n    }\n''')
s = s.replace('''        controller.startUpdater()\n        started = true\n        refresh()\n''','''        let controller = SPUStandardUpdaterController(\n            startingUpdater: false,\n            updaterDelegate: nil,\n            userDriverDelegate: nil\n        )\n        self.controller = controller\n        controller.startUpdater()\n        started = true\n        refresh()\n''')
s = s.replace('''        guard started else { return }\n        let updater = controller.updater\n''','''        guard started, let controller else { return }\n        let updater = controller.updater\n''')
s = s.replace('''        controller.checkForUpdates(nil)\n        refresh()\n''','''        controller?.checkForUpdates(nil)\n        refresh()\n''')
s = s.replace('''        guard started else { return }\n        controller.updater.automaticallyChecksForUpdates = enabled\n''','''        guard started, let controller else { return }\n        controller.updater.automaticallyChecksForUpdates = enabled\n''')
s = s.replace('''        guard started else { return }\n        controller.updater.automaticallyDownloadsUpdates = enabled\n''','''        guard started, let controller else { return }\n        controller.updater.automaticallyDownloadsUpdates = enabled\n''')
s = s.replace('''        guard started else { return }\n        controller.updater.sendsSystemProfile = enabled\n''','''        guard started, let controller else { return }\n        controller.updater.sendsSystemProfile = enabled\n''')
s = s.replace('''        guard started else { return }\n        controller.updater.updateCheckInterval = max(3_600, interval)\n''','''        guard started, let controller else { return }\n        controller.updater.updateCheckInterval = max(3_600, interval)\n''')
p.write_text(s)

plist = Path('Halo/Info.plist')
s = plist.read_text()
if '<key>CFBundleShortVersionString</key>' not in s:
    s = s.replace('<key>CFBundleIconFile</key>\n\t<string>AppIcon</string>', '<key>CFBundleIconFile</key>\n\t<string>AppIcon</string>\n\t<key>CFBundleShortVersionString</key>\n\t<string>$(MARKETING_VERSION)</string>\n\t<key>CFBundleVersion</key>\n\t<string>$(CURRENT_PROJECT_VERSION)</string>')
plist.write_text(s)

pbx = Path('Halo.xcodeproj/project.pbxproj')
s = pbx.read_text()
# Ensure every app configuration with MARKETING_VERSION has a numeric build number.
s = s.replace('MARKETING_VERSION = 0.2.0;\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.redstoneinvente.Halo;', 'MARKETING_VERSION = 0.2.0;\n\t\t\t\tCURRENT_PROJECT_VERSION = 200;\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.redstoneinvente.Halo;')
pbx.write_text(s)

print('Applied lazy Sparkle startup and bundle version hardening.')
