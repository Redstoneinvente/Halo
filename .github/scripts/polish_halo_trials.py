from pathlib import Path

# AppStore: identify trial plans cleanly in the UI.
p = Path('Halo/Core/AppStore.swift')
s = p.read_text()
old = '''    var activatedMacsTitle: String {
        guard let activeSeats else { return "Unavailable" }
        if let seatLimit { return "\\(activeSeats) of \\(seatLimit)" }
        return "\\(activeSeats)"
    }
'''
new = '''    var activatedMacsTitle: String {
        guard let activeSeats else { return "Unavailable" }
        if let seatLimit { return "\\(activeSeats) of \\(seatLimit)" }
        return "\\(activeSeats)"
    }

    var isTrial: Bool {
        let normalized = plan.lowercased()
        return normalized.contains("trial") || normalized.contains("demo")
    }
'''
if old not in s:
    raise SystemExit('HaloLicenseDetails block not found')
s = s.replace(old, new, 1)
p.write_text(s)

# Settings: label expiring trials correctly.
p = Path('Halo/Views/WorkspaceSettingsView.swift')
s = p.read_text()
old = '''                    if let days = license.details.daysRemaining, let expiresAt = license.details.expiresAt {
                        LabeledContent("Subscription remaining", value: "\\(days) day\\(days == 1 ? "" : "s")")
                        LabeledContent("Expires", value: expiresAt.formatted(date: .abbreviated, time: .omitted))
                    } else {
'''
new = '''                    if let days = license.details.daysRemaining, let expiresAt = license.details.expiresAt {
                        LabeledContent(license.details.isTrial ? "Trial remaining" : "Subscription remaining",
                                       value: "\\(days) day\\(days == 1 ? "" : "s")")
                        LabeledContent("Expires", value: expiresAt.formatted(date: .abbreviated, time: .omitted))
                    } else {
'''
if old not in s:
    raise SystemExit('remaining-days UI block not found')
s = s.replace(old, new, 1)
p.write_text(s)

# Locked notch needs more vertical room now that trial + paid activation are both present.
p = Path('Halo/Core/ExtensionContracts.swift')
s = p.read_text()
old = '    private var preferredSize: CGSize { CGSize(width: 520, height: account.isSignedIn ? 360 : 390) }'
new = '    private var preferredSize: CGSize { CGSize(width: 540, height: account.isSignedIn ? 470 : 390) }'
if old not in s:
    raise SystemExit('locked-notch preferred size block not found')
s = s.replace(old, new, 1)
p.write_text(s)

# Trial responses carry a license key; explicitly prevent intermediary caching.
p = Path('functions/index.js')
s = p.read_text()
old = '''  async (req, res) => {
    if (req.method !== "POST") {
'''
new = '''  async (req, res) => {
    res.set("Cache-Control", "no-store");
    if (req.method !== "POST") {
'''
if old not in s:
    raise SystemExit('function handler block not found')
s = s.replace(old, new, 1)
p.write_text(s)

print('Halo trial UX/security polish applied')
