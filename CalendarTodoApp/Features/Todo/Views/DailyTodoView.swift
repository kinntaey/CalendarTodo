import CalendarTodoCore
import SwiftData
import SwiftUI
import WidgetKit

struct DailyTodoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(AppSettings.self) private var appSettings
    @State private var viewModel = DailyTodoViewModel()
    @State private var editingTodo: LocalTodo?
    @State private var showCreateCategory = false
    @State private var categories: [LocalTodoList] = []
    @State private var newCategoryTitle = ""
    @State private var newCategoryIsPublic = true
    @State private var categoryToDelete: LocalTodoList?
    @State private var showDeleteCategoryConfirm = false

    private var ownerID: UUID {
        authService.currentUser?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date navigation
                dateHeader

                // Overall progress
                if !viewModel.todos.isEmpty {
                    progressSection
                }

                // Content
                ScrollView {
                    VStack(spacing: 0) {
                        // Categories
                        ForEach(categories, id: \.id) { category in
                            CategoryGroupView(
                                category: category,
                                selectedDate: viewModel.selectedDate,
                                ownerID: ownerID,
                                onEditTodo: { editingTodo = $0 },
                                onTodosChanged: {
                                    viewModel.loadTodos()
                                    loadCategories()
                                },
                                onDelete: {
                                    categoryToDelete = category
                                    showDeleteCategoryConfirm = true
                                },
                                onToggleVisibility: {
                                    category.isPublic.toggle()
                                    try? modelContext.save()
                                    syncCategory(category)
                                    loadCategories()
                                }
                            )
                        }

                        // Add group button
                        Button {
                            showCreateCategory = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text(L10n.newCategory)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.accent.opacity(0.1), in: Capsule())
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 90)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .padding(.bottom, 70)
            .navigationBarHidden(true)
            .gesture(
                DragGesture(minimumDistance: 50, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.width > 80 {
                            withAnimation { viewModel.goToPreviousDay() }
                            loadCategories()
                        } else if value.translation.width < -80 {
                            withAnimation { viewModel.goToNextDay() }
                            loadCategories()
                        }
                    }
            )
            .onAppear {
                viewModel.setup(modelContext: modelContext, ownerID: ownerID)
                loadCategories()
            }
            .onChange(of: viewModel.selectedDate) { _, _ in
                loadCategories()
            }
            .sheet(item: $editingTodo) { todo in
                TodoEditView(todo: todo, onSave: {
                    viewModel.loadTodos()
                    loadCategories()
                })
            }
            .sheet(isPresented: $showCreateCategory) {
                createCategorySheet
            }
            .confirmationDialog(L10n.deleteCategoryConfirm, isPresented: $showDeleteCategoryConfirm, titleVisibility: .visible) {
                Button(L10n.delete, role: .destructive) {
                    if let cat = categoryToDelete {
                        deleteCategory(cat)
                    }
                    categoryToDelete = nil
                }
                Button(L10n.cancel, role: .cancel) { categoryToDelete = nil }
            }
            .environment(\.locale, DateHelpers.preferredLocale)
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        VStack(spacing: 6) {
            Text(L10n.dailyTodoTab)
                .font(AppTheme.titleFont)

            HStack(spacing: 16) {
                Button { viewModel.goToPreviousDay() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.accent.opacity(0.1), in: Circle())
                }

                Text(appSettings.formatMonthDay(viewModel.selectedDate))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                if viewModel.isToday {
                    Text(L10n.today)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accentGradient, in: Capsule())
                }

                Button { viewModel.goToNextDay() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.accent.opacity(0.1), in: Circle())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Progress

    private var progressSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(AppTheme.accent.opacity(0.12), lineWidth: 4)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: viewModel.completionRate)
                    .stroke(AppTheme.accentGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.completionRate)

                Text("\(Int(viewModel.completionRate * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.completedTodos.count)/\(viewModel.todos.count) completed")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.accent.opacity(0.12))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.accentGradient)
                            .frame(width: geo.size.width * viewModel.completionRate, height: 4)
                            .animation(.easeInOut(duration: 0.5), value: viewModel.completionRate)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    // MARK: - Create Category Sheet

    private var createCategorySheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.categoryName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    TextField(L10n.categoryNamePlaceholder, text: $newCategoryTitle)
                        .font(.system(size: 17, design: .rounded))
                        .padding(14)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.visibility)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button {
                            newCategoryIsPublic = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 13))
                                Text(L10n.publicToFriends)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(newCategoryIsPublic ? Color.black : Color(.systemGray5)))
                            .foregroundStyle(newCategoryIsPublic ? .white : .primary)
                        }

                        Button {
                            newCategoryIsPublic = false
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "lock")
                                    .font(.system(size: 13))
                                Text(L10n.privateOnly)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(!newCategoryIsPublic ? Color.black : Color(.systemGray5)))
                            .foregroundStyle(!newCategoryIsPublic ? .white : .primary)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle(L10n.newCategory)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        showCreateCategory = false
                        newCategoryTitle = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) { createCategory() }
                        .bold()
                        .disabled(newCategoryTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func loadCategories() {
        let uid = ownerID
        let allLists: [LocalTodoList] = (try? modelContext.fetch(
            FetchDescriptor<LocalTodoList>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        categories = allLists.filter { !$0.isDeleted && $0.listType == "custom" && $0.ownerID == uid }
    }

    private func createCategory() {
        let list = LocalTodoList(
            ownerID: ownerID,
            title: newCategoryTitle.trimmingCharacters(in: .whitespaces),
            listType: "custom",
            isPublic: newCategoryIsPublic
        )
        modelContext.insert(list)
        try? modelContext.save()
        syncCategory(list)
        newCategoryTitle = ""
        newCategoryIsPublic = true
        showCreateCategory = false
        loadCategories()
    }

    private func deleteCategory(_ cat: LocalTodoList) {
        let catID = cat.id
        // 소속 투두도 삭제
        let allTodos: [LocalTodo] = (try? modelContext.fetch(FetchDescriptor<LocalTodo>())) ?? []
        let catTodos = allTodos.filter { $0.todoListID == catID }
        for todo in catTodos {
            Task {
                try? await SupabaseService.shared.client
                    .from("todos")
                    .delete()
                    .eq("id", value: todo.id.uuidString.lowercased())
                    .execute()
            }
            modelContext.delete(todo)
        }
        // 카테고리 삭제
        Task {
            try? await SupabaseService.shared.client
                .from("todo_lists")
                .delete()
                .eq("id", value: catID.uuidString.lowercased())
                .execute()
        }
        modelContext.delete(cat)
        try? modelContext.save()
        viewModel.loadTodos()
        loadCategories()
    }

    private func syncCategory(_ list: LocalTodoList) {
        let id = list.id.uuidString.lowercased()
        let ownerStr = list.ownerID.uuidString.lowercased()
        let title = list.title
        let listType = list.listType
        let isShared = list.isPublic
        let isDeleted = list.isDeleted

        Task {
            do {
                struct ListUpsert: Encodable {
                    let id: String
                    let owner_id: String
                    let title: String
                    let list_type: String
                    let is_shared: Bool
                    let is_deleted: Bool
                }
                try await SupabaseService.shared.client
                    .from("todo_lists")
                    .upsert(ListUpsert(id: id, owner_id: ownerStr, title: title, list_type: listType, is_shared: isShared, is_deleted: isDeleted))
                    .execute()
                print("[Category] Synced: \(title)")
            } catch {
                print("[Category] Sync ERROR: \(error)")
            }
        }
    }
}

// MARK: - Category Group View

private struct CategoryGroupView: View {
    let category: LocalTodoList
    let selectedDate: Date
    let ownerID: UUID
    var onEditTodo: (LocalTodo) -> Void
    var onTodosChanged: () -> Void
    var onDelete: () -> Void
    var onToggleVisibility: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var todos: [LocalTodo] = []
    @State private var newTodoTitle = ""
    @State private var showAddInput = false
    @State private var isRenamingCategory = false
    @State private var renameCategoryTitle = ""
    @State private var showDeleteConfirm = false
    @FocusState private var isInputFocused: Bool
    @FocusState private var isRenameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header capsule
            HStack(spacing: 0) {
                // Visibility + name capsule
                if isRenamingCategory {
                    HStack(spacing: 6) {
                        Image(systemName: category.isPublic ? "person.2.fill" : "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        TextField("", text: $renameCategoryTitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .focused($isRenameFocused)
                            .onSubmit {
                                if !renameCategoryTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                    category.title = renameCategoryTitle
                                    try? modelContext.save()
                                    syncCategoryFromView(category)
                                    onTodosChanged()
                                }
                                isRenamingCategory = false
                            }
                            .onAppear {
                                renameCategoryTitle = category.title
                                isRenameFocused = true
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5), in: Capsule())
                } else {
                    Menu {
                        Button {
                            onToggleVisibility()
                        } label: {
                            Label(
                                category.isPublic ? L10n.privateOnly : L10n.publicToFriends,
                                systemImage: category.isPublic ? "lock" : "person.2"
                            )
                        }
                        Button {
                            isRenamingCategory = true
                        } label: {
                            Label(L10n.edit, systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label(L10n.delete, systemImage: "trash")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.isPublic ? "person.2.fill" : "lock.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                            Text(category.title)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Add todo button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAddInput = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color(.systemGray5), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Todo items
            ForEach(todos, id: \.id) { todo in
                TodoItemRow(
                    todo: todo,
                    onToggle: { toggleTodo(todo) },
                    onEdit: { onEditTodo(todo) },
                    onRename: { newTitle in
                        todo.title = newTitle
                        todo.syncStatus = "pendingUpload"
                        try? modelContext.save()
                        loadTodos()
                        onTodosChanged()
                    },
                    onDelete: {
                        modelContext.delete(todo)
                        try? modelContext.save()
                        loadTodos()
                        onTodosChanged()
                    }
                )
            }

            // Inline add todo
            if showAddInput {
                HStack(spacing: 10) {
                    Circle()
                        .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 16, height: 16)

                    TextField(L10n.addTodoPlaceholder, text: $newTodoTitle)
                        .font(.system(size: 15, design: .rounded))
                        .focused($isInputFocused)
                        .onSubmit {
                            if !newTodoTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                addTodo()
                                DispatchQueue.main.async {
                                    isInputFocused = true
                                }
                            } else {
                                showAddInput = false
                                newTodoTitle = ""
                            }
                        }
                        .onAppear { isInputFocused = true }

                    Button {
                        showAddInput = false
                        newTodoTitle = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onChange(of: isInputFocused) { _, focused in
                    if !focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            if !isInputFocused {
                                showAddInput = false
                                newTodoTitle = ""
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .opacity(0.5)
        }
        .onAppear { loadTodos() }
        .alert(L10n.delete, isPresented: $showDeleteConfirm) {
            Button(L10n.delete, role: .destructive) { onDelete() }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deleteCategoryConfirm)
        }
        .onChange(of: selectedDate) { _, _ in loadTodos() }
    }

    private func dismissInput() {
        if showAddInput && newTodoTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            showAddInput = false
            isInputFocused = false
        }
    }

    private func loadTodos() {
        let listID = category.id
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: selectedDate)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

        let allTodos: [LocalTodo] = (try? modelContext.fetch(
            FetchDescriptor<LocalTodo>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        )) ?? []
        todos = allTodos.filter { todo in
            !todo.isDeleted && todo.todoListID == listID && {
                guard let assigned = todo.assignedDate else { return false }
                return assigned >= dayStart && assigned < dayEnd
            }()
        }.sorted { a, b in
            if a.isCompleted != b.isCompleted {
                return !a.isCompleted
            }
            return a.sortOrder < b.sortOrder
        }
    }

    private func syncCategoryFromView(_ cat: LocalTodoList) {
        let id = cat.id.uuidString.lowercased()
        let ownerStr = cat.ownerID.uuidString.lowercased()
        let title = cat.title
        let isShared = cat.isPublic
        Task {
            struct ListUpsert: Encodable {
                let id: String; let owner_id: String; let title: String; let list_type: String; let is_shared: Bool
            }
            try? await SupabaseService.shared.client
                .from("todo_lists")
                .upsert(ListUpsert(id: id, owner_id: ownerStr, title: title, list_type: "custom", is_shared: isShared))
                .execute()
        }
    }

    private func addTodo() {
        let trimmed = newTodoTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let todo = LocalTodo(
            ownerID: ownerID,
            title: trimmed,
            assignedDate: Calendar.current.startOfDay(for: selectedDate),
            sortOrder: todos.count
        )
        todo.todoListID = category.id
        modelContext.insert(todo)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        syncTodo(todo)
        newTodoTitle = ""
        loadTodos()
        onTodosChanged()
    }

    private func toggleTodo(_ todo: LocalTodo) {
        todo.isCompleted.toggle()
        todo.completedAt = todo.isCompleted ? .now : nil
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        syncTodo(todo)
        loadTodos()
        onTodosChanged()
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func syncTodo(_ todo: LocalTodo) {
        let id = todo.id.uuidString.lowercased()
        let ownerStr = todo.ownerID.uuidString.lowercased()
        let listID = todo.todoListID?.uuidString.lowercased()
        let title = todo.title
        let desc = todo.todoDescription
        let completed = todo.isCompleted
        let priority = todo.priority
        let sortOrder = todo.sortOrder
        let assignedStr = todo.assignedDate.map { Self.dateOnlyFormatter.string(from: $0) }

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
                }

                try await SupabaseService.shared.client
                    .from("todos")
                    .upsert(TodoUpsert(
                        id: id, owner_id: ownerStr, todo_list_id: listID,
                        title: title, description: desc, is_completed: completed,
                        assigned_date: assignedStr, priority: priority, sort_order: sortOrder
                    ))
                    .execute()
            } catch {
                #if DEBUG
                print("[Todo] Sync error: \(error)")
                #endif
            }
        }
    }
}

// MARK: - Todo Item Row (inline edit)

private struct TodoItemRow: View {
    let todo: LocalTodo
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onRename: (String) -> Void
    var onDelete: (() -> Void)?

    @State private var isEditing = false
    @State private var editTitle = ""
    @FocusState private var editFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    onToggle()
                }
            } label: {
                ZStack {
                    if todo.isCompleted {
                        Circle()
                            .fill(AppTheme.accentGradient)
                            .frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .stroke(Color(.systemGray3), lineWidth: 1.5)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .buttonStyle(.plain)

            // Title (tap to edit)
            if isEditing {
                TextField("", text: $editTitle)
                    .font(.system(size: 15, design: .rounded))
                    .focused($editFocused)
                    .onSubmit {
                        if !editTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            onRename(editTitle)
                        }
                        isEditing = false
                    }
                    .onAppear {
                        editTitle = todo.title
                        editFocused = true
                    }
            } else {
                Text(todo.title)
                    .font(.system(size: 15, design: .rounded))
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .tertiary : .primary)
                    .onTapGesture {
                        isEditing = true
                    }
            }

            Spacer()

            // Menu
            Menu {
                Button { onEdit() } label: {
                    Label(L10n.edit, systemImage: "pencil")
                }
                Button(role: .destructive) { onDelete?() } label: {
                    Label(L10n.delete, systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
    }
}
