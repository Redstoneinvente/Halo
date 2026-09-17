from pathlib import Path

# Triggered integration patch.
pbx = Path('Halo.xcodeproj/project.pbxproj')
text = pbx.read_text()

# IDs reserved for Sentry package integration.
build_file = 'A11C0F1A0000000000000401'
product_ref = 'A11C0F1A0000000000000402'
package_ref = 'A11C0F1A0000000000000403'

if 'SentrySPM in Frameworks' not in text:
    text = text.replace(
        '\t\tA11C0F1A0000000000000353 /* Sparkle in Frameworks */ = {isa = PBXBuildFile; productRef = A11C0F1A0000000000000354 /* Sparkle */; };',
        '\t\tA11C0F1A0000000000000353 /* Sparkle in Frameworks */ = {isa = PBXBuildFile; productRef = A11C0F1A0000000000000354 /* Sparkle */; };\n'
        f'\t\t{build_file} /* SentrySPM in Frameworks */ = {{isa = PBXBuildFile; productRef = {product_ref} /* SentrySPM */; }};'
    )
    text = text.replace(
        '\t\t\t\tA11C0F1A0000000000000353 /* Sparkle in Frameworks */,',
        '\t\t\t\tA11C0F1A0000000000000353 /* Sparkle in Frameworks */,\n'
        f'\t\t\t\t{build_file} /* SentrySPM in Frameworks */,'
    )
    text = text.replace(
        '\t\t\t\tA11C0F1A0000000000000354 /* Sparkle */,',
        '\t\t\t\tA11C0F1A0000000000000354 /* Sparkle */,\n'
        f'\t\t\t\t{product_ref} /* SentrySPM */,'
    )
    text = text.replace(
        '\t\t\t\tA11C0F1A0000000000000355 /* XCRemoteSwiftPackageReference "Sparkle" */,',
        '\t\t\t\tA11C0F1A0000000000000355 /* XCRemoteSwiftPackageReference "Sparkle" */,\n'
        f'\t\t\t\t{package_ref} /* XCRemoteSwiftPackageReference "sentry-cocoa" */,'
    )
    marker = '/* End XCRemoteSwiftPackageReference section */'
    block = (
        f'\t\t{package_ref} /* XCRemoteSwiftPackageReference "sentry-cocoa" */ = {{\n'
        '\t\t\tisa = XCRemoteSwiftPackageReference;\n'
        '\t\t\trepositoryURL = "https://github.com/getsentry/sentry-cocoa.git";\n'
        '\t\t\trequirement = {\n'
        '\t\t\t\tkind = upToNextMajorVersion;\n'
        '\t\t\t\tminimumVersion = 9.24.0;\n'
        '\t\t\t};\n'
        '\t\t};\n'
    )
    text = text.replace(marker, block + marker)

    marker2 = '/* End XCSwiftPackageProductDependency section */'
    block2 = (
        f'\t\t{product_ref} /* SentrySPM */ = {{\n'
        '\t\t\tisa = XCSwiftPackageProductDependency;\n'
        f'\t\t\tpackage = {package_ref} /* XCRemoteSwiftPackageReference "sentry-cocoa" */;\n'
        '\t\t\tproductName = SentrySPM;\n'
        '\t\t};\n'
    )
    text = text.replace(marker2, block2 + marker2)

if 'HALO_SENTRY_DSN' not in text:
    needle = '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.redstoneinvente.Halo;'
    text = text.replace(needle, needle + '\n\t\t\t\tHALO_SENTRY_DSN = "";', 2)

pbx.write_text(text)

plist = Path('Halo/Info.plist')
ptext = plist.read_text()
if '<key>HaloSentryDSN</key>' not in ptext:
    ptext = ptext.replace(
        '\t<key>HaloLicenseSeatPublishableKey</key>\n\t<string>$(HALO_LICENSESEAT_PUBLISHABLE_KEY)</string>',
        '\t<key>HaloLicenseSeatPublishableKey</key>\n\t<string>$(HALO_LICENSESEAT_PUBLISHABLE_KEY)</string>\n'
        '\t<key>HaloSentryDSN</key>\n\t<string>$(HALO_SENTRY_DSN)</string>'
    )
plist.write_text(ptext)

app = Path('Halo/App/HaloApp.swift')
atext = app.read_text()
if 'import Sentry' not in atext:
    atext = atext.replace('import Combine\n', 'import Combine\nimport Sentry\n')

if 'private func configureSentry()' not in atext:
    insert_after = '''    private var commercialAccessGranted: Bool {\n        let account = HaloAccountManager.shared\n        return account.isSignedIn && HaloLicenseManager.shared.accessValid(for: account.userID)\n    }\n'''
    sentry_method = r'''

    private func configureSentry() {
        guard let rawDSN = Bundle.main.object(forInfoDictionaryKey: "HaloSentryDSN") as? String else { return }
        let dsn = rawDSN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dsn.isEmpty, !dsn.contains("HALO_SENTRY_DSN") else { return }

        SentrySDK.start { options in
            options.dsn = dsn
            options.sendDefaultPii = false
            options.tracesSampleRate = 0.10
            #if DEBUG
            options.environment = "development"
            options.debug = true
            #else
            options.environment = "production"
            options.debug = false
            #endif
        }
    }
'''
    if insert_after not in atext:
        raise SystemExit('Could not find AppDelegate insertion point')
    atext = atext.replace(insert_after, insert_after + sentry_method)

if 'configureSentry()\n        NSApp.setActivationPolicy' not in atext:
    atext = atext.replace(
        '    func applicationDidFinishLaunching(_ notification: Notification) {\n        NSApp.setActivationPolicy(.accessory)',
        '    func applicationDidFinishLaunching(_ notification: Notification) {\n        configureSentry()\n        NSApp.setActivationPolicy(.accessory)'
    )

if 'commercial_access.granted' not in atext:
    atext = atext.replace(
        '        if commercialAccessGranted {\n            startLicensedServices()',
        '        if commercialAccessGranted {\n            let breadcrumb = Breadcrumb(level: .info, category: "license")\n            breadcrumb.message = "commercial_access.granted"\n            SentrySDK.addBreadcrumb(breadcrumb)\n            startLicensedServices()'
    )

if 'workspace.start' not in atext:
    atext = atext.replace(
        '        licensedServicesStarted = true\n        store.workspace.start()',
        '        licensedServicesStarted = true\n        let breadcrumb = Breadcrumb(level: .info, category: "startup")\n        breadcrumb.message = "workspace.start"\n        SentrySDK.addBreadcrumb(breadcrumb)\n        store.workspace.start()'
    )

app.write_text(atext)

assert 'SentrySPM in Frameworks' in text
assert 'https://github.com/getsentry/sentry-cocoa.git' in text
assert 'minimumVersion = 9.24.0;' in text
assert 'productName = SentrySPM;' in text
assert 'HALO_SENTRY_DSN = "";' in text
assert 'import Sentry' in atext
assert 'configureSentry()' in atext
assert 'sendDefaultPii = false' in atext
assert 'tracesSampleRate = 0.10' in atext
assert 'commercial_access.granted' in atext
assert 'workspace.start' in atext
print('Sentry integration patch applied')
