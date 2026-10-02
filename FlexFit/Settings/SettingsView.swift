import SwiftUI
import SwiftData
import FlexFitEngine

/// Profile (the split tab): who you are, the plan's inputs, coaching, Apple Health, Pro, and the health notice
/// (PRD: disclaimer in onboarding *and* here). Drawn with the app's own tiles, not a system form.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementService.self) private var entitlements
    @Environment(StoreService.self) private var store
    @Query private var profiles: [ProfileRecord]
    @State private var legal: LegalPage?
    @State private var confirmReset = false
    @State private var editing: ValueEdit?
    /// Shown as the Profile tab rather than as a sheet (a sheet gets a Done button instead of the cart).
    var isTab = false

    var body: some View {
        NavigationStack {
            if let record = profiles.first {
                page(record)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .legalPage($legal)
        .sheet(item: $editing) { edit in
            ValueSheet(edit: edit)
        }
    }

    private func page(_ record: ProfileRecord) -> some View {
        let profile = record.profile()
        let units = profile.displayUnits
        return ScrollView {
            VStack(alignment: .leading, spacing: Space.md - 2) {
                HStack(spacing: Space.sm) {
                    ScreenHeader(initial: record.name.isEmpty ? "Y" : record.name,
                                 kicker: entitlements.isPro ? "FlexFit Pro" : "Your profile",
                                 title: record.name.isEmpty ? "You" : record.name)
                    if isTab {
                        CartButton()
                    } else {
                        Button("Done") { dismiss() }
                            .textStyle(.label)
                            .foregroundStyle(Palette.ink)
                    }
                }

                SummaryPanel(profile: profile, isPro: entitlements.isPro)

                SectionHeader(title: "About you").padding(.top, Space.xs)
                CardList {
                    ProfileRow(icon: "person", tint: .navy, title: "Name", value: record.name.isEmpty ? "Add" : record.name) {
                        editing = .text("Name", record.name) { record.name = $0; save() }
                    }
                    ProfileRow(icon: "birthday.cake", tint: .copper, title: "Age", value: profile.age > 0 ? "\(profile.age)" : "Add") {
                        editing = .number("Age", unit: "years", profile.age > 0 ? "\(profile.age)" : "", range: 16...90) {
                            record.birthYear = Calendar.current.component(.year, from: .now) - Int($0); save()
                        }
                    }
                    menuRow(icon: "figure.stand", tint: .blue, title: "Sex", value: profile.sex.title,
                            selection: bind(record, \.sex), options: Sex.allCases.map { ($0.title, $0.rawValue) })
                    ProfileRow(icon: "ruler", tint: .navy, title: "Height", value: height(record.heightCm, units)) {
                        let imperial = units == .imperial
                        editing = .number("Height", unit: imperial ? "in" : "cm",
                                          number(imperial ? record.heightCm / 2.54 : record.heightCm),
                                          range: imperial ? 48...90 : 120...230) {
                            record.heightCm = imperial ? $0 * 2.54 : $0; save()
                        }
                    }
                    ProfileRow(icon: "scope", tint: .copper, title: "Target weight", value: Formatters.mass(record.targetWeightKg, units: units)) {
                        editing = .number("Target weight", unit: units == .metric ? "kg" : "lb",
                                          number(Mass.display(kilograms: record.targetWeightKg, in: units)),
                                          range: units == .metric ? 35...250 : 77...550) {
                            record.targetWeightKg = Mass.kilograms(from: $0, in: units); save()
                        }
                    }
                    menuRow(icon: "flag", tint: .blue, title: "Goal", value: profile.goal.title,
                            selection: bind(record, \.goal), options: Goal.allCases.map { ($0.title, $0.rawValue) })
                    menuRow(icon: "scalemass", tint: .navy, title: "Units", value: units == .metric ? "Metric (kg)" : "Imperial (lb)",
                            selection: bind(record, \.displayUnits),
                            options: [("Metric (kg)", DisplayUnits.metric.rawValue), ("Imperial (lb)", DisplayUnits.imperial.rawValue)])
                }

                SectionHeader(title: "Training").padding(.top, Space.xs)
                CardList {
                    menuRow(icon: "calendar", tint: .navy, title: "Training days", value: "\(record.trainingDays) days a week",
                            selection: bind(record, \.trainingDays), options: (2...6).map { ("\($0) days", $0) })
                    menuRow(icon: "timer", tint: .copper, title: "Session length", value: "\(record.sessionMinutes) min",
                            selection: bind(record, \.sessionMinutes), options: [20, 30, 45, 60].map { ("\($0) min", $0) })
                    menuRow(icon: "building.2", tint: .copper, title: "Where you train", value: profile.environment.title,
                            selection: bind(record, \.environment), options: TrainingEnvironment.allCases.map { ($0.title, $0.rawValue) })
                    menuRow(icon: "chart.bar", tint: .blue, title: "Experience", value: profile.experience.title,
                            selection: bind(record, \.experience), options: Experience.allCases.map { ($0.title, $0.rawValue) })
                    NavigationLink { EquipmentEditor(record: record) } label: {
                        ProfileRowLabel(icon: "dumbbell", tint: .navy, title: "Equipment",
                                        value: record.equipment.isEmpty ? "Bodyweight" : "\(record.equipment.count) items", chevron: .push)
                    }
                    .buttonStyle(.plain)
                    NavigationLink { LimitationsEditor(record: record) } label: {
                        ProfileRowLabel(icon: "bandage", tint: .copper, title: "Areas to protect",
                                        value: record.limitations.isEmpty ? "None" : "\(record.limitations.count)", chevron: .push)
                    }
                    .buttonStyle(.plain)
                    menuRow(icon: "figure.walk", tint: .blue, title: "Daily steps", value: profile.dailySteps.title,
                            selection: bind(record, \.dailySteps), options: DailySteps.allCases.map { ($0.title, $0.rawValue) })
                    menuRow(icon: "moon", tint: .navy, title: "Sleep", value: profile.sleep.title,
                            selection: bind(record, \.sleep), options: SleepBand.allCases.map { ($0.title, $0.rawValue) })
                }

                SectionHeader(title: "Food").padding(.top, Space.xs)
                CardList {
                    menuRow(icon: "fork.knife", tint: .copper, title: "Diet style", value: profile.diet.title,
                            selection: bind(record, \.dietStyle), options: DietStyle.allCases.map { ($0.title, $0.rawValue) })
                    menuRow(icon: "clock", tint: .navy, title: "Meals per day", value: profile.mealPattern.title,
                            selection: bind(record, \.mealPattern), options: MealPattern.allCases.map { ($0.title, $0.rawValue) })
                    Button {
                        record.snacksBetweenMeals = !profile.snacksBetweenMeals
                        save()
                    } label: {
                        ProfileRowLabel(icon: "carrot", tint: .blue, title: "Snacks between meals", value: nil,
                                        chevron: .toggle(profile.snacksBetweenMeals))
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(profile.snacksBetweenMeals ? "On" : "Off")
                    NavigationLink { CheatDaysEditor(record: record) } label: {
                        ProfileRowLabel(icon: "birthday.cake", tint: .copper, title: "Cheat days",
                                        value: profile.cheatDays.summary, chevron: .push)
                    }
                    .buttonStyle(.plain)
                    menuRow(icon: "frying.pan", tint: .blue, title: "Max cooking time",
                            value: record.maxCookMinutes == 0 ? "No limit" : "\(record.maxCookMinutes) min",
                            selection: bind(record, \.maxCookMinutes), options: [10, 20, 40, 0].map { ($0 == 0 ? "No limit" : "\($0) min", $0) })
                    NavigationLink { FoodEditor(record: record) } label: {
                        ProfileRowLabel(icon: "globe", tint: .copper, title: "Cuisines, allergies & dislikes",
                                        value: record.cuisines.isEmpty ? "All" : record.cuisines.sorted().joined(separator: " + "), chevron: .push)
                    }
                    .buttonStyle(.plain)
                    menuRow(icon: "cart", tint: .navy, title: "Grocery budget", value: profile.budget.title,
                            selection: bind(record, \.budget), options: GroceryBudget.allCases.map { ($0.title, $0.rawValue) })
                    menuRow(icon: "bag", tint: .blue, title: "Shopping day", value: profile.shopDay.title,
                            selection: bind(record, \.shopDay), options: ShopDay.allCases.map { ($0.title, $0.rawValue) })
                }

                SectionHeader(title: "Coaching").padding(.top, Space.xs)
                CardList {
                    menuRow(icon: "bell", tint: .copper, title: "Check-in reminder", value: profile.reminder.title,
                            selection: bind(record, \.reminder), options: ReminderTime.allCases.map { ($0.title, $0.rawValue) })
                    menuRow(icon: "quote.bubble", tint: .navy, title: "Tone", value: profile.tone.title,
                            selection: bind(record, \.tone), options: CoachTone.allCases.map { ($0.title, $0.rawValue) })
                }
                note(Reminders.message(profile.tone))
                    .onChange(of: record.reminder + record.tone) {
                        let p = record.profile()
                        Task { await Reminders.schedule(time: p.reminder, tone: p.tone); await Reminders.scheduleWeekly(time: p.reminder) }
                    }

                SectionHeader(title: "Apple Health").padding(.top, Space.xs)
                CardList {
                    Button { setHealth(record, on: !record.healthSyncEnabled) } label: {
                        ProfileRowLabel(icon: "heart", tint: .copper, title: "Sync with Apple Health", value: nil,
                                        chevron: .toggle(record.healthSyncEnabled))
                    }
                    .buttonStyle(.plain)
                    .disabled(!HealthService.shared.isAvailable)
                    .accessibilityValue(record.healthSyncEnabled ? "On" : "Off")
                }
                note("Reads your body weight for the weekly trend and saves finished sessions as strength workouts. Nothing leaves your devices.")

                SectionHeader(title: "FlexFit Pro").padding(.top, Space.xs)
                if entitlements.isPro {
                    CardList {
                        ProfileRowLabel(icon: "checkmark.seal", tint: .navy, title: "Pro is active", value: nil, chevron: .none)
                    }
                } else {
                    ProPromo { openPaywall() }
                }
                CardList {
                    ProfileRow(icon: "arrow.clockwise", tint: .blue, title: "Restore purchases", value: nil) {
                        Task { await store.restore() }
                    }
                    #if DEBUG
                    Button { entitlements.debugProOverride.toggle() } label: {
                        ProfileRowLabel(icon: "ladybug", tint: .copper, title: "Debug: pretend Pro", value: nil,
                                        chevron: .toggle(entitlements.debugProOverride))
                    }
                    .buttonStyle(.plain)
                    #endif
                }

                SectionHeader(title: "Health & privacy").padding(.top, Space.xs)
                InlineNote(text: "FlexFit gives general fitness guidance, not medical advice. If you have a medical condition, are pregnant, or feel pain, check with a clinician before training or changing how you eat.",
                           systemImage: "cross.case")
                CardList {
                    ProfileRow(icon: "lock", tint: .navy, title: "Privacy Policy", value: nil) { legal = .privacy }
                    ProfileRow(icon: "doc.text", tint: .blue, title: "Terms of Use", value: nil) { legal = .terms }
                    ProfileRow(icon: "heart.text.square", tint: .copper, title: "Acknowledgements", value: nil) { legal = .acknowledgements }
                }
                note("Your health data stays on this device and in your own iCloud. No ads, no data sales.")

                Button { confirmReset = true } label: {
                    Text("Start over")
                        .textStyle(.button)
                        .foregroundStyle(Palette.proteinRed)
                        .frame(maxWidth: .infinity, minHeight: Size.button)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
                        .cardShadow()
                }
                .buttonStyle(.plain)
                .padding(.top, Space.sm)
                note("Deletes your plan, logs and weigh-ins from this device. Apple Health data is untouched.")
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xl)
            .readableColumn()
            // Never wider than the screen, whatever the values say: the page must not slide sideways.
            .containerRelativeFrame(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .statusBarBackdrop()
        .pageBackground()
        .confirmationDialog("Start over?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { reset() }
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: Rows

    /// A tile row that opens a menu of choices in place.
    private func menuRow<T: Hashable>(icon: String, tint: ActionRow.Tint, title: String, value: String,
                                      selection: Binding<T>, options: [(String, T)]) -> some View {
        Menu {
            Picker(title, selection: selection) {
                ForEach(options, id: \.1) { Text($0.0).tag($0.1) }
            }
        } label: {
            ProfileRowLabel(icon: icon, tint: tint, title: title, value: value, chevron: .menu)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .textStyle(.caption)
            .foregroundStyle(Palette.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Space.xxs)
    }

    // MARK: Actions

    private func bind<T>(_ record: ProfileRecord, _ key: ReferenceWritableKeyPath<ProfileRecord, T>) -> Binding<T> {
        Binding(get: { record[keyPath: key] }, set: { record[keyPath: key] = $0; try? modelContext.save() })
    }

    private func save() { try? modelContext.save() }

    private func setHealth(_ record: ProfileRecord, on: Bool) {
        guard on else {
            record.healthSyncEnabled = false
            save()
            return
        }
        Task {
            let ok = await HealthService.shared.requestAuthorization()
            record.healthSyncEnabled = ok
            save()
            if ok { await TargetsStore.importHealthWeights(context: modelContext) }
        }
    }

    private func openPaywall() {
        guard !isTab else { router.paywall = .settings; return }
        // As a sheet: close first; the paywall is presented from the root.
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            router.paywall = .settings
        }
    }

    private func height(_ cm: Double, _ units: DisplayUnits) -> String {
        guard cm > 0 else { return "Add" }
        if units == .metric { return "\(Int(cm.rounded())) cm" }
        let inches = Int((cm / 2.54).rounded())
        return "\(inches / 12) ft \(inches % 12) in"
    }

    private func number(_ value: Double) -> String {
        value > 0 ? value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never)) : ""
    }

    private func reset() {
        for model in [ProfileRecord.self, DailyLog.self, ExerciseSwap.self, SessionLog.self, WeighIn.self,
                      WeeklyTargets.self, PainFlag.self, IngredientSwapRecord.self,
                      GroceryCheck.self, PantryItem.self, SavedMeal.self, FoodEntry.self, FavoriteExercise.self, ExerciseNote.self, BodyMeasurement.self] as [any PersistentModel.Type] {
            try? modelContext.delete(model: model)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Pieces

/// Navy "you" card: start → target weight, and the plan's shape in three stats.
private struct SummaryPanel: View {
    let profile: UserProfile
    let isPro: Bool

    var body: some View {
        let units = profile.displayUnits
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(profile.goal.title).textStyle(.micro).foregroundStyle(Palette.onPanelMuted)
                    Text("\(Mass.display(kilograms: profile.weightKg, in: units).formatted(.number.precision(.fractionLength(0...1)))) → \(Formatters.mass(profile.targetWeightKg, units: units))")
                        .textStyle(.goalValue)
                        .foregroundStyle(Palette.onPanel)
                }
                Spacer()
                Text(isPro ? "Pro" : "Free")
                    .textStyle(.micro)
                    .foregroundStyle(isPro ? Palette.navy : Palette.ice)
                    .padding(.horizontal, Space.sm - 1)
                    .padding(.vertical, Space.xs - 1)
                    .background(isPro ? Palette.copper : Palette.ice.opacity(0.14), in: Capsule())
            }
            HStack(spacing: 0) {
                stat("\(profile.trainingDays) × \(profile.sessionMinutes) min", "training a week", first: true)
                stat(profile.environment.shortTitle, "where you train")
                stat(profile.diet.title, "diet style")
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Space.md - 2)
            .overlay(alignment: .top) { Rectangle().fill(Palette.onPanelHairline).frame(height: 1) }
            .padding(.top, Space.md)
        }
        .padding(.horizontal, Space.lg - 2)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.md)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.panelEdge))
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ label: String, first: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs + 2) {
            Text(value).textStyle(.label).foregroundStyle(Palette.onPanel).lineLimit(1).minimumScaleFactor(0.8)
            Text(label).textStyle(.micro).foregroundStyle(Palette.onPanelMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, first ? 0 : Space.sm - 2)
        .overlay(alignment: .leading) {
            if !first { Rectangle().fill(Palette.onPanelHairline).frame(width: 1) }
        }
    }
}

/// Peach card in the "Picked for you" style: what Pro adds, and a way in.
private struct ProPromo: View {
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("✦ FlexFit Pro").textStyle(.micro).foregroundStyle(Palette.copperInk)
            Text("Targets that follow your trend")
                .textStyle(.cardTitle)
                .foregroundStyle(Palette.navy)
                .padding(.top, Space.xs + 1)
            Text("Weekly adaptive calories, travel mode, unlimited low-energy days and your full history.")
                .textStyle(.caption)
                .foregroundStyle(Palette.navy.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.xs - 2)
            Button(action: onOpen) {
                Text("See what Pro adds")
                    .textStyle(.pill)
                    .foregroundStyle(Palette.white)
                    .padding(.horizontal, Space.md - 2)
                    .padding(.vertical, Space.sm)
                    .background(Palette.navy, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .padding(.top, Space.sm + 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg - 2)
        .background(
            LinearGradient(colors: [Palette.peach, Palette.peachDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Radius.lg)
        )
    }
}

/// Icon tile, title, the current value, and what tapping does.
struct ProfileRowLabel: View {
    enum Trailing { case push, menu, toggle(Bool), none }
    let icon: String
    let tint: ActionRow.Tint
    let title: String
    let value: String?
    let chevron: Trailing

    var body: some View {
        HStack(spacing: Space.sm + 1) {
            Image(systemName: icon)
                .font(TextStyle.label.font)
                .foregroundStyle(iconColor)
                .frame(width: Size.iconTile, height: Size.iconTile)
                .background(tileColor, in: RoundedRectangle(cornerRadius: Radius.xs))
                .accessibilityHidden(true)
            Text(title)
                .textStyle(.rowTitle)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer(minLength: Space.xs)
            if let value {
                // The value gives way first: it truncates rather than pushing the row wider.
                Text(value)
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            switch chevron {
            case .push:
                Image(systemName: "chevron.right").font(TextStyle.chip.font).foregroundStyle(Palette.inkMuted).accessibilityHidden(true)
            case .menu:
                Image(systemName: "chevron.up.chevron.down").font(TextStyle.micro.font).foregroundStyle(Palette.inkMuted).accessibilityHidden(true)
            case .toggle(let on):
                MockSwitch(isOn: on)
            case .none:
                EmptyView()
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .frame(minHeight: Size.row)
        .contentShape(Rectangle())
    }

    private var iconColor: Color {
        switch tint { case .navy: Palette.onInkFill; case .copper: Palette.copperText; case .blue: Palette.blueText }
    }
    private var tileColor: Color {
        switch tint { case .navy: Palette.inkFill; case .copper: Palette.copperTint; case .blue: Palette.blueTint }
    }
}

/// A tappable `ProfileRowLabel` with a chevron.
private struct ProfileRow: View {
    let icon: String
    let tint: ActionRow.Tint
    let title: String
    let value: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProfileRowLabel(icon: icon, tint: tint, title: title, value: value, chevron: .push)
        }
        .buttonStyle(.plain)
    }
}

/// One value to type in: a name, or a number with a unit and a sensible range.
struct ValueEdit: Identifiable {
    let id = UUID()
    let title: String
    let unit: String?
    let initial: String
    let isNumber: Bool
    let range: ClosedRange<Double>?
    let onSave: (String) -> Void

    static func text(_ title: String, _ initial: String, onSave: @escaping (String) -> Void) -> ValueEdit {
        ValueEdit(title: title, unit: nil, initial: initial, isNumber: false, range: nil, onSave: onSave)
    }

    static func number(_ title: String, unit: String, _ initial: String, range: ClosedRange<Double>,
                       onSave: @escaping (Double) -> Void) -> ValueEdit {
        ValueEdit(title: title, unit: unit, initial: initial, isNumber: true, range: range) { text in
            if let v = OnboardingDraft.number(text) { onSave(v) }
        }
    }

    func isValid(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard isNumber else { return !t.isEmpty }
        guard let v = OnboardingDraft.number(t) else { return false }
        return range.map { $0.contains(v) } ?? true
    }
}

/// Plain header (not a nav bar, so Save works in one tap with the keyboard up) and one field.
private struct ValueSheet: View {
    let edit: ValueEdit
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Button("Cancel") { dismiss() }
                    .textStyle(.chip)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(edit.title).textStyle(.headline).foregroundStyle(Palette.ink)
                Spacer()
                Button {
                    edit.onSave(text.trimmingCharacters(in: .whitespaces))
                    dismiss()
                } label: {
                    Text("Save")
                        .textStyle(.chip)
                        .foregroundStyle(Palette.onInkFill)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.xs + 1)
                        .background(Palette.inkFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!edit.isValid(text))
                .opacity(edit.isValid(text) ? 1 : 0.5)
            }
            if let unit = edit.unit {
                UnitField(text: $text, placeholder: "", unit: unit, accessibilityLabel: edit.title)
                    .focused($focused)
                if let range = edit.range, !text.isEmpty, !edit.isValid(text) {
                    Text("Enter a value between \(Int(range.lowerBound)) and \(Int(range.upperBound)) \(unit).")
                        .textStyle(.caption)
                        .foregroundStyle(Palette.copperText)
                }
            } else {
                TextField(edit.title, text: $text)
                    .textStyle(.input)
                    .foregroundStyle(Palette.ink)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, Space.md)
                    .frame(minHeight: Size.buttonTall)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
                    .focused($focused)
            }
            Spacer()
        }
        .padding(Space.lg)
        .pageBackground()
        .onAppear { text = edit.initial; focused = true }
        .presentationDetents([.medium])
    }
}

