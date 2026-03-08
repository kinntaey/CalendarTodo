import Foundation

public enum DateHelpers {
    public static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ko_KR")
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    public static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f
    }()

    public static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f
    }()

    public static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        return f
    }()

    public static func startOfWeek(for date: Date) -> Date {
        let cal = calendar
        var components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
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
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "E"
        return f.string(from: date)
    }

    public static func dayNumber(_ date: Date) -> Int {
        calendar.component(.day, from: date)
    }
}
