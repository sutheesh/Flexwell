import SwiftUI
import SwiftData
import Charts
import FlexFitEngine

/// Where the Gym tab's stack can go.
enum GymRoute: Hashable {
    case group(MuscleGroup)
    case exercise(String)
}

// MARK: - Library (the "Exercises" half of Gym)

/// The tap-a-muscle body map, with favourites, the front/back flip and the rest timer. Navy, like the rest of Gym.
struct ExerciseLibraryView: View {
    @Query private var favorites: [FavoriteExercise]
    @State private var side: BodyFigure.Side = .front
    @State private var showsFavorites = false
    @State private var isTimerOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if showsFavorites {
                ExerciseGrid(exercises: favorites.compactMap { ExerciseLibrary.bundled[$0.exerciseID] },
                             empty: "Tap ☆ on any exercise to keep it here.")
            } else {
                BodyMap(side: side)
            }
            // Flip, favourites and timer along the bottom, as in the reference.
            HStack {
                RoundIconButton(icon: "arrow.triangle.2.circlepath", label: side == .front ? "Show back" : "Show front") {
                    withAnimation(.easeInOut(duration: 0.25)) { showsFavorites = false; side = side == .front ? .back : .front }
                }
                Spacer()
                RoundIconButton(icon: showsFavorites ? "star.fill" : "star",
                                label: showsFavorites ? "Show the body map" : "Show favourites",
                                tint: Palette.copper) {
                    withAnimation(.easeInOut(duration: 0.2)) { showsFavorites.toggle() }
                }
                Spacer()
                RoundIconButton(icon: "timer", label: "Rest timer") { isTimerOpen = true }
            }
        }
        .sheet(isPresented: $isTimerOpen) { RestTimerSheet() }
    }
}

/// The figure with a dot on each muscle group and a dashed leader out to its label.
private struct BodyMap: View {
    let side: BodyFigure.Side
    @State private var tapped: MuscleGroup?

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let figureWidth = height * BodyFigure.aspect
            let originX = (geo.size.width - figureWidth) / 2
            ZStack(alignment: .topLeading) {
                BodyFigure(side: side, onTap: { tapped = $0 })
                    .frame(width: figureWidth, height: height)
                    .offset(x: originX)
                let column = originX + figureWidth * 0.2
                ForEach(BodyGeometry.anchors(side), id: \.group) { anchor in
                    let dot = CGPoint(x: originX + anchor.point.x * figureWidth, y: anchor.point.y * height)
                    let underline = anchor.labelY * height + Space.sm
                    // Leader: along under the label, across to the dot's x, then up to the dot.
                    Path { p in
                        p.move(to: CGPoint(x: anchor.leftLabel ? 0 : geo.size.width, y: underline))
                        p.addLine(to: CGPoint(x: dot.x, y: underline))
                        p.addLine(to: dot)
                    }
                    .stroke(Palette.onPanel.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    NavigationLink(value: GymRoute.group(anchor.group)) {
                        Text(anchor.group.title)
                            .textStyle(.rowTitle)
                            .foregroundStyle(Palette.onPanel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(width: column, alignment: anchor.leftLabel ? .leading : .trailing)
                            .padding(.vertical, Space.xxs)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: anchor.leftLabel ? column / 2 : geo.size.width - column / 2, y: underline - Space.sm - 1)
                    NavigationLink(value: GymRoute.group(anchor.group)) {
                        Group {
                            if anchor.group == .cardio {
                                Image(systemName: "heart.fill").font(TextStyle.headline.font).foregroundStyle(Palette.copper)
                            } else {
                                Circle().fill(Palette.copper).frame(width: Space.sm, height: Space.sm)
                            }
                        }
                            .padding(Space.sm)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(dot)
                    .accessibilityLabel(anchor.group.title)
                }
            }
        }
        .frame(height: Size.bodyMap)
        .navigationDestination(item: $tapped) { MuscleGroupView(group: $0) }
        .id(side)
        .transition(.opacity)
    }
}

// MARK: - Muscle group list

/// One muscle group: a 2-column grid of exercises, filtered to your equipment or all.
struct MuscleGroupView: View {
    let group: MuscleGroup
    @Query private var profiles: [ProfileRecord]
    @State private var mineOnly = true

