import CalendarTodoCore
import SwiftUI

struct SocialView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @State private var friendVM = SocialViewModel()
    @State private var showFriendManager = false
    @State private var friendTodoLists: [FriendTodoLists] = []
    @State private var pendingAssignments: [PendingAssignment] = []
    @State private var isLoading = false
    @State private var selectedDate: Date = .now
    @State private var isDataLoaded = false
    @State private var refreshID = UUID()

    private var ownerID: UUID {
        authService.currentUser?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(L10n.socialTab)
                        .font(AppTheme.titleFont)

                    Spacer()

                    Button {
                        showFriendManager = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "person.2")
                                .font(.system(size: 18))
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.accent.opacity(0.1), in: Circle())

                            let badgeCount = friendVM.totalPendingCount
                            if badgeCount > 0 {
                                Text("\(badgeCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.red, in: Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)

                // 날짜 네비게이션
                socialDateHeader

                ScrollView {
                    VStack(spacing: 16) {
                        if !pendingAssignments.isEmpty {
                            pendingAssignmentsSection
                        }

                        if isLoading && !isDataLoaded {
                            ProgressView()
                                .padding(.top, 40)
                        } else if friendTodoLists.isEmpty {
                            VStack(spacing: 16) {
                                Spacer().frame(height: 40)
                                Image(systemName: "list.clipboard")
                                    .font(.system(size: 48))
                                    .foregroundStyle(AppTheme.accent.opacity(0.3))
                                Text(friendVM.friends.isEmpty ? L10n.noFriends : L10n.noSharedLists)
                                    .font(AppTheme.bodyFont)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(friendTodoLists) { friendLists in
                                FriendTodoSection(friendLists: friendLists, selectedDate: selectedDate)
                                    .id("\(friendLists.id)-\(refreshID)")
                            }
                        }
                    }
                    .padding(.bottom, 90)
                }
            }
            .background(Color(.systemBackground))
            .padding(.bottom, 70)
            .navigationBarHidden(true)
            .task {
                await loadFriendData()
                isDataLoaded = true

                RealtimeService.shared.onTodoChange = {
                    Task {
                        await loadFriendData()
                        refreshID = UUID()
                    }
                }
            }
            .refreshable {
                await loadFriendData()
                refreshID = UUID()
            }
            .onAppear {
                Task {
                    await loadFriendData()
                    refreshID = UUID()
                }
            }
            .sheet(isPresented: $showFriendManager) {
                FriendManagerSheet(viewModel: friendVM)
            }
        }
    }

    // MARK: - Date Header

    @Environment(AppSettings.self) private var appSettings

    private var socialDateHeader: some View {
        HStack(spacing: 16) {
            Button {
                if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
                    selectedDate = prev
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accent.opacity(0.1), in: Circle())
            }

            Text(appSettings.formatMonthDay(selectedDate))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            if DateHelpers.isSameDay(selectedDate, .now) {
                Text(L10n.today)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.accentGradient, in: Capsule())
            }

            Button {
                if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                    selectedDate = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.accent.opacity(0.1), in: Circle())
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Pending Assignments

    private var pendingAssignmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.pendingAssignments)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .padding(.horizontal, 20)

            ForEach(pendingAssignments) { assignment in
                HStack(spacing: 12) {
                    ProfileAvatar(name: assignment.assigner.displayName, size: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(assignment.assigner.displayName)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text(assignment.title)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }

                    Spacer()

                    Button {
                        Task { await respondAssignment(assignment, accept: true) }
                    } label: {
                        Text(L10n.accept)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.accentGradient, in: Capsule())
                    }

                    Button {
                        Task { await respondAssignment(assignment, accept: false) }
                    } label: {
                        Text(L10n.decline)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5), in: Capsule())
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                        .fill(Color(.systemBackground))
                )
                .cardShadow()
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Actions

    private func loadFriendData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let friends = try await FriendshipService().fetchFriends()
            let friendIDs = friends.map(\.profile.id)
            friendVM.friends = friends

            guard !friendIDs.isEmpty else { return }

            async let lists = TodoSharingService().fetchAllFriendsPublicLists(friendIDs: friendIDs)
            async let assignments = TodoSharingService().fetchPendingAssignments()
            friendTodoLists = try await lists
            pendingAssignments = try await assignments
        } catch {
            print("[Social] Load error: \(error)")
        }
    }

    private func respondAssignment(_ assignment: PendingAssignment, accept: Bool) async {
        do {
            try await TodoSharingService().respondToAssignment(todoID: assignment.todoID, accept: accept)
            pendingAssignments.removeAll { $0.todoID == assignment.todoID }
        } catch {
            print("[Social] Respond error: \(error)")
        }
    }
}

