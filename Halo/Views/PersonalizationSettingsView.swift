import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO

private enum HaloSchedulePaneSection: String, CaseIterable, Identifiable {
    case profiles = "Profiles"
    case backgrounds = "Backgrounds"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .profiles: return "person.crop.rectangle.stack"
        case .backgrounds: return "photo.on.rectangle.angled"
        }
    }
}

private enum HaloSchedulePresentation {
    static let everyDay: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    static let weekdays: Set<Int> = [2, 3, 4, 5, 6]
    static let weekends: Set<Int> = [1, 7]

    static func time(_ minute: Int) -> String {
        let clamped = min(1439, max(0, minute))
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    static func days(_ weekdays: Set<Int>) -> String {
        let valid = Set(weekdays.filter { (1...7).contains($0) })
        if valid == everyDay { return "Every day" }
        if valid == Self.weekdays { return "Weekdays" }
        if valid == weekends { return "Weekends" }
        if valid.isEmpty { return "No days selected" }
        return valid.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
    }

    static func window(_ window: DailyWindow) -> String {
        let days = days(window.weekdays)
        if window.startMinute == window.endMinute {
            return "\(days) · All day"
        }
        let overnight = window.startMinute > window.endMinute ? " · overnight" : ""
        return "\(days) · \(time(window.startMinute))–\(time(window.endMinute))\(overnight)"
    }

    static func backgroundTitle(_ kind: BackgroundKind) -> String {
        switch kind {
        case .gradient: return "Gradient"
        case .solid: return "Solid color"
        case .glass: return "Glass"
        case .image: return "Image"
        case .video: return "Video"
        }
    }

    static func backgroundSymbol(_ kind: BackgroundKind) -> String {
        switch kind {
        case .gradient: return "circle.lefthalf.filled"
        case .solid: return "paintbrush.fill"
        case .glass: return "sparkles.rectangle.stack"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        }
    }
}

struct DailyWindowEditor: View {
    @Binding var window: DailyWindow

    private var noDaysSelected: Bool {
        window.weekdays.intersection(Set(1...7)).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                HaloScheduleTimePicker(title: "Starts", minute: $window.startMinute)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                HaloScheduleTimePicker(title: "Ends", minute: $window.endMinute)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Days")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 5) {
                        schedulePresetButton("Every day", HaloSchedulePresentation.everyDay)
                        schedulePresetButton("Weekdays", HaloSchedulePresentation.weekdays)
                        schedulePresetButton("Weekend", HaloSchedulePresentation.weekends)
                    }
                }

                HStack(spacing: 5) {
                    ForEach(1...7, id: \.self) { day in
                        Button {
                            if window.weekdays.contains(day) {
                                window.weekdays.remove(day)
                            } else {
                                window.weekdays.insert(day)
                            }
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                        } label: {
                            Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 28)
                                .foregroundStyle(window.weekdays.contains(day) ? Color.white : Color.primary)
                                .background(
                                    window.weekdays.contains(day) ? Color.accentColor : Color.primary.opacity(0.045),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                        .accessibilityValue(window.weekdays.contains(day) ? "Selected" : "Not selected")
                    }
                }
            }

