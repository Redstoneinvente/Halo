import SwiftUI

@MainActor
struct HaloFeedbackCenterView: View {
    @ObservedObject private var feedback = HaloFeedbackService.shared

    @State private var title = ""
    @State private var details = ""
    @State private var context = ""
    @State private var category = "General"
    @State private var includeDiagnostics = true
    @State private var initialized = false

    private let categories = [
        "General",
        "Notch",
        "Closed Notch",
        "Widgets",
        "Context Interface",
        "Integrations",
        "Media",
        "Appearance",
        "Automation",
        "Account & License",
        "Performance",
        "Other"
    ]

    var body: some View {
        Group {
            Section("Feedback Center") {
                Text("Report bugs, crashes, feature requests, or other feedback without leaving Halo.")
                    .font(.callout)

                Picker("Type", selection: $feedback.selectedKind) {
                    ForEach(HaloFeedbackKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }

                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }

                TextField("Short title", text: $title)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 6) {
                    Text(feedback.selectedKind.detailPrompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $details)
                        .frame(minHeight: 110)
                        .padding(6)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(feedback.selectedKind.contextPrompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $context)
                        .frame(minHeight: 80)
                        .padding(6)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                }

                Label(
                    "The title, description, category, type, version, and status are designed to appear on Halo's public issues website. Your account details and diagnostics are stored separately and are never part of the public issue document.",
                    systemImage: "globe"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Technical diagnostics") {
                Toggle("Include technical diagnostics with this report", isOn: $includeDiagnostics)

                Text("Diagnostics contain only Halo's version/build, macOS version, CPU architecture, display count, distribution channel, and—when crash reporting is enabled—a random Halo installation identifier. They do not include clipboard contents, files, notes, calendar data, screenshots, license keys, or integration payloads.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if includeDiagnostics {
                    DisclosureGroup("Preview diagnostics") {
                        ForEach(feedback.safeDiagnosticsPreview(), id: \.0) { key, value in
                            LabeledContent(key, value: value)
                                .font(.caption)
                        }
                    }
                }
            }

            Section("Crash & reliability reporting") {
                Toggle(
                    "Automatically share crash & reliability diagnostics",
                    isOn: Binding(
                        get: { feedback.crashDiagnosticsEnabled },
                        set: { feedback.setCrashDiagnosticsEnabled($0) }
                    )
                )

                Text("You can opt out at any time. Turning this off disables future Crashlytics collection for Halo; the change is persisted for future launches. A crash stored locally while reporting is disabled may be sent if you later turn reporting back on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if feedback.crashedDuringPreviousExecution {
                    Label("Halo detected that the previous session ended in a crash.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Report the previous crash") {
                        feedback.select(.crash)
                    }
                }
            }

            Section {
                HStack {
                    Button {
                        Task {
                            let sent = await feedback.submit(
                                HaloFeedbackSubmission(
                                    kind: feedback.selectedKind,
                                    title: title,
                                    details: details,
                                    context: context,
                                    category: category,
                                    includeDiagnostics: includeDiagnostics
                                )
                            )
                            if sent {
                                title = ""
                                details = ""
                                context = ""
                            }
                        }
                    } label: {
                        if feedback.isSubmitting {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Sending…")
                            }
                        } else {
                            Label("Send Feedback", systemImage: "paperplane.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        feedback.isSubmitting ||
                        title.trimmingCharacters(in: .whitespacesAndNewlines).count < 4 ||
                        details.trimmingCharacters(in: .whitespacesAndNewlines).count < 10
                    )

                    Spacer()

                    if !feedback.firebaseAvailable {
                        Label("Firebase not configured", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if let success = feedback.successMessage {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .textSelection(.enabled)
                }

                if let error = feedback.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Public issue status updates should be performed by Halo's website/backend using trusted Firebase Admin credentials; the Mac app can only create new reports.")
            }
        }
        .onAppear {
            feedback.start()
            if !initialized {
                includeDiagnostics = feedback.crashDiagnosticsEnabled
                initialized = true
            }
        }
    }
}