// MARK: - Friend Todo Section

private struct FriendTodoSection: View {
    let friendLists: FriendTodoLists
    let selectedDate: Date
    @State private var todosByList: [UUID: [RemoteTodo]] = [:]
    @State private var loaded = false
    @State private var isExpanded = false
    @State private var loadID = UUID()
    @State private var addingToListID: UUID?
    @State private var newTodoTitle = ""
    @FocusState private var isAddFocused: Bool

    private var allDateTodos: [(list: RemoteTodoList, todos: [RemoteTodo])] {
        friendLists.lists.compactMap { list in
            let todos = filterByDate(todosByList[list.id] ?? [], date: selectedDate)
            return todos.isEmpty ? nil : (list: list, todos: todos)
        }
    }

    private var completionRate: Double {
        let all = allDateTodos.flatMap(\.todos)
        guard !all.isEmpty else { return 0 }
        return Double(all.filter(\.is_completed).count) / Double(all.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 친구 카드 헤더 (탭하면 펼침/접기)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    ProfileAvatar(name: friendLists.profile.displayName, size: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("@\(friendLists.profile.username)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        // 완료율 바
                        HStack(spacing: 8) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppTheme.accent.opacity(0.12))
                                        .frame(height: 4)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppTheme.accentGradient)
                                        .frame(width: geo.size.width * completionRate, height: 4)
                                }
                            }
                            .frame(height: 4)

                            Text("\(Int(completionRate * 100))%")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.accent)
                                .fixedSize()
                                .frame(minWidth: 32, alignment: .trailing)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // 카테고리별 투두 (펼쳤을 때만)
            if isExpanded && allDateTodos.isEmpty {
                Text(L10n.noTodosForDay)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
            } else if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(allDateTodos, id: \.list.id) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            // 카테고리 이름 + 추가 버튼
                            Text(item.list.title)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)

                            // 투두들
                            ForEach(item.todos) { todo in
                                HStack(spacing: 8) {
                                    ZStack {
                                        if todo.is_completed {
                                            Circle()
                                                .fill(Color.green.opacity(0.2))
                                                .frame(width: 16, height: 16)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(.green)
                                        } else {
                                            Circle()
                                                .stroke(Color(.systemGray3), lineWidth: 1.5)
                                                .frame(width: 16, height: 16)
                                        }
                                    }

                                    Text(todo.title)
                                        .font(.system(size: 14, design: .rounded))
                                        .strikethrough(todo.is_completed)
                                        .foregroundStyle(todo.is_completed ? .tertiary : .primary)
                                }
                            }

                            // 인라인 추가
                            if addingToListID == item.list.id {
                                HStack(spacing: 8) {
                                    Circle()
                                        .stroke(Color(.systemGray3), lineWidth: 1.5)
                                        .frame(width: 16, height: 16)

                                    TextField(L10n.addTodoPlaceholder, text: $newTodoTitle)
                                        .font(.system(size: 14, design: .rounded))
                                        .focused($isAddFocused)
                                        .onSubmit {
                                            if !newTodoTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                                                addTodoToFriend(listID: item.list.id, friendID: friendLists.profile.id, friendUsername: friendLists.profile.username)
                                            }
                                            addingToListID = nil
                                            newTodoTitle = ""
                                        }
                                        .onAppear { isAddFocused = true }

                                    Button {
                                        addingToListID = nil
                                        newTodoTitle = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.tertiary)
                                            .font(.system(size: 14))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .fill(Color(.systemBackground))
        )
        .cardShadow()
        .padding(.horizontal, 16)
        .task(id: loadID) {
            for list in friendLists.lists {
                do {
                    let todos = try await TodoSharingService().fetchTodosInList(listID: list.id)
                    todosByList[list.id] = todos
                } catch {}
            }
            loaded = true
        }
        .onAppear {
            loadID = UUID()
        }
    }

    private func addTodoToFriend(listID: UUID, friendID: UUID, friendUsername: String) {
        let title = newTodoTitle.trimmingCharacters(in: .whitespaces)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: selectedDate)

        Task {
            do {
                let supabase = SupabaseService.shared.client
                let myID = try await supabase.auth.session.user.id
                let myProfile: ProfileResponse = try await supabase
                    .from("profiles").select()
                    .eq("id", value: myID.uuidString.lowercased())
                    .single().execute().value

                // 친구의 투두에 추가
                struct TodoInsert: Encodable {
                    let owner_id: String
                    let todo_list_id: String
                    let title: String
                    let assigned_date: String
                    let sort_order: Int
                }

                try await supabase
                    .from("todos")
                    .insert(TodoInsert(
                        owner_id: friendID.uuidString.lowercased(),
                        todo_list_id: listID.uuidString.lowercased(),
                        title: title,
                        assigned_date: dateStr,
                        sort_order: 0
                    ))
                    .execute()

                // 푸시 알림
                struct PushPayload: Encodable {
                    let recipient_id: String
                    let title: String
                    let body: String
                }

                try? await supabase.functions.invoke(
                    "send-push-notification",
                    options: .init(body: PushPayload(
                        recipient_id: friendID.uuidString.lowercased(),
                        title: "CalendarTodo",
                        body: "@\(myProfile.username) added '\(title)' to your todos"
                    ))
                )

                // 새로고침
                loadID = UUID()
            } catch {
                print("[Social] Add todo to friend error: \(error)")
            }
        }
    }

    private func filterByDate(_ todos: [RemoteTodo], date: Date) -> [RemoteTodo] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let targetStr = df.string(from: dayStart)

        return todos.filter { todo in
            guard let assigned = todo.assigned_date else { return false }
            return assigned == targetStr
        }.sorted { a, b in
            if a.is_completed != b.is_completed { return !a.is_completed }
            return a.sort_order < b.sort_order
        }
    }
}

