from pathlib import Path

path = Path("Halo/Core/AppStore.swift")
text = path.read_text()

old = '''        if pressBool(document, "bound") != true {
            do {
                try await bindPressLicense(key: key, document: document, token: token)
            } catch {
                document = try await fetchPressLicense(key: key, token: token)
            }
        }

        let expiresAt = try validatePressLicenseDocument(document, key: key, requireBound: true)
'''
new = '''        if pressBool(document, "bound") != true {
            do {
                try await bindPressLicense(key: key, document: document, token: token)
            } catch {
                // A concurrent activation may have won the one-way bind. Re-fetch below and
                // validate the canonical owner/device instead of trusting the failed write.
            }
            document = try await fetchPressLicense(key: key, token: token)
        }

        let expiresAt = try validatePressLicenseDocument(document, key: key, requireBound: true)
'''
if text.count(old) != 1:
    raise SystemExit(f"post-bind refresh: expected 1 match, found {text.count(old)}")
text = text.replace(old, new, 1)

old = '''                "updateMask": [
                    "fieldPaths": ["bound", "boundUid", "boundEmail", "boundDeviceId", "boundAt", "updatedAt"]
                ],
'''
new = '''                "updateMask": [
                    "fieldPaths": ["bound", "boundUid", "boundEmail", "boundDeviceId"]
                ],
'''
if text.count(old) != 1:
    raise SystemExit(f"update mask: expected 1 match, found {text.count(old)}")
text = text.replace(old, new, 1)

path.write_text(text)
