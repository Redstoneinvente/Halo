import Foundation
import AppKit
import FirebaseAuth
import FirebaseCore
import FirebaseCrashlytics
import FirebaseFirestore

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

        guard firebaseAvailable else { return }

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
            Crashlytics.crashlytics().setCustomValue(installationID(), forKey: "halo_installation_id")
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

        guard let user = Auth.auth().currentUser else {
            errorMessage = "Sign in to your Halo account before sending feedback."
            return false
        }

        guard user.isEmailVerified else {
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
            let db = Firestore.firestore()
            let issueRef = db.collection("feedbackIssues").document()
            let reportRef = db.collection("feedbackReports").document(issueRef.documentID)

            let metadata = baseMetadata()
            let createdAt = FieldValue.serverTimestamp()

            var publicIssue: [String: Any] = [
                "schemaVersion": 1,
                "type": submission.kind.storageValue,
                "title": title,
                "description": details,
                "category": category.isEmpty ? "General" : category,
                "status": "received",
                "createdAt": createdAt,
                "updatedAt": createdAt,
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
                "issueID": issueRef.documentID,
                "uid": user.uid,
                "email": user.email ?? "",
                "type": submission.kind.storageValue,
                "context": context,
                "includeDiagnostics": submission.includeDiagnostics,
                "createdAt": createdAt,
                "previousExecutionCrashed": submission.kind == .crash && crashedDuringPreviousExecution
            ]

            if submission.includeDiagnostics {
                privateReport["diagnostics"] = safeDiagnostics()
                if crashDiagnosticsEnabled {
                    privateReport["diagnosticsInstallationID"] = installationID()
                }
            }

            let batch = db.batch()
            batch.setData(publicIssue, forDocument: issueRef)
            batch.setData(privateReport, forDocument: reportRef)

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                batch.commit { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }

            if crashDiagnosticsEnabled {
                let crashlytics = Crashlytics.crashlytics()
                crashlytics.setCustomValue(issueRef.documentID, forKey: "halo_latest_feedback_issue")
                crashlytics.log("Feedback submitted: \(submission.kind.storageValue)")
            }

            successMessage = "Thanks — your report was sent. Reference: \(issueRef.documentID)"
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
        firebaseAvailable = FirebaseApp.app() != nil
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
