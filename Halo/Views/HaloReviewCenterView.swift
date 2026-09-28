import SwiftUI

@MainActor
struct HaloReviewCenterView: View {
    @ObservedObject private var reviews = HaloReviewService.shared
    @ObservedObject private var account = HaloAccountManager.shared

    @State private var draft = HaloReviewDraft()
    @State private var editingReviewID: String?
    @State private var pendingDelete: HaloCustomerReview?

    @State private var authEmail = ""
    @State private var authPassword = ""
    @State private var creatingAccount = false

    var body: some View {
        Group {
            Section("Review Halo") {
                Text("Tell other people what Halo is actually like to use. Reviews submitted here can appear on the Halo website after moderation.")
                    .font(.callout)

                reviewIdentity

                if account.isSignedIn && account.emailVerified {
                    reviewComposer
                }

                if let notice = reviews.notice {
                    Label(notice, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let error = reviews.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            Section("Your reviews") {
                if !account.isSignedIn {
                    Text("Sign in to manage reviews you have already submitted.")
                        .foregroundStyle(.secondary)
                } else if !account.emailVerified {
                    Text("Verify your email to load and manage your reviews.")
                        .foregroundStyle(.secondary)
                } else if reviews.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading your reviews…")
                            .foregroundStyle(.secondary)
                    }
                } else if reviews.reviews.isEmpty {
                    Text("You have not submitted a review yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(reviews.reviews) { review in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(review.title.isEmpty ? "Halo review" : review.title)
                                        .font(.headline)
                                    Text(String(repeating: "★", count: review.rating))
                                        .foregroundStyle(Color.accentColor)
                                        .accessibilityLabel("\(review.rating) out of 5 stars")
                                }
                                Spacer()
                                reviewStatus(review)
                            }

                            Text(review.review)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)

                            if let date = review.updatedAt ?? review.date {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            HStack(spacing: 8) {
                                Button("Edit") {
                                    beginEditing(review)
                                }
                                .buttonStyle(.bordered)

                                Button("Delete", role: .destructive) {
                                    pendingDelete = review
                                }
                                .buttonStyle(.bordered)
                            }
                            .controlSize(.small)
                        }
                        .padding(.vertical, 5)
                    }
                }

                if account.isSignedIn && account.emailVerified && !reviews.isLoading {
                    Button {
                        Task { await reviews.refresh() }
                    } label: {
                        Label("Refresh Reviews", systemImage: "arrow.clockwise")
                    }
                    .disabled(reviews.isSubmitting)
                }
            }
        }
        .task {
            if account.isSignedIn && account.emailVerified {
                await reviews.refresh()
            }
        }
        .onChange(of: account.isSignedIn) { signedIn in
            guard signedIn else {
                resetDraft()
                return
            }

            authPassword = ""
            if draft.name.isEmpty {
                draft.name = suggestedDisplayName
            }

            if account.emailVerified {
                Task { await reviews.refresh() }
            }
        }
        .onChange(of: account.emailVerified) { verified in
            if verified {
                if draft.name.isEmpty {
                    draft.name = suggestedDisplayName
                }
                Task { await reviews.refresh() }
            }
        }
        .alert(
            "Delete this review?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let review = pendingDelete else { return }
                pendingDelete = nil
                Task {
                    _ = await reviews.delete(review)
                    if editingReviewID == review.id {
                        resetDraft()
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("This removes the review from your Halo account and from the website if it was published.")
        }
    }

    @ViewBuilder
    private var reviewIdentity: some View {
        if !account.isConfigured {
            Label("Review accounts are unavailable because Firebase is not configured in this build.", systemImage: "wrench.and.screwdriver")
                .foregroundStyle(.secondary)
        } else if !account.isSignedIn {
            VStack(alignment: .leading, spacing: 10) {
                Label("Use a Halo account to own your review.", systemImage: "person.crop.circle")
                    .font(.headline)

                Text(HaloDistribution.current.supportsAppStoreLicensing
                     ? "Your App Store purchase still stays with Apple. This lightweight Halo account is only used so you can submit, edit, or delete your review later."
                     : "Your Halo account lets you submit, edit, and delete your own review.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Account", selection: $creatingAccount) {
                    Text("Sign In").tag(false)
                    Text("Create Account").tag(true)
                }
                .pickerStyle(.segmented)

                TextField("Email", text: $authEmail)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $authPassword)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button(creatingAccount ? "Create Halo Account" : "Sign In") {
                        Task {
                            if creatingAccount {
                                await account.signUp(email: authEmail, password: authPassword)
                            } else {
                                await account.signIn(email: authEmail, password: authPassword)
                            }
                            if account.isSignedIn {
                                authPassword = ""
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(account.isBusy || authEmail.isEmpty || authPassword.isEmpty)

                    if !creatingAccount {
                        Button("Forgot Password?") {
                            Task { await account.resetPassword(email: authEmail) }
                        }
                        .disabled(account.isBusy || authEmail.isEmpty)
                    }

                    if account.isBusy {
                        ProgressView().controlSize(.small)
                    }
                }

                Text("Your account email is never shown with the public review.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } else if !account.emailVerified {
            VStack(alignment: .leading, spacing: 9) {
                Label("Verify your email before submitting a review.", systemImage: "envelope.badge")
                    .foregroundStyle(.orange)

                if !account.email.isEmpty {
                    Text(account.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Send Verification Email") {
                        Task { await account.sendVerificationEmail() }
                    }
                    .disabled(account.isBusy)

                    Button("I've Verified It") {
                        Task { await account.refreshVerificationStatus() }
                    }
                    .disabled(account.isBusy)

                    Button("Sign Out") {
                        account.signOut()
                    }

                    if account.isBusy {
                        ProgressView().controlSize(.small)
                    }
                }
            }
        } else {
            HStack {
                Label(account.email.isEmpty ? "Signed in" : account.email, systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Sign Out") {
                    account.signOut()
                    reviews.notice = nil
                    reviews.errorMessage = nil
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }

        if let notice = account.notice {
            Text(notice)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let error = account.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var reviewComposer: some View {
        TextField("Display name", text: $draft.name)
            .textFieldStyle(.roundedBorder)

        TextField("Short title (optional)", text: $draft.title)
            .textFieldStyle(.roundedBorder)

        Picker("Rating", selection: $draft.rating) {
            ForEach(1...5, id: \.self) { rating in
                Text("\(rating) ★").tag(rating)
            }
        }
        .pickerStyle(.segmented)

        VStack(alignment: .leading, spacing: 6) {
            Text("Your review")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $draft.review)
                .frame(minHeight: 120)
                .padding(6)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        }

        HStack {
            Button {
                save()
            } label: {
                if reviews.isSubmitting {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(editingReviewID == nil ? "Submitting…" : "Saving…")
                    }
                } else {
                    Label(
                        editingReviewID == nil ? "Submit Review" : "Save Changes",
                        systemImage: editingReviewID == nil ? "paperplane.fill" : "checkmark"
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(reviews.isSubmitting)

            if editingReviewID != nil {
                Button("Cancel Editing") {
                    resetDraft()
                }
            }

            Spacer()

            Button("Preview notch reminder") {
                HaloReviewPromptCoordinator.shared.presentForTesting()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Shows the subtle review prompt in the closed notch.")
        }

        Text(editingReviewID == nil
             ? "New reviews are unpublished until you approve them in Firestore."
             : "Editing a published review sends it back for approval before it appears publicly again.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func reviewStatus(_ review: HaloCustomerReview) -> some View {
        if review.published {
            Label("Published", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        } else {
            Label("Awaiting approval", systemImage: "clock")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var suggestedDisplayName: String {
        let prefix = account.email.split(separator: "@").first.map(String.init) ?? ""
        let cleaned = prefix
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.count >= 2 ? cleaned : "Halo user"
    }

    private func beginEditing(_ review: HaloCustomerReview) {
        editingReviewID = review.id
        draft = HaloReviewDraft(
            name: review.name,
            title: review.title,
            review: review.review,
            rating: review.rating
        )
    }

    private func resetDraft() {
        editingReviewID = nil
        draft = HaloReviewDraft(name: suggestedDisplayName, title: "", review: "", rating: 5)
    }

    private func save() {
        Task {
            let success: Bool
            if let id = editingReviewID,
               let existing = reviews.reviews.first(where: { $0.id == id }) {
                success = await reviews.update(existing, with: draft)
            } else {
                success = await reviews.submit(draft)
            }

            if success {
                resetDraft()
            }
        }
    }
}

@MainActor
struct HaloReviewNotchPromptView: View {
    @ObservedObject private var coordinator = HaloReviewPromptCoordinator.shared

    var body: some View {
        VStack(spacing: 4) {
            Text("Enjoying Halo?")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .lineLimit(1)

            HStack(spacing: 6) {
                Button {
                    coordinator.openReviewCenter()
                } label: {
                    Label("Review", systemImage: "star.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)

                Button("Don't remind me") {
                    coordinator.dontRemind()
                }
                .buttonStyle(.plain)
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Halo review reminder")
    }
}
