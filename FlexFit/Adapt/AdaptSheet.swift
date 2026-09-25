import SwiftUI
import SwiftData
import FlexFitEngine

/// ⚡ Adapt: reshape today — energy, soreness, Travel Mode (PRD F4, F5).
struct AdaptSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementService.self) private var entitlements
    @Query private var profiles: [ProfileRecord]
    @Query private var logs: [DailyLog]
    @Query private var swaps: [ExerciseSwap]
    @Query private var painFlags: [PainFlag]

    @State private var travelUntil = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now

    private let today = Date.now

    var body: some View {
        NavigationStack {
            if let record = profiles.first {
                content(record)
                    .navigationTitle("Adapt today")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
        }
        .presentationDetents([.large])
    }

    private func content(_ record: ProfileRecord) -> some View {
        let resolver = PlanResolver(record: record, swaps: swaps, logs: logs, painFlags: painFlags)
        let weekday = TrainView.todayWeekday
        let day = resolver.week[weekday]
        let log = resolver.log(for: today)
        let plan = resolver.session(forWeekday: weekday, on: today, applyPivot: true)
        let pivotsLeft = entitlements.pivotsLeftThisMonth(logs: logs, now: today)

        return ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                PreviewCard(day: day, plan: plan, travel: record.activeTravelKit(now: today))

                if day.kind == .training {
                    section(title: "Energy", trailing: pivotsLeft.map { "\($0) of \(FreeTier.pivotsPerMonth) low-energy pivots left this month" }) {
                        CardList {
                            ForEach(Energy.allCases, id: \.self) { energy in
                                ChoiceRow(title: energy.title, subtitle: energySubtitle(energy),
                                          isSelected: log?.energyValue == energy) {
                                    pick(energy, current: log?.energyValue, pivotsLeft: pivotsLeft)
                                }
                            }
                        }
                    }

                    section(title: "Anything sore?", trailing: "Optional. Exercises that load it are swapped today.") {
                        FlowLayout {
                            ForEach(SoreArea.allCases, id: \.self) { area in
                                Chip(title: area.title, isSelected: log?.soreAreas.contains(area.rawValue) == true) {
                                    toggleSore(area)
                                }
                            }
                        }
                    }
                } else {
                    InlineNote(text: day.kind == .rest
                               ? "Rest day, nothing to adapt. Travel Mode below applies to your next sessions."
                               : "Recovery day: a walk and mobility. Travel Mode below applies to your next sessions.")
                }

                travelSection(record)
            }
            .padding(Space.lg)
            .readableColumn()
        }
        .pageBackground()
    }

    // MARK: Travel Mode

    @ViewBuilder
    private func travelSection(_ record: ProfileRecord) -> some View {
        let active = record.activeTravelKit(now: today)
        section(title: "Travel mode", badge: entitlements.canUseTravelMode ? nil : "Pro",
                trailing: "Same muscle groups with what you have on the road.") {
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
                    .padding(.top, Space.xs)
                }
            } else {
                Button { showPaywall(.travel) } label: {
                    ActionRowContent(icon: "airplane", title: "Unlock Travel Mode",
                                     subtitle: "Bodyweight, bands or hotel dumbbells, until the date you pick")
                }
                .buttonStyle(.plain)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
            }
        }
    }

    // MARK: Actions

    private func pick(_ energy: Energy, current: Energy?, pivotsLeft: Int?) {
        if energy == .low, entitlements.lowNeedsPro(todayIsLow: current == .low, logs: logs, now: today) {
            showPaywall(.pivots)
            return
        }
        DailyLog.forDay(today, in: modelContext).energyValue = energy
        try? modelContext.save()
    }

    /// A sheet can't present the root's paywall over itself: close first, then ask for it.
    private func showPaywall(_ reason: AppRouter.PaywallReason) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            router.paywall = reason
        }
    }

    private func toggleSore(_ area: SoreArea) {
        let log = DailyLog.forDay(today, in: modelContext)
        if let i = log.soreAreas.firstIndex(of: area.rawValue) {
            log.soreAreas.remove(at: i)
        } else {
            log.soreAreas.append(area.rawValue)
        }
        log.updatedAt = .now
        try? modelContext.save()
    }

    private func setTravel(_ kit: TravelKit?, record: ProfileRecord) {
        record.travelKit = kit?.rawValue
        record.travelUntil = kit == nil ? nil : (record.travelUntil.flatMap { $0 > today ? $0 : nil } ?? travelUntil)
        try? modelContext.save()
    }

    private func energySubtitle(_ energy: Energy) -> String {
        switch energy {
        case .high: "Full session, loads up. Optional finisher."
        case .ok: "Session as written."
        case .low: "Trimmed: top 3 lifts, 2 sets each. Still counts."
        }
    }

    // MARK: Layout

    private func section<Content: View>(title: String, badge: String? = nil, trailing: String? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs - 2) {
                Text(title)
                    .textStyle(.headline)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                if let badge { ProBadge(text: badge) }
            }
            if let trailing {
                Text(trailing)
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
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
