/// The weekly split (PRD F2): full body for 2–3 days, upper/lower for 4, push/pull/legs for 5–6.
public enum SessionFocus: String, Codable, Sendable, CaseIterable {
    case fullBodyA, fullBodyB, fullBodyC, upper, lower, push, pull, legs
}

public enum DayKind: String, Codable, Sendable {
    case training, activeRecovery, rest
}

public struct PlannedDay: Codable, Sendable, Equatable {
    /// 0 = Monday … 6 = Sunday.
    public var weekday: Int
    public var kind: DayKind
    public var focus: SessionFocus?
    public var minutes: Int
}

public enum WeekPlanner {
    /// Training weekdays for each count, spread so hard days rarely sit back to back.
    static let trainingWeekdays: [Int: [Int]] = [
        2: [0, 3],
        3: [0, 2, 4],
        4: [0, 1, 3, 4],
        5: [0, 1, 3, 4, 5],
        6: [0, 1, 2, 3, 4, 5],
    ]

    public static func split(forDays days: Int) -> [SessionFocus] {
        switch days {
        case ...2: [.fullBodyA, .fullBodyB]
        case 3: [.fullBodyA, .fullBodyB, .fullBodyC]
        case 4: [.upper, .lower, .upper, .lower]
        case 5: [.push, .pull, .legs, .upper, .lower]
        default: [.push, .pull, .legs, .push, .pull, .legs]
        }
    }

    public static func week(for p: UserProfile) -> [PlannedDay] {
        let days = min(max(p.trainingDays, 2), 6)
        let slots = trainingWeekdays[days] ?? trainingWeekdays[4]!
        let foci = split(forDays: days)
        return (0..<7).map { weekday in
            if let i = slots.firstIndex(of: weekday) {
                return PlannedDay(weekday: weekday, kind: .training, focus: foci[i], minutes: p.sessionMinutes)
            }
            // Sunday is full rest; other off days are a walk plus mobility.
            return weekday == 6
                ? PlannedDay(weekday: weekday, kind: .rest, focus: nil, minutes: 0)
                : PlannedDay(weekday: weekday, kind: .activeRecovery, focus: nil, minutes: 25)
        }
    }
}