            if window.startMinute == window.endMinute {
                Label("Start and end are equal, so this schedule runs all day.", systemImage: "clock.badge.checkmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if window.startMinute > window.endMinute {
                Label("This range continues past midnight into the following day.", systemImage: "moon.stars")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if noDaysSelected {
                Label("Choose at least one day for this schedule to run.", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func schedulePresetButton(_ title: String, _ days: Set<Int>) -> some View {
        Button(title) {
            window.weekdays = days
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }
}

private struct HaloScheduleTimePicker: View {
    let title: String
    @Binding var minute: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Picker("Hour", selection: Binding(
                    get: { min(23, max(0, minute / 60)) },
                    set: { minute = $0 * 60 + min(59, max(0, minute % 60)) }
                )) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d", hour)).tag(hour)
                    }
                }
                .labelsHidden()
                .frame(width: 66)

                Text(":")
                    .foregroundStyle(.secondary)

                Picker("Minute", selection: Binding(
                    get: { min(59, max(0, minute % 60)) },
                    set: { minute = min(23, max(0, minute / 60)) * 60 + $0 }
                )) {
                    ForEach(0..<60, id: \.self) { value in
                        Text(String(format: "%02d", value)).tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 66)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GrainSettingsView: View {
    @Binding var options: GrainOptions
    var body: some View {
        Toggle("Soft grain", isOn: $options.enabled)
        if options.enabled {
            Slider(value: $options.amount, in: 0...0.6) { Text("Grain amount") }
            Slider(value: $options.size, in: 0.5...3) { Text("Grain size") }
            Slider(value: $options.warmth, in: 0...1) { Text("Warmth") }
        }
    }
}

@MainActor
struct ScheduleSettingsView: View {
    @ObservedObject var workspace: WorkspaceStore
    @State private var selection: HaloSchedulePaneSection = .profiles
    @State private var expandedProfileSchedules = Set<UUID>()
    @State private var expandedBackgroundSchedules = Set<UUID>()

    private var profiles: Binding<[ProfileSchedule]> {
        Binding(
            get: { workspace.settings.profileSchedules ?? [] },
            set: { workspace.settings.profileSchedules = $0 }
        )
    }

    private var backgrounds: Binding<[TimedBackground]> {
        Binding(
            get: { workspace.settings.layout.appearance.backgroundSchedule ?? [] },
            set: { workspace.settings.layout.appearance.backgroundSchedule = $0 }
        )
    }

    private var activeProfileScheduleID: UUID? {
        guard let activeProfileID = workspace.scheduledProfileID else { return nil }
        return profiles.wrappedValue.first { entry in
            entry.enabled &&
            entry.profileID == activeProfileID &&
            workspace.settings.profiles.contains(where: { $0.id == entry.profileID }) &&
            entry.window.occurrence(at: Date()) != nil
        }?.id
    }

    private var activeBackgroundScheduleID: UUID? {
        backgrounds.wrappedValue.first {
            $0.enabled && $0.window.occurrence(at: Date()) != nil
        }?.id
    }

    private var enabledProfileCount: Int {
        profiles.wrappedValue.filter { entry in
            entry.enabled &&
            !entry.window.weekdays.isEmpty &&
            workspace.settings.profiles.contains(where: { $0.id == entry.profileID })
        }.count
    }

    private var enabledBackgroundCount: Int {
        backgrounds.wrappedValue.filter { entry in
            guard entry.enabled, !entry.window.weekdays.isEmpty else { return false }
            if entry.kind == .image || entry.kind == .video {
                return !entry.assetPath.isEmpty && FileManager.default.fileExists(atPath: entry.assetPath)
            }
            return true
        }.count
    }

    private var enabledScheduleCount: Int {
        enabledProfileCount + enabledBackgroundCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            scheduleHeader

            Picker("Schedule category", selection: $selection) {
                ForEach(HaloSchedulePaneSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.symbol)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch selection {
                case .profiles:
                    profileScheduleContent
                case .backgrounds:
                    backgroundScheduleContent
                }
            }
            .animation(.easeInOut(duration: 0.16), value: selection)
        }
    }

    private var scheduleHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Schedules")
                    .font(.title3.bold())
                Text("Change Halo automatically using your Mac's local time and time zone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(enabledScheduleCount)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(enabledScheduleCount == 1 ? "enabled schedule" : "enabled schedules")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private var profileScheduleContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HaloScheduleSectionHeader(
                title: "Timed profiles",
                detail: "Switch to a saved profile during a recurring time window. When schedules overlap, the first matching enabled schedule in this list takes priority.",
                actionTitle: "Add schedule",
                actionSymbol: "plus"
            ) {
                addProfileSchedule()
            }
            .disabled(workspace.settings.profiles.isEmpty)

            if let id = workspace.scheduledProfileID,
               let profile = workspace.settings.profiles.first(where: { $0.id == id }) {
                HaloScheduleStatusBanner(
                    symbol: "checkmark.circle.fill",
                    title: "\(profile.name) is active",
                    detail: "A timed profile currently controls the base Halo layout."
                )
            } else if !profiles.wrappedValue.isEmpty {
                HaloScheduleStatusBanner(
                    symbol: "clock.badge",
                    title: "No timed profile is active",
                    detail: "Halo is using your normal layout or a manually selected profile.",
                    actionTitle: "Resume schedules",
                    action: {
                        workspace.resumeSchedules()
                    }
                )
            }

            if workspace.settings.profiles.isEmpty {
                HaloScheduleEmptyState(
                    symbol: "person.crop.rectangle.badge.exclamationmark",
                    title: "Create a profile first",
                    detail: "Timed profile schedules need a saved profile to switch to."
                )
            } else if profiles.wrappedValue.isEmpty {
                HaloScheduleEmptyState(
                    symbol: "calendar.badge.plus",
                    title: "No profile schedules yet",
                    detail: "Add a schedule to switch Halo profiles automatically on selected days and times."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(profiles.wrappedValue) { snapshot in
                        let index = profiles.wrappedValue.firstIndex(where: { $0.id == snapshot.id })

                        HaloProfileScheduleCard(
                            schedule: profileScheduleBinding(snapshot),
                            profiles: workspace.settings.profiles,
                            isExpanded: Binding(
                                get: { expandedProfileSchedules.contains(snapshot.id) },
                                set: { expanded in
                                    if expanded {
                                        expandedProfileSchedules.insert(snapshot.id)
                                    } else {
                                        expandedProfileSchedules.remove(snapshot.id)
                                    }
                                }
                            ),
                            isActive: activeProfileScheduleID == snapshot.id,
                            canMoveUp: (index ?? 0) > 0,
                            canMoveDown: index.map { $0 < profiles.wrappedValue.count - 1 } ?? false,
                            onMoveUp: { moveProfile(snapshot.id, by: -1) },
                            onMoveDown: { moveProfile(snapshot.id, by: 1) },
                            onDuplicate: { duplicateProfileSchedule(snapshot) },
                            onRemove: { removeProfileSchedule(snapshot.id) }
                        )
                    }
                }
            }

            Text("Applying a profile manually pauses only the current scheduled occurrence. The normal layout returns when the range ends. Display-specific profiles still take precedence on their displays.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var backgroundScheduleContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HaloScheduleSectionHeader(
                title: "Timed backgrounds",
                detail: "Change the background of the current base layout during recurring time windows. The first matching enabled schedule takes priority.",
                actionTitle: "Add schedule",
                actionSymbol: "plus"
            ) {
                addBackgroundSchedule()
            }

            if backgrounds.wrappedValue.isEmpty {
                HaloScheduleEmptyState(
                    symbol: "photo.badge.plus",
                    title: "No background schedules yet",
                    detail: "Add a schedule to automatically change Halo's background at different times of day."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(backgrounds.wrappedValue) { snapshot in
                        let index = backgrounds.wrappedValue.firstIndex(where: { $0.id == snapshot.id })

                        HaloBackgroundScheduleCard(
                            schedule: backgroundScheduleBinding(snapshot),
                            isExpanded: Binding(
                                get: { expandedBackgroundSchedules.contains(snapshot.id) },
                                set: { expanded in
                                    if expanded {
                                        expandedBackgroundSchedules.insert(snapshot.id)
                                    } else {
                                        expandedBackgroundSchedules.remove(snapshot.id)
                                    }
                                }
                            ),
                            isActive: activeBackgroundScheduleID == snapshot.id,
                            canMoveUp: (index ?? 0) > 0,
                            canMoveDown: index.map { $0 < backgrounds.wrappedValue.count - 1 } ?? false,
                            onMoveUp: { moveBackground(snapshot.id, by: -1) },
                            onMoveDown: { moveBackground(snapshot.id, by: 1) },
                            onDuplicate: { duplicateBackgroundSchedule(snapshot) },
                            onRemove: { removeBackgroundSchedule(snapshot.id) },
                            onChooseFile: { chooseBackground(snapshot.id) }
                        )
                    }
                }
            }

            Text("Outside these ranges, your normal background returns. Save this layout as a profile to include these background schedules. Image and video schedules reference files on this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func profileScheduleBinding(_ snapshot: ProfileSchedule) -> Binding<ProfileSchedule> {
        Binding(
            get: { profiles.wrappedValue.first(where: { $0.id == snapshot.id }) ?? snapshot },
            set: { updated in
                var items = profiles.wrappedValue
                guard let index = items.firstIndex(where: { $0.id == snapshot.id }) else { return }
                items[index] = updated
                profiles.wrappedValue = items
            }
        )
    }

    private func backgroundScheduleBinding(_ snapshot: TimedBackground) -> Binding<TimedBackground> {
        Binding(
            get: { backgrounds.wrappedValue.first(where: { $0.id == snapshot.id }) ?? snapshot },
            set: { updated in
                var items = backgrounds.wrappedValue
                guard let index = items.firstIndex(where: { $0.id == snapshot.id }) else { return }
                items[index] = updated
                backgrounds.wrappedValue = items
            }
        )
    }

    private func addProfileSchedule() {
        guard let first = workspace.settings.profiles.first else { return }
        var item = ProfileSchedule(profileID: first.id)
        item.enabled = false
        var items = profiles.wrappedValue
        items.append(item)
        profiles.wrappedValue = items
        expandedProfileSchedules.insert(item.id)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func addBackgroundSchedule() {
        var item = TimedBackground()
        item.enabled = false
        var items = backgrounds.wrappedValue
        items.append(item)
        backgrounds.wrappedValue = items
        expandedBackgroundSchedules.insert(item.id)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func duplicateProfileSchedule(_ snapshot: ProfileSchedule) {
        guard let index = profiles.wrappedValue.firstIndex(where: { $0.id == snapshot.id }) else { return }
        var copy = snapshot
        copy.id = UUID()
        copy.enabled = false
        var items = profiles.wrappedValue
        items.insert(copy, at: min(index + 1, items.count))
        profiles.wrappedValue = items
        expandedProfileSchedules.insert(copy.id)
    }

    private func duplicateBackgroundSchedule(_ snapshot: TimedBackground) {
        guard let index = backgrounds.wrappedValue.firstIndex(where: { $0.id == snapshot.id }) else { return }
        var copy = snapshot
        copy.id = UUID()
        copy.enabled = false
        var items = backgrounds.wrappedValue
        items.insert(copy, at: min(index + 1, items.count))
        backgrounds.wrappedValue = items
        expandedBackgroundSchedules.insert(copy.id)
    }

    private func removeProfileSchedule(_ id: UUID) {
        var items = profiles.wrappedValue
        items.removeAll { $0.id == id }
        profiles.wrappedValue = items
        expandedProfileSchedules.remove(id)
    }

    private func removeBackgroundSchedule(_ id: UUID) {
        var items = backgrounds.wrappedValue
        items.removeAll { $0.id == id }
        backgrounds.wrappedValue = items
        expandedBackgroundSchedules.remove(id)
    }

    private func moveProfile(_ id: UUID, by delta: Int) {
        var items = profiles.wrappedValue
        guard let index = items.firstIndex(where: { $0.id == id }),
              items.indices.contains(index + delta) else { return }
        items.swapAt(index, index + delta)
        profiles.wrappedValue = items
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func moveBackground(_ id: UUID, by delta: Int) {
        var items = backgrounds.wrappedValue
        guard let index = items.firstIndex(where: { $0.id == id }),
              items.indices.contains(index + delta) else { return }
        items.swapAt(index, index + delta)
        backgrounds.wrappedValue = items
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func chooseBackground(_ id: UUID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var items = backgrounds.wrappedValue
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].assetPath = url.path
        items[index].kind = ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) ? .video : .image
        backgrounds.wrappedValue = items
    }
}

@MainActor
private struct HaloScheduleSectionHeader: View {
    let title: String
    let detail: String
    let actionTitle: String
    let actionSymbol: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(action: action) {
                Label(actionTitle, systemImage: actionSymbol)
            }
            .buttonStyle(.bordered)
        }
    }
}

@MainActor
private struct HaloScheduleStatusBanner: View {
    let symbol: String
    let title: String
    let detail: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(11)
        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
        }
    }
}

@MainActor
private struct HaloScheduleEmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 25))
                .foregroundStyle(.secondary)
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.primary.opacity(0.09))
        }
    }
}