    var body: some View {
        let owned = profiles.first?.profile().equipment ?? []
        let all = group.exercises()
        let shown = mineOnly ? all.filter { $0.isAvailable(with: owned) } : all
        GymPage(title: group.title.uppercased()) {
            HStack(spacing: Space.xs) {
                GymChip(title: "My equipment", isSelected: mineOnly) { mineOnly = true }
                GymChip(title: "All \(all.count)", isSelected: !mineOnly) { mineOnly = false }
                Spacer()
            }
            ExerciseGrid(exercises: shown, highlight: group,
                         empty: "Nothing for \(group.title.lowercased()) with your equipment. Try All.")
        }
    }
}

/// Two columns of exercise cards.
struct ExerciseGrid: View {
    let exercises: [Exercise]
    var highlight: MuscleGroup?
    let empty: String

    var body: some View {
        if exercises.isEmpty {
            Text(empty)
                .textStyle(.body)
                .foregroundStyle(Palette.onPanelMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Space.md)
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.sm), GridItem(.flexible(), spacing: Space.sm)],
                      spacing: Space.sm) {
                ForEach(exercises, id: \.id) { ex in
                    NavigationLink(value: GymRoute.exercise(ex.id)) {
                        ExerciseCard(exercise: ex, highlight: highlight)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// A figure with the exercise's muscles lit, the name, the kit, and a favourite star.
private struct ExerciseCard: View {
    let exercise: Exercise
    var highlight: MuscleGroup?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BodyFigure(side: highlight?.side ?? exercise.bestSide, primary: exercise.primaryGroups,
                       secondary: exercise.secondaryGroups, outlined: false)
                .frame(maxWidth: .infinity)
                .frame(height: Size.exerciseCardFigure)
                .padding(.vertical, Space.sm)
                .background(Palette.navyRaised.opacity(0.6))
                .overlay(alignment: .topTrailing) { FavoriteStar(exerciseID: exercise.id).padding(Space.xs) }
            VStack(alignment: .leading, spacing: Space.xxs + 1) {
                Text(exercise.name)
                    .textStyle(.label)
                    .foregroundStyle(Palette.onPanel)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(ExerciseCopy.equipment(exercise, owned: []))
                    .textStyle(.micro)
                    .foregroundStyle(Palette.onPanelMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: Size.control + 8, alignment: .topLeading)
            .padding(Space.sm)
        }
        .background(Palette.navyRaised, in: RoundedRectangle(cornerRadius: Radius.lg))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.name), \(exercise.primaryGroups.map(\.title).sorted().joined(separator: ", "))")
    }
}

// MARK: - Exercise detail

struct ExerciseDetailView: View {
    enum Tab: String, CaseIterable { case guidance = "Guidance", performance = "Performance" }

    let exerciseID: String
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [ProfileRecord]
    @Query private var swaps: [ExerciseSwap]
    @Query private var logs: [DailyLog]
    @Query private var painFlags: [PainFlag]
    @Query(sort: \SessionLog.day, order: .reverse) private var sessions: [SessionLog]
    @State private var tab: Tab = .guidance

    var body: some View {
        if let exercise = ExerciseLibrary.bundled[exerciseID] {
            GymPage(title: nil, trailing: { FavoriteStar(exerciseID: exercise.id, large: true) }) {
                Text(exercise.name)
                    .textStyle(.title2)
                    .foregroundStyle(Palette.onPanel)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                GymSegmented(selection: $tab, options: Tab.allCases, title: \.rawValue)
                switch tab {
                case .guidance: guidance(exercise)
                case .performance: performance(exercise)
                }
            }
        }
    }

    // MARK: Guidance

    @ViewBuilder
    private func guidance(_ ex: Exercise) -> some View {
        let profile = profiles.first?.profile()
        GymCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("At a glance").textStyle(.headline).foregroundStyle(Palette.onPanel)
                    Text(ExerciseCopy.equipment(ex, owned: profile?.equipment ?? []))
                        .textStyle(.caption).foregroundStyle(Palette.onPanelMuted)
                    HStack(spacing: Space.xs - 2) {
                        GymTag(text: ex.measure == .seconds ? "\(ex.targetLow)–\(ex.targetHigh) s" : "\(ex.targetLow)–\(ex.targetHigh) reps")
                        GymTag(text: ["", "Easy", "Moderate", "Hard"][min(3, max(1, ex.difficulty))])
                        if ex.compound { GymTag(text: "Compound") }
                    }
                    .padding(.top, Space.xxs)
                }
                Spacer(minLength: Space.xs)
                Image(ex.pattern == .conditioning || ex.pattern == .mobility ? "Illustration-walk" : "Illustration-lift")
                    .resizable().scaledToFill()
                    .frame(width: Size.detailThumb.width, height: Size.detailThumb.height)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .accessibilityHidden(true)
            }
        }

