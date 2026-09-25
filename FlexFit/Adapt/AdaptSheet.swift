import SwiftUI
import SwiftData
import FlexFitEngine

/// ⚡ Adapt (mock "What changed?"): one tap and the session and the food both move.
/// Below the mock's five rows: soreness (PRD F4) and multi-day Travel Mode (PRD F5).
struct AdaptSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementService.self) private var entitlements
    @Query private var profiles: [ProfileRecord]
    @Query private var logs: [DailyLog]
    @Query private var swaps: [ExerciseSwap]
    @Query private var painFlags: [PainFlag]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]
    @Query private var ingredientSwaps: [IngredientSwapRecord]

    @State private var travelUntil = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
    private let today = Date.now

    var body: some View {
        MockSheet(kicker: "Adapt today", title: "What changed?",
                  subtitle: "One tap — the session and the food both move with you.",
                  footer: "Adapting is the streak. Skipping is what ends it.") {
            if let record = profiles.first { content(record) }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func content(_ record: ProfileRecord) -> some View {
        let resolver = PlanResolver(record: record, swaps: swaps, logs: logs, painFlags: painFlags)
        let weekday = TrainView.todayWeekday
        let day = resolver.week[weekday]
        let log = resolver.log(for: today)
        let plan = resolver.session(forWeekday: weekday, on: today, applyPivot: true)
        let pivotsLeft = entitlements.pivotsLeftThisMonth(logs: logs, now: today)
        let lowMinutes = EnergyPivot.pivot(energy: .low, lowYesterday: resolver.log(for: today.addingTimeInterval(-86_400))?.energyValue == .low,
                                           plannedMinutes: day.minutes).minutes

        PreviewCard(day: day, plan: plan, travel: record.activeTravelKit(now: today))

        CardList {
            SheetRow(badge: "☾", title: "I’m low on energy",
                     subtitle: "Session drops to \(lowMinutes) min, top lifts only." + (pivotsLeft.map { " \($0) of \(FreeTier.pivotsPerMonth) left this month." } ?? "")) {
                setEnergy(.low, current: log?.energyValue, toast: "Cut to \(lowMinutes) minutes. Streak intact.")
            }
            SheetRow(badge: "⌂", title: "I can’t reach the gym",
                     subtitle: "Zero-equipment session, same muscles." + (entitlements.canUseTravelMode ? "" : " Pro.")) {
                noGym(record)
            }
            SheetRow(badge: "◍", title: "I’m missing an ingredient", subtitle: "Rebuild your next meal from what you have.") {
                missingIngredient(record)
            }
            SheetRow(badge: "▣", title: "I’m eating out", subtitle: "Three safe orders for the cuisine you’re at.") {
                handOff { router.isRestaurantPresented = true }
            }
            SheetRow(badge: "✦", title: "I feel strong", subtitle: "Full session, loads up where you earned them.") {
                if record.activeTravelKit(now: today) == TravelKit.none, record.travelUntil.map({ Calendar.current.isDateInToday($0) }) == true {
                    record.travelKit = nil; record.travelUntil = nil
                }
                setEnergy(.high, current: log?.energyValue, toast: "Full session. Loads go up where you've earned them.")
            }
        }

        if day.kind == .training {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Anything sore?").textStyle(.headline).foregroundStyle(Palette.ink)
                Text("Exercises that load it are swapped today.").textStyle(.caption).foregroundStyle(Palette.inkMuted)
                FlowLayout {
                    ForEach(SoreArea.allCases, id: \.self) { area in
                        Chip(title: area.title, isSelected: log?.soreAreas.contains(area.rawValue) == true) { toggleSore(area) }
                    }
                }
            }
            .padding(.top, Space.xs)
        }

        travelSection(record)
    }

    // MARK: Travel Mode (multi-day)

    @ViewBuilder
    private func travelSection(_ record: ProfileRecord) -> some View {
        let active = record.activeTravelKit(now: today)
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs - 2) {
                Text("Travelling for a few days?").textStyle(.headline).foregroundStyle(Palette.ink)
                if !entitlements.canUseTravelMode { ProBadge() }
            }
            Text("Travel mode: same muscle groups with what you have on the road, until the date you pick.")
                .textStyle(.caption).foregroundStyle(Palette.inkMuted).fixedSize(horizontal: false, vertical: true)
            if entitlements.canUseTravelMode {
                CardList {
                    ForEach(TravelKit.allCases, id: \.self) { kit in
                        ChoiceRow(title: kit.title, subtitle: kit.subtitle, isSelected: active == kit) {
                            setTravel(active == kit ? nil : kit, record: record)
                        }
                    }
                }
                if active != nil {
                    DatePicker("Until", selection: Binding(
                        get: { record.travelUntil ?? travelUntil },
                        set: { record.travelUntil = $0; try? modelContext.save() }
                    ), in: today...(Calendar.current.date(byAdding: .day, value: 30, to: today) ?? today), displayedComponents: .date)
                    .textStyle(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.xs)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
                }
            } else {
                Button { handOff { router.paywall = .travel } } label: {
                    ActionRowContent(icon: "airplane", title: "Unlock Travel Mode",
                                     subtitle: "Bodyweight, bands or hotel dumbbells, until the date you pick")
                }
                .buttonStyle(.plain)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
            }
        }
        .padding(.top, Space.xs)
    }

    // MARK: Actions

    private func setEnergy(_ energy: Energy, current: Energy?, toast: String) {
        if energy == .low, entitlements.lowNeedsPro(todayIsLow: current == .low, logs: logs, now: today) {
            handOff { router.paywall = .pivots }
            return
        }
        DailyLog.forDay(today, in: modelContext).energyValue = energy
        try? modelContext.save()
        dismiss()
        router.toast(toast)
    }

    private func noGym(_ record: ProfileRecord) {
        guard entitlements.canUseTravelMode else { handOff { router.paywall = .travel }; return }
        record.travelKit = TravelKit.none.rawValue
        record.travelUntil = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: today)
        try? modelContext.save()
        dismiss()
        router.toast("No-gym mode on — zero-equipment session, same muscles.")
    }

    private func missingIngredient(_ record: ProfileRecord) {
        let profile = record.profile()
        let context = MealPlanContext(profile: profile, targets: TargetsStore.current(weekly, profile: profile), swaps: ingredientSwaps)
        let meals = context.meals(on: today)
        let eaten = Set(logs.first { Calendar.current.isDateInToday($0.day) }?.eatenMeals ?? [])
        guard let next = MealPlanContext.nextMeal(meals, eaten: eaten) ?? meals.first else { return }
        handOff { router.ingredientSwap = MealSelection(date: today, planned: next) }
    }

    /// A sheet can't present the root's sheets over itself: close first, then ask for the next one.
    private func handOff(_ action: @escaping @MainActor () -> Void) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            action()
        }
    }

    private func toggleSore(_ area: SoreArea) {
        let log = DailyLog.forDay(today, in: modelContext)
        if let i = log.soreAreas.firstIndex(of: area.rawValue) {
            log.soreAreas.remove(at: i)
        } else {
            log.soreAreas.append(area.rawValue)
            router.toast("Sore \(area.title.lowercased()): those exercises are swapped today.")
        }
        log.updatedAt = .now
        try? modelContext.save()
    }

    private func setTravel(_ kit: TravelKit?, record: ProfileRecord) {
        record.travelKit = kit?.rawValue
        record.travelUntil = kit == nil ? nil : (record.travelUntil.flatMap { $0 > today ? $0 : nil } ?? travelUntil)
        try? modelContext.save()
        router.toast(kit == nil ? "Travel mode off. Back to your normal sessions." : "Travel mode on: \(kit!.title.lowercased()).")
    }
}

