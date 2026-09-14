from pathlib import Path

path = Path("Halo/Core/AppStore.swift")
text = path.read_text()

def replace_once(old: str, new: str, label: str):
    global text
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"{label}: expected 1 match, found {n}")
    text = text.replace(old, new, 1)

replace_once(
'''    func restoreAndValidate() async {
        // Press licenses are a separate Halo entitlement and must never be sent to LicenseSeat.
        if restorePressLicense() { return }
''',
'''    func restoreAndValidate() async {
        // Press licenses are a separate Halo entitlement and must never be sent to LicenseSeat.
        if await restorePressLicense() { return }
''',
"restore await"
)

replace_once(
'''        // PK_ keys are Halo press licenses. Keep this branch before every LicenseSeat guard/request.
        if Self.isPressLicenseKey(cleaned) {
            guard HaloAccountManager.shared.isSignedIn,
                  !HaloAccountManager.shared.userID.isEmpty else {
                errorMessage = "Sign in to your Halo account before activating a press license."
                return
            }
            isBusy = true; state = .checking; errorMessage = nil; notice = nil
            defer { isBusy = false }
            guard HaloKeychain.set(cleaned, for: pressLicenseKey),
                  HaloKeychain.set(HaloAccountManager.shared.userID, for: pressLicenseOwnerKey) else {
                state = .invalid("Halo could not save the press license securely on this Mac.")
                errorMessage = "Halo could not save the press license securely on this Mac."
                return
            }
            applyPressLicense(cleaned)
            notice = "Press license activated on this Mac (test mode)."
            return
        }
''',
'''        // PK_ keys are Halo press licenses. Keep this branch before every LicenseSeat guard/request.
        if Self.isPressLicenseKey(cleaned) {
            isBusy = true; state = .checking; errorMessage = nil; notice = nil
            defer { isBusy = false }
            do {
                try await activatePressLicense(cleaned)
                notice = "Press license activated on this Mac."
            } catch {
                let message = readable(error)
                details = HaloLicenseDetails(status: "invalid", plan: "Press", expiresAt: nil, activeSeats: 0, seatLimit: 1)
                state = .invalid(message)
                errorMessage = message
            }
            return
        }
''',
"activate press branch"
)

replace_once(
'''    func validate() async {
        if restorePressLicense() { return }
''',
'''    func validate() async {
        if await restorePressLicense() { return }
''',
"validate await"
)

