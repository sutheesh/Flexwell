import SwiftUI
import SwiftData
import Charts
import FlexFitEngine

/// Where the Gym tab's stack can go.
enum GymRoute: Hashable {
    case group(MuscleGroup)
    case exercise(String)
    /// An alternative's detail page, with "Swap in" for the exercise it would replace.
    case swapDetail(SwapChoice)
}

struct SwapRequest: Hashable {
    let originalID: String
    let day: Date
}

struct SwapChoice: Hashable {
    let request: SwapRequest
    let candidateID: String
    let scope: SwapScope
}

/// Saves a swap: for that day only, or for good.
enum SwapStore {
    @MainActor
    static func save(_ choice: SwapChoice, context: ModelContext, router: AppRouter) {
        context.insert(ExerciseSwap(
            day: choice.scope == .today ? Calendar.current.startOfDay(for: choice.request.day) : nil,
            originalID: choice.request.originalID,
            replacementID: choice.candidateID
        ))
        try? context.save()
        let name = ExerciseLibrary.bundled[choice.candidateID]?.name ?? "the alternative"
        router.sheet = nil
        router.toast(choice.scope == .today ? "Swapped in \(name) for this session." : "Swapped in \(name) from now on.")
    }
}

// MARK: - Library (the "Exercises" half of Gym)

/// The tap-a-muscle body map (swipe or tap the centre button to turn it around), or your favourites when the
/// header's ★ is on. Navy, like the rest of Gym.
struct ExerciseLibraryView: View {
    @Binding var showsFavorites: Bool
    @Query private var favorites: [FavoriteExercise]
    @State private var side: BodyFigure.Side = .front
    /// Y-axis turn of the figure during a flip, in degrees.
    @State private var turn: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if showsFavorites {
                ExerciseGrid(exercises: favorites.compactMap { ExerciseLibrary.bundled[$0.exerciseID] },
                             empty: "Tap ☆ on any exercise to keep it here.")
            } else {
                BodyMap(side: side)
                    .rotation3DEffect(.degrees(turn), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                    // A sideways swipe anywhere on the map turns the body; vertical scrolling is untouched.
                    .simultaneousGesture(
                        DragGesture(minimumDistance: Space.lg)
                            .onEnded { drag in
                                let dx = drag.translation.width, dy = drag.translation.height
                                if abs(dx) > Space.xxl * 2, abs(dx) > abs(dy) * 1.5 { flip(toward: dx > 0 ? 1 : -1) }
                            }
                    )
                FlipButton(showing: side) { flip(toward: 1) }
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Turns the figure a quarter, swaps front/back while it's edge-on, then turns it the rest of the way.
    private func flip(toward direction: Double) {
        withAnimation(.easeIn(duration: 0.14)) { turn = 90 * direction } completion: {
            side = side == .front ? .back : .front
            turn = -90 * direction
            withAnimation(.easeOut(duration: 0.16)) { turn = 0 }
        }
    }
}

/// The centre button under the body map: turn it around. The label names the side you'll see next.
private struct FlipButton: View {
    let showing: BodyFigure.Side
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Space.xxs) {
                Image(systemName: "rotate.3d")
                    .font(TextStyle.headline.font)
                    .foregroundStyle(Palette.ice)
                    .frame(width: Size.buttonTall, height: Size.buttonTall)
                    .background(Palette.navyRaised, in: Circle())
                Text(showing == .front ? "Back" : "Front")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.onPanelMuted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showing == .front ? "Show back" : "Show front")
        .accessibilityHint("Or swipe sideways on the body")
    }
}

