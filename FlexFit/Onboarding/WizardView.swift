import SwiftUI
import FlexFitEngine

struct WizardView: View {
    @Bindable var draft: OnboardingDraft
    @Binding var stepIndex: Int
    let onExit: () -> Void
    let onFinish: () -> Void

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name, age, heightCm, heightFt, heightIn, weight, target
    }

    private var steps: [OnboardingDraft.Step] { draft.steps }
    private var step: OnboardingDraft.Step { steps[min(stepIndex, steps.count - 1)] }
    private var isLast: Bool { stepIndex >= steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.xs)
                .readableColumn()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header(for: step)
                    StepQuestions(step: step, draft: draft, focusedField: $focusedField)
                    if let problem = draft.problem(for: step) {
                        InlineNote(text: problem)
                            .padding(.top, Space.md)
                    }
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.xl)
                .padding(.bottom, Space.lg)
                .readableColumn()
                .id(step)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            // Hidden while typing: it would ride up on the keyboard and cover the field
            // being edited. The keyboard's Done button brings it back.
            if focusedField == nil {
                footer
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.sm)
                    .padding(.bottom, Space.xs)
                    .readableColumn()
                    .bottomBarBackground()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: focusedField == nil)
        .pageBackground()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: stepIndex)
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: Space.md - 2) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(TextStyle.label.font)
                    .foregroundStyle(Palette.ink)
                    .frame(width: Size.control, height: Size.control)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.sm))
                    .cardShadow()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            HStack(spacing: Space.xxs) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= stepIndex ? Palette.inkFill : Palette.track)
                        .frame(height: Size.progressBar)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(stepIndex + 1) of \(steps.count)")

            Text(String(format: "%02d/%02d", stepIndex + 1, steps.count))
                .textStyle(.micro)
                .monospacedDigit()
                .foregroundStyle(Palette.inkMuted)
                .accessibilityHidden(true)
        }
    }

    private func header(for step: OnboardingDraft.Step) -> some View {
        let copy = step.copy
        return VStack(alignment: .leading, spacing: 0) {
            KickerPill(text: copy.kicker)
            Text(copy.title)
                .textStyle(.title1)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.md - 2)
                .padding(.bottom, Space.xs)
                .accessibilityAddTraits(.isHeader)
            Text(copy.subtitle)
                .textStyle(.body)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var footer: some View {
        if draft.canContinue(step) {
            PrimaryButton(title: isLast ? "Build my plan" : "Continue", action: next)
        } else {
            DisabledCTA(title: draft.isAnswered(step) ? "Check your answers" : "Answer to continue")
        }
    }

    // MARK: Navigation

    private func next() {
        focusedField = nil
        if isLast {
            onFinish()
        } else {
            stepIndex += 1
        }
    }

    private func back() {
        focusedField = nil
        if stepIndex == 0 {
            onExit()
        } else {
            stepIndex -= 1
        }
    }
}

// MARK: - Step copy

extension OnboardingDraft.Step {
    struct Copy {
        let kicker: String
        let title: String
        let subtitle: String
    }

    var copy: Copy {
        switch self {
        case .basics: Copy(kicker: "The basics", title: "Who am I coaching?", subtitle: "A name and two numbers. Nothing leaves your phone.")
        case .body: Copy(kicker: "Body", title: "Where are you starting?", subtitle: "Pick units first — everything after follows it.")
        case .goal: Copy(kicker: "Goal", title: "What are we actually chasing?", subtitle: "Be specific. Vague goals make vague plans.")
        case .pace: Copy(kicker: "Pace", title: "How fast?", subtitle: "Faster is not better. Faster is harder to keep.")
        case .dailyLife: Copy(kicker: "Daily life", title: "What does a normal day cost you?", subtitle: "This sets calories more than workouts do.")
        case .environment: Copy(kicker: "Training", title: "Where will you train?", subtitle: "The single biggest fork in your programme.")
        case .equipment: Copy(kicker: "Equipment", title: "What do you actually have?", subtitle: "Every exercise — and every swap — is built from this list.")
        case .schedule: Copy(kicker: "Schedule", title: "How much time is real?", subtitle: "Pick what you will still do in week six.")
        case .experience: Copy(kicker: "Experience", title: "How much have you lifted?", subtitle: "Sets starting loads and how fast they climb.")
        case .limitations: Copy(kicker: "Body signals", title: "Anything to work around?", subtitle: "Injuries get programmed around, not ignored.")
        case .notice: Copy(kicker: "Before we start", title: "One honest note", subtitle: "Last one. Then I build your plan.")
        }
    }
}

