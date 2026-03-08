import CalendarTodoCore
import SwiftUI

struct ContentView: View {
    enum Tab: String, CaseIterable {
        case calendar = "캘린더"
        case dailyTodo = "오늘 할 일"
        case weeklyTodo = "주간 할 일"
        case social = "친구"
        case settings = "설정"

        var icon: String {
            switch self {
            case .calendar: "calendar"
            case .dailyTodo: "checklist"
            case .weeklyTodo: "list.bullet.rectangle"
            case .social: "person.2"
            case .settings: "gearshape"
            }
        }
    }

    @State private var selectedTab: Tab = .calendar

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .navigationTitle("CalendarTodo")
        } detail: {
            tabContent(for: selectedTab)
        }
        #else
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        #endif
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .calendar:
            CalendarContainerView()
        case .dailyTodo:
            DailyTodoPlaceholderView()
        case .weeklyTodo:
            WeeklyTodoPlaceholderView()
        case .social:
            SocialPlaceholderView()
        case .settings:
            SettingsPlaceholderView()
        }
    }
}

// MARK: - Placeholder Views (to be replaced in Phase 2-5)

private struct DailyTodoPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("일일 투두 뷰 (Phase 3)")
                .navigationTitle("오늘 할 일")
        }
    }
}

private struct WeeklyTodoPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("주간 투두 뷰 (Phase 3)")
                .navigationTitle("주간 할 일")
        }
    }
}

private struct SocialPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("소셜 뷰 (Phase 5)")
                .navigationTitle("친구")
        }
    }
}

private struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("설정 뷰")
                .navigationTitle("설정")
        }
    }
}
