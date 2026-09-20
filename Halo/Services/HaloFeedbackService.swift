import Foundation
import AppKit
import Combine
import MetricKit

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

private final class HaloMetricKitBridge: NSObject, MXMetricManagerSubscriber {
    weak var owner: HaloFeedbackService?

    init(owner: HaloFeedbackService) {
        self.owner = owner
        super.init()
    }

    func start() {
        MXMetricManager.shared.add(self)
    }

    func stop() {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        // Daily performance metrics are intentionally ignored for now.
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        Task { @MainActor [weak self] in
            self?.owner?.receiveMetricKitDiagnostics(payloads)
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
    private let lastMetricKitCrashKey = "HaloMetricKitLastCrashEndV1"
    private var latestCrashSummary: [String: String] = [:]
    private var metricKitBridge: HaloMetricKitBridge?
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
        firebaseAvailable = firebaseProjectID() != nil

        guard crashDiagnosticsEnabled else {
            crashedDuringPreviousExecution = false
            return
        }

        let bridge = HaloMetricKitBridge(owner: self)
        metricKitBridge = bridge
        bridge.start()
        receiveMetricKitDiagnostics(MXMetricManager.shared.pastDiagnosticPayloads)
    }

    func setCrashDiagnosticsEnabled(_ enabled: Bool) {
        crashDiagnosticsEnabled = enabled
        defaults.set(enabled, forKey: crashDiagnosticsKey)

        if enabled {
            if metricKitBridge == nil {
                let bridge = HaloMetricKitBridge(owner: self)
                metricKitBridge = bridge
                bridge.start()
            }
            receiveMetricKitDiagnostics(MXMetricManager.shared.pastDiagnosticPayloads)
        } else {
            metricKitBridge?.stop()
            metricKitBridge = nil
            latestCrashSummary = [:]
            crashedDuringPreviousExecution = false
        }
    }

    func select(_ kind: HaloFeedbackKind) {
        selectedKind = kind
        successMessage = nil
        errorMessage = nil
    }

    func logReliabilityEvent(_ message: String) {
        guard crashDiagnosticsEnabled else { return }
        let key = "HaloReliabilityLastEventV1"
        defaults.set(String(message.prefix(240)), forKey: key)
    }

    func recordNonFatal(_ error: Error, context: String? = nil) {
        guard crashDiagnosticsEnabled else { return }
        defaults.set(String(error.localizedDescription.prefix(500)), forKey: "HaloReliabilityLastNonFatalV1")
        if let context, !context.isEmpty {
            defaults.set(String(context.prefix(240)), forKey: "HaloReliabilityLastNonFatalContextV1")
        }
    }

    func receiveMetricKitDiagnostics(_ payloads: [MXDiagnosticPayload]) {
        guard crashDiagnosticsEnabled else { return }

        let lastHandled = defaults.object(forKey: lastMetricKitCrashKey) as? Date ?? .distantPast
        var newestCrashEnd: Date?
        var newestSummary: [String: String] = [:]

        for payload in payloads {
            guard let crashes = payload.crashDiagnostics, !crashes.isEmpty else { continue }
            guard payload.timeStampEnd > lastHandled else { continue }

            if newestCrashEnd == nil || payload.timeStampEnd > newestCrashEnd! {
                newestCrashEnd = payload.timeStampEnd
                newestSummary = metricKitSummary(from: crashes)
            }
        }

        guard let newestCrashEnd else { return }

        latestCrashSummary = newestSummary
        crashedDuringPreviousExecution = true

        // Mark this system payload as seen so Halo does not nag again on every launch.
        // The user can still submit a crash report manually from Feedback & Support.
        defaults.set(newestCrashEnd, forKey: lastMetricKitCrashKey)

        NotificationCenter.default.post(name: .init("HaloMetricKitCrashDetected"), object: nil)
    }

    func submit(_ submission: HaloFeedbackSubmission) async -> Bool {
        firebaseAvailable = firebaseProjectID() != nil
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
                var diagnostics = safeDiagnostics()
                if submission.kind == .crash {
                    latestCrashSummary.forEach { diagnostics[$0.key] = $0.value }
                }
                privateReport["diagnostics"] = diagnostics
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

            successMessage = "Thanks — your report was sent. Reference: \(issueID)"
            if submission.kind == .crash {
                crashedDuringPreviousExecution = false
                latestCrashSummary = [:]
            }
            return true
        } catch {
            errorMessage = "Could not send feedback: \(error.localizedDescription)"
            return false
        }
    }

    func safeDiagnosticsPreview() -> [(String, String)] {
        var preview = safeDiagnostics()
        if selectedKind == .crash {
            latestCrashSummary.forEach { preview[$0.key] = $0.value }
        }
        return preview
            .map { ($0.key, $0.value) }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    private func metricKitSummary(from crashes: [MXCrashDiagnostic]) -> [String: String] {
        guard let crash = crashes.last else { return [:] }

        var values: [String: String] = [
            "metricKitCrashCount": String(crashes.count)
        ]

        if let signal = crash.signal {
            values["crashSignal"] = signal.stringValue
        }
        if let exceptionType = crash.exceptionType {
            values["crashExceptionType"] = exceptionType.stringValue
        }
        if let exceptionCode = crash.exceptionCode {
            values["crashExceptionCode"] = exceptionCode.stringValue
        }
        if let terminationReason = crash.terminationReason, !terminationReason.isEmpty {
            values["crashTerminationReason"] = String(terminationReason.prefix(500))
        }

        return values
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
        diagnostics["diagnosticsSource"] = "Apple MetricKit"
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
