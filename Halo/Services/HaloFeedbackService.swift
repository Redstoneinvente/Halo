import Foundation
import AppKit
import Combine
import FirebaseCore
import FirebaseCrashlytics

enum HaloFeedbackKind: String, CaseIterable, Identifiable {
    case bug = "Bug"
    case feature = "Feature Request"
    case crash = "Crash"
    case other = "Other Feedback"

    var id: String { rawValue }

    var storageValue: String {
        switch self {
        case .bug: return "bug"
        case .feature: return "feature"
        case .crash: return "crash"
        case .other: return "other"
        }
    }

    var detailPrompt: String {
        switch self {
        case .bug: return "What happened?"
        case .feature: return "What would you like Halo to do?"
        case .crash: return "What were you doing just before Halo closed?"
        case .other: return "What would you like to tell us?"
        }
    }

    var contextPrompt: String {
        switch self {
        case .bug, .crash: return "Steps to reproduce (optional)"
        case .feature: return "What would this help you accomplish? (optional)"
        case .other: return "Anything else we should know? (optional)"
        }
    }
}

struct HaloFeedbackSubmission {
    var kind: HaloFeedbackKind
    var title: String
    var details: String
    var context: String
    var category: String
    var includeDiagnostics: Bool
}

private enum HaloFeedbackError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let value): return value
        }
    }
}

@MainActor
final class HaloFeedbackService: ObservableObject {
    static let shared = HaloFeedbackService()

    @Published var selectedKind: HaloFeedbackKind = .bug
    @Published private(set) var firebaseAvailable = false
    @Published private(set) var crashDiagnosticsEnabled: Bool
    @Published private(set) var crashedDuringPreviousExecution = false
    @Published private(set) var isSubmitting = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private let defaults = UserDefaults.standard
    private let crashDiagnosticsKey = "HaloCrashDiagnosticsEnabledV1"
    private let installationIDKey = "HaloDiagnosticsInstallationIDV1"
    private var started = false

    private init() {
        if defaults.object(forKey: crashDiagnosticsKey) == nil {
            defaults.set(true, forKey: crashDiagnosticsKey)
        }
        crashDiagnosticsEnabled = defaults.bool(forKey: crashDiagnosticsKey)
    }

    func start() {
        guard !started else { return }
        started = true
        configureFirebaseIfPossible()

        guard FirebaseApp.app() != nil else { return }

        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCrashlyticsCollectionEnabled(crashDiagnosticsEnabled)

        guard crashDiagnosticsEnabled else {
            crashlytics.deleteUnsentReports()
            crashedDuringPreviousExecution = false
            return
        }

        crashedDuringPreviousExecution = crashlytics.didCrashDuringPreviousExecution()
        let diagnostics = safeDiagnostics()
        crashlytics.setCustomValue(diagnostics["appVersion"] ?? "unknown", forKey: "halo_app_version")
        crashlytics.setCustomValue(diagnostics["appBuild"] ?? "unknown", forKey: "halo_app_build")
        crashlytics.setCustomValue(diagnostics["macOS"] ?? "unknown", forKey: "halo_macos")
        crashlytics.setCustomValue(diagnostics["architecture"] ?? "unknown", forKey: "halo_architecture")
        crashlytics.setCustomValue(installationID(), forKey: "halo_installation_id")
    }

    func setCrashDiagnosticsEnabled(_ enabled: Bool) {
        crashDiagnosticsEnabled = enabled
        defaults.set(enabled, forKey: crashDiagnosticsKey)

        guard FirebaseApp.app() != nil else {
            if !enabled { crashedDuringPreviousExecution = false }
            return
        }

        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCrashlyticsCollectionEnabled(enabled)
        if !enabled {
            crashlytics.deleteUnsentReports()
            crashedDuringPreviousExecution = false
            crashlytics.setUserID("")
        } else {
            crashlytics.setCustomValue(installationID(), forKey: "halo_installation_id")
        }
    }

