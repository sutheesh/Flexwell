import SwiftUI
import FlexFitEngine

// Shared controls from the mock. Each draws only from DesignTokens.

/// Full-width primary CTA on the page. Inverts against the page in both appearances.
struct PrimaryButton: View {
    let title: String
    var showsArrow = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                Text(title)
                if showsArrow {
                    Image(systemName: "arrow.right")
                }
            }
            .textStyle(.button)
            .foregroundStyle(Palette.onInkFill)
            .frame(maxWidth: .infinity, minHeight: Size.buttonTall)
            .background(Palette.inkFill, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Full-width CTA on an always-dark ground (intro). Fixed ice fill, fixed navy label.
struct IceButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                Text(title)
                Image(systemName: "arrow.right")
            }
            .textStyle(.button)
            .foregroundStyle(Palette.navy)
            .frame(maxWidth: .infinity, minHeight: Size.buttonTall)
            .background(Palette.ice, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

/// The disabled state of the wizard's CTA. Not a button, so VoiceOver reads it as a hint.
struct DisabledCTA: View {
    let title: String

    var body: some View {
        Text(title)
            .textStyle(.chip)
            .foregroundStyle(Palette.inkMuted)
            .frame(maxWidth: .infinity, minHeight: Size.buttonTall)
            .background(Palette.track, in: Capsule())
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Small uppercase pill ("THE BASICS"). Inverts against the page.
struct KickerPill: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(.kicker)
            .foregroundStyle(Palette.onInkFill)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs - 1)
            .background(Palette.inkFill, in: Capsule())
    }
}

/// A group of rows on a card, separated by hairlines.
struct CardList<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    row
                    if index < rows.count - 1 {
                        Rectangle().fill(Palette.hairline).frame(height: 1)
                    }
                }
            }
        }
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .cardShadow()
    }
}

/// Single-choice row with a title, optional subtitle and a selection ring.
struct ChoiceRow: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .textStyle(.rowTitle)
                        .foregroundStyle(Palette.ink)
                    if let subtitle {
                        Text(subtitle)
                            .textStyle(.caption)
                            .foregroundStyle(Palette.inkMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

                SelectionRing(isSelected: isSelected)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm - 1)
            .frame(minHeight: Size.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SelectionRing: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Palette.inkFill : Palette.track, lineWidth: 1.5)
            if isSelected {
                Circle().fill(Palette.inkFill)
                Image(systemName: "checkmark")
                    .font(TextStyle.micro.font.weight(.heavy))
                    .foregroundStyle(Palette.onInkFill)
            }
        }
        .frame(width: Size.checkRing, height: Size.checkRing)
        .accessibilityHidden(true)
    }
}

/// Multi-select chip.
struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(.chip)
                .foregroundStyle(isSelected ? Palette.onInkFill : Palette.ink)
                .padding(.horizontal, Space.md - 1)
                .padding(.vertical, Space.sm)
                .background(isSelected ? Palette.inkFill : Palette.card, in: Capsule())
                .cardShadow()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Wraps children onto new lines, like CSS flex-wrap.
struct FlowLayout: Layout {
    var spacing: CGFloat = Space.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

/// Card-backed text/number field with a trailing unit label.
struct UnitField: View {
    @Binding var text: String
    let placeholder: String
    let unit: String
    var keyboard: UIKeyboardType = .decimalPad
    var accessibilityLabel: String

    var body: some View {
        HStack(spacing: 0) {
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textStyle(.input)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, Space.md + 2)
                .padding(.vertical, Space.md + 1)
                .accessibilityLabel(accessibilityLabel)
            Text(unit)
                .textStyle(.kicker)
                .foregroundStyle(Palette.inkMuted)
                .padding(.horizontal, Space.md + 2)
                .accessibilityHidden(true)
        }
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.sm))
        .cardShadow()
    }
}

/// Inline guidance under a question: a neutral note, never an alarm.
struct InlineNote: View {
    let text: String
    var systemImage = "info.circle"

    var body: some View {
        Label {
            Text(text)
                .textStyle(.caption)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.copperText)
        }
        .padding(Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.copperTint, in: RoundedRectangle(cornerRadius: Radius.sm))
    }
}

extension View {
    /// Centres content in a column no wider than `Size.readableWidth` (keeps iPad layouts readable).
    func readableColumn() -> some View {
        frame(maxWidth: Size.readableWidth)
            .frame(maxWidth: .infinity)
    }
}

/// Every ingredient in the library, searchable: tap to mark foods the user won't eat.
struct FoodSearchPicker: View {
    @Binding var selection: Set<String>
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var matches: [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? FoodDislikes.all : FoodDislikes.all.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            List(matches, id: \.self) { name in
                Button {
                    selection.formSymmetricDifference([name])
                } label: {
                    HStack(spacing: Space.sm) {
                        Text(NutritionTable.bundled[name]?.emoji ?? "🍽️").accessibilityHidden(true)
                        Text(name).textStyle(.body).foregroundStyle(Palette.ink)
                        Spacer()
                        if selection.contains(name) {
                            Image(systemName: "checkmark").foregroundStyle(Palette.copper)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection.contains(name) ? .isSelected : [])
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods")
            .navigationTitle("Foods you won't eat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
