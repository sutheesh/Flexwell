import SwiftUI
import SwiftData
import FlexFitEngine

/// Settings: plan inputs, Apple Health, Pro, the health notice (PRD: disclaimer in onboarding *and* settings).
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementService.self) private var entitlements
    @Environment(StoreService.self) private var store
    @Query private var profiles: [ProfileRecord]
    @State private var legal: LegalPage?
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            if let record = profiles.first {
                form(record)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            }
        }
        .legalPage($legal)
    }

    private func form(_ record: ProfileRecord) -> some View {
        Form {
            Section("Plan") {
                Picker("Training days", selection: bind(record, \.trainingDays)) {
                    ForEach(2...6, id: \.self) { Text("\($0) days").tag($0) }
                }
                Picker("Session length", selection: bind(record, \.sessionMinutes)) {
                    ForEach([20, 30, 45, 60], id: \.self) { Text("\($0) min").tag($0) }
                }
                Picker("Units", selection: bind(record, \.displayUnits)) {
                    Text("Metric (kg)").tag(DisplayUnits.metric.rawValue)
                    Text("Imperial (lb)").tag(DisplayUnits.imperial.rawValue)
                }
                Picker("Goal", selection: bind(record, \.goal)) {
                    ForEach(Goal.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                }
                NavigationLink("Equipment") { EquipmentEditor(record: record) }
                NavigationLink("Areas to protect") { LimitationsEditor(record: record) }
            }

            Section("Food") {
                Picker("Diet style", selection: bind(record, \.dietStyle)) {
                    ForEach(DietStyle.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Meals per day", selection: bind(record, \.mealPattern)) {
                    ForEach(MealPattern.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Max cooking time", selection: bind(record, \.maxCookMinutes)) {
                    ForEach([10, 20, 40, 0], id: \.self) { Text($0 == 0 ? "No limit" : "\($0) min").tag($0) }
                }
                NavigationLink("Cuisines, allergies & dislikes") { FoodEditor(record: record) }
            }

            Section {
                Picker("Check-in reminder", selection: bind(record, \.reminder)) {
                    ForEach(ReminderTime.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Tone", selection: bind(record, \.tone)) {
                    ForEach(CoachTone.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Shopping day", selection: bind(record, \.shopDay)) {
                    ForEach(ShopDay.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                }
            } header: {
                Text("Coaching")
            } footer: {
                Text(Reminders.message(CoachTone(rawValue: record.tone) ?? .direct))
            }
            .onChange(of: record.reminder + record.tone) {
                let p = record.profile()
                Task { await Reminders.schedule(time: p.reminder, tone: p.tone) }
            }

            Section {
                Toggle("Sync with Apple Health", isOn: Binding(
                    get: { record.healthSyncEnabled },
                    set: { on in
                        if on {
                            Task {
                                let ok = await HealthService.shared.requestAuthorization()
                                record.healthSyncEnabled = ok
                                try? modelContext.save()
                                if ok { await TargetsStore.importHealthWeights(context: modelContext) }
                            }
                        } else {
                            record.healthSyncEnabled = false
                            try? modelContext.save()
                        }
                    }
                ))
                .disabled(!HealthService.shared.isAvailable)
            } header: {
                Text("Apple Health")
            } footer: {
                Text("Reads your body weight for the weekly trend and saves finished sessions as strength workouts. Nothing leaves your devices.")
            }

            Section("FlexFit Pro") {
                if entitlements.isPro {
                    Label("Pro is active", systemImage: "checkmark.seal")
                } else {
                    Button("See what Pro adds") {
                        // Close Settings first; the paywall is presented from the root.
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(450))
                            router.paywall = .settings
                        }
                    }
                }
                Button("Restore purchases") { Task { await store.restore() } }
                #if DEBUG
                Toggle("Debug: pretend Pro", isOn: Binding(
                    get: { entitlements.debugProOverride },
                    set: { entitlements.debugProOverride = $0 }
                ))
                #endif
            }

            Section {
                Text("FlexFit gives general fitness guidance, not medical advice. If you have a medical condition, are pregnant, or feel pain, check with a clinician before training or changing how you eat.")
                Text("Your health data stays on this device and in your own iCloud. No ads, no data sales.")
                Button("Privacy Policy") { legal = .privacy }
                Button("Terms of Use") { legal = .terms }
            } header: {
                Text("Health & privacy")
            }

            Section {
                Button("Start over", role: .destructive) { confirmReset = true }
            } footer: {
                Text("Deletes your plan, logs and weigh-ins from this device. Apple Health data is untouched.")
            }
        }
        .scrollContentBackground(.hidden)
        .pageBackground()
        .confirmationDialog("Start over?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { reset() }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func bind<T>(_ record: ProfileRecord, _ key: ReferenceWritableKeyPath<ProfileRecord, T>) -> Binding<T> {
        Binding(get: { record[keyPath: key] }, set: { record[keyPath: key] = $0; try? modelContext.save() })
    }

    private func reset() {
        for model in [ProfileRecord.self, DailyLog.self, ExerciseSwap.self, SessionLog.self, WeighIn.self,
                      WeeklyTargets.self, PainFlag.self, IngredientSwapRecord.self,
                      GroceryCheck.self, PantryItem.self] as [any PersistentModel.Type] {
            try? modelContext.delete(model: model)
        }
        try? modelContext.save()
        dismiss()
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
    }
}

private struct FoodEditor: View {
    let record: ProfileRecord
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
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
                    ForEach(FoodDislikes.options, id: \.self) { f in
                        Chip(title: f, isSelected: record.dislikes.contains(f)) { toggle(\.dislikes, f) }
                    }
                }
            }
            .padding(Space.lg)
            .readableColumn()
        }
        .pageBackground()
        .navigationTitle("Food preferences")
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
