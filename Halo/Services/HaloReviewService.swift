import Foundation
import Combine

struct HaloCustomerReview: Identifiable, Equatable {
    let id: String
    var name: String
    var title: String
    var review: String
    var rating: Int
    var source: String
    var sourceURL: String
    var avatarURL: String
    var published: Bool
    var featured: Bool
    var verifiedPurchase: Bool
    var date: Date?
    var createdAt: Date?
    var updatedAt: Date?
}

struct HaloReviewDraft: Equatable {
    var name = ""
    var title = ""
    var review = ""
    var rating = 5
}

private enum HaloReviewError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let value): return value
        }
    }
}

@MainActor
final class HaloReviewService: ObservableObject {
    static let shared = HaloReviewService()

    @Published private(set) var reviews: [HaloCustomerReview] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var notice: String?
    @Published var errorMessage: String?

    private init() {}

    func refresh() async {
        notice = nil
        errorMessage = nil

        let account = HaloAccountManager.shared
        guard account.isSignedIn else {
            reviews = []
            return
        }
        guard account.emailVerified else {
            reviews = []
            errorMessage = "Verify your Halo account email before loading or submitting reviews."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await account.validIDToken()
            reviews = try await loadReviews(uid: account.userID, idToken: token)
        } catch {
            errorMessage = readable(error)
        }
    }

