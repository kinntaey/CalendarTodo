import CalendarTodoCore
import SwiftUI

struct WeeklyTodoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(AppSettings.self) private var appSettings
    @State private var viewModel = WeeklyTodoViewModel()
    @State private var showCreateCategory = false
    @State private var newCategoryTitle = ""
    @State private var newCategoryIsPublic = true

    private var ownerID: UUID {
        authService.currentUser?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekHeader

                if viewModel.totalAssigned > 0 {
                    statsBar
                }

                ScrollView {
                    VStack(spacing: 16) {
                        // 카테고리별 주간 투두
                        ForEach(viewModel.categories, id: \.id) { category in
                            WeeklyCategorySection(
                                category: category,
                                items: viewModel.todosByCategory[category.id] ?? [],
                                weekDays: viewModel.weekDays,
                                viewModel: viewModel
                            )
                        }

                        // 카테고리 추가 버튼
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
                        .padding(.top, 8)
                        .padding(.bottom, 90)
                    }
                }
            }
            .background(Color(.systemBackground))
            .padding(.bottom, 70)
            .navigationBarHidden(true)
            .gesture(
                DragGesture(minimumDistance: 50, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.width > 80 {
                            withAnimation { viewModel.goToPreviousWeek() }
                        } else if value.translation.width < -80 {
                            withAnimation { viewModel.goToNextWeek() }
                        }
                    }
            )
            .onAppear {
                viewModel.setup(modelContext: modelContext, ownerID: ownerID)
            }
            .sheet(isPresented: $showCreateCategory) {
                createCategorySheet
            }
            .environment(\.locale, DateHelpers.preferredLocale)
        }
    }

    // MARK: - Week Header

    private var weekHeader: some View {
        VStack(spacing: 6) {
            Text(L10n.weeklyTodoTab)
                .font(AppTheme.titleFont)

            HStack(spacing: 16) {
                Button { viewModel.goToPreviousWeek() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.accent.opacity(0.1), in: Circle())
                }

                Text(viewModel.weekRangeString)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                if viewModel.isCurrentWeek {
                    Text(L10n.thisWeek)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accentGradient, in: Capsule())
                }

                Button { viewModel.goToNextWeek() } label: {
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

    // MARK: - Stats

    private var statsBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(AppTheme.accent.opacity(0.12), lineWidth: 4)
                    .frame(width: 36, height: 36)

                let rate = viewModel.totalAssigned > 0
                    ? Double(viewModel.totalCompleted) / Double(viewModel.totalAssigned) : 0

                Circle()
                    .trim(from: 0, to: rate)
                    .stroke(AppTheme.accentGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: rate)

                Text("\(Int(rate * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.totalCompleted)/\(viewModel.totalAssigned) completed")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    let rate = viewModel.totalAssigned > 0
                        ? Double(viewModel.totalCompleted) / Double(viewModel.totalAssigned) : 0
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.accent.opacity(0.12))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.accentGradient)
                            .frame(width: geo.size.width * rate, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
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
                                Image(systemName: "person.2").font(.system(size: 13))
                                Text(L10n.publicToFriends).font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Capsule().fill(newCategoryIsPublic ? Color.black : Color(.systemGray5)))
                            .foregroundStyle(newCategoryIsPublic ? .white : .primary)
                        }

                        Button {
                            newCategoryIsPublic = false
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "lock").font(.system(size: 13))
                                Text(L10n.privateOnly).font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
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
                    Button(L10n.cancel) { showCreateCategory = false; newCategoryTitle = "" }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) { createCategory() }.bold()
                        .disabled(newCategoryTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
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
        newCategoryTitle = ""
        newCategoryIsPublic = true
        showCreateCategory = false
        viewModel.loadWeek()
    }
}

// MARK: - Weekly Category Section

private struct WeeklyCategorySection: View {
    let category: LocalTodoList
    let items: [WeeklyTodoItem]
    let weekDays: [Date]
    @Bindable var viewModel: WeeklyTodoViewModel

    @State private var showAddInput = false
    @State private var newTitle = ""
    @State private var draggingItemID: String?
    @State private var reorderedItems: [WeeklyTodoItem]?
    @FocusState private var isInputFocused: Bool