    func select(_ kind: HaloFeedbackKind) {
        selectedKind = kind
        successMessage = nil
        errorMessage = nil
    }

    func logReliabilityEvent(_ message: String) {
        guard crashDiagnosticsEnabled, FirebaseApp.app() != nil else { return }
        Crashlytics.crashlytics().log(message)
    }

    func recordNonFatal(_ error: Error, context: String? = nil) {
        guard crashDiagnosticsEnabled, FirebaseApp.app() != nil else { return }
        if let context, !context.isEmpty {
            Crashlytics.crashlytics().setCustomValue(context, forKey: "halo_nonfatal_context")
        }
        Crashlytics.crashlytics().record(error: error)
    }

    func submit(_ submission: HaloFeedbackSubmission) async -> Bool {
        configureFirebaseIfPossible()
        successMessage = nil
        errorMessage = nil

        guard firebaseAvailable else {
            errorMessage = "Feedback is not available in this build because Firebase is not configured."
            return false
        }

        let account = HaloAccountManager.shared
        guard account.isSignedIn else {
            errorMessage = "Sign in to your Halo account before sending feedback."
            return false
        }

        guard account.emailVerified else {
            errorMessage = "Verify your Halo account email before sending feedback."
            return false
        }

        let title = submission.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = submission.details.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = submission.context.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = submission.category.trimmingCharacters(in: .whitespacesAndNewlines)

        guard title.count >= 4, title.count <= 120 else {
            errorMessage = "Use a title between 4 and 120 characters."
            return false
        }

        guard details.count >= 10, details.count <= 4_000 else {
            errorMessage = "Use a description between 10 and 4,000 characters."
            return false
        }

        guard context.count <= 6_000 else {
            errorMessage = "The extra context is too long."
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let token = try await account.validIDToken()
            let issueID = UUID().uuidString.lowercased()
            let metadata = baseMetadata()

            var publicIssue: [String: Any] = [
                "schemaVersion": 1,
                "type": submission.kind.storageValue,
                "title": title,
                "description": details,
                "category": category.isEmpty ? "General" : category,
                "status": "received",
                "appVersion": metadata["appVersion"] ?? "unknown",
                "appBuild": metadata["appBuild"] ?? "unknown",
                "platform": "macOS"
            ]

            // This document is intentionally safe for the public issue website.
            // Never add uid, email, device identifiers, diagnostics, file paths,
            // clipboard data, notes, calendar content, or integration payloads here.
            if submission.kind == .crash {
                publicIssue["crashRelated"] = true
            }

            var privateReport: [String: Any] = [
                "schemaVersion": 1,
                "issueID": issueID,
                "uid": account.userID,
                "email": account.email,
                "type": submission.kind.storageValue,
                "context": context,
                "includeDiagnostics": submission.includeDiagnostics,
                "previousExecutionCrashed": submission.kind == .crash && crashedDuringPreviousExecution
            ]

            if submission.includeDiagnostics {
                privateReport["diagnostics"] = safeDiagnostics()
                if crashDiagnosticsEnabled {
                    privateReport["diagnosticsInstallationID"] = installationID()
                }
            }

            try await commitFeedback(
                issueID: issueID,
                idToken: token,
                publicIssue: publicIssue,
                privateReport: privateReport
            )

            if crashDiagnosticsEnabled, FirebaseApp.app() != nil {
                let crashlytics = Crashlytics.crashlytics()
                crashlytics.setCustomValue(issueID, forKey: "halo_latest_feedback_issue")
                crashlytics.log("Feedback submitted: \(submission.kind.storageValue)")
            }

            successMessage = "Thanks — your report was sent. Reference: \(issueID)"
            if submission.kind == .crash {
                crashedDuringPreviousExecution = false
            }
            return true
        } catch {
            errorMessage = "Could not send feedback: \(error.localizedDescription)"
            return false
        }
    }

