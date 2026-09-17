from pathlib import Path

path = Path("Halo/Views/WorkspaceSettingsView.swift")
text = path.read_text()

replacements = {
    'TextField("Excluded app bundle IDs, comma-separated", text: $workspace.settings.clipboardExcludedApps)':
        'InstalledAppExclusionPicker(bundleIDs: $workspace.settings.clipboardExcludedApps)',
    'TextField("Excluded app bundle IDs, comma-separated", text: $excludedApps)':
        'InstalledAppExclusionPicker(bundleIDs: $excludedApps)',
}

for old, new in replacements.items():
    if old not in text:
        raise SystemExit(f"Expected source not found: {old}")
    text = text.replace(old, new, 1)

marker = "// MARK: - Installed app exclusion picker"
if marker in text:
    raise SystemExit("Installed app exclusion picker already exists")

helper = r'''

// MARK: - Installed app exclusion picker

private struct HaloInstalledApplication: Identifiable, Hashable, Sendable {
    let bundleIdentifier: String
    let name: String
    let url: URL

    var id: String { bundleIdentifier }
}

private enum HaloInstalledApplicationCatalog {
    static func discover() -> [HaloInstalledApplication] {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        var applicationsByBundleID: [String: HaloInstalledApplication] = [:]

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension.lowercased() == "app",
                      let bundle = Bundle(url: url),
                      let rawBundleID = bundle.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !rawBundleID.isEmpty else { continue }

                let displayName = [
                    bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
                    bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
                    url.deletingPathExtension().lastPathComponent
                ]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? url.deletingPathExtension().lastPathComponent

                let candidate = HaloInstalledApplication(
                    bundleIdentifier: rawBundleID,
                    name: displayName,
                    url: url
                )

                if let existing = applicationsByBundleID[rawBundleID] {
                    let existingIsSystem = existing.url.path.hasPrefix("/System/")
                    let candidateIsSystem = url.path.hasPrefix("/System/")
                    if existingIsSystem && !candidateIsSystem {
                        applicationsByBundleID[rawBundleID] = candidate
                    }
                } else {
                    applicationsByBundleID[rawBundleID] = candidate
                }
            }
        }

        return applicationsByBundleID.values.sorted {
            let nameComparison = $0.name.localizedCaseInsensitiveCompare($1.name)
            if nameComparison == .orderedSame {
                return $0.bundleIdentifier.localizedCaseInsensitiveCompare($1.bundleIdentifier) == .orderedAscending
            }
            return nameComparison == .orderedAscending
        }
    }
}

private struct InstalledAppExclusionPicker: View {
    @Binding var bundleIDs: String
    @State private var showingPicker = false

    private var selectedIDs: Set<String> {
        Self.parse(bundleIDs)
    }

    var body: some View {
        LabeledContent("Excluded apps") {
            HStack(spacing: 10) {
                Text(selectedIDs.isEmpty ? "None" : "\(selectedIDs.count) selected")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button("Choose Apps…") {
                    showingPicker = true
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            InstalledAppSelectionSheet(bundleIDs: $bundleIDs)
        }
    }

    fileprivate static func parse(_ value: String) -> Set<String> {
        Set(
            value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    fileprivate static func serialize(_ values: Set<String>) -> String {
        values
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .joined(separator: ", ")
    }
}

private struct InstalledAppSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bundleIDs: String

    @State private var applications: [HaloInstalledApplication] = []
    @State private var searchText = ""
    @State private var isLoading = true

    private var selectedIDs: Set<String> {
        InstalledAppExclusionPicker.parse(bundleIDs)
    }

    private var filteredApplications: [HaloInstalledApplication] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return applications }
        return applications.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    private var unavailableSelectedIDs: [String] {
        let installedIDs = Set(applications.map(\.bundleIdentifier))
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return selectedIDs
            .subtracting(installedIDs)
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Excluded Apps")
                        .font(.title2.bold())
                    Text("Select the apps Halo should ignore for clipboard capture.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            TextField("Search apps or bundle IDs", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            Divider()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Finding installed apps…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredApplications.isEmpty && unavailableSelectedIDs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("No apps found")
                        .font(.headline)
                    Text("Try a different app name or bundle ID.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredApplications) { application in
                            applicationRow(application)
                        }

                        if !unavailableSelectedIDs.isEmpty {
                            HStack {
                                Text("Previously selected")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)

                            ForEach(unavailableSelectedIDs, id: \.self) { bundleID in
                                unavailableRow(bundleID)
                            }
                        }
                    }
                    .padding(8)
                }
            }

            Divider()

            HStack {
                Button("Clear Selection", role: .destructive) {
                    bundleIDs = ""
                }
                .disabled(selectedIDs.isEmpty)

                Spacer()

                Text("\(selectedIDs.count) selected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(16)
        }
        .frame(width: 640, height: 560)
        .task {
            await loadApplications()
        }
    }

    @ViewBuilder
    private func applicationRow(_ application: HaloInstalledApplication) -> some View {
        let selected = selectedIDs.contains(application.bundleIdentifier)
        Button {
            toggle(application.bundleIdentifier)
        } label: {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: application.url.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(application.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(application.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                selected ? Color.accentColor.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func unavailableRow(_ bundleID: String) -> some View {
        Button {
            toggle(bundleID)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "app.dashed")
                    .font(.title2)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bundleID)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("Not currently installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ bundleID: String) {
        var values = selectedIDs
        if values.contains(bundleID) {
            values.remove(bundleID)
        } else {
            values.insert(bundleID)
        }
        bundleIDs = InstalledAppExclusionPicker.serialize(values)
    }

    private func loadApplications() async {
        guard applications.isEmpty else {
            isLoading = false
            return
        }
        isLoading = true
        let discovered = await Task.detached(priority: .utility) {
            HaloInstalledApplicationCatalog.discover()
        }.value
        applications = discovered
        isLoading = false
    }
}
'''

path.write_text(text + helper)
