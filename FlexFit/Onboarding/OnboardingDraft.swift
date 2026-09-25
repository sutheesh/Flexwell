import Foundation
import Observation
import FlexFitEngine

/// The wizard's answers while they're being given. Raw text for typed fields so
/// the user can type freely; converted and validated into a `UserProfile` at the end.
@Observable
final class OnboardingDraft {
    enum Step: CaseIterable {
        case basics, body, goal, pace, dailyLife, environment, equipment, schedule, experience, limitations, notice
    }

    var name = ""
    var ageText = ""
    var sex: Sex?

    var units: DisplayUnits?
    var heightCmText = ""
    var heightFtText = ""
    var heightInText = ""
    var weightText = ""

    var goal: Goal?
    var targetText = ""
    var pacePct: Double?

    var activity: ActivityLevel?
    var environment: TrainingEnvironment? {
        didSet {
            if let environment, environment != oldValue {
                equipment = environment.presetEquipment
            }
        }
    }
    var equipment: Set<Equipment> = []
    var trainingDays: Int?
    var sessionMinutes: Int?
    var experience: Experience?
    /// Nil until answered; empty set means "None".
    var limitations: Set<Limitation>?
    var acceptedNotice = false

    var steps: [Step] {
        // Pace is counted until the user picks Maintain, so the counter doesn't jump up mid-flow.
        Step.allCases.filter { $0 != .pace || goal != .maintain }
    }

    // MARK: Parsed values (metric)

    var age: Int? { Int(ageText.trimmingCharacters(in: .whitespaces)) }

    var heightCm: Double? {
        switch units {
        case .metric?:
            return Self.number(heightCmText)
        case .imperial?:
            guard let ft = Self.number(heightFtText) else { return nil }
            let inches = Self.number(heightInText) ?? 0
            return (ft * 12 + inches) * 2.54
        case nil:
            return nil
        }
    }

    var weightKg: Double? {
        guard let units, let v = Self.number(weightText) else { return nil }
        return Mass.kilograms(from: v, in: units)
    }

    var targetKg: Double? {
        if goal == .maintain { return weightKg }
        guard let units, let v = Self.number(targetText) else { return nil }
        return Mass.kilograms(from: v, in: units)
    }

    static func number(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    // MARK: Validation

    /// A blocking problem with the current answers, phrased neutrally. Nil when the step can continue.
    func problem(for step: Step) -> String? {
        switch step {
        case .basics:
            if let age, age < Safety.minimumAge { return "FlexFit is built for adults, 18 and over." }
            if let age, age > Safety.maximumAge { return "Check your age — that looks like a typo." }
        case .body:
            if let h = heightCm, !(120...230).contains(h) { return "Check your height — that looks outside the usual range." }
            if let w = weightKg, !(35...300).contains(w) { return "Check your weight — that looks outside the usual range." }
        case .goal:
            guard let goal, goal != .maintain, let target = targetKg, let weight = weightKg, let height = heightCm else { break }
            let minimum = Safety.minimumTargetWeightKg(heightCm: height)
            if target < minimum {
                return "For your height, the lowest target FlexFit plans for is \(format(kg: minimum.rounded(.up)))."
            }
            if goal == .lose, target >= weight { return "A loss target should be below your current weight." }
            if goal == .gain, target <= weight { return "A gain target should be above your current weight." }
        default:
            break
        }
        return nil
    }

    func isAnswered(_ step: Step) -> Bool {
        switch step {
        case .basics:
            !name.trimmingCharacters(in: .whitespaces).isEmpty && age != nil && sex != nil
        case .body:
            units != nil && heightCm != nil && weightKg != nil
        case .goal:
            goal != nil && targetKg != nil
        case .pace:
            pacePct != nil
        case .dailyLife:
            activity != nil
        case .environment:
            environment != nil
        case .equipment:
            true    // Bodyweight-only with nothing ticked is a valid answer.
        case .schedule:
            trainingDays != nil && sessionMinutes != nil
        case .experience:
            experience != nil
        case .limitations:
            limitations != nil
        case .notice:
            acceptedNotice
        }
    }

    func canContinue(_ step: Step) -> Bool {
        isAnswered(step) && problem(for: step) == nil
    }

    // MARK: Output

    func makeProfile() -> UserProfile? {
        guard let age, let sex, let units, let heightCm, let weightKg, let goal, let targetKg,
              let activity, let environment, let trainingDays, let sessionMinutes, let experience
        else { return nil }
        return UserProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            age: age,
            sex: sex,
            heightCm: heightCm,
            weightKg: weightKg,
            displayUnits: units,
            goal: goal,
            targetWeightKg: targetKg,
            pacePctPerWeek: goal == .maintain ? 0 : Safety.cappedPace(pacePct ?? 0.5, goal: goal),
            activity: activity,
            experience: experience,
            trainingDays: trainingDays,
            sessionMinutes: sessionMinutes,
            environment: environment,
            equipment: equipment,
            limitations: limitations ?? []
        )
    }

    // MARK: Display helpers

    var massUnit: String { units == .imperial ? "lb" : "kg" }

    func format(kg: Double) -> String {
        Formatters.mass(kg, units: units ?? .metric)
    }

    /// "0.4 kg / week" for a pace option, from the entered weight.
    func paceLabel(_ pct: Double) -> String {
        guard let w = weightKg else { return "\(Formatters.percent(pct)) of body weight" }
        return "\(format(kg: w * pct / 100)) / week"
    }
}
