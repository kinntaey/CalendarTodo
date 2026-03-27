import Foundation

public enum DateHelpers {
    /// Locale derived from system language + region
    public static var preferredLocale: Locale {
        let lang = Locale.preferredLanguages.first ?? "en"
        // Use the full language tag (e.g. "en-US", "ko-KR") which includes region info
        return Locale(identifier: lang)
    }

    public static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = preferredLocale
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    public static func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = preferredLocale
        f.timeStyle = .short
        return f.string(from: date)
    }

    public static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = preferredLocale
        f.timeStyle = .short
        return f
    }()

    public static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = preferredLocale
        f.setLocalizedDateFormatFromTemplate("MMMd E")
        return f
    }()

    public static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = preferredLocale
        f.setLocalizedDateFormatFromTemplate("yyyy MMMM")
        return f
    }()

    public static func startOfWeek(for date: Date) -> Date {
        let cal = calendar
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components) ?? date
    }

    public static func endOfWeek(for date: Date) -> Date {
        let start = startOfWeek(for: date)
        return calendar.date(byAdding: .day, value: 6, to: start) ?? date
    }

    public static func daysInWeek(for date: Date) -> [Date] {
        let start = startOfWeek(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    public static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        calendar.isDate(date1, inSameDayAs: date2)
    }

    public static func shortDayName(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = preferredLocale
        f.dateFormat = "E"
        return f.string(from: date)
    }

    public static func dayNumber(_ date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    public static func monthName(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = preferredLocale
        f.dateFormat = "MMMM"
        return f.string(from: date)
    }

    public static func yearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: date)
    }
}