        if let swap = todaySwap(for: ex) {
            Button { swapIn(ex, replacing: swap) } label: {
                Text("Swap into today for \(swap.name) ›")
                    .textStyle(.button)
                    .foregroundStyle(Palette.navy)
                    .frame(maxWidth: .infinity, minHeight: Size.button)
                    .background(Palette.ice, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }

        GymCard {
            Text("Muscles worked").textStyle(.headline).foregroundStyle(Palette.onPanel)
            HStack(alignment: .top, spacing: Space.lg) {
                chipColumn("Primary", ex.primaryGroups, fill: Palette.copper)
                if !ex.secondaryGroups.isEmpty { chipColumn("Secondary", ex.secondaryGroups, fill: Palette.sand) }
            }
            .padding(.top, Space.xs)
            HStack(spacing: Space.md) {
                BodyFigure(side: .front, primary: ex.primaryGroups, secondary: ex.secondaryGroups)
                BodyFigure(side: .back, primary: ex.primaryGroups, secondary: ex.secondaryGroups)
            }
            .frame(height: Size.detailFigure)
            .frame(maxWidth: .infinity)
            .padding(.top, Space.md)
        }

        if let guide = ExerciseGuides.bundled[ex.id] {
            GymCard {
                Text("How to do it").textStyle(.headline).foregroundStyle(Palette.onPanel)
                ForEach(Array(guide.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: Space.sm) {
                        Text("\(i + 1)")
                            .textStyle(.label)
                            .foregroundStyle(Palette.navy)
                            .frame(width: Size.checkRing + 4, height: Size.checkRing + 4)
                            .background(Palette.ice, in: Circle())
                        Text(step)
                            .textStyle(.body)
                            .foregroundStyle(Palette.onPanel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, Space.xs)
                }
                Text("Key cues").textStyle(.label).foregroundStyle(Palette.copper).padding(.top, Space.md)
                ForEach(guide.cues, id: \.self) { cue in
                    Label(cue, systemImage: "checkmark")
                        .textStyle(.caption)
                        .foregroundStyle(Palette.onPanelMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.xxs)
                }
            }
        }

        if !ex.contraindications.isEmpty {
            let mine = Set(profile?.limitations ?? [])
            GymCard {
                Text("Take care if").textStyle(.headline).foregroundStyle(Palette.onPanel)
                Text("You have trouble with your " + ex.contraindications.map { $0.title.lowercased() }.joined(separator: " or ")
                     + ". Go lighter, shorten the range, or swap it.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.onPanelMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if !mine.isDisjoint(with: ex.contraindications) {
                    Label("You marked this area to protect, so your plan won't pick this exercise.", systemImage: "exclamationmark.triangle")
                        .textStyle(.caption)
                        .foregroundStyle(Palette.copper)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.xxs)
                }
            }
        }

        ExerciseNotesCard(exerciseID: ex.id)

        Text("Guidance is general and not medical advice. Written with care, pending review by a qualified coach.")
            .textStyle(.micro)
            .foregroundStyle(Palette.onPanelMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func chipColumn(_ title: String, _ groups: Set<MuscleGroup>, fill: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.xs - 2) {
            Text(title).textStyle(.caption).foregroundStyle(Palette.onPanelMuted)
            FlowLayout {
                ForEach(groups.sorted { $0.title < $1.title }, id: \.self) { g in
                    Text(g.title.uppercased())
                        .textStyle(.badge)
                        .foregroundStyle(Palette.navy)
                        .padding(.horizontal, Space.sm - 2)
                        .padding(.vertical, Space.xxs + 1)
                        .background(fill, in: Capsule())
                }
            }
        }
    }

    // MARK: Performance

    @ViewBuilder
    private func performance(_ ex: Exercise) -> some View {
        let units = profiles.first?.profile().displayUnits ?? .metric
        let history = ProgressStats.history(of: ex.id, in: sessions.flatMap(\.loggedExercises))
        if history.isEmpty {
            GymCard {
                Text("No sets logged yet").textStyle(.headline).foregroundStyle(Palette.onPanel)
                Text("Log this exercise in a workout and your best sets, estimated max and every session show up here.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.onPanelMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            let maxes = history.compactMap { log in ProgressStats.bestEstimatedMax(log).map { (log.date, $0) } }.reversed()
            let best = history.flatMap(\.sets).max { a, b in (a.loadKg ?? 0, a.value) < (b.loadKg ?? 0, b.value) }
            HStack(spacing: Space.sm) {
                GymStat(value: "\(history.count)", label: "sessions")
                GymStat(value: best.map { setText($0, units) } ?? "—", label: "best set")
                GymStat(value: maxes.map(\.1).max().map { Formatters.mass($0, units: units) } ?? "—", label: "est. max")
            }
            if maxes.count >= 2 {
                GymCard {
                    Text("Estimated max").textStyle(.headline).foregroundStyle(Palette.onPanel)
                    EstimatedMaxChart(points: Array(maxes), units: units)
                        .frame(height: Size.row * 2.4)
                        .padding(.top, Space.sm)
                }
            }
            GymCard {
                Text("Sessions").textStyle(.headline).foregroundStyle(Palette.onPanel)
                ForEach(Array(history.prefix(12).enumerated()), id: \.offset) { _, log in
                    HStack(alignment: .firstTextBaseline) {
                        Text(DayMonth.text(log.date))
                            .textStyle(.label).foregroundStyle(Palette.onPanel)
                            .frame(width: Size.avatar + 18, alignment: .leading)
                        Text(log.sets.map { setText($0, units) }.joined(separator: " · "))
                            .textStyle(.caption).foregroundStyle(Palette.onPanelMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, Space.xs)
                }
            }
        }
    }

    private func setText(_ s: SetResult, _ units: DisplayUnits) -> String {
        let unit = ExerciseLibrary.bundled[exerciseID]?.measure == .seconds ? " s" : ""
        return s.loadKg.map { "\(s.value)\(unit) × \(Formatters.mass($0, units: units))" } ?? "\(s.value)\(unit)"
    }

    // MARK: Swap into today

    /// Today's planned exercise with the same movement pattern, if this one could stand in for it.
    private func todaySwap(for ex: Exercise) -> Exercise? {
        guard let record = profiles.first else { return nil }
        let resolver = PlanResolver(record: record, swaps: swaps, logs: logs, painFlags: painFlags)
        guard let plan = resolver.session(forWeekday: TrainView.todayWeekday, on: .now, applyPivot: true),
              !plan.exercises.contains(where: { $0.exerciseID == ex.id }),
              ex.isAvailable(with: resolver.equipment(on: .now)) else { return nil }
        return plan.exercises.lazy
            .compactMap { ExerciseLibrary.bundled[$0.exerciseID] }
            .first { $0.pattern == ex.pattern }
    }

    private func swapIn(_ ex: Exercise, replacing old: Exercise) {
        modelContext.insert(ExerciseSwap(day: Calendar.current.startOfDay(for: .now), originalID: old.id, replacementID: ex.id))
        try? modelContext.save()
        router.toast("\(ex.name) is in today's session instead of \(old.name).")
    }
}

private struct EstimatedMaxChart: View {
    let points: [(Date, Double)]
    let units: DisplayUnits

    var body: some View {
        Chart(Array(points.enumerated()), id: \.offset) { _, point in
            LineMark(x: .value("Date", point.0), y: .value("Max", Mass.display(kilograms: point.1, in: units)))
                .foregroundStyle(Palette.copper)
                .interpolationMethod(.monotone)
            PointMark(x: .value("Date", point.0), y: .value("Max", Mass.display(kilograms: point.1, in: units)))
                .foregroundStyle(Palette.copper)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Palette.onPanelMuted) } }
        .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(Palette.onPanelHairline); AxisValueLabel().foregroundStyle(Palette.onPanelMuted) } }
        .accessibilityLabel("Estimated one-rep max over time")
    }
}

/// Notes the user keeps on an exercise; saved as they type.
private struct ExerciseNotesCard: View {
    let exerciseID: String
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [ExerciseNote]
    @State private var text = ""
    @FocusState private var focused: Bool