replace_once(
'''    @discardableResult
    private func restorePressLicense() -> Bool {
        guard let key = HaloKeychain.string(for: pressLicenseKey),
              Self.isPressLicenseKey(key) else { return false }
        let account = HaloAccountManager.shared
        guard account.isSignedIn, !account.userID.isEmpty else { return false }
        guard let owner = HaloKeychain.string(for: pressLicenseOwnerKey),
              owner == account.userID else {
            licenseHint = Self.hint(key)
            details = HaloLicenseDetails(status: "account_mismatch", plan: "Press", expiresAt: nil, activeSeats: 1, seatLimit: 1)
            state = .invalid("This press license belongs to another Halo account.")
            return true
        }
        applyPressLicense(key)
        return true
    }

    private func applyPressLicense(_ key: String) {
        trialExpiryTask?.cancel()
        licenseHint = Self.hint(key)
        details = HaloLicenseDetails(status: "active", plan: "Press", expiresAt: nil, activeSeats: 1, seatLimit: 1)
        state = .valid(plan: "Press")
    }
''',
'''    @discardableResult
    private func restorePressLicense() async -> Bool {
        guard let key = HaloKeychain.string(for: pressLicenseKey),
              Self.isPressLicenseKey(key) else { return false }

        let account = HaloAccountManager.shared
        guard account.isSignedIn, !account.userID.isEmpty else {
            licenseHint = Self.hint(key)
            details = HaloLicenseDetails(status: "account_required", plan: "Press", expiresAt: nil, activeSeats: 0, seatLimit: 1)
            state = .invalid("Sign in to the Halo account that activated this press license.")
            return true
        }

        do {
            let token = try await account.validIDToken()
            let document = try await fetchPressLicense(key: key, token: token)
            let expiresAt = try validatePressLicenseDocument(document, key: key, requireBound: true)
            guard HaloKeychain.set(account.userID, for: pressLicenseOwnerKey) else {
                throw HaloCommercialError.message("Halo could not save the press license owner securely on this Mac.")
            }
            applyPressLicense(key, expiresAt: expiresAt)
        } catch {
            let message = readable(error)
            licenseHint = Self.hint(key)
            details = HaloLicenseDetails(status: "invalid", plan: "Press", expiresAt: nil, activeSeats: 0, seatLimit: 1)
            state = .invalid(message)
            errorMessage = message
        }
        return true
    }

    private func activatePressLicense(_ key: String) async throws {
        let account = HaloAccountManager.shared
        guard account.isSignedIn, !account.userID.isEmpty else {
            throw HaloCommercialError.message("Sign in to your Halo account before activating a press license.")
        }
        guard !account.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HaloCommercialError.message("Your Halo account does not have an email address.")
        }

        let token = try await account.validIDToken()
        var document = try await fetchPressLicense(key: key, token: token)
        _ = try validatePressLicenseDocument(document, key: key, requireBound: false)

        if pressBool(document, "bound") != true {
            do {
                try await bindPressLicense(key: key, document: document, token: token)
            } catch {
                document = try await fetchPressLicense(key: key, token: token)
            }
        }

        let expiresAt = try validatePressLicenseDocument(document, key: key, requireBound: true)
        guard HaloKeychain.set(key, for: pressLicenseKey),
              HaloKeychain.set(account.userID, for: pressLicenseOwnerKey) else {
            throw HaloCommercialError.message("Halo could not save the press license securely on this Mac.")
        }
        applyPressLicense(key, expiresAt: expiresAt)
    }

    private func validatePressLicenseDocument(
        _ document: [String: Any],
        key: String,
        requireBound: Bool
    ) throws -> Date? {
        guard pressString(document, "licenseType")?.lowercased() == "press" else {
            throw HaloCommercialError.message("This is not a Halo press license.")
        }
        guard pressBool(document, "active") == true else {
            throw HaloCommercialError.message("This press license is disabled.")
        }
        guard pressBool(document, "revoked") != true else {
            throw HaloCommercialError.message("This press license has been revoked.")
        }

        let expiresAt = pressTimestamp(document, "expiresAt")
        if let expiresAt, Date() >= expiresAt {
            throw HaloCommercialError.message("This press license has expired.")
        }

        let bound = pressBool(document, "bound") == true
        if requireBound || bound {
            guard bound else {
                throw HaloCommercialError.message("This press license has not been activated yet.")
            }

            let account = HaloAccountManager.shared
            let expectedEmail = account.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let boundUID = pressString(document, "boundUid") ?? ""
            let boundEmail = (pressString(document, "boundEmail") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let boundDevice = pressString(document, "boundDeviceId") ?? ""

            guard boundUID == account.userID else {
                throw HaloCommercialError.message("This press license is already bound to another Halo account.")
            }
            guard boundEmail == expectedEmail else {
                throw HaloCommercialError.message("This press license is already bound to another email address.")
            }
            guard boundDevice == fingerprint() else {
                throw HaloCommercialError.message("This press license is already bound to another Mac.")
            }
        }

        return expiresAt
    }

    private func fetchPressLicense(key: String, token: String) async throws -> [String: Any] {
        guard let projectID = firebaseProjectID(from: token), !projectID.isEmpty else {
            throw HaloCommercialError.message("Halo could not identify the Firebase project.")
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard let encodedProject = projectID.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(encodedProject)/databases/(default)/documents/pressLicenses/\(encodedKey)") else {
            throw HaloCommercialError.message("Halo could not prepare the press license lookup.")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HaloCommercialError.message("No response from Firestore.")
        }
        if http.statusCode == 404 {
            throw HaloCommercialError.message("Press license was not found.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HaloCommercialError.message(firestorePressError(data, statusCode: http.statusCode))
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HaloCommercialError.message("Firestore returned an unreadable press license.")
        }
        return root
    }

    private func bindPressLicense(key: String, document: [String: Any], token: String) async throws {
        let account = HaloAccountManager.shared
        guard let projectID = firebaseProjectID(from: token), !projectID.isEmpty,
              let updateTime = document["updateTime"] as? String,
              let documentName = document["name"] as? String else {
            throw HaloCommercialError.message("The press license record is incomplete.")
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard let encodedProject = projectID.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(encodedProject)/databases/(default)/documents:commit") else {
            throw HaloCommercialError.message("Halo could not prepare the press license activation.")
        }

        let email = account.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let body: [String: Any] = [
            "writes": [[
                "update": [
                    "name": documentName,
                    "fields": [
                        "bound": ["booleanValue": true],
                        "boundUid": ["stringValue": account.userID],
                        "boundEmail": ["stringValue": email],
                        "boundDeviceId": ["stringValue": fingerprint()]
                    ]
                ],
                "updateMask": [
                    "fieldPaths": ["bound", "boundUid", "boundEmail", "boundDeviceId", "boundAt", "updatedAt"]
                ],
                "currentDocument": ["updateTime": updateTime],
                "updateTransforms": [
                    ["fieldPath": "boundAt", "setToServerValue": "REQUEST_TIME"],
                    ["fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"]
                ]
            ]]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HaloCommercialError.message("No response from Firestore while activating the press license.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HaloCommercialError.message(firestorePressError(data, statusCode: http.statusCode))
        }
    }

    private func pressField(_ document: [String: Any], _ name: String) -> [String: Any]? {
        guard let fields = document["fields"] as? [String: Any] else { return nil }
        return fields[name] as? [String: Any]
    }

    private func pressString(_ document: [String: Any], _ name: String) -> String? {
        pressField(document, name)?["stringValue"] as? String
    }

    private func pressBool(_ document: [String: Any], _ name: String) -> Bool? {
        pressField(document, name)?["booleanValue"] as? Bool
    }

    private func pressTimestamp(_ document: [String: Any], _ name: String) -> Date? {
        guard let raw = pressField(document, name)?["timestampValue"] as? String else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    private func firestorePressError(_ data: Data, statusCode: Int) -> String {
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let error = root?["error"] as? [String: Any]
        let status = (error?["status"] as? String) ?? ""
        if status == "PERMISSION_DENIED" || statusCode == 403 {
            return "Halo is not allowed to access this press license. Check the Firestore press-license rules."
        }
        if status == "UNAUTHENTICATED" || statusCode == 401 {
            return "Your Halo session expired. Sign in again and retry."
        }
        if status == "FAILED_PRECONDITION" || status == "ABORTED" || statusCode == 409 {
            return "This press license was activated by another request. Halo will re-check its binding."
        }
        return (error?["message"] as? String) ?? "Firestore press license request failed (\(statusCode))."
    }

    private func applyPressLicense(_ key: String, expiresAt: Date?) {
        trialExpiryTask?.cancel()
        licenseHint = Self.hint(key)
        details = HaloLicenseDetails(status: "active", plan: "Press", expiresAt: expiresAt, activeSeats: 1, seatLimit: 1)
        state = .valid(plan: "Press")
        errorMessage = nil
    }
''',
"replace press helpers"
)

replace_once(
'''    func clearLocalLicense() {
        HaloKeychain.remove(licenseKeyKey)
        licenseHint = ""
''',
'''    func clearLocalLicense() {
        HaloKeychain.remove(licenseKeyKey)
        HaloKeychain.remove(pressLicenseKey)
        HaloKeychain.remove(pressLicenseOwnerKey)
        licenseHint = ""
''',
"clear local press"
)

path.write_text(text)
