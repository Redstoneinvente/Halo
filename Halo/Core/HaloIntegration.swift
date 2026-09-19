//
//  HaloIntegration.swift
//  Halo
//
//  Reusable template for third-party app integrations.
//

import AppKit

struct HaloIntegration {
    let name: String
    let bundleIdentifier: String
    let websiteURL: URL

    var installedURL: URL? {
        NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        )
    }

    var isInstalled: Bool {
        installedURL != nil
    }
}