private struct EquipmentEditor: View {
    let record: ProfileRecord
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("Every exercise and every swap is built from this list.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                ForEach(Equipment.Group.allCases, id: \.self) { group in
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text(group.title).textStyle(.label).foregroundStyle(Palette.ink)
                        FlowLayout {
                            ForEach(Equipment.allCases.filter { $0.group == group }, id: \.self) { item in
                                Chip(title: item.title, isSelected: record.equipment.contains(item.rawValue)) {
                                    if let i = record.equipment.firstIndex(of: item.rawValue) {
                                        record.equipment.remove(at: i)
                                    } else {
                                        record.equipment.append(item.rawValue)
                                    }
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                }
            }
            .padding(Space.lg)
            .readableColumn()
        }
        .pageBackground()
        .navigationTitle("Equipment")
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct LimitationsEditor: View {
    let record: ProfileRecord
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("Exercises that load these areas are left out of your plan.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                FlowLayout {
                    ForEach(Limitation.allCases, id: \.self) { item in
                        Chip(title: item.title, isSelected: record.limitations.contains(item.rawValue)) {
                            if let i = record.limitations.firstIndex(of: item.rawValue) {
                                record.limitations.remove(at: i)
                            } else {
                                record.limitations.append(item.rawValue)
                            }
                            try? modelContext.save()
                        }
                    }
                }
                if !record.limitations.isEmpty {
                    InlineNote(text: "If any of these hurt right now, check with a clinician before you train.", systemImage: "cross.case")
                }
            }
            .padding(Space.lg)
            .readableColumn()
        }
        .pageBackground()
        .navigationTitle("Areas to protect")
        .toolbar(.visible, for: .navigationBar)
    }
}