    func submit(_ draft: HaloReviewDraft) async -> Bool {
        notice = nil
        errorMessage = nil

        let account = HaloAccountManager.shared
        guard account.isSignedIn else {
            errorMessage = "Sign in to your Halo account before leaving a review."
            return false
        }
        guard account.emailVerified else {
            errorMessage = "Verify your Halo account email before leaving a review."
            return false
        }

        guard let cleaned = validated(draft) else { return false }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let token = try await account.validIDToken()
            let id = UUID().uuidString.lowercased()
            try await createReview(
                id: id,
                uid: account.userID,
                draft: cleaned,
                idToken: token
            )
            notice = "Thanks for reviewing Halo. Your review was submitted for approval."
            NotificationCenter.default.post(name: .init("HaloReviewSubmitted"), object: nil)
            await refreshPreservingNotice()
            return true
        } catch {
            errorMessage = readable(error)
            return false
        }
    }

    func update(_ review: HaloCustomerReview, with draft: HaloReviewDraft) async -> Bool {
        notice = nil
        errorMessage = nil

        let account = HaloAccountManager.shared
        guard account.isSignedIn, account.userID.count > 0 else {
            errorMessage = "Sign in to your Halo account before editing a review."
            return false
        }
        guard account.emailVerified else {
            errorMessage = "Verify your Halo account email before editing a review."
            return false
        }
        guard reviews.contains(where: { $0.id == review.id }) else {
            errorMessage = "That review is no longer available."
            return false
        }
        guard let cleaned = validated(draft) else { return false }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let token = try await account.validIDToken()
            try await updateReview(id: review.id, draft: cleaned, idToken: token)
            notice = review.published
                ? "Changes saved. Because the review changed, it has been sent back for approval."
                : "Review updated."
            await refreshPreservingNotice()
            return true
        } catch {
            errorMessage = readable(error)
            return false
        }
    }

    func delete(_ review: HaloCustomerReview) async -> Bool {
        notice = nil
        errorMessage = nil

        let account = HaloAccountManager.shared
        guard account.isSignedIn, account.emailVerified else {
            errorMessage = "Sign in with a verified Halo account before deleting a review."
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let token = try await account.validIDToken()
            try await deleteReview(id: review.id, idToken: token)
            notice = "Review deleted."
            await refreshPreservingNotice()
            return true
        } catch {
            errorMessage = readable(error)
            return false
        }
    }

    private func refreshPreservingNotice() async {
        let savedNotice = notice
        await refresh()
        notice = savedNotice
    }

    private func validated(_ draft: HaloReviewDraft) -> HaloReviewDraft? {
        var value = draft
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        value.review = value.review.trimmingCharacters(in: .whitespacesAndNewlines)
        value.rating = min(5, max(1, value.rating))

        guard value.name.count >= 2, value.name.count <= 60 else {
            errorMessage = "Use a display name between 2 and 60 characters."
            return nil
        }
        guard value.title.count <= 100 else {
            errorMessage = "Keep the review title under 100 characters."
            return nil
        }
        guard value.review.count >= 10, value.review.count <= 2_000 else {
            errorMessage = "Write between 10 and 2,000 characters."
            return nil
        }
        return value
    }

    private func firebaseProjectID() throws -> String {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let values = NSDictionary(contentsOfFile: path),
              let projectID = values["PROJECT_ID"] as? String,
              !projectID.isEmpty else {
            throw HaloReviewError.message("Firebase project configuration is missing.")
        }
        return projectID
    }

    private func databasePath() throws -> String {
        "projects/\(try firebaseProjectID())/databases/(default)"
    }

    private func loadReviews(uid: String, idToken: String) async throws -> [HaloCustomerReview] {
        let database = try databasePath()
        guard let url = URL(string: "https://firestore.googleapis.com/v1/\(database)/documents:runQuery") else {
            throw HaloReviewError.message("Could not create the Firestore endpoint.")
        }

        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "customerReviews"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "uid"],
                        "op": "EQUAL",
                        "value": ["stringValue": uid]
                    ]
                ]
            ]
        ]

        let data = try await send(url: url, idToken: idToken, body: body)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return rows.compactMap { row -> HaloCustomerReview? in
            guard let document = row["document"] as? [String: Any],
                  let fields = document["fields"] as? [String: Any],
                  let name = document["name"] as? String else { return nil }

            let id = name.split(separator: "/").last.map(String.init) ?? ""
            guard !id.isEmpty else { return nil }

            return HaloCustomerReview(
                id: id,
                name: string(fields["name"]) ?? "Halo user",
                title: string(fields["title"]) ?? "",
                review: string(fields["review"]) ?? "",
                rating: min(5, max(1, integer(fields["rating"]) ?? 5)),
                source: string(fields["source"]) ?? "Halo app",
                sourceURL: string(fields["sourceUrl"]) ?? "",
                avatarURL: string(fields["avatarUrl"]) ?? "",
                published: boolean(fields["published"]) ?? false,
                featured: boolean(fields["featured"]) ?? false,
                verifiedPurchase: boolean(fields["verifiedPurchase"]) ?? false,
                date: timestamp(fields["date"]),
                createdAt: timestamp(fields["createdAt"]),
                updatedAt: timestamp(fields["updatedAt"])
            )
        }
        .sorted {
            let lhs = $0.updatedAt ?? $0.date ?? .distantPast
            let rhs = $1.updatedAt ?? $1.date ?? .distantPast
            return lhs > rhs
        }
    }

    private func createReview(id: String, uid: String, draft: HaloReviewDraft, idToken: String) async throws {
        let database = try databasePath()
        guard let url = URL(string: "https://firestore.googleapis.com/v1/\(database)/documents:commit") else {
            throw HaloReviewError.message("Could not create the Firestore endpoint.")
        }

        let name = "\(database)/documents/customerReviews/\(id)"
        let fields: [String: Any] = [
            "schemaVersion": ["integerValue": "1"],
            "uid": ["stringValue": uid],
            "name": ["stringValue": draft.name],
            "title": ["stringValue": draft.title],
            "review": ["stringValue": draft.review],
            "rating": ["integerValue": String(draft.rating)],
            "source": ["stringValue": "Halo app"],
            "sourceUrl": ["stringValue": ""],
            "avatarUrl": ["stringValue": ""],
            "published": ["booleanValue": false],
            "featured": ["booleanValue": false],
            "verifiedPurchase": ["booleanValue": false]
        ]

        let write: [String: Any] = [
            "update": ["name": name, "fields": fields],
            "updateTransforms": [
                ["fieldPath": "date", "setToServerValue": "REQUEST_TIME"],
                ["fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"],
                ["fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"]
            ],
            "currentDocument": ["exists": false]
        ]

        _ = try await send(url: url, idToken: idToken, body: ["writes": [write]])
    }

    private func updateReview(id: String, draft: HaloReviewDraft, idToken: String) async throws {
        let database = try databasePath()
        guard let url = URL(string: "https://firestore.googleapis.com/v1/\(database)/documents:commit") else {
            throw HaloReviewError.message("Could not create the Firestore endpoint.")
        }

        let name = "\(database)/documents/customerReviews/\(id)"
        let write: [String: Any] = [
            "update": [
                "name": name,
                "fields": [
                    "name": ["stringValue": draft.name],
                    "title": ["stringValue": draft.title],
                    "review": ["stringValue": draft.review],
                    "rating": ["integerValue": String(draft.rating)],
                    "published": ["booleanValue": false]
                ]
            ],
            "updateMask": [
                "fieldPaths": ["name", "title", "review", "rating", "published"]
            ],
            "updateTransforms": [
                ["fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME"]
            ],
            "currentDocument": ["exists": true]
        ]

        _ = try await send(url: url, idToken: idToken, body: ["writes": [write]])
    }

    private func deleteReview(id: String, idToken: String) async throws {
        let database = try databasePath()
        guard let url = URL(string: "https://firestore.googleapis.com/v1/\(database)/documents:commit") else {
            throw HaloReviewError.message("Could not create the Firestore endpoint.")
        }

        let name = "\(database)/documents/customerReviews/\(id)"
        let write: [String: Any] = [
            "delete": name,
            "currentDocument": ["exists": true]
        ]
        _ = try await send(url: url, idToken: idToken, body: ["writes": [write]])
    }

    private func send(url: URL, idToken: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HaloReviewError.message("No response from Firestore.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HaloReviewError.message(
                firestoreErrorMessage(from: data) ?? "Firestore request failed (\(http.statusCode))."
            )
        }
        return data
    }

    private func string(_ field: Any?) -> String? {
        (field as? [String: Any])?["stringValue"] as? String
    }

    private func boolean(_ field: Any?) -> Bool? {
        (field as? [String: Any])?["booleanValue"] as? Bool
    }

    private func integer(_ field: Any?) -> Int? {
        guard let raw = (field as? [String: Any])?["integerValue"] else { return nil }
        if let value = raw as? String { return Int(value) }
        if let value = raw as? Int { return value }
        return nil
    }

    private func timestamp(_ field: Any?) -> Date? {
        guard let raw = (field as? [String: Any])?["timestampValue"] as? String else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    private func firestoreErrorMessage(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = root["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }

    private func readable(_ error: Error) -> String {
        (error as? HaloReviewError)?.errorDescription ?? error.localizedDescription
    }
}

@MainActor
final class HaloReviewPromptCoordinator: ObservableObject {
    static let shared = HaloReviewPromptCoordinator()

    @Published private(set) var isPresented = false

    private let defaults = UserDefaults.standard
    private let suppressedKey = "HaloReviewPromptSuppressedV1"
    private let completedKey = "HaloReviewPromptCompletedV1"
    /// Temporary QA mode. While enabled the notch review nudge appears after every
    /// app launch regardless of persisted suppression/completion state.
    private let forceLaunchPromptForTesting = true
    private var started = false
    private var evaluationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        NotificationCenter.default.publisher(for: .init("HaloReviewSubmitted"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.defaults.set(true, forKey: self.completedKey)
                self.dismiss()
            }
            .store(in: &cancellables)

        // QA cadence: 10 seconds after launch, then wait for Halo's surface runtime.
        // This makes the test deterministic even if startup verification takes >10 seconds.
        evaluationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled, let self else { return }

            while !HaloRuntimeGate.shared.isReady {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
            }

            await self.evaluateAndPresent()
        }
    }

    func presentForTesting() {
        guard !isPresented else { return }
        present()
    }

    func openReviewCenter() {
        dismiss()
        NotificationCenter.default.post(name: .init("HaloOpenSettings"), object: nil)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .init("HaloOpenReviews"), object: nil)
        }
    }

    func dontRemind() {
        defaults.set(true, forKey: suppressedKey)
        dismiss()
    }

    func dismiss() {
        if isPresented { isPresented = false }
    }

    private func evaluateAndPresent() async {
        guard HaloRuntimeGate.shared.isReady else { return }

        if forceLaunchPromptForTesting {
            // Deliberately ignore old "don't remind me" and completed-review flags during QA.
            // The user can still dismiss this launch's prompt normally.
            present()
            return
        }

        guard !defaults.bool(forKey: suppressedKey),
              !defaults.bool(forKey: completedKey) else { return }

        let account = HaloAccountManager.shared

        // Production behavior: if this signed-in account already reviewed Halo, do not nag.
        if account.isSignedIn, account.emailVerified {
            await HaloReviewService.shared.refresh()
            guard HaloReviewService.shared.reviews.isEmpty else {
                defaults.set(true, forKey: completedKey)
                return
            }
        }

        present()
    }

    private func present() {
        // The review nudge is intentionally persistent once shown. It stays open until
        // the user chooses Review or Don't remind me, rather than collapsing on a timer.
        isPresented = true
    }
}
