import CalendarTodoCore
import Foundation
import SwiftUI

@MainActor
@Observable
final class AppSettings {
    // MARK: - Stored properties (synced with UserDefaults)

    var timeFormat: TimeFormat = .system {
        didSet { UserDefaults.standard.set(timeFormat.rawValue, forKey: "timeFormat") }
    }

    var dateFormat: DateFormatStyle = .system {
        didSet { UserDefaults.standard.set(dateFormat.rawValue, forKey: "dateFormat") }
    }

    var hasCompletedOnboarding: Bool = false {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    init() {
        self.timeFormat = TimeFormat(rawValue: UserDefaults.standard.string(forKey: "timeFormat") ?? "") ?? .system
        self.dateFormat = DateFormatStyle(rawValue: UserDefaults.standard.string(forKey: "dateFormat") ?? "") ?? .system
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    // MARK: - Time Format

    enum TimeFormat: String, CaseIterable {
        case system
        case h24
        case h12

        var label: String {
            switch self {
            case .system: L10n.systemDefault
            case .h24: L10n.time24h
            case .h12: L10n.time12h
            }
        }

        var example: String {
            switch self {
            case .system: "19:00 / 7:00 PM"
            case .h24: "19:00"
            case .h12: "7:00 PM"
            }
        }
    }

    // MARK: - Date Format

    enum DateFormatStyle: String, CaseIterable {
        case system
        case yyyyMMdd  // 2026-03-08
        case ddMMyyyy  // 08/03/2026
        case MMddyyyy  // 03/08/2026

        var label: String {
            switch self {
            case .system: L10n.systemDefault
            case .yyyyMMdd: "2026-03-08"
            case .ddMMyyyy: "08/03/2026"
            case .MMddyyyy: "03/08/2026"
            }
        }
    }

    // MARK: - Formatted time string

    func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        switch timeFormat {
        case .system:
            f.timeStyle = .short
        case .h24:
            f.dateFormat = "HH:mm"
        case .h12:
            f.dateFormat = "h:mm a"
        }
        return f.string(from: date)
    }

    // MARK: - Formatted date string

    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        switch dateFormat {
        case .system:
            f.dateStyle = .medium
        case .yyyyMMdd:
            f.dateFormat = "yyyy-MM-dd"
        case .ddMMyyyy:
            f.dateFormat = "dd/MM/yyyy"
        case .MMddyyyy:
            f.dateFormat = "MM/dd/yyyy"
        }
        return f.string(from: date)
    }

    func formatDateWithDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = DateHelpers.preferredLocale
        let isKorean = (Locale.preferredLanguages.first ?? "en").hasPrefix("ko")
        if isKorean {
            f.dateFormat = "yyyy년 M월 d일 E"
        } else {
            switch dateFormat {
            case .system:
                f.dateFormat = DateFormatter.dateFormat(fromTemplate: "EEE d MMM yyyy", options: 0, locale: DateHelpers.preferredLocale)
            case .yyyyMMdd:
                f.dateFormat = "EEE, yyyy-MM-dd"
            case .ddMMyyyy:
                f.dateFormat = "EEE, dd/MM/yyyy"
            case .MMddyyyy:
                f.dateFormat = "EEE, MM/dd/yyyy"
            }
        }
        return f.string(from: date)
    }

    func formatMonthDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = DateHelpers.preferredLocale
        f.setLocalizedDateFormatFromTemplate("MMMMd E")
        return f.string(from: date)
    }
}
