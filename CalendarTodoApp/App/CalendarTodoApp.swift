import CalendarTodoCore
import SwiftUI
import SwiftData

@main
struct CalendarTodoApp: App {
    @State private var authService = AuthService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalEvent.self,
            LocalTodo.self,
            LocalTodoList.self,
            LocalTag.self,
            LocalProfile.self,
            LocalNotification.self,
            SyncCursor.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: AppGroup.containerURL.appending(path: "CalendarTodo.store"),
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
        }
        .modelContainer(sharedModelContainer)
    }
}