/// The figure with a dot on each muscle group and a dashed leader out to its label.
private struct BodyMap: View {
    let side: BodyFigure.Side
    @State private var tapped: MuscleGroup?

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let figureWidth = height * BodyPhoto.aspect
            let originX = (geo.size.width - figureWidth) / 2
            ZStack(alignment: .topLeading) {
                // Tapping the body opens the muscle whose dot is nearest the tap.
                BodyPhoto(side: side)
                    .frame(width: figureWidth, height: height)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let nearest = BodyGeometry.anchors(side).min { a, b in
                            hypot(a.point.x * figureWidth - location.x, a.point.y * height - location.y)
                                < hypot(b.point.x * figureWidth - location.x, b.point.y * height - location.y)
                        }
                        if let nearest, hypot(nearest.point.x * figureWidth - location.x, nearest.point.y * height - location.y) < Space.xxl * 2 {
                            tapped = nearest.group
                        }
                    }
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
                                Image(systemName: "heart.fill").font(TextStyle.headline.font).foregroundStyle(Palette.mapDot)
                            } else {
                                Circle().fill(Palette.mapDot)
                                    .frame(width: Space.sm, height: Space.sm)
                                    .overlay(Circle().strokeBorder(Palette.white, lineWidth: 1.5))
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
struct ExerciseCard: View {
    let exercise: Exercise
    var highlight: MuscleGroup?
    /// A small tag over the figure, e.g. "Best match".
    var badge: String?
    /// Leaves room at the bottom for a button laid over the card (the swap list's Swap).
    var reservesButtonRow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExerciseArt(exercise: exercise, pose: .peak, highlight: highlight)
                .overlay(alignment: .topTrailing) { FavoriteStar(exerciseID: exercise.id).padding(Space.xs) }
                .overlay(alignment: .topLeading) {
                    if let badge {
                        Text(badge)
                            .textStyle(.badge)
                            .foregroundStyle(Palette.navy)
                            .padding(.horizontal, Space.xs)
                            .padding(.vertical, Space.xxs)
                            .background(Palette.copper, in: Capsule())
                            .padding(Space.sm)
                    }
                }
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
            .padding(.bottom, reservesButtonRow ? Size.checkRing + Space.md : 0)
        }
        .background(Palette.navyRaised, in: RoundedRectangle(cornerRadius: Radius.lg))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel((badge.map { "\($0): " } ?? "") + "\(exercise.name), \(exercise.primaryGroups.map(\.title).sorted().joined(separator: ", "))")
    }
}

// MARK: - Swap list

/// The swap bottom sheet: the list, with an alternative's detail page pushed inside the sheet.
struct SwapSheet: View {
    let request: SwapRequest

    var body: some View {
        NavigationStack {
            SwapListView(request: request)
                .navigationDestination(for: GymRoute.self) { route in
                    switch route {
                    case .swapDetail(let choice): ExerciseDetailView(exerciseID: choice.candidateID, swap: choice)
                    case .exercise(let id): ExerciseDetailView(exerciseID: id)
                    case .group(let group): MuscleGroupView(group: group)
                    }
                }
        }
        .environment(\.colorScheme, .dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.navy)
    }
}

/// Swap from the plan: every safe alternative for the same movement with gear you have, best match first,
/// laid out like a muscle list. Swap from a card's own button, or open it and swap from its page.
struct SwapListView: View {
    let request: SwapRequest
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [ProfileRecord]
    @Query private var swaps: [ExerciseSwap]
    @Query private var logs: [DailyLog]
    @Query private var painFlags: [PainFlag]
    @State private var scope: SwapScope = .today

    var body: some View {
        if let record = profiles.first, let original = ExerciseLibrary.bundled[request.originalID] {
            let resolver = PlanResolver(record: record, swaps: swaps, logs: logs, painFlags: painFlags)
            let options = SwapRanker.alternatives(
                for: original, equipment: resolver.equipment(on: request.day), limitations: resolver.profile.limitations,
                history: resolver.history, usedThisWeek: resolver.usedThisWeek(on: request.day), limit: 40)
            GymPage(title: "SWAP", closes: true) {
                VStack(alignment: .leading, spacing: Space.xs - 2) {
                    Text("Replace \(original.name)")
                        .textStyle(.title2)
                        .foregroundStyle(Palette.onPanel)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Same movement and set volume, only gear you have. Best match first.")
                        .textStyle(.caption)
                        .foregroundStyle(Palette.onPanelMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                GymSegmented(selection: $scope, options: [SwapScope.today, .always], title: \.title)
                Text(scope == .today ? "Just this session. Your plan stays the same next week."
                                     : "Every week of your plan, from now on.")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.onPanelMuted)

                if options.isEmpty {
                    Text("Nothing else with your equipment trains this movement safely. Keep it, or add equipment in Profile.")
                        .textStyle(.body)
                        .foregroundStyle(Palette.onPanelMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.md)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.sm), GridItem(.flexible(), spacing: Space.sm)],
                              spacing: Space.sm) {
                        ForEach(Array(options.enumerated()), id: \.element.exercise.id) { i, option in
                            let choice = SwapChoice(request: request, candidateID: option.exercise.id, scope: scope)
                            // Swap sits on the card, bottom right; the rest of the card opens the detail page.
                            NavigationLink(value: GymRoute.swapDetail(choice)) {
                                ExerciseCard(exercise: option.exercise, badge: i == 0 ? "Best match" : nil, reservesButtonRow: true)
                            }
                            .buttonStyle(.plain)
                            .overlay(alignment: .bottomTrailing) {
                                Button { SwapStore.save(choice, context: modelContext, router: router) } label: {
                                    Label("Swap", systemImage: "arrow.left.arrow.right")
                                        .textStyle(.micro)
                                        .foregroundStyle(Palette.navy)
                                        .padding(.horizontal, Space.sm)
                                        .frame(minHeight: Size.checkRing + 8)
                                        .background(Palette.ice, in: Capsule())
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(PressableStyle())
                                .padding(Space.sm)
                                .accessibilityLabel("Swap in \(option.exercise.name)")
                            }
                        }
                    }
                }
            }
        }
    }
}

