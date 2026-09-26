import SwiftUI

/// A logged food (scan, barcode, label, library, restaurant, manual) in Today's food and on Eat.
struct FoodEntryRow: View {
    let entry: FoodEntry
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Space.sm + 1) {
            Group {
                if let data = entry.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: icon)
                        .font(TextStyle.rowTitle.font)
                        .foregroundStyle(Palette.copperText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.copperTint)
                }
            }
            .frame(width: Size.avatar + 10, height: Size.avatar + 10)
            .clipShape(Circle())
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Space.xxs + 2) {
                HStack(spacing: Space.xs - 1) {
                    Text("\(sourceTitle) · \(entry.loggedAt.formatted(date: .omitted, time: .shortened))")
                        .textStyle(.micro).foregroundStyle(Palette.inkMuted)
                    Text("Logged").textStyle(.micro).foregroundStyle(Palette.blueText)
                        .padding(.horizontal, Space.xs - 1).padding(.vertical, Space.xxs)
                        .background(Palette.blueTint, in: Capsule())
                }
                Text(entry.name).textStyle(.rowTitle).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail).textStyle(.micro).foregroundStyle(Palette.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: Space.xs - 2) {
                Text("\(entry.kcal)").textStyle(.statValue).foregroundStyle(Palette.ink)
                Button("Undo", action: onRemove).textStyle(.micro).foregroundStyle(Palette.copperText)
                    .accessibilityLabel("Remove \(entry.name)")
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm + 1)
        .accessibilityElement(children: .contain)
    }

    private var detail: String {
        let grams = entry.grams > 0 ? "\(entry.grams) g · " : ""
        return grams + "P \(Int(entry.proteinG.rounded()))g · C \(Int(entry.carbsG.rounded()))g · F \(Int(entry.fatG.rounded()))g"
    }

    private var sourceTitle: String {
        switch entry.source {
        case "restaurant": entry.replacesDinner ? "Dinner · eating out" : "Eating out"
        case "barcode": "Barcode"
        case "label": "Food label"
        case "scan", "library": "Scanned"
        default: "Added"
        }
    }

    private var icon: String {
        switch entry.source {
        case "restaurant": "fork.knife"
        case "barcode": "barcode"
        case "label": "doc.text.viewfinder"
        default: "camera"
        }
    }
}
