import SwiftUI
import FlexFitEngine

/// 1-tap swap (PRD F3): the top 3 alternatives, ranked by the engine, with a "why this" line.
struct SwapSheet: View {
    let exercise: Exercise
    let profile: UserProfile
    /// What's in play today (the travel kit while Travel Mode is on).
    let equipment: Set<Equipment>
    let history: Set<String>
    let usedThisWeek: Set<String>
    let onChoose: (Exercise, SwapScope) -> Void

    @State private var scope: SwapScope = .today

    private var options: [SwapOption] {
        SwapRanker.alternatives(for: exercise, equipment: equipment, limitations: profile.limitations,
                                history: history, usedThisWeek: usedThisWeek)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Swap")
                    .textStyle(.kicker)
                    .foregroundStyle(Palette.copperText)
                Text(exercise.name)
                    .textStyle(.title2)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs - 2)
                    .accessibilityAddTraits(.isHeader)

                Picker("Why", selection: $scope) {
                    Text("Machine taken").tag(SwapScope.today)
                    Text("Don't like it").tag(SwapScope.always)
                }
                .pickerStyle(.segmented)
                .padding(.top, Space.md)

                Text(scope == .today ? "Just for today. Your plan stays the same next week." : "From now on, in every week of your plan.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .padding(.top, Space.xs)

                if options.isEmpty {
                    InlineNote(text: "Nothing else with your equipment trains this movement safely. Keep it, or add equipment in Settings (tap your initial).")
                        .padding(.top, Space.md)
                } else {
                    CardList {
                        ForEach(options, id: \.exercise.id) { option in
                            Button { onChoose(option.exercise, scope) } label: {
                                OptionRow(option: option, owned: equipment)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, Space.md)
                }
            }
            .padding(Space.lg)
            .readableColumn()
        }
        .background(Palette.page)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct OptionRow: View {
    let option: SwapOption
    let owned: Set<Equipment>

    var body: some View {
        HStack(spacing: Space.sm) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(option.exercise.name)
                    .textStyle(.rowTitle)
                    .foregroundStyle(Palette.ink)
                Text(why)
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let load = option.carriedLoadKg {
                Text(load.formatted(.number.precision(.fractionLength(0...1))) + " kg")
                    .textStyle(.label)
                    .foregroundStyle(Palette.copperText)
            }
            Image(systemName: "chevron.right")
                .font(TextStyle.chip.font)
                .foregroundStyle(Palette.inkMuted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm + 1)
        .frame(minHeight: Size.row)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// "Why this": same muscles, joint-friendlier, and what it needs.
    private var why: String {
        var parts: [String] = []
        parts.append(option.sameMuscles ? "Same muscles" : "Same movement")
        if option.easierOnJoints { parts.append("easier on your joints") }
        parts.append(ExerciseCopy.equipment(option.exercise, owned: owned))
        return parts.joined(separator: " · ")
    }
}
