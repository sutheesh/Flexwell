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
        MockSheet(kicker: "Swap · \(exercise.primaryMuscles.first?.title ?? "")", title: "Replace \(exercise.name)",
                  subtitle: "Same movement, same set volume, only gear you have.",
                  footer: "Bench taken, shoulder cranky, rack is a queue — swapping is not cheating.") {
            Picker("Why", selection: $scope) {
                Text("Machine taken").tag(SwapScope.today)
                Text("Don't like it").tag(SwapScope.always)
            }
            .pickerStyle(.segmented)
            Text(scope == .today ? "Just for today. Your plan stays the same next week." : "From now on, in every week of your plan.")
                .textStyle(.caption)
                .foregroundStyle(Palette.inkMuted)
            if options.isEmpty {
                InlineNote(text: "Nothing else with your equipment trains this movement safely. Keep it, or add equipment in Profile (tap your initial).")
            } else {
                CardList {
                    ForEach(Array(options.enumerated()), id: \.element.exercise.id) { i, option in
                        SheetRow(badge: String(UnicodeScalar(UInt8(65 + i))), title: option.exercise.name,
                                 subtitle: why(option),
                                 trailing: option.carriedLoadKg.map { $0.formatted(.number.precision(.fractionLength(0...1))) + " kg" }) {
                            onChoose(option.exercise, scope)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// "Why this": same muscles, joint-friendlier, and what it needs.
    private func why(_ option: SwapOption) -> String {
        var parts: [String] = [option.sameMuscles ? "Same muscles" : "Same movement"]
        if option.easierOnJoints { parts.append("easier on your joints") }
        parts.append(ExerciseCopy.equipment(option.exercise, owned: equipment))
        return parts.joined(separator: " · ")
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