    init(exerciseID: String) {
        self.exerciseID = exerciseID
        _notes = Query(filter: #Predicate<ExerciseNote> { $0.exerciseID == exerciseID })
    }

    var body: some View {
        GymCard {
            HStack {
                Text("My notes").textStyle(.headline).foregroundStyle(Palette.onPanel)
                Spacer()
                if focused {
                    Button("Done") { focused = false }
                        .textStyle(.label)
                        .foregroundStyle(Palette.copper)
                }
            }
            TextField("Seat height, grip, what felt off…", text: $text, axis: .vertical)
                .textStyle(.body)
                .foregroundStyle(Palette.onPanel)
                .lineLimit(3...8)
                .focused($focused)
                .padding(.top, Space.xs)
        }
        .onAppear { text = notes.first?.text ?? "" }
        .onChange(of: text) { save() }
    }

    private func save() {
        if let note = notes.first {
            guard note.text != text else { return }
            note.text = text
            note.updatedAt = .now
        } else if !text.isEmpty {
            modelContext.insert(ExerciseNote(exerciseID: exerciseID, text: text))
        }
        try? modelContext.save()
    }
}

// MARK: - Favourites

struct FavoriteStar: View {
    let exerciseID: String
    var large = false
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [FavoriteExercise]

    init(exerciseID: String, large: Bool = false) {
        self.exerciseID = exerciseID
        self.large = large
        _favorites = Query(filter: #Predicate<FavoriteExercise> { $0.exerciseID == exerciseID })
    }

    var body: some View {
        let on = !favorites.isEmpty
        Button {
            if on { favorites.forEach(modelContext.delete) } else { modelContext.insert(FavoriteExercise(exerciseID: exerciseID)) }
            try? modelContext.save()
        } label: {
            Image(systemName: on ? "star.fill" : "star")
                .font((large ? TextStyle.title2 : TextStyle.label).font)
                .foregroundStyle(Palette.copper)
                .frame(width: large ? Size.avatar : Size.control - 8, height: large ? Size.avatar : Size.control - 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "Remove from favourites" : "Add to favourites")
    }
}

// MARK: - Rest timer

struct RestTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var total = 90
    @State private var endsAt: Date?
    @State private var pausedLeft: Int?

    var body: some View {
        VStack(spacing: Space.lg) {
            HStack {
                Text("Rest timer").textStyle(.headline).foregroundStyle(Palette.onPanel)
                Spacer()
                Button("Done") { dismiss() }.textStyle(.label).foregroundStyle(Palette.copper)
            }
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                let left = remaining(at: context.date)
                ZStack {
                    Circle().stroke(Palette.onPanelTrack, lineWidth: Space.sm)
                    Circle()
                        .trim(from: 0, to: CGFloat(left) / CGFloat(max(1, total)))
                        .stroke(Palette.copper, style: StrokeStyle(lineWidth: Space.sm, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(String(format: "%d:%02d", left / 60, left % 60))
                        .textStyle(.display)
                        .foregroundStyle(Palette.onPanel)
                        .monospacedDigit()
                }
                .frame(width: Size.spinner * 1.6, height: Size.spinner * 1.6)
                .onChange(of: left) { _, new in if new == 0 && endsAt != nil { finish() } }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(left) seconds left")
            }
            HStack(spacing: Space.xs) {
                ForEach([60, 90, 120, 180], id: \.self) { s in
                    GymChip(title: s < 120 ? "\(s) s" : "\(s / 60) min", isSelected: total == s) {
                        total = s; endsAt = nil; pausedLeft = nil
                    }
                }
            }
            Button(action: toggle) {
                Text(endsAt == nil ? (pausedLeft == nil ? "Start" : "Resume") : "Pause")
                    .textStyle(.button)
                    .foregroundStyle(Palette.navy)
                    .frame(maxWidth: .infinity, minHeight: Size.button)
                    .background(Palette.ice, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            Spacer(minLength: 0)
        }
        .padding(Space.lg)
        .background(Palette.navy.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .environment(\.colorScheme, .dark)
    }

    private func remaining(at date: Date) -> Int {
        if let endsAt { return max(0, Int(endsAt.timeIntervalSince(date).rounded(.up))) }
        return pausedLeft ?? total
    }

    private func toggle() {
        if let endsAt {
            pausedLeft = max(0, Int(endsAt.timeIntervalSinceNow.rounded(.up)))
            self.endsAt = nil
        } else {
            endsAt = .now.addingTimeInterval(TimeInterval(pausedLeft ?? total))
            pausedLeft = nil
        }
    }

    private func finish() {
        endsAt = nil
        pausedLeft = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Gym chrome (navy)

/// A pushed Gym page: back button, optional centred title, trailing accessory, navy background.
struct GymPage<Trailing: View, Content: View>: View {
    let title: String?
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    init(title: String?, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                ZStack {
                    if let title {
                        Text(title).textStyle(.kicker).foregroundStyle(Palette.onPanelMuted).accessibilityAddTraits(.isHeader)
                    }
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(TextStyle.headline.font)
                                .foregroundStyle(Palette.onPanel)
                                .frame(width: Size.avatar, height: Size.avatar)
                                .background(Palette.navyRaised, in: RoundedRectangle(cornerRadius: Radius.sm))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")
                        Spacer()
                        trailing()
                    }
                }
                content()
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xl)
            .readableColumn()
            .containerRelativeFrame(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .overlay(alignment: .top) {
            Color.clear.frame(height: 0).background(Palette.navy.ignoresSafeArea(edges: .top))
        }
        .background(Palette.navy.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct GymCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.md + 2)
            .background(Palette.navyRaised, in: RoundedRectangle(cornerRadius: Radius.lg))
    }
}

struct GymChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(.chip)
                .foregroundStyle(isSelected ? Palette.navy : Palette.onPanel)
                .padding(.horizontal, Space.md - 2)
                .padding(.vertical, Space.xs + 1)
                .background(isSelected ? Palette.ice : Palette.navyRaised, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct GymTag: View {
    let text: String
    var body: some View {
        Text(text)
            .textStyle(.micro)
            .foregroundStyle(Palette.ice)
            .padding(.horizontal, Space.xs)
            .padding(.vertical, Space.xxs)
            .background(Palette.ice.opacity(0.14), in: Capsule())
    }
}

private struct GymStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs + 1) {
            Text(value).textStyle(.label).foregroundStyle(Palette.onPanel).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).textStyle(.micro).foregroundStyle(Palette.onPanelMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.sm + 2)
        .background(Palette.navyRaised, in: RoundedRectangle(cornerRadius: Radius.md))
    }
}

/// The mock-style two-option switch on navy.
struct GymSegmented<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: KeyPath<Option, String>

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button { withAnimation(.easeInOut(duration: 0.2)) { selection = option } } label: {
                    Text(option[keyPath: title])
                        .textStyle(.label)
                        .foregroundStyle(on ? Palette.navy : Palette.onPanel)
                        .frame(maxWidth: .infinity, minHeight: Size.control)
                        .background(on ? Palette.ice : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(Space.xxs)
        .background(Palette.navyRaised, in: Capsule())
    }
}

private struct RoundIconButton: View {
    let icon: String
    let label: String
    var tint: Color = Palette.ice
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(TextStyle.headline.font)
                .foregroundStyle(tint)
                .frame(width: Size.buttonTall, height: Size.buttonTall)
                .background(Palette.navyRaised, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