@MainActor
private struct HaloProfileScheduleCard: View {
    @Binding var schedule: ProfileSchedule
    let profiles: [Profile]
    @Binding var isExpanded: Bool
    let isActive: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDuplicate: () -> Void
    let onRemove: () -> Void

    private var profile: Profile? {
        profiles.first { $0.id == schedule.profileID }
    }

    private var invalid: Bool {
        profile == nil || schedule.window.weekdays.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: profile?.icon ?? "person.crop.rectangle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(schedule.enabled ? Color.accentColor : Color.secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                (schedule.enabled ? Color.accentColor : Color.secondary).opacity(0.09),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile?.name ?? "Missing profile")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            HStack(spacing: 5) {
                                Circle()
                                    .fill(isActive ? Color.green : (schedule.enabled ? Color.accentColor : Color.secondary.opacity(0.6)))
                                    .frame(width: 6, height: 6)

                                Text(isActive
                                     ? "Active now · \(HaloSchedulePresentation.window(schedule.window))"
                                     : schedule.enabled
                                        ? HaloSchedulePresentation.window(schedule.window)
                                        : "Paused · \(HaloSchedulePresentation.window(schedule.window))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Toggle("Enabled", isOn: $schedule.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help(schedule.enabled ? "Pause schedule" : "Enable schedule")

                HaloScheduleCardMenu(
                    canMoveUp: canMoveUp,
                    canMoveDown: canMoveDown,
                    onMoveUp: onMoveUp,
                    onMoveDown: onMoveDown,
                    onDuplicate: onDuplicate,
                    onRemove: onRemove
                )

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(12)

            if isExpanded {
                Divider()
                    .opacity(0.65)

                VStack(alignment: .leading, spacing: 16) {
                    HaloScheduleStepHeader(number: "1", title: "Use this profile")

                    Picker("Profile", selection: $schedule.profileID) {
                        ForEach(profiles) { profile in
                            Label(profile.name, systemImage: profile.icon ?? "person.crop.rectangle")
                                .tag(profile.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Divider()
                        .padding(.vertical, 1)

                    HaloScheduleStepHeader(number: "2", title: "During this time")
                    DailyWindowEditor(window: $schedule.window)
                }
                .padding(14)
                .background(Color.primary.opacity(0.018))
            }
        }
        .background(Color.primary.opacity(schedule.enabled ? 0.035 : 0.02), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(
                    invalid && schedule.enabled
                    ? Color.orange.opacity(0.35)
                    : Color.primary.opacity(isExpanded ? 0.12 : 0.075),
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

@MainActor
private struct HaloBackgroundScheduleCard: View {
    @Binding var schedule: TimedBackground
    @Binding var isExpanded: Bool
    let isActive: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDuplicate: () -> Void
    let onRemove: () -> Void
    let onChooseFile: () -> Void

    private var needsFile: Bool {
        guard schedule.kind == .image || schedule.kind == .video else { return false }
        return schedule.assetPath.isEmpty || !FileManager.default.fileExists(atPath: schedule.assetPath)
    }

    private var invalid: Bool {
        schedule.window.weekdays.isEmpty || needsFile
    }

    private var fileName: String {
        guard !schedule.assetPath.isEmpty else { return "No file selected" }
        return URL(fileURLWithPath: schedule.assetPath).lastPathComponent
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: HaloSchedulePresentation.backgroundSymbol(schedule.kind))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(schedule.enabled ? Color.accentColor : Color.secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                (schedule.enabled ? Color.accentColor : Color.secondary).opacity(0.09),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(HaloSchedulePresentation.backgroundTitle(schedule.kind)) background")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            HStack(spacing: 5) {
                                Circle()
                                    .fill(isActive ? Color.green : (schedule.enabled ? Color.accentColor : Color.secondary.opacity(0.6)))
                                    .frame(width: 6, height: 6)

                                Text(isActive
                                     ? "Active now · \(HaloSchedulePresentation.window(schedule.window))"
                                     : schedule.enabled
                                        ? HaloSchedulePresentation.window(schedule.window)
                                        : "Paused · \(HaloSchedulePresentation.window(schedule.window))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Toggle("Enabled", isOn: $schedule.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help(schedule.enabled ? "Pause schedule" : "Enable schedule")

                HaloScheduleCardMenu(
                    canMoveUp: canMoveUp,
                    canMoveDown: canMoveDown,
                    onMoveUp: onMoveUp,
                    onMoveDown: onMoveDown,
                    onDuplicate: onDuplicate,
                    onRemove: onRemove
                )

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(12)

            if isExpanded {
                Divider()
                    .opacity(0.65)

                VStack(alignment: .leading, spacing: 16) {
                    HaloScheduleStepHeader(number: "1", title: "During this time")
                    DailyWindowEditor(window: $schedule.window)

                    Divider()
                        .padding(.vertical, 1)

                    HaloScheduleStepHeader(number: "2", title: "Use this background")

                    Picker("Background", selection: $schedule.kind) {
                        ForEach(BackgroundKind.allCases, id: \.self) { kind in
                            Label(HaloSchedulePresentation.backgroundTitle(kind), systemImage: HaloSchedulePresentation.backgroundSymbol(kind))
                                .tag(kind)
                        }
                    }
                    .pickerStyle(.menu)

                    if schedule.kind == .image || schedule.kind == .video {
                        VStack(alignment: .leading, spacing: 6) {
                            Button(action: onChooseFile) {
                                Label(schedule.assetPath.isEmpty ? "Choose background file…" : "Choose another file…", systemImage: "folder")
                            }
                            .buttonStyle(.bordered)

                            Text(fileName)
                                .font(.caption)
                                .foregroundStyle(needsFile ? Color.orange : Color.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    if schedule.kind != .glass {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("Diffusion / blur")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.0f", schedule.blur))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $schedule.blur, in: 0...20)
                        }
                    }

                    GrainSettingsView(options: $schedule.grain)
                }
                .padding(14)
                .background(Color.primary.opacity(0.018))
            }
        }
        .background(Color.primary.opacity(schedule.enabled ? 0.035 : 0.02), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(
                    invalid && schedule.enabled
                    ? Color.orange.opacity(0.35)
                    : Color.primary.opacity(isExpanded ? 0.12 : 0.075),
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

@MainActor
private struct HaloScheduleCardMenu: View {
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDuplicate: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Menu {
            Button(action: onMoveUp) {
                Label("Move Up", systemImage: "arrow.up")
            }
            .disabled(!canMoveUp)

            Button(action: onMoveDown) {
                Label("Move Down", systemImage: "arrow.down")
            }
            .disabled(!canMoveDown)

            Divider()

            Button(action: onDuplicate) {
                Label("Duplicate Schedule", systemImage: "plus.square.on.square")
            }

            Divider()

            Button(role: .destructive, action: onRemove) {
                Label("Delete Schedule", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .help("Schedule actions")
    }
}

@MainActor
private struct HaloScheduleStepHeader: View {
    let number: String
    let title: String

    var body: some View {
        HStack(spacing: 7) {
            Text(number)
                .font(.caption2.bold())
                .foregroundStyle(Color.accentColor)
                .frame(width: 20, height: 20)
                .background(Color.accentColor.opacity(0.10), in: Circle())

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.35)
        }
    }
}

@MainActor struct SideDecorationSettingsView: View {
    let title: String
    @Binding var options: SideDecoration
    @State private var error: String?
    var body: some View {
        Section(title) {
            Picker("Display", selection: $options.visibility) {
                Text("Disabled").tag(DecorationVisibility.disabled)
                Text("Always").tag(DecorationVisibility.always)
                Text("Only while music plays").tag(DecorationVisibility.playing)
            }
            if options.visibility != .disabled {
                Picker("Content", selection: $options.kind) {
                    Text("Icon").tag(DecorationKind.symbol)
                    Text("Image / GIF").tag(DecorationKind.image)
                }
                if options.kind == .symbol {
                    Picker("Icon", selection: $options.symbol) {
                        ForEach(Array(Set([options.symbol, "sparkles", "heart.fill", "moon.stars.fill", "sun.max.fill", "music.note", "headphones", "bolt.fill", "flame.fill", "leaf.fill", "gamecontroller.fill"])).sorted(), id: \.self) {
                            Label($0, systemImage: $0).tag($0)
                        }
                    }
                    TextField("SF Symbol name", text: $options.symbol)
                    ColorPicker("Icon color", selection: Binding(get: { options.color.color }, set: { options.color = WidgetColor($0) }), supportsOpacity: false)
                } else {
                    Button("Choose image or GIF…") { chooseFile() }
                    Text(options.assetPath.isEmpty ? "No file selected" : URL(fileURLWithPath: options.assetPath).lastPathComponent).font(.caption)
                    if let error { Text(error).foregroundStyle(.orange) }
                }
                Slider(value: $options.size, in: 12...64) { Text("Size") }
                SideDecorationView(options: options, playing: true, lowPower: false)
                Text("Shown beside this side's content while the notch is closed. Images scale to fit the closed height. GIFs: up to 10 MB / 120 frames, cached at 128 px. Reduce Motion and Low Power Mode show a still frame.").font(.caption)
            }
        }
    }
    private func chooseFile() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 10_000_000,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) <= 120 else {
            error = "Choose an image under 10 MB, with at most 120 frames."; return
        }
        error = nil; options.assetPath = url.path
    }
}