// MARK: - Friend Manager Sheet

private struct FriendManagerSheet: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    segmentButton(L10n.friendList, index: 0)
                    segmentButton(L10n.friendRequests, index: 1, badge: viewModel.totalPendingCount)
                    segmentButton(L10n.friendSearch, index: 2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                switch selectedTab {
                case 0: FriendListSection(viewModel: viewModel)
                case 1: FriendRequestsSection(viewModel: viewModel)
                case 2: FriendSearchSection(viewModel: viewModel)
                default: EmptyView()
                }

                Spacer()
            }
            .navigationTitle(L10n.socialTab)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
            .onAppear {
                Task { await viewModel.refresh() }
            }
        }
    }

    private func segmentButton(_ title: String, index: Int, badge: Int = 0) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: selectedTab == index ? .bold : .medium, design: .rounded))
                        .foregroundStyle(selectedTab == index ? .primary : .secondary)

                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.red, in: Circle())
                    }
                }

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(selectedTab == index ? Color.primary : .clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Friend List

private struct FriendListSection: View {
    @Bindable var viewModel: SocialViewModel
    @State private var deleteTargetID: UUID?
    @State private var showDeleteConfirm = false

    var body: some View {
        if viewModel.friends.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "person.2")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accent.opacity(0.3))
                Text(L10n.noFriends)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            List {
                ForEach(viewModel.friends) { friend in
                    FriendRow(profile: friend.profile)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteTargetID = friend.friendshipID
                                showDeleteConfirm = true
                            } label: {
                                Label(L10n.delete, systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .confirmationDialog(L10n.removeFriendConfirm, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button(L10n.delete, role: .destructive) {
                    if let id = deleteTargetID,
                       let friend = viewModel.friends.first(where: { $0.friendshipID == id }) {
                        Task { await viewModel.removeFriend(friend) }
                    }
                    deleteTargetID = nil
                }
                Button(L10n.cancel, role: .cancel) { deleteTargetID = nil }
            }
        }
    }
}

// MARK: - Friend Requests

private struct FriendRequestsSection: View {
    @Bindable var viewModel: SocialViewModel

    var body: some View {
        if viewModel.allPendingItems.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "bell")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accent.opacity(0.3))
                Text(L10n.noRequests)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            List {
                ForEach(viewModel.allPendingItems) { item in
                    switch item {
                    case .friendRequest(let request):
                        PendingFriendRequestRow(request: request, viewModel: viewModel)

                    case .eventInvitation(let invitation):
                        PendingEventInvitationRow(invitation: invitation, viewModel: viewModel)

                    case .todoAssignment(let assignment):
                        PendingTodoAssignmentRow(assignment: assignment, viewModel: viewModel)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Pending Friend Request Row

private struct PendingFriendRequestRow: View {
    let request: FriendshipWithProfile
    @Bindable var viewModel: SocialViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ProfileAvatar(name: request.profile.displayName, size: 40)
                Text(L10n.friendRequestMessage(request.profile.username))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .lineLimit(2)
            }
            acceptDeclineButtons(
                onAccept: { Task { await viewModel.acceptFriendRequest(request) } },
                onDecline: { Task { await viewModel.declineFriendRequest(request) } }
            )
        }
    }
}

// MARK: - Pending Event Invitation Row

private struct PendingEventInvitationRow: View {
    let invitation: EventInvitation
    @Bindable var viewModel: SocialViewModel
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 초대자 정보
            HStack(spacing: 10) {
                ProfileAvatar(name: invitation.inviter.displayName, size: 36)
                Text(L10n.eventInvitationMessage(invitation.inviter.username, invitation.event.title))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .lineLimit(2)
            }

            // 일정 상세
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(invitation.event.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }

                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    let formatter = DateFormatter()
                    let _ = formatter.setLocalizedDateFormatFromTemplate("MMMd EEE HH:mm")
                    Text(formatter.string(from: invitation.event.start_at))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if let location = invitation.event.location_name, !location.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(location)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))

            acceptDeclineButtons(
                onAccept: { Task { await viewModel.acceptEventInvitation(invitation) } },
                onDecline: { Task { await viewModel.declineEventInvitation(invitation) } }
            )
        }
    }
}

