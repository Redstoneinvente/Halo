from pathlib import Path

root = Path('.')
app = root / 'Halo/Core/AppStore.swift'
text = app.read_text()

old = '''        let startedAt = Date()
        let expiresAt = startedAt.addingTimeInterval(14 * 86_400)
        guard HaloKeychain.set("1", for: localTrialUsedKey),
              HaloKeychain.set(accountID, for: localTrialOwnerKey),
              HaloKeychain.set(String(startedAt.timeIntervalSince1970), for: localTrialStartedKey),
              HaloKeychain.set(String(expiresAt.timeIntervalSince1970), for: localTrialExpiresKey),
              HaloKeychain.set(String(startedAt.timeIntervalSince1970), for: localTrialLastCheckKey) else {
            errorMessage = "Halo could not save the local trial securely in Keychain."
            return
        }

        applyLocalTrial(expiresAt: expiresAt)
        notice = "Your 14-day Halo trial is active on this Mac."
'''

new = '''        let startedAt = Date()
        let expiresAt = startedAt.addingTimeInterval(14 * 86_400)

        // Firestore is the one-time claim authority. createDocument is atomic: if
        // haloTrialClaims/{uid} already exists, the same account cannot claim again.
        do {
            let claimed = try await claimFirestoreTrial(
                accountID: accountID,
                startedAt: startedAt,
                expiresAt: expiresAt
            )
            guard claimed else {
                errorMessage = "This Halo account has already used its free trial."
                return
            }
        } catch {
            errorMessage = readable(error)
            return
        }

        guard HaloKeychain.set("1", for: localTrialUsedKey),
              HaloKeychain.set(accountID, for: localTrialOwnerKey),
              HaloKeychain.set(String(startedAt.timeIntervalSince1970), for: localTrialStartedKey),
              HaloKeychain.set(String(expiresAt.timeIntervalSince1970), for: localTrialExpiresKey),
              HaloKeychain.set(String(startedAt.timeIntervalSince1970), for: localTrialLastCheckKey) else {
            errorMessage = "Your trial was reserved, but Halo could not save it securely in Keychain. Contact r.support@redstoneinvente.com."
            return
        }

        applyLocalTrial(expiresAt: expiresAt)
        notice = "Your 14-day Halo trial is active on this Mac."
'''

if old not in text:
    raise SystemExit('startTrial persistence block not found')
text = text.replace(old, new, 1)

marker = '''    private func localTrialDate(for key: String) -> Date? {
        guard let raw = HaloKeychain.string(for: key), let timestamp = TimeInterval(raw) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

'''

helpers = '''    private func claimFirestoreTrial(accountID: String, startedAt: Date, expiresAt: Date) async throws -> Bool {
        let token = try await HaloAccountManager.shared.validIDToken()
        guard let projectID = firebaseProjectID(from: token), !projectID.isEmpty else {
            throw HaloCommercialError.message("Halo could not identify the Firebase project for the trial check.")
        }

        let pathAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard let encodedProject = projectID.addingPercentEncoding(withAllowedCharacters: pathAllowed),
              let encodedUID = accountID.addingPercentEncoding(withAllowedCharacters: pathAllowed),
              let url = URL(string: "https://firestore.googleapis.com/v1/projects/\\(encodedProject)/databases/(default)/documents/haloTrialClaims?documentId=\\(encodedUID)") else {
            throw HaloCommercialError.message("Halo could not prepare the Firestore trial check.")
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \\(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "fields": [
                "uid": ["stringValue": accountID],
                "device_fingerprint": ["stringValue": fingerprint()],
                "started_at": ["timestampValue": iso.string(from: startedAt)],
                "expires_at": ["timestampValue": iso.string(from: expiresAt)],
                "source": ["stringValue": "halo-macos-client-trial"],
                "version": ["integerValue": "1"]
            ]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HaloCommercialError.message("No response from Firestore while checking trial eligibility.")
        }
        if (200..<300).contains(http.statusCode) { return true }

        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let error = root?["error"] as? [String: Any]
        let status = (error?["status"] as? String) ?? ""
        if http.statusCode == 409 || status == "ALREADY_EXISTS" {
            return false
        }
        if http.statusCode == 403 || status == "PERMISSION_DENIED" {
            throw HaloCommercialError.message("Halo could not verify trial eligibility. Make sure the Firestore trial rules are deployed.")
        }
        if http.statusCode == 401 || status == "UNAUTHENTICATED" {
            throw HaloCommercialError.message("Your Halo session expired. Sign in again before starting a trial.")
        }

        let message = (error?["message"] as? String) ?? "Firestore trial check failed (\\(http.statusCode))."
        throw HaloCommercialError.message(message)
    }

    private func firebaseProjectID(from idToken: String) -> String? {
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder != 0 { payload += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audience = object["aud"] as? String else { return nil }
        return audience
    }

'''

if marker not in text:
    raise SystemExit('localTrialDate marker not found')
text = text.replace(marker, marker + helpers, 1)
app.write_text(text)

(root / 'firestore.rules').write_text('''rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // One immutable trial claim per Firebase account. The client can create only
    // its own claim, and only after Firebase says the email is verified.
    match /haloTrialClaims/{userId} {
      allow get: if request.auth != null && request.auth.uid == userId;
      allow list: if false;

      allow create: if request.auth != null
                    && request.auth.uid == userId
                    && request.auth.token.email_verified == true
                    && request.resource.data.uid == request.auth.uid
                    && request.resource.data.version == 1;

      // A client must never be able to reset or remove its "trial used" record.
      allow update, delete: if false;
    }

    // This rules file intentionally grants no other Firestore access.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
''')

(root / 'firebase.json').write_text('''{
  "firestore": {
    "rules": "firestore.rules"
  }
}
''')

(root / 'FIRESTORE_TRIAL_SETUP.md').write_text('''# Halo Firestore trial claim setup

Halo keeps the 14-day countdown locally, but Firestore owns the one-time trial claim.
When a verified Firebase user presses **Start 14-Day Trial**, Halo atomically creates:

`haloTrialClaims/{firebaseUID}`

If the document already exists, the account has already claimed a trial and Halo refuses a new one.
The document is immutable from the client: Firestore rules deny update and delete.

## Deploy once

Use the same Firebase project as Halo Authentication:

```bash
npm install -g firebase-tools
firebase login
firebase use --add
firebase deploy --only firestore:rules
```

No Cloud Function is required and no LicenseSeat secret key is used for trials.
Halo obtains the Firebase project ID from the signed-in user's Firebase ID token and calls the Firestore REST API directly with that token.

## Firestore collection

The collection is created automatically on the first successful trial claim. Each claim stores the Firebase UID, Halo device fingerprint, start/expiry timestamps, source, and schema version.

Starting a trial requires internet access. Once started, the local trial can continue offline until its locally stored expiry.
''')

print('Added Firestore-backed one-time trial claims')