/// The mock's "Daily check-in" sheet (opened by "Change" on Today).
struct EnergySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementService.self) private var entitlements
    @Query private var logs: [DailyLog]

    var body: some View {
        MockSheet(kicker: "Daily check-in", title: "How much have you got today?",
                  subtitle: "Ten seconds — the plan reshapes itself.") {
            CardList {
                SheetRow(badge: "✦", title: "High — let’s go", subtitle: "Full session, loads up where earned.") { pick(.high, "Full session locked in.") }
                SheetRow(badge: "⚡", title: "Medium — normal day", subtitle: "Session as written, hold the loads.") { pick(.ok, "Session as written.") }
                SheetRow(badge: "☾", title: "Low — barely slept", subtitle: "Trimmed session. Calories stay put: tired days aren't diet days.") { pick(.low, "Downsized. Still counts.") }
            }
        }
        .presentationDetents([.medium])
    }

    private func pick(_ energy: Energy, _ message: String) {
        let todayLog = logs.first { Calendar.current.isDateInToday($0.day) }
        if energy == .low, entitlements.lowNeedsPro(todayIsLow: todayLog?.energyValue == .low, logs: logs) {
            dismiss()
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(450)); router.paywall = .pivots }
            return
        }
        DailyLog.forDay(.now, in: modelContext).energyValue = energy
        try? modelContext.save()
        dismiss()
        router.toast(message)
    }
}

