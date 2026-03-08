import Foundation

public enum RecurrenceFrequency: String, Codable {
    case daily
    case weekly
    case monthly
    case yearly
}

public struct RecurrenceRule: Codable, Equatable {
    public var frequency: RecurrenceFrequency
    public var interval: Int // every N weeks/months/etc.
    public var daysOfWeek: [Int]? // 1=Mon ... 7=Sun
    public var endDate: Date?
    public var count: Int? // or limit by count

    public init(frequency: RecurrenceFrequency, interval: Int, daysOfWeek: [Int]? = nil, endDate: Date? = nil, count: Int? = nil) {
        self.frequency = frequency
        self.interval = interval
        self.daysOfWeek = daysOfWeek
        self.endDate = endDate
        self.count = count
    }

    /// Preset: weekdays only (Mon-Fri)
    public static var weekdays: RecurrenceRule {
        RecurrenceRule(frequency: .weekly, interval: 1, daysOfWeek: [1, 2, 3, 4, 5])
    }

    /// Preset: weekends only (Sat-Sun)
    public static var weekends: RecurrenceRule {
        RecurrenceRule(frequency: .weekly, interval: 1, daysOfWeek: [6, 7])
    }

    /// Preset: every week
    public static var everyWeek: RecurrenceRule {
        RecurrenceRule(frequency: .weekly, interval: 1)
    }

    /// Preset: every month
    public static var everyMonth: RecurrenceRule {
        RecurrenceRule(frequency: .monthly, interval: 1)
    }

    /// Preset: every year
    public static var everyYear: RecurrenceRule {
        RecurrenceRule(frequency: .yearly, interval: 1)
    }
}
