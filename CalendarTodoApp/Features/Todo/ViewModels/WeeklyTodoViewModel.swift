import CalendarTodoCore
import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class WeeklyTodoViewModel {
    var currentWeekStart: Date = DateHelpers.startOfWeek(for: .now)
    var categories: [LocalTodoList] = []
    var todosByCategory: [UUID: [WeeklyTodoItem]] = [:]
    var newTodoTitle = ""
    var addingToCategoryID: UUID?

    private var todoRepository: TodoRepository?
    private var ownerID: UUID?
    private var modelContext: ModelContext?

    func setup(modelContext: ModelContext, ownerID: UUID) {
        self.todoRepository = TodoRepository(modelContext: modelContext)
        self.ownerID = ownerID
        self.modelContext = modelContext
        loadWeek()
    }

    func loadWeek() {
        guard let modelContext, let ownerID else { return }

        // 카테고리 로드
        let allLists: [LocalTodoList] = (try? modelContext.fetch(
            FetchDescriptor<LocalTodoList>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        categories = allLists.filter { !$0.isDeleted && $0.listType == "custom" && $0.ownerID == ownerID }

        // 이번 주 날짜 범위
        let weekEnd = DateHelpers.calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!

        // 각 카테고리별로 이번 주 투두 로드
        let allTodos: [LocalTodo] = (try? modelContext.fetch(
            FetchDescriptor<LocalTodo>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        )) ?? []

        var grouped: [UUID: [WeeklyTodoItem]] = [:]

        for category in categories {
            let categoryTodos = allTodos.filter { todo in
                !todo.isDeleted && todo.todoListID == category.id && todo.ownerID == ownerID
            }

            // 같은 제목끼리 그룹핑 (순서 유지)
            var titleOrder: [String] = []
            var titleGroups: [String: [LocalTodo]] = [:]
            for todo in categoryTodos {
                if titleGroups[todo.title] == nil {
                    titleOrder.append(todo.title)
                }
                titleGroups[todo.title, default: []].append(todo)
            }

            var items: [WeeklyTodoItem] = []
            for title in titleOrder {
                guard let todos = titleGroups[title] else { continue }
                // 이번 주에 배정된 것들 (요일 배정 인스턴스)
                let weekInstances = todos.filter { todo in
                    guard let assigned = todo.assignedDate else { return false }
                    return assigned >= currentWeekStart && assigned < weekEnd
                }
                // 템플릿 (assignedDate 없음)
                let template = todos.first(where: { $0.assignedDate == nil })

                // 주간 할 일: 템플릿이 있고 (이번 주에 생성됐거나 이번 주에 배정 있는 것)
                let templateInThisWeek = template != nil && (
                    (template!.createdAt >= currentWeekStart && template!.createdAt < weekEnd) ||
                    !weekInstances.isEmpty
                )
                if templateInThisWeek {
                    items.append(WeeklyTodoItem(
                        title: title,
                        categoryID: category.id,
                        instances: weekInstances,
                        template: template
                    ))
                }
            }

            if !items.isEmpty {
                // 정렬: 모든 배정 요일이 완료된 항목은 아래로
                grouped[category.id] = items.sorted { a, b in
                    let aAllDone = !a.instances.isEmpty && a.instances.allSatisfy(\.isCompleted)
                    let bAllDone = !b.instances.isEmpty && b.instances.allSatisfy(\.isCompleted)
                    if aAllDone != bAllDone {
                        return !aAllDone
                    }
                    return false // 기존 순서 유지
                }
            }
        }

        todosByCategory = grouped
    }

    // MARK: - Navigation

    func goToPreviousWeek() {
        if let prev = DateHelpers.calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) {
            currentWeekStart = prev
            loadWeek()
        }
    }

    func goToNextWeek() {
        if let next = DateHelpers.calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) {
            currentWeekStart = next
            loadWeek()
        }
    }

    func goToCurrentWeek() {
        currentWeekStart = DateHelpers.startOfWeek(for: .now)
        loadWeek()
    }

    var isCurrentWeek: Bool {
        DateHelpers.isSameDay(currentWeekStart, DateHelpers.startOfWeek(for: .now))
    }

    var weekDays: [Date] {
        DateHelpers.daysInWeek(for: currentWeekStart)
    }

    var weekRangeString: String {
        let end = DateHelpers.calendar.date(byAdding: .day, value: 6, to: currentWeekStart) ?? currentWeekStart
        let f = DateFormatter()
        f.locale = DateHelpers.preferredLocale
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(f.string(from: currentWeekStart)) - \(f.string(from: end))"
    }

    // MARK: - Add Todo to Category

    func addTodo(to categoryID: UUID) {
        let trimmed = newTodoTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let modelContext, let ownerID else { return }

        // 템플릿 투두 생성 (assignedDate 없음 = 주간 목표 마커)
        let todo = LocalTodo(
            ownerID: ownerID,
            title: trimmed,
            sortOrder: 0
        )
        todo.todoListID = categoryID
        modelContext.insert(todo)
        try? modelContext.save()
        newTodoTitle = ""
        addingToCategoryID = nil
        loadWeek()
    }

    // MARK: - Toggle Day

    func toggleDay(_ day: Date, for item: WeeklyTodoItem) {
        guard let modelContext, let ownerID else { return }
        let startOfDay = DateHelpers.calendar.startOfDay(for: day)

        // 이미 배정됐는지 확인
        if let existing = item.instances.first(where: {
            guard let d = $0.assignedDate else { return false }
            return DateHelpers.isSameDay(d, day)
        }) {
            // 배정된 요일 다시 탭 → 삭제
            modelContext.delete(existing)
            try? modelContext.save()
        } else {
            // 추가: 해당 날짜에 투두 생성
            let instance = LocalTodo(
                ownerID: ownerID,
                title: item.title,
                assignedDate: startOfDay,
                sortOrder: 0
            )
            instance.todoListID = item.categoryID
            modelContext.insert(instance)
            try? modelContext.save()
        }
        loadWeek()
    }

    func isDayAssigned(_ day: Date, for item: WeeklyTodoItem) -> Bool {
        item.instances.contains { todo in
            guard let d = todo.assignedDate else { return false }
            return DateHelpers.isSameDay(d, day)
        }
    }

    func isDayCompleted(_ day: Date, for item: WeeklyTodoItem) -> Bool {
        item.instances.first { todo in
            guard let d = todo.assignedDate else { return false }
            return DateHelpers.isSameDay(d, day)
        }?.isCompleted ?? false
    }

    // MARK: - Delete

    func deleteItem(_ item: WeeklyTodoItem) {
        guard let modelContext else { return }
        for todo in item.instances {
            Task {
                try? await SupabaseService.shared.client
                    .from("todos").delete()
                    .eq("id", value: todo.id.uuidString.lowercased()).execute()
            }
            modelContext.delete(todo)
        }
        if let template = item.template {
            Task {
                try? await SupabaseService.shared.client
                    .from("todos").delete()
                    .eq("id", value: template.id.uuidString.lowercased()).execute()
            }
            modelContext.delete(template)
        }
        try? modelContext.save()
        loadWeek()
    }

    // MARK: - Reorder

    func reorderItems(_ items: [WeeklyTodoItem], in categoryID: UUID) {
        guard let modelContext else { return }
        for (index, item) in items.enumerated() {
            for instance in item.instances {
                instance.sortOrder = index
                instance.syncStatus = "pendingUpload"
            }
            item.template?.sortOrder = index
        }
        try? modelContext.save()
        loadWeek()
    }

    // MARK: - Stats

    var totalAssigned: Int {
        todosByCategory.values.flatMap { $0 }.flatMap(\.instances).count
    }

    var totalCompleted: Int {
        todosByCategory.values.flatMap { $0 }.flatMap(\.instances).filter(\.isCompleted).count
    }
}

// MARK: - Weekly Todo Item

struct WeeklyTodoItem: Identifiable {
    let title: String
    let categoryID: UUID
    var instances: [LocalTodo]
    var template: LocalTodo?
    var id: String { "\(categoryID)-\(title)" }
}
