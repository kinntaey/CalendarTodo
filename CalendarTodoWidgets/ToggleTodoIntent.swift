import AppIntents
import CalendarTodoCore
import SwiftData
import WidgetKit

struct ToggleTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Todo"
    static var description = IntentDescription("Mark a todo as completed or incomplete")

    @Parameter(title: "Todo ID")
    var todoID: String

    init() {}

    init(todoID: String) {
        self.todoID = todoID
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: todoID) else { return .result() }

        // Open SwiftData via App Group
        let storeURL: URL
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            storeURL = groupURL.appending(path: "CalendarTodo.store")
        } else {
            storeURL = URL.applicationSupportDirectory.appending(path: "CalendarTodo.store")
        }

        let schema = Schema([LocalEvent.self, LocalTodo.self, LocalTodoList.self, LocalTag.self, LocalProfile.self, LocalNotification.self, SyncCursor.self])
        let config = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // Find and toggle the todo
        let allTodos: [LocalTodo] = (try? context.fetch(FetchDescriptor<LocalTodo>())) ?? []
        if let todo = allTodos.first(where: { $0.id == uuid }) {
            todo.isCompleted.toggle()
            todo.completedAt = todo.isCompleted ? .now : nil
            try? context.save()
        }

        // Sync to Supabase
        await syncTodoToSupabase(todoID: uuid, allTodos: allTodos)

        // Reload widget
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }

    private func syncTodoToSupabase(todoID: UUID, allTodos: [LocalTodo]) async {
        guard let todo = allTodos.first(where: { $0.id == todoID }) else { return }

        struct TodoUpdate: Encodable {
            let is_completed: Bool
            let completed_at: String?
        }

        let completedStr: String? = todo.isCompleted
            ? ISO8601DateFormatter().string(from: todo.completedAt ?? .now)
            : nil

        try? await SupabaseService.shared.client
            .from("todos")
            .update(TodoUpdate(is_completed: todo.isCompleted, completed_at: completedStr))
            .eq("id", value: todoID.uuidString.lowercased())
            .execute()
    }
}