// MARK: - Pending Todo Assignment Row

private struct PendingTodoAssignmentRow: View {
    let assignment: PendingAssignment
    @Bindable var viewModel: SocialViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ProfileAvatar(name: assignment.assigner.displayName, size: 40)
                Text(L10n.todoAssignedMessage(assignment.assigner.username, assignment.title))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .lineLimit(2)
            }
            acceptDeclineButtons(
                onAccept: { Task { await viewModel.acceptTodoAssignment(assignment) } },
                onDecline: { Task { await viewModel.declineTodoAssignment(assignment) } }
            )
        }
    }
}

// MARK: - Accept / Decline Buttons

private func acceptDeclineButtons(onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) -> some View {
    HStack(spacing: 10) {
        Spacer()
        Button(action: onAccept) {
            Text(L10n.accept)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(AppTheme.accentGradient, in: Capsule())
        }
        .buttonStyle(.borderless)
        Button(action: onDecline) {
            Text(L10n.decline)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(.systemGray5), in: Capsule())
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Friend Search

private struct FriendSearchSection: View {
    @Bindable var viewModel: SocialViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(L10n.searchByUsername, text: $viewModel.searchQuery)
                    .font(.system(size: 15, design: .rounded))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit {
                        Task { await viewModel.searchUsers() }
                    }

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                        viewModel.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .onChange(of: viewModel.searchQuery) { _, _ in
                Task { await viewModel.searchUsers() }
            }

            if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty && !viewModel.isSearching {
                VStack(spacing: 12) {
                    Spacer()
                    Text(L10n.noSearchResults)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(viewModel.searchResults, id: \.id) { profile in
                        HStack(spacing: 12) {
                            ProfileAvatar(name: profile.displayName, size: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.displayName)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                Text("@\(profile.username)")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if viewModel.friendIDs.contains(profile.id) {
                                Text(L10n.alreadyFriends)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Color(.systemGray5), in: Capsule())
                            } else if viewModel.sentRequestUserIDs.contains(profile.id) {
                                Button {
                                    Task { await viewModel.cancelFriendRequest(to: profile.id) }
                                } label: {
                                    Text(L10n.requestSent)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Color(.systemGray5), in: Capsule())
                                }
                            } else {
                                Button {
                                    Task { await viewModel.sendFriendRequest(to: profile.id) }
                                } label: {
                                    Text(L10n.addFriend)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(AppTheme.accentGradient, in: Capsule())
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Reusable Components

struct ProfileAvatar: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(AppTheme.accentGradient, in: Circle())
    }
}

private struct FriendRow: View {
    let profile: ProfileResponse

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatar(name: profile.displayName, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                Text("@\(profile.username)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
