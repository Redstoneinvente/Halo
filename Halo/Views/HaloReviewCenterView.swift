import SwiftUI

@MainActor
struct HaloReviewCenterView: View {
    @ObservedObject private var reviews = HaloReviewService.shared
    @ObservedObject private var account = HaloAccountManager.shared
    @State private var draft = HaloReviewDraft()
    @State private var editingReviewID: String?
    @State private var pendingDelete: HaloCustomerReview?

    var body: some View {
        Group {
            Section("Review Halo") {
                Text("Tell other people what Halo is actually like to use. Reviews submitted here can appear on the Halo website after moderation.")
                    .font(.callout)

                if !account.isSignedIn {
                    Label("Sign in to your Halo account first.", systemImage: "person.crop.circle.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                    Button("Open Account & License") {
                        NotificationCenter.default.post(name: .init("HaloOpenAccount"), object: nil)
                    }
                } else if !account.emailVerified {
                    Label("Verify your Halo account email before submitting a review.", systemImage: "envelope.badge")
                        .foregroundStyle(.orange)
                    Button("Open Account & License") {
                        NotificationCenter.default.post(name: .init("HaloOpenAccount"), object: nil)
                    }
                } else {
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

                if account.isSignedIn && !reviews.isLoading {
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
            if account.isSignedIn {
                await reviews.refresh()
            }
        }
        .onChange(of: account.isSignedIn) { signedIn in
            if signedIn {
                Task { await reviews.refresh() }
            } else {
                resetDraft()
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
        draft = HaloReviewDraft()
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Halo review reminder")
    }
}
