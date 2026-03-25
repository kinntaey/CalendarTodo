import CalendarTodoCore
import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class DailyTodoViewModel {
    var selectedDate: Date = .now
    var todos: [LocalTodo] = []
    var newTodoTitle = ""
    var newTodoPriority: Int = 0
    var newTodoDueDate: Date?
    var newTodoRecurrence: RecurrenceRule?
    var errorMessage: String?

    private var todoRepository: TodoRepository?
    private var ownerID: UUID?

    func setup(modelContext: ModelContext, ownerID: UUID) {
        self.todoRepository = TodoRepository(modelContext: modelContext)
        self.ownerID = ownerID
        loadTodos()
    }

    func loadTodos() {
        guard let repo = todoRepository, let ownerID else { return }
        var result = repo.fetchTodos(for: selectedDate, ownerID: ownerID)

        // Expand recurring todos
        let recurring = repo.fetchRecurringTodos(ownerID: ownerID)
        let cal = Calendar.current
        for todo in recurring {
            guard let rule = todo.recurrenceRule,
                  let assignedDate = todo.assignedDate else { continue }
            // Skip if already in results (original date)
            if DateHelpers.isSameDay(assignedDate, selectedDate) { continue }
            // Check if selectedDate matches recurrence
            if matchesRecurrence(rule: rule, startDate: assignedDate, checkDate: selectedDate, calendar: cal) {
                result.append(todo)
            }
        }
        todos = result
    }

    private func matchesRecurrence(rule: RecurrenceRule, startDate: Date, checkDate: Date, calendar: Calendar) -> Bool {
        guard checkDate >= startDate else { return false }
        if let endDate = rule.endDate, checkDate > endDate { return false }

        switch rule.frequency {
        case .daily:
            let days = calendar.dateComponents([.day], from: startDate, to: checkDate).day ?? 0
            return days > 0 && days % rule.interval == 0
        case .weekly:
            if let daysOfWeek = rule.daysOfWeek, !daysOfWeek.isEmpty {
                let weekday = calendar.component(.weekday, from: checkDate)
                let ourDay = weekday == 1 ? 7 : weekday - 1
                return daysOfWeek.contains(ourDay)
            }
            let days = calendar.dateComponents([.day], from: startDate, to: checkDate).day ?? 0
            return days > 0 && days % (7 * rule.interval) == 0
        case .monthly:
            let startDay = calendar.component(.day, from: startDate)
            let checkDay = calendar.component(.day, from: checkDate)
            let months = calendar.dateComponents([.month], from: startDate, to: checkDate).month ?? 0
            return checkDay == startDay && months > 0 && months % rule.interval == 0
        case .yearly:
            let startComps = calendar.dateComponents([.month, .day], from: startDate)
            let checkComps = calendar.dateComponents([.month, .day], from: checkDate)
            let years = calendar.dateComponents([.year], from: startDate, to: checkDate).year ?? 0
            return startComps.month == checkComps.month && startComps.day == checkComps.day && years > 0 && years % rule.interval == 0
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        loadTodos()
    }

    func goToToday() {
        selectDate(.now)
    }

    func goToPreviousDay() {
        if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            selectDate(prev)
        }
    }

    func goToNextDay() {
        if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
            selectDate(next)
        }
    }

    var isToday: Bool {
        DateHelpers.isSameDay(selectedDate, .now)
    }

    // MARK: - CRUD

    func addTodo() {
        let trimmed = newTodoTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let repo = todoRepository, let ownerID else { return }

        let todo = LocalTodo(
            ownerID: ownerID,
            title: trimmed,
            assignedDate: Calendar.current.startOfDay(for: selectedDate),
            dueDate: newTodoDueDate,
            priority: newTodoPriority,
            sortOrder: todos.count
        )
        todo.recurrenceRule = newTodoRecurrence
        repo.create(todo)
        newTodoTitle = ""
        newTodoPriority = 0
        newTodoDueDate = nil
        newTodoRecurrence = nil
        loadTodos()
    }

    func toggleComplete(_ todo: LocalTodo) {
        guard let repo = todoRepository, let ownerID else { return }
        repo.toggleComplete(todo, by: ownerID)
        loadTodos()
    }

    func deleteTodo(_ todo: LocalTodo) {
        guard let repo = todoRepository else { return }
        repo.softDelete(todo)
        loadTodos()
    }

    func updatePriority(_ todo: LocalTodo, priority: Int) {
        guard let repo = todoRepository else { return }
        todo.priority = priority
        repo.update(todo)
        loadTodos()
    }

    func moveTodo(from source: IndexSet, to destination: Int) {
        guard let repo = todoRepository else { return }
        todos.move(fromOffsets: source, toOffset: destination)
        repo.reorder(todos)
    }

    // MARK: - Computed

    var incompleteTodos: [LocalTodo] {
        todos.filter { !$0.isCompleted }
    }

    var completedTodos: [LocalTodo] {
        todos.filter { $0.isCompleted }
    }

    var completionRate: Double {
        guard !todos.isEmpty else { return 0 }
        return Double(completedTodos.count) / Double(todos.count)
    }
}
