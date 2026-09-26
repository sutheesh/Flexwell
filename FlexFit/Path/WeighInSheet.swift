import SwiftUI
import FlexFitEngine

/// Log a weigh-in. Opened from Path.
struct WeighInSheet: View {
    let units: DisplayUnits
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    private var kg: Double? {
        OnboardingDraft.number(text).map { Mass.kilograms(from: $0, in: units) }.flatMap { (30...300).contains($0) ? $0 : nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            // Plain header, not a navigation bar: with the keyboard up a nav-bar button's first tap
            // only drops the keyboard, so Save needed two taps.
            HStack {
                Button("Cancel") { dismiss() }
                    .textStyle(.chip)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("Log weight").textStyle(.headline).foregroundStyle(Palette.ink)
                Spacer()
                Button {
                    if let kg { onSave(kg); dismiss() }
                } label: {
                    Text("Save")
                        .textStyle(.chip)
                        .foregroundStyle(Palette.onInkFill)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.xs + 1)
                        .background(Palette.inkFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(kg == nil)
                .opacity(kg == nil ? 0.5 : 1)
            }
            Text("Same time of day each week, ideally after waking. It's the trend that matters, not one reading.")
                .textStyle(.caption)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            UnitField(text: $text, placeholder: units == .metric ? "82.5" : "182", unit: units == .metric ? "kg" : "lb",
                      accessibilityLabel: "Weight")
                .focused($focused)
            Spacer()
        }
        .padding(Space.lg)
        .pageBackground()
        .onAppear { focused = true }
        .presentationDetents([.medium])
    }
}