/// How often, which days, the whole day or one meal, and what pays for it — with what that means in calories.
private struct CheatDaysEditor: View {
    let record: ProfileRecord
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]

    var body: some View {
        let profile = record.profile()
        let cheat = profile.cheatDays
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                group("How often") {
                    ForEach(CheatDays.Frequency.allCases, id: \.self) { f in
                        Chip(title: f.title, isSelected: cheat.frequency == f) { set { $0.frequency = f } }
                    }
                }
                if cheat.frequency != .none {
                    group(cheat.frequency == .twice ? "Which days (pick two)" : "Which day") {
                        ForEach(Weekday.displayOrder, id: \.self) { day in
                            Chip(title: Weekday.shortName(day), isSelected: cheat.activeWeekdays.contains(day)) {
                                set { c in
                                    // The newest pick comes first; the oldest drops off past the count.
                                    c.weekdays.removeAll { $0 == day }
                                    c.weekdays.insert(day, at: 0)
                                    c.weekdays = Array(c.weekdays.prefix(max(2, c.frequency.count)))
                                }
                            }
                        }
                    }
                    group("What it is") {
                        ForEach(CheatDays.Style.allCases, id: \.self) { s in
                            Chip(title: s.title, isSelected: cheat.style == s) { set { $0.style = s } }
                        }
                    }
                    group("Paying for it") {
                        ForEach(CheatDays.Budget.allCases, id: \.self) { b in
                            Chip(title: b.title, isSelected: cheat.budget == b) { set { $0.budget = b } }
                        }
                    }
                    InlineNote(text: effect(profile), systemImage: "info.circle")
                }
            }
            .padding(Space.lg)
            .readableColumn()
        }
        .pageBackground()
        .navigationTitle("Cheat days")
        .toolbar(.visible, for: .navigationBar)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title).textStyle(.label).foregroundStyle(Palette.ink)
            FlowLayout { content() }
        }
    }

    private func set(_ change: (inout CheatDays) -> Void) {
        var p = record.profile()
        change(&p.cheatDays)
        record.cheatFrequency = p.cheatDays.frequency.rawValue
        record.cheatWeekdays = p.cheatDays.weekdays
        record.cheatStyle = p.cheatDays.style.rawValue
        record.cheatBudget = p.cheatDays.budget.rawValue
        try? modelContext.save()
    }

    /// What the choice does to the week, in plain numbers.
    private func effect(_ profile: UserProfile) -> String {
        let targets = TargetsStore.current(weekly, profile: profile)
        let week = CalorieWeek.week(for: profile, base: targets.calories, expenditure: targets.expenditure)
        let cheatDays = week.days.enumerated().filter { $0.element.cheat != nil }
        guard let first = cheatDays.first?.element else { return "" }
        let what = first.cheat == .meal
            ? "a free meal of about \(Formatters.kcal(first.cheatMealKcal ?? 0)) kcal in place of dinner"
            : "about \(Formatters.kcal(first.calories)) kcal for the day"
        let others = week.days.filter { $0.cheat == nil }
        let cut = others.isEmpty ? 0 : others.reduce(0) { $0 + $1.plain - $1.calories } / others.count
        var text = "On cheat days you have \(what)."
        if profile.cheatDays.budget == .spread {
            text += cut > 0 ? " The other days eat about \(cut) kcal less to pay for it." : ""
            if week.unpaidKcal > 0 {
                text += " Your other days are already near the safe minimum, so \(Formatters.kcal(week.unpaidKcal)) kcal a week can't be made up — your goal date moves a little."
            }
        } else if let with = TargetCalculator.weeksToGoal(for: profile) {
            var without = profile
            without.cheatDays.frequency = .none
            if let base = TargetCalculator.weeksToGoal(for: without), with > base {
                text += " Nothing else changes; your goal moves from \(base) to \(with) weeks."
            } else {
                text += " Nothing else changes."
            }
        }
        return text
    }
}

