import Foundation

enum RecurrenceFrequency: String, Codable {
    case daily
    case weekly
    case monthly
    case yearly
}

struct RecurrenceRule: Codable, Equatable {
    var frequency: RecurrenceFrequency
    var interval: Int // every N weeks/months/etc.
    var daysOfWeek: [Int]? // 1=Mon ... 7=Sun
    var endDate: Date?
    var count: Int? // or limit by count

    /// Preset: weekdays only (Mon-Fri)
    static var weekdays: RecurrenceRule {
        RecurrenceRule(frequency: .weekly, interval: 1, daysOfWeek: [1, 2, 3, 4, 5])
    }

    /// Preset: weekends only (Sat-Sun)
    static var weekends: RecurrenceRule {
        RecurrenceRule(frequency: .weekly, interval: 1, daysOfWeek: [6, 7])
    }

    /// Preset: every week
    static var everyWeek: RecurrenceRule {
        RecurrenceRule(frequency: .weekly, interval: 1)
    }

    /// Preset: every month
    static var everyMonth: RecurrenceRule {
        RecurrenceRule(frequency: .monthly, interval: 1)
    }

    /// Preset: every year
    static var everyYear: RecurrenceRule {
        RecurrenceRule(frequency: .yearly, interval: 1)
    }
}
