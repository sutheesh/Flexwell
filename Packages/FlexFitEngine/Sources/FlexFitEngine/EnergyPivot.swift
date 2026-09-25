/// Energy check-in answers (PRD F4).
public enum Energy: String, Codable, Sendable, CaseIterable {
    case high, ok, low
}

public enum SessionVariant: String, Codable, Sendable {
    /// As planned.
    case full
    /// ≤ 60% of the time: top 3 compound lifts, 2 sets each.
    case trimmed
    /// 15–20 minutes: mobility plus one easy compound.
    case minimum
}

public struct PivotResult: Codable, Sendable, Equatable {
    public var variant: SessionVariant
    public var minutes: Int
    /// Effort cap (RPE) for the session.
    public var rpeCap: Int
    /// High energy: an optional finisher is offered.
    public var offersFinisher: Bool
    /// Low energy: nudge the daily protein check.
    public var promptProtein: Bool
    /// Second low day in a row: suggest eating at maintenance today. Calories are never cut for low energy.
    public var suggestMaintenanceDay: Bool
}

/// Deterministic energy pivot rules (PRD "Energy pivot rules"). A Minimum session still counts toward the streak.
public enum EnergyPivot {
    public static func pivot(energy: Energy, lowYesterday: Bool, plannedMinutes: Int) -> PivotResult {
        switch energy {
        case .high:
            return PivotResult(variant: .full, minutes: plannedMinutes, rpeCap: 9,
                               offersFinisher: true, promptProtein: false, suggestMaintenanceDay: false)
        case .ok:
            return PivotResult(variant: .full, minutes: plannedMinutes, rpeCap: 8,
                               offersFinisher: false, promptProtein: false, suggestMaintenanceDay: false)
        case .low where lowYesterday:
            let minutes = plannedMinutes >= 30 ? 20 : 15
            return PivotResult(variant: .minimum, minutes: minutes, rpeCap: 6,
                               offersFinisher: false, promptProtein: false, suggestMaintenanceDay: true)
        case .low:
            // ≤ 60% of the planned time, rounded down to 5 minutes, never below 15.
            let minutes = max(15, Int(Double(plannedMinutes) * 0.6) / 5 * 5)
            return PivotResult(variant: .trimmed, minutes: minutes, rpeCap: 7,
                               offersFinisher: false, promptProtein: true, suggestMaintenanceDay: false)
        }
    }
}

/// Daily protein check answers (PRD F7).
public enum ProteinCheck: String, Codable, Sendable, CaseIterable {
    case yes, close, no
}