extension SwapScope {
    var title: String {
        switch self {
        case .today: "Just today"
        case .always: "From now on"
        }
    }
}

// MARK: - Exercise art

/// The card picture: RepDB's illustration (free tier, credited in Acknowledgements) where one matches the
/// exercise, otherwise the muscle figure with the worked muscles lit.
struct ExerciseArt: View {
    enum Pose: String { case start, peak }
    let exercise: Exercise
    var pose: Pose = .peak
    var highlight: MuscleGroup?

    /// `ex_<exercise id>_<pose>` in the asset catalog (Assets.xcassets/Exercises).
    static func image(_ id: String, _ pose: Pose) -> Image? {
        let name = "ex_\(id)_\(pose.rawValue)"
        return UIImage(named: name) == nil ? nil : Image(name)
    }

    var body: some View {
        if let image = Self.image(exercise.id, pose) {
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: Size.exerciseCardFigure + Space.sm * 2)
                .background(Palette.repdbSky)
                .accessibilityHidden(true)
        } else {
            BodyFigure(side: highlight?.side ?? exercise.bestSide, primary: exercise.primaryGroups,
                       secondary: exercise.secondaryGroups, outlined: false)
                .frame(maxWidth: .infinity)
                .frame(height: Size.exerciseCardFigure)
                .padding(.vertical, Space.sm)
                .background(Palette.navyRaised.opacity(0.6))
        }
    }
}

// MARK: - Exercise detail

struct ExerciseDetailView: View {
    enum Tab: String, CaseIterable { case guidance = "Guidance", performance = "Performance" }

    let exerciseID: String
    /// Opened from a swap list: the page leads with "Swap in".
    var swap: SwapChoice?
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
                Group {
                    if let image = ExerciseArt.image(ex.id, .peak) {
                        image.resizable().scaledToFit().background(Palette.repdbSky)
                    } else {
                        Image(ex.pattern == .conditioning || ex.pattern == .mobility ? "Illustration-walk" : "Illustration-lift")
                            .resizable().scaledToFill()
                    }
                }
                .frame(width: Size.detailThumb.width, height: Size.detailThumb.height)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .accessibilityHidden(true)
            }
        }

        if let swap, let original = ExerciseLibrary.bundled[swap.request.originalID] {
            Button { SwapStore.save(swap, context: modelContext, router: router) } label: {
                VStack(spacing: Space.xxs) {
                    Text("Swap in for \(original.name) ›").textStyle(.button)
                    Text(swap.scope.title).textStyle(.micro).opacity(0.7)
                }
                .foregroundStyle(Palette.navy)
                .frame(maxWidth: .infinity, minHeight: Size.buttonTall)
                .background(Palette.ice, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        } else if let swap = todaySwap(for: ex) {
            Button { swapIn(ex, replacing: swap) } label: {
                Text("Swap into today for \(swap.name) ›")
                    .textStyle(.button)
                    .foregroundStyle(Palette.navy)
                    .frame(maxWidth: .infinity, minHeight: Size.button)
                    .background(Palette.ice, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }

        if let start = ExerciseArt.image(ex.id, .start), let peak = ExerciseArt.image(ex.id, .peak) {
            GymCard {
                Text("The movement").textStyle(.headline).foregroundStyle(Palette.onPanel)
                HStack(spacing: Space.sm) {
                    ForEach([("Start", start), ("Finish", peak)], id: \.0) { label, image in
                        VStack(spacing: Space.xs - 2) {
                            image.resizable().scaledToFit()
                                .background(Palette.repdbSky)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            Text(label).textStyle(.micro).foregroundStyle(Palette.onPanelMuted)
                        }
                    }
                }
                .padding(.top, Space.sm)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Start and finish positions")
            }
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

// MARK: - Gym chrome (navy)

/// A pushed Gym page: back button, optional centred title, trailing accessory, navy background.
struct GymPage<Trailing: View, Content: View>: View {
    let title: String?
    /// At the root of a sheet: an ✕ that closes it instead of a back chevron.
    var closes = false
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    init(title: String?, closes: Bool = false, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.closes = closes
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
                            Image(systemName: closes ? "xmark" : "chevron.left")
                                .font(TextStyle.headline.font)
                                .foregroundStyle(Palette.onPanel)
                                .frame(width: Size.avatar, height: Size.avatar)
                                .background(Palette.navyRaised, in: RoundedRectangle(cornerRadius: Radius.sm))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(closes ? "Close" : "Back")
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
            .lineLimit(1)
            .fixedSize()
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