private struct FoodEditor: View {
    let record: ProfileRecord
    @Environment(\.modelContext) private var modelContext
    @State private var searchingFoods = false

    var body: some View {
        let profile = record.profile()
        let ruledOut = Protein.ruledOut(by: profile.diet, rules: profile.foodRules)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                group("Food rules", hint: "On top of your diet style.") {
                    ForEach(FoodRule.allCases, id: \.self) { rule in
                        Chip(title: "\(rule.title) · \(rule.subtitle.lowercased())", isSelected: record.foodRules.contains(rule.rawValue)) {
                            toggle(\.foodRules, rule.rawValue)
                        }
                    }
                }
                if ruledOut.count < Protein.allCases.count {
                    group("Proteins you eat", hint: "Hard rule: meals with the ones you untick never appear.") {
                        ForEach(Protein.allCases.filter { !ruledOut.contains($0) }, id: \.self) { protein in
                            Chip(title: protein.title, isSelected: !record.excludedProteins.contains(protein.rawValue)) {
                                toggle(\.excludedProteins, protein.rawValue)
                            }
                        }
                    }
                }
                if profile.snacksBetweenMeals {
                    group("Snack taste", hint: "Which snacks to lean towards.") {
                        ForEach(SnackTaste.allCases, id: \.self) { taste in
                            Chip(title: taste.title, isSelected: profile.snackTaste == taste) {
                                record.snackTaste = taste.rawValue
                                try? modelContext.save()
                            }
                        }
                    }
                }
                group("Cuisines", hint: "Your meals come from these kitchens.") {
                    ForEach(Cuisine.allCases, id: \.self) { c in
                        Chip(title: c.rawValue, isSelected: record.cuisines.contains(c.rawValue)) { toggle(\.cuisines, c.rawValue) }
                    }
                }
                group("Allergies", hint: "Hard rule: meals with these never appear.") {
                    ForEach(Allergen.allCases, id: \.self) { a in
                        Chip(title: a.title, isSelected: record.allergens.contains(a.rawValue)) { toggle(\.allergens, a.rawValue) }
                    }
                }
                group("Foods you won't eat", hint: "Avoided wherever there's an alternative.") {
                    ForEach(FoodDislikes.options + record.dislikes.filter { !FoodDislikes.options.contains($0) }.sorted(), id: \.self) { f in
                        Chip(title: f, isSelected: record.dislikes.contains(f)) { toggle(\.dislikes, f) }
                    }
                    Chip(title: "Search more…", isSelected: false) { searchingFoods = true }
                }
            }
            .padding(Space.lg)
            .readableColumn()
        }
        .pageBackground()
        .navigationTitle("Food preferences")
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $searchingFoods) {
            FoodSearchPicker(selection: Binding(get: { Set(record.dislikes) }, set: {
                record.dislikes = $0.sorted()
                try? modelContext.save()
            }))
        }
    }

    private func group<C: View>(_ title: String, hint: String, @ViewBuilder chips: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title).textStyle(.label).foregroundStyle(Palette.ink)
            Text(hint).textStyle(.caption).foregroundStyle(Palette.inkMuted)
            FlowLayout { chips() }
        }
    }

    private func toggle(_ key: ReferenceWritableKeyPath<ProfileRecord, [String]>, _ value: String) {
        if let i = record[keyPath: key].firstIndex(of: value) { record[keyPath: key].remove(at: i) }
        else { record[keyPath: key].append(value) }
        try? modelContext.save()
    }
}
