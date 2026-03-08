import CalendarTodoCore
import SwiftUI
import WidgetKit

@main
struct CalendarTodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyTodoWidget()
        UpcomingEventsWidget()
    }
}
