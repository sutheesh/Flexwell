/// All values are stored in metric; display units are a user preference (PRD: "Units").
public enum DisplayUnits: String, Codable, Sendable, CaseIterable {
    case metric
    case imperial
}

public enum Mass {
    public static let poundsPerKilogram = 2.204_622_621_8

    public static func display(kilograms: Double, in units: DisplayUnits) -> Double {
        switch units {
        case .metric: kilograms
        case .imperial: kilograms * poundsPerKilogram
        }
    }

    public static func kilograms(from value: Double, in units: DisplayUnits) -> Double {
        switch units {
        case .metric: value
        case .imperial: value / poundsPerKilogram
        }
    }
}
