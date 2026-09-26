import SwiftUI
import SwiftData
import FlexFitEngine

/// "Food Details" (reference design): photo header, tags, name, total kcal, macro rings,
/// Update Details and Add Meal. Adding logs a FoodEntry for today.
struct FoodDetailsView: View {
    let result: ScanResult
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]

    @State private var facts: FoodFacts
    @State private var name: String
    @State private var grams: Int
    @State private var isEditing = false

    init(result: ScanResult, onFinished: @escaping () -> Void) {
        self.result = result
        self.onFinished = onFinished
        let f = result.facts ?? FoodFacts(name: "", category: "Food", kcalPer100g: 0, proteinPer100g: 0,
                                          carbsPer100g: 0, fatPer100g: 0, defaultGrams: 100)
        _facts = State(initialValue: f)
        _name = State(initialValue: f.name)
        _grams = State(initialValue: f.defaultGrams)
    }

    private var macros: Macros { facts.macros(grams: grams) }

    var body: some View {
        ZStack(alignment: .top) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: Size.flower * 0.95)
                    sheet
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            topBar
        }
        .background(Palette.navy.ignoresSafeArea())
        .sheet(isPresented: $isEditing) {
            EditFoodSheet(facts: $facts, name: $name, grams: $grams)
        }
        .onAppear { if name.isEmpty && facts.kcalPer100g == 0 { isEditing = true } }
    }

    // MARK: Header

    private var header: some View {
        Group {
            if let photo = result.photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Palette.tilePeach, Palette.tileGreen], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        Text(NutritionTable.bundled[facts.name]?.emoji ?? (result.source == "barcode" ? "🛒" : "🍽️"))
                            .font(TextStyle.display.font)
                            .scaleEffect(2.4)
                    }
            }
        }
        .frame(height: Size.flower * 1.15)
        .frame(maxWidth: .infinity)
        .clipped()
        .ignoresSafeArea(edges: .top)
        .accessibilityHidden(true)
    }

    private var topBar: some View {
        HStack {
            circle("arrow.left", "Back") { dismiss() }
            Spacer()
            // White over a photo, navy over the light placeholder.
            Text("Food Details").textStyle(.headline)
                .foregroundStyle(result.photo == nil ? Palette.navy : Palette.white)
                .shadow(color: Palette.navy.opacity(result.photo == nil ? 0 : 0.5), radius: 4)
            Spacer()
            circle("xmark", "Close") { onFinished() }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
    }

    private func circle(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(TextStyle.rowTitle.font)
                .foregroundStyle(Palette.navy)
                .frame(width: Size.detailButton, height: Size.detailButton)
                .background(Palette.white, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Sheet

    private var sheet: some View {
        VStack(spacing: Space.md) {
            Capsule().fill(Palette.track).frame(width: Size.avatar, height: Size.progressBar)
            HStack(spacing: Space.xs) {
                tag(facts.category.isEmpty ? "Food" : facts.category)
                tag("\(grams) g")
            }
            Text(name.isEmpty ? "Name this food" : name)
                .textStyle(.title1)
                .foregroundStyle(name.isEmpty ? Palette.inkMuted : Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if result.candidates.count > 1 {
                VStack(spacing: Space.xs) {
                    Text("Looks like").textStyle(.micro).foregroundStyle(Palette.inkMuted)
                    FlowLayout {
                        ForEach(result.candidates, id: \.name) { c in
                            Chip(title: c.name, isSelected: c.name == name) {
                                facts = c
                                name = c.name
                                grams = c.defaultGrams
                            }
                        }
                    }
                }
            }

            HStack {
                Text("Total \(Int(macros.kcal.rounded())) kcal").textStyle(.headline).foregroundStyle(Palette.ink)
                Spacer()
                Text("🔥")
                    .frame(width: Size.control, height: Size.control)
                    .background(Palette.card, in: Circle())
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(Palette.chipFill, in: RoundedRectangle(cornerRadius: Radius.tile - 4))

            HStack(spacing: Space.sm - 2) {
                ring("Protein", macros.proteinG, target: Double(targets.proteinG), color: Palette.proteinRed)
                ring("Fat", macros.fatG, target: Double(targets.fatG), color: Palette.fatOrange)
                ring("Carbs", macros.carbsG, target: Double(targets.carbsG), color: Palette.carbGreen)
            }

            portion

            Text(sourceNote)
                .textStyle(.caption)
                .foregroundStyle(Palette.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Space.sm) {
                Button { isEditing = true } label: {
                    Text("Update Details")
                        .textStyle(.button)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: Size.buttonTall)
                        .background(Palette.chipFill, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                Button(action: add) {
                    Text("Add Meal")
                        .textStyle(.button)
                        .foregroundStyle(Palette.onInkFill)
                        .frame(maxWidth: .infinity, minHeight: Size.buttonTall)
                        .background(Palette.inkFill, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || facts.kcalPer100g <= 0)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty || facts.kcalPer100g <= 0 ? 0.5 : 1)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.xxl)
        .frame(maxWidth: .infinity)
        .background(Palette.page, in: UnevenRoundedRectangle(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet))
    }

    private var portion: some View {
        HStack {
            Text("Portion").textStyle(.rowTitle).foregroundStyle(Palette.ink)
            Spacer()
            Stepper(value: $grams, in: 5...2000, step: grams < 50 ? 5 : 10) {
                Text("\(grams) g").textStyle(.rowTitle).foregroundStyle(Palette.ink).monospacedDigit()
            }
            .fixedSize()
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .textStyle(.kicker)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs - 1)
            .overlay(Capsule().strokeBorder(Palette.track))
    }

    private func ring(_ title: String, _ value: Double, target: Double, color: Color) -> some View {
        VStack(spacing: Space.sm) {
            Text(title).textStyle(.chip).foregroundStyle(Palette.inkMuted)
            ZStack {
                Circle().stroke(color.opacity(0.18), lineWidth: 7)
                if value >= 0.5 {
                    Circle()
                        .trim(from: 0, to: min(1, value / max(1, target)))
                        .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Text("\(Int(value.rounded()))g").textStyle(.statValue).foregroundStyle(Palette.ink)
            }
            .frame(width: Size.ingredientTile * 0.85, height: Size.ingredientTile * 0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.md)
        .background(Palette.chipFill, in: RoundedRectangle(cornerRadius: Radius.tile - 4))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(Int(value.rounded())) grams, \(Int((value / max(1, target) * 100).rounded())) percent of today's target")
    }

    private var targets: DailyTargets {
        guard let record = profiles.first else {
            return DailyTargets(calories: 2000, proteinG: 150, carbsG: 200, fatG: 60, expenditure: 2000, floorApplied: false)
        }
        return TargetsStore.current(weekly, profile: record.profile())
    }

    private var sourceNote: String {
        switch result.source {
        case "barcode": "From Open Food Facts. Rings show the share of today's targets."
        case "label": "Read from the label. Check the numbers before adding."
        case "scan", "library": "Recognised on your phone. It's an estimate: check the portion."
        default: "Rings show the share of today's targets."
        }
    }

    private func add() {
        let entry = FoodEntry(day: .now, name: name.trimmingCharacters(in: .whitespaces))
        entry.category = facts.category
        entry.grams = grams
        entry.kcal = Int(macros.kcal.rounded())
        entry.proteinG = macros.proteinG
        entry.carbsG = macros.carbsG
        entry.fatG = macros.fatG
        entry.source = result.source
        entry.photo = result.photo?.logThumbnail()
        modelContext.insert(entry)
        try? modelContext.save()
        router.toast("Added \(entry.name) · \(entry.kcal) kcal")
        onFinished()
    }
}

/// "Update Details": name, portion and per-100 g nutrition, all editable.
private struct EditFoodSheet: View {
    @Binding var facts: FoodFacts
    @Binding var name: String
    @Binding var grams: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // A plain header, not a navigation bar: with the keyboard up, a nav-bar button's
            // first tap only drops the keyboard, so Done needed two taps.
            HStack {
                Text("Update details").textStyle(.headline).foregroundStyle(Palette.ink)
                Spacer()
                Button { dismiss() } label: {
                    Text("Done")
                        .textStyle(.chip)
                        .foregroundStyle(Palette.onInkFill)
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.xs + 1)
                        .background(Palette.inkFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("edit.done")
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xs)
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Category", text: $facts.category)
                    Stepper("Portion: \(grams) g", value: $grams, in: 5...2000, step: 5)
                }
                Section("Per 100 g") {
                    number("Calories (kcal)", $facts.kcalPer100g)
                    number("Protein (g)", $facts.proteinPer100g)
                    number("Carbs (g)", $facts.carbsPer100g)
                    number("Fat (g)", $facts.fatPer100g)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// Text-backed so every keystroke lands immediately (a formatted field only commits on
    /// losing focus, which would drop the last value when Done is tapped straight away).
    private func number(_ title: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: Binding(
                get: { value.wrappedValue == 0 ? "" : value.wrappedValue.formatted(.number.precision(.fractionLength(0...1))) },
                set: { value.wrappedValue = Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 }
            ))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: Size.ingredientTile)
            .accessibilityLabel(title)
        }
    }
}