    private var displayItems: [WeeklyTodoItem] {
        reorderedItems ?? items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 카테고리 헤더
            HStack(spacing: 0) {
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

                Button {
                    withAnimation { showAddInput = true }
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

            // 투두 목표들
            ForEach(displayItems) { item in
                WeeklyTodoRow(
                    item: item,
                    weekDays: weekDays,
                    onToggleDay: { viewModel.toggleDay($0, for: item) },
                    isDayAssigned: { viewModel.isDayAssigned($0, for: item) },
                    isDayCompleted: { viewModel.isDayCompleted($0, for: item) },
                    onDelete: { viewModel.deleteItem(item) }
                )
                .onDrag {
                    draggingItemID = item.id
                    reorderedItems = reorderedItems ?? items
                    return NSItemProvider(object: item.id as NSString)
                }
                .onDrop(of: [.text], delegate: WeeklyDropDelegate(
                    item: item,
                    items: Binding(
                        get: { reorderedItems ?? items },
                        set: { reorderedItems = $0 }
                    ),
                    draggingID: $draggingItemID,
                    onReorder: { viewModel.reorderItems(reorderedItems ?? items, in: category.id) ; reorderedItems = nil }
                ))
            }

            // 인라인 추가 (카드 형태)
            if showAddInput {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Circle()
                            .stroke(Color(.systemGray3), lineWidth: 1.5)
                            .frame(width: 18, height: 18)

                        TextField(L10n.addTodoPlaceholder, text: $newTitle)
                            .font(.system(size: 15, design: .rounded))
                            .focused($isInputFocused)
                            .onSubmit {
                                if !newTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                    viewModel.newTodoTitle = newTitle
                                    viewModel.addTodo(to: category.id)
                                    newTitle = ""
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isInputFocused = true
                                    }
                                } else {
                                    showAddInput = false
                                    newTitle = ""
                                }
                            }
                            .onAppear { isInputFocused = true }

                        Spacer()

                        Button {
                            showAddInput = false
                            newTitle = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // 요일 칩 (비활성 상태로 표시)
                    HStack(spacing: 6) {
                        ForEach(weekDays, id: \.self) { day in
                            Text(DateHelpers.shortDayName(day))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                        .fill(Color(.systemBackground))
                )
                .cardShadow()
                .padding(.horizontal, 16)
                .onChange(of: isInputFocused) { _, focused in
                    if !focused { showAddInput = false; newTitle = "" }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Weekly Todo Row

private struct WeeklyTodoRow: View {
    let item: WeeklyTodoItem
    let weekDays: [Date]
    let onToggleDay: (Date) -> Void
    let isDayAssigned: (Date) -> Bool
    let isDayCompleted: (Date) -> Bool
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    private var isAllCompleted: Bool {
        !item.instances.isEmpty && item.instances.allSatisfy(\.isCompleted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .strikethrough(isAllCompleted)
                    .foregroundStyle(isAllCompleted ? .secondary : .primary)

                Spacer()

                let completed = item.instances.filter(\.isCompleted).count
                let total = item.instances.count
                if total > 0 {
                    Text("\(completed)/\(total)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Button { showDeleteConfirm = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
            }

            // 요일 칩
            HStack(spacing: 6) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { _, day in
                    let assigned = isDayAssigned(day)
                    let completed = isDayCompleted(day)
                    let isToday = DateHelpers.isSameDay(day, .now)

                    Button {
                        onToggleDay(day)
                    } label: {
                        VStack(spacing: 3) {
                            Text(DateHelpers.shortDayName(day))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            completed ? Color.green.opacity(0.2) :
                                            assigned ? AppTheme.accent.opacity(0.15) :
                                            Color(.systemGray6)
                                        )
                                )
                                .foregroundStyle(
                                    completed ? .green :
                                    assigned ? AppTheme.accent :
                                    .secondary
                                )

                            Circle()
                                .fill(isToday ? AppTheme.accent : .clear)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .fill(Color(.systemBackground))
        )
        .cardShadow()
        .opacity(isAllCompleted ? 0.5 : 1)
        .padding(.horizontal, 16)
        .alert(L10n.delete, isPresented: $showDeleteConfirm) {
            Button(L10n.delete, role: .destructive) { onDelete() }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deleteCategoryConfirm)
        }
    }
}

// MARK: - Weekly Drop Delegate

private struct WeeklyDropDelegate: DropDelegate {
    let item: WeeklyTodoItem
    @Binding var items: [WeeklyTodoItem]
    @Binding var draggingID: String?
    let onReorder: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        onReorder()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragID = draggingID,
              let fromIndex = items.firstIndex(where: { $0.id == dragID }),
              let toIndex = items.firstIndex(where: { $0.id == item.id }),
              fromIndex != toIndex else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
