import Foundation
import SwiftData
import WidgetKit

@MainActor
public final class TodoRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD

    public func create(_ todo: LocalTodo) {
        modelContext.insert(todo)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        syncTodoToSupabase(todo)
    }

    public func update(_ todo: LocalTodo) {
        todo.updatedAt = .now
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        syncTodoToSupabase(todo)
    }

    public func softDelete(_ todo: LocalTodo) {
        Task {
            try? await SupabaseService.shared.client
                .from("todos")
                .delete()
                .eq("id", value: todo.id.uuidString.lowercased())
                .execute()
        }
        modelContext.delete(todo)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func toggleComplete(_ todo: LocalTodo, by userID: UUID) {
        todo.isCompleted.toggle()
        todo.completedAt = todo.isCompleted ? .now : nil
        todo.completedBy = todo.isCompleted ? userID : nil
        todo.updatedAt = .now
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        syncTodoToSupabase(todo)
    }

    private func syncTodoToSupabase(_ todo: LocalTodo) {
        let id = todo.id.uuidString.lowercased()
        let ownerStr = todo.ownerID.uuidString.lowercased()
        let listID = todo.todoListID?.uuidString.lowercased()
        let title = todo.title
        let desc = todo.todoDescription
        let completed = todo.isCompleted
        let priority = todo.priority
        let sortOrder = todo.sortOrder
        let deleted = todo.isDeleted
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let assignedStr = todo.assignedDate.map { df.string(from: $0) }

        Task {
            do {
                struct TodoUpsert: Encodable {
                    let id: String
                    let owner_id: String
                    let todo_list_id: String?
                    let title: String
                    let description: String?
                    let is_completed: Bool
                    let assigned_date: String?
                    let priority: Int
                    let sort_order: Int
                    let is_deleted: Bool
                }

                try await SupabaseService.shared.client
                    .from("todos")
                    .upsert(TodoUpsert(
                        id: id,
                        owner_id: ownerStr,
                        todo_list_id: listID,
                        title: title,
                        description: desc,
                        is_completed: completed,
                        assigned_date: assignedStr,
                        priority: priority,
                        sort_order: sortOrder,
                        is_deleted: deleted
                    ))
                    .execute()
                print("[Todo] Synced to Supabase: \(title)")
            } catch {
                print("[Todo] Sync ERROR: \(error)")
            }
        }
    }

    public func reorder(_ todos: [LocalTodo]) {
        for (index, todo) in todos.enumerated() {
            todo.sortOrder = index
            todo.updatedAt = .now
        }
        try? modelContext.save()
    }

    // MARK: - Queries

    public func fetchTodos(for date: Date, ownerID: UUID) -> [LocalTodo] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let allTodos = fetchAllActiveTodos(ownerID: ownerID)
        return allTodos.filter { todo in
            guard let assigned = todo.assignedDate else { return false }
            return assigned >= startOfDay && assigned < endOfDay
        }
        .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    public func fetchTodos(from startDate: Date, to endDate: Date, ownerID: UUID) -> [LocalTodo] {
        let allTodos = fetchAllActiveTodos(ownerID: ownerID)
        return allTodos.filter { todo in
            guard let assigned = todo.assignedDate else { return false }
            return assigned >= startDate && assigned < endDate
        }
        .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    public func fetchUnassignedTodos(ownerID: UUID) -> [LocalTodo] {
        let allTodos = fetchAllActiveTodos(ownerID: ownerID)
        return allTodos.filter { $0.assignedDate == nil }
            .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    public func fetchRecurringTodos(ownerID: UUID) -> [LocalTodo] {
        let allTodos = fetchAllActiveTodos(ownerID: ownerID)
        return allTodos.filter { $0.recurrenceRuleData != nil }
    }

    public func fetchTodo(by id: UUID) -> LocalTodo? {
        let predicate = #Predicate<LocalTodo> {
            $0.id == id && $0.isDeleted == false
        }
        var descriptor = FetchDescriptor<LocalTodo>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Private

    private func fetchAllActiveTodos(ownerID: UUID) -> [LocalTodo] {
        let predicate = #Predicate<LocalTodo> {
            $0.isDeleted == false && $0.ownerID == ownerID
        }
        let descriptor = FetchDescriptor<LocalTodo>(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - TodoList

    public func createList(_ list: LocalTodoList) {
        modelContext.insert(list)
        try? modelContext.save()
    }

    public func fetchOrCreateWeeklyList(ownerID: UUID, weekStart: Date) -> LocalTodoList {
        let calendar = Calendar.current
        let startOfWeek = calendar.startOfDay(for: weekStart)

        let predicate = #Predicate<LocalTodoList> {
            $0.isDeleted == false
            && $0.ownerID == ownerID
            && $0.listType == "weekly"
        }

        let descriptor = FetchDescriptor<LocalTodoList>(predicate: predicate)
        let lists = (try? modelContext.fetch(descriptor)) ?? []

        if let existing = lists.first(where: { $0.weekStartDate == startOfWeek }) {
            return existing
        }

        let newList = LocalTodoList(
            ownerID: ownerID,
            title: "Weekly",
            listType: "weekly",
            weekStartDate: startOfWeek
        )
        modelContext.insert(newList)
        try? modelContext.save()
        return newList
    }
}