// MARK: - Questions

private struct StepQuestions: View {
    let step: OnboardingDraft.Step
    @Bindable var draft: OnboardingDraft
    var focusedField: FocusState<WizardView.Field?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            switch step {
            case .basics: basics
            case .body: bodyStep
            case .goal: goal
            case .pace: pace
            case .dailyLife: dailyLife
            case .environment: environment
            case .equipment: equipment
            case .schedule: schedule
            case .experience: experience
            case .limitations: limitations
            case .notice: notice
            }
        }
        .padding(.top, Space.xl)
    }

    // Steps

    @ViewBuilder private var basics: some View {
        Question("What should I call you?") {
            UnitField(text: $draft.name, placeholder: "Alex", unit: "", keyboard: .default, accessibilityLabel: "Name")
                .textContentType(.givenName)
                .submitLabel(.next)
                .focused(focusedField, equals: .name)
                .onSubmit { focusedField.wrappedValue = .age }
        }
        Question("Age") {
            UnitField(text: $draft.ageText, placeholder: "29", unit: "yrs", keyboard: .numberPad, accessibilityLabel: "Age in years")
                .focused(focusedField, equals: .age)
        }
        Question("Biological sex", hint: "Only used to size your energy needs.") {
            choices(Sex.allCases, selection: $draft.sex) { ($0.title, nil) }
        }
    }

    @ViewBuilder private var bodyStep: some View {
        Question("Units") {
            CardList {
                ChoiceRow(title: "Imperial — lb / ft", isSelected: draft.units == .imperial) { draft.units = .imperial }
                ChoiceRow(title: "Metric — kg / cm", isSelected: draft.units == .metric) { draft.units = .metric }
            }
        }
        if let units = draft.units {
            Question("Height") {
                if units == .metric {
                    UnitField(text: $draft.heightCmText, placeholder: "178", unit: "cm", accessibilityLabel: "Height in centimetres")
                        .focused(focusedField, equals: .heightCm)
                } else {
                    HStack(spacing: Space.xs) {
                        UnitField(text: $draft.heightFtText, placeholder: "5", unit: "ft", keyboard: .numberPad, accessibilityLabel: "Height, feet")
                            .focused(focusedField, equals: .heightFt)
                        UnitField(text: $draft.heightInText, placeholder: "10", unit: "in", accessibilityLabel: "Height, inches")
                            .focused(focusedField, equals: .heightIn)
                    }
                }
            }
            Question("Current weight") {
                UnitField(text: $draft.weightText, placeholder: units == .metric ? "82.5" : "182", unit: draft.massUnit,
                          accessibilityLabel: "Current weight in \(units == .metric ? "kilograms" : "pounds")")
                    .focused(focusedField, equals: .weight)
            }
        }
    }

    @ViewBuilder private var goal: some View {
        Question("Primary goal") {
            choices(Goal.allCases, selection: $draft.goal) { ($0.title, $0.subtitle) }
        }
        if let goal = draft.goal, goal != .maintain {
            Question("Target weight") {
                UnitField(text: $draft.targetText, placeholder: goal == .lose ? "75" : "88", unit: draft.massUnit,
                          accessibilityLabel: "Target weight")
                    .focused(focusedField, equals: .target)
            }
        }
    }

    @ViewBuilder private var pace: some View {
        let goal = draft.goal ?? .lose
        let options = Safety.paceOptions(for: goal)
        Question("Rate of change per week") {
            CardList {
                ForEach(options, id: \.self) { pct in
                    ChoiceRow(title: draft.paceLabel(pct), subtitle: paceSubtitle(pct, goal: goal),
                              isSelected: draft.pacePct == pct) { draft.pacePct = pct }
                }
            }
        }
        InlineNote(text: goal == .lose
                   ? "Loss is capped at 1% of your body weight a week. Faster than that costs muscle and rarely lasts."
                   : "Gain is capped at 0.5% a week. Faster than that adds mostly fat.")
    }

    @ViewBuilder private var dailyLife: some View {
        Question("Your working day") {
            choices(ActivityLevel.allCases, selection: $draft.activity) { ($0.title, $0.subtitle) }
        }
    }

    @ViewBuilder private var environment: some View {
        Question("Main training environment") {
            choices(TrainingEnvironment.allCases, selection: $draft.environment) { ($0.title, $0.subtitle) }
        }
    }

    @ViewBuilder private var equipment: some View {
        ForEach(Equipment.Group.allCases, id: \.self) { group in
            Question(group.title, hint: group == .gym ? "Tap everything you can use. Pre-ticked from where you train." : nil) {
                FlowLayout {
                    ForEach(Equipment.allCases.filter { $0.group == group }, id: \.self) { item in
                        Chip(title: item.title, isSelected: draft.equipment.contains(item)) {
                            draft.equipment.formSymmetricDifference([item])
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var schedule: some View {
        Question("Training days per week") {
            choices(Array(2...6), selection: $draft.trainingDays) { ("\($0) days", nil) }
        }
        Question("Time per session") {
            choices([20, 30, 45, 60], selection: $draft.sessionMinutes) { ("\($0) minutes", nil) }
        }
    }

    @ViewBuilder private var experience: some View {
        Question("Training experience") {
            choices(Experience.allCases, selection: $draft.experience) { ($0.title, $0.subtitle) }
        }
    }

    @ViewBuilder private var limitations: some View {
        Question("Areas to protect", hint: "Exercises that load these are left out of your plan.") {
            FlowLayout {
                Chip(title: "None", isSelected: draft.limitations?.isEmpty == true) {
                    draft.limitations = []
                }
                ForEach(Limitation.allCases, id: \.self) { item in
                    Chip(title: item.title, isSelected: draft.limitations?.contains(item) == true) {
                        var set = draft.limitations ?? []
                        set.formSymmetricDifference([item])
                        draft.limitations = set
                    }
                }
            }
        }
        if let set = draft.limitations, !set.isEmpty {
            InlineNote(text: "If any of these hurt right now, check with a clinician before you start training.",
                       systemImage: "cross.case")
        }
    }

    @ViewBuilder private var notice: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            noticeRow(icon: "heart.text.square", text: "FlexFit gives general fitness guidance, not medical advice. If you have a medical condition, are pregnant, or feel pain, check with a clinician first.")
            noticeRow(icon: "lock", text: "Your health data stays on this phone and in your own iCloud. No ads, no data sales.")
        }
        CardList {
            ChoiceRow(title: "I understand", isSelected: draft.acceptedNotice) { draft.acceptedNotice.toggle() }
        }
    }

    // Building blocks

    private func noticeRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: icon)
                .font(TextStyle.rowTitle.font)
                .foregroundStyle(Palette.copperText)
                .frame(width: Size.iconTile, height: Size.iconTile)
                .background(Palette.copperTint, in: RoundedRectangle(cornerRadius: Radius.xs))
                .accessibilityHidden(true)
            Text(text)
                .textStyle(.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func paceSubtitle(_ pct: Double, goal: Goal) -> String {
        let share = "\(Formatters.percent(pct)) of body weight"
        switch (goal, pct) {
        case (.lose, 0.25): return "\(share) · barely noticeable, very sustainable"
        case (.lose, 0.5): return "\(share) · recommended"
        case (.lose, 0.75): return "\(share) · faster, hunger shows up"
        case (.lose, _): return "\(share) · the ceiling, short blocks only"
        case (_, 0.25): return "\(share) · lean gain, recommended"
        default: return "\(share) · faster, more fat comes with it"
        }
    }

    private func choices<T: Hashable>(_ options: [T], selection: Binding<T?>,
                                      label: @escaping (T) -> (String, String?)) -> some View {
        CardList {
            ForEach(options, id: \.self) { option in
                let (title, subtitle) = label(option)
                ChoiceRow(title: title, subtitle: subtitle, isSelected: selection.wrappedValue == option) {
                    selection.wrappedValue = option
                }
            }
        }
    }
}

private struct Question<Content: View>: View {
    let label: String
    let hint: String?
    @ViewBuilder let content: Content

    init(_ label: String, hint: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .textStyle(.label)
                .foregroundStyle(Palette.ink)
            if let hint {
                Text(hint)
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
            }
            content
                .padding(.top, Space.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