/// What today looks like after the adjustments above. Navy panel, fixed-dark content.
private struct PreviewCard: View {
    let day: PlannedDay
    let plan: SessionPlan?
    let travel: TravelKit?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Today becomes")
                .textStyle(.micro)
                .foregroundStyle(Palette.onPanelMuted)
            Text(title)
                .textStyle(.title2)
                .foregroundStyle(Palette.onPanel)
            Text(meta)
                .textStyle(.caption)
                .foregroundStyle(Palette.onPanelMuted)
            if let travel {
                Label("Travel mode · \(travel.title.lowercased())", systemImage: "airplane")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.ice)
                    .padding(.top, Space.xxs)
            }
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.panelEdge))
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        guard let plan else { return day.kind == .rest ? "Rest day" : "Walk + mobility" }
        let base = plan.focus.title
        switch plan.variant {
        case .full: return base
        case .trimmed: return "\(base), trimmed"
        case .minimum: return "Minimum session"
        }
    }

    private var meta: String {
        guard let plan else { return day.minutes > 0 ? "\(day.minutes) min · easy" : "Recover" }
        return "\(plan.minutes) min · \(plan.exercises.count) exercises · RPE ≤ \(plan.exercises.first?.rpeCap ?? 8)"
    }
}

extension SoreArea {
    var title: String {
        switch self {
        case .chest: "Chest"
        case .shoulders: "Shoulders"
        case .back: "Back"
        case .arms: "Arms"
        case .legs: "Legs"
        case .core: "Core"
        }
    }
}

extension TravelKit {
    var title: String {
        switch self {
        case .none: "No equipment"
        case .bands: "Resistance bands"
        case .hotelDumbbells: "Hotel dumbbells"
        }
    }

    var subtitle: String {
        switch self {
        case .none: "Bodyweight and a chair"
        case .bands: "Bands, bodyweight and a chair"
        case .hotelDumbbells: "A hotel gym's dumbbells and a chair"
        }
    }
}

struct ProBadge: View {
    var text = "Pro"

    var body: some View {
        Text(text)
            .textStyle(.kicker)
            .foregroundStyle(Palette.copperText)
            .padding(.horizontal, Space.xs - 2)
            .padding(.vertical, Space.xxs - 1)
            .background(Palette.copperTint, in: Capsule())
    }
}

/// Row body shared by tappable action rows.
struct ActionRowContent: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Space.sm + 1) {
            Image(systemName: icon)
                .font(TextStyle.rowTitle.font)
                .foregroundStyle(Palette.onInkFill)
                .frame(width: Size.iconTile, height: Size.iconTile)
                .background(Palette.inkFill, in: RoundedRectangle(cornerRadius: Radius.xs))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(title)
                    .textStyle(.rowTitle)
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(TextStyle.chip.font)
                .foregroundStyle(Palette.inkMuted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md - 2)
        .contentShape(Rectangle())
    }
}