    func safeDiagnosticsPreview() -> [(String, String)] {
        safeDiagnostics()
            .map { ($0.key, $0.value) }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    private func configureFirebaseIfPossible() {
        if FirebaseApp.app() == nil,
           let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
        }
        firebaseAvailable = firebaseProjectID() != nil
    }

    private func firebaseProjectID() -> String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let values = NSDictionary(contentsOfFile: path),
              let projectID = values["PROJECT_ID"] as? String,
              !projectID.isEmpty else {
            return nil
        }
        return projectID
    }

    private func commitFeedback(
        issueID: String,
        idToken: String,
        publicIssue: [String: Any],
        privateReport: [String: Any]
    ) async throws {
        guard let projectID = firebaseProjectID() else {
            throw HaloFeedbackError.message("Firebase project configuration is missing.")
        }

        let database = "projects/\(projectID)/databases/(default)"
        guard let url = URL(string: "https://firestore.googleapis.com/v1/\(database)/documents:commit") else {
            throw HaloFeedbackError.message("Could not create the Firestore endpoint.")
        }

        let issueName = "\(database)/documents/feedbackIssues/\(issueID)"
        let reportName = "\(database)/documents/feedbackReports/\(issueID)"

        let issueWrite: [String: Any] = [
            "update": [
                "name": issueName,
                "fields": firestoreFields(publicIssue)
            ],
            "updateTransforms": [
                ["fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"],
                ["fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"]
            ],
            "currentDocument": ["exists": false]
        ]

        let reportWrite: [String: Any] = [
            "update": [
                "name": reportName,
                "fields": firestoreFields(privateReport)
            ],
            "updateTransforms": [
                ["fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"]
            ],
            "currentDocument": ["exists": false]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["writes": [issueWrite, reportWrite]],
            options: []
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HaloFeedbackError.message("No response from Firestore.")
        }

        guard (200..<300).contains(http.statusCode) else {
            throw HaloFeedbackError.message(
                firestoreErrorMessage(from: data) ?? "Firestore request failed (\(http.statusCode))."
            )
        }
    }

    private func firestoreFields(_ values: [String: Any]) -> [String: Any] {
        var fields: [String: Any] = [:]
        for (key, value) in values {
            fields[key] = firestoreValue(value)
        }
        return fields
    }

    private func firestoreValue(_ value: Any) -> [String: Any] {
        if let value = value as? String {
            return ["stringValue": value]
        }
        if let value = value as? Bool {
            return ["booleanValue": value]
        }
        if let value = value as? Int {
            return ["integerValue": String(value)]
        }
        if let value = value as? [String: String] {
            let nested = value.reduce(into: [String: Any]()) { partialResult, pair in
                partialResult[pair.key] = ["stringValue": pair.value]
            }
            return ["mapValue": ["fields": nested]]
        }
        if let value = value as? [String: Any] {
            return ["mapValue": ["fields": firestoreFields(value)]]
        }
        return ["stringValue": String(describing: value)]
    }

    private func firestoreErrorMessage(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = root["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }

    private func baseMetadata() -> [String: String] {
        let bundle = Bundle.main
        return [
            "appVersion": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "appBuild": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        ]
    }

    private func safeDiagnostics() -> [String: String] {
        var diagnostics = baseMetadata()
        diagnostics["macOS"] = ProcessInfo.processInfo.operatingSystemVersionString
        diagnostics["architecture"] = architectureName
        diagnostics["displayCount"] = String(NSScreen.screens.count)
        diagnostics["notchedDisplayCount"] = String(NSScreen.screens.filter { $0.safeAreaInsets.top > 0 }.count)
        diagnostics["distribution"] = distributionName
        return diagnostics
    }

    private var architectureName: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    private var distributionName: String {
        #if HALO_APP_STORE
        return "App Store"
        #else
        return "Direct"
        #endif
    }

    private func installationID() -> String {
        if let existing = defaults.string(forKey: installationIDKey), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        defaults.set(created, forKey: installationIDKey)
        return created
    }
}
