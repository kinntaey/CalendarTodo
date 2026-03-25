import CalendarTodoCore
import SwiftUI

struct ContentView: View {
    enum Tab: String, CaseIterable {
        case calendar
        case dailyTodo
        case weeklyTodo
        case social
        case settings

        var label: String {
            switch self {
            case .calendar: L10n.calendarTab
            case .dailyTodo: L10n.dailyTodoTab
            case .weeklyTodo: L10n.weeklyTodoTab
            case .social: L10n.socialTab
            case .settings: L10n.settingsTab
            }
        }

        var icon: String {
            switch self {
            case .calendar: "calendar"
            case .dailyTodo: "checklist"
            case .weeklyTodo: "list.bullet.rectangle"
            case .social: "person.2"
            case .settings: "gearshape"
            }
        }

        var selectedIcon: String {
            switch self {
            case .calendar: "calendar"
            case .dailyTodo: "checklist.checked"
            case .weeklyTodo: "list.bullet.rectangle.fill"
            case .social: "person.2.fill"
            case .settings: "gearshape.fill"
            }
        }
    }

    @Environment(AuthService.self) private var authService
    @State private var selectedTab: Tab = .calendar
    @State private var pendingInvitation: EventInvitation?
    @State private var socialBadgeCount: Int = 0

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.label, systemImage: tab.icon)
            }
            .navigationTitle("CalendarTodo")
        } detail: {
            tabContent(for: selectedTab)
        }
        #else
        ZStack(alignment: .bottom) {
            tabContent(for: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom floating tab bar
            floatingTabBar
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSocialTab)) { _ in
            selectedTab = .social
        }
        .task {
            // 초기 동기화
            if let userID = authService.currentUser?.id {
                await SyncService.shared.syncAll(modelContext: modelContext, ownerID: userID)

                // Realtime 구독
                RealtimeService.shared.onEventParticipantChange = {
                    Task {
                        await checkPendingInvitations()
                        await updateSocialBadge()
                    }
                }
                RealtimeService.shared.onFriendshipChange = {
                    Task { await updateSocialBadge() }
                }
                RealtimeService.shared.onNotificationChange = {
                    Task {
                        await checkPendingInvitations()
                        await updateSocialBadge()
                    }
                }
                await RealtimeService.shared.subscribe(userID: userID)
            }
            await checkPendingInvitations()
            await updateSocialBadge()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task {
                if let userID = authService.currentUser?.id {
                    await SyncService.shared.syncAll(modelContext: modelContext, ownerID: userID)
                }
                await checkPendingInvitations()
                await updateSocialBadge()
            }
        }
        .sheet(item: $pendingInvitation) { invitation in
            InvitationPopupView(
                invitation: invitation,
                onAccept: {
                    Task {
                        await acceptInvitation(invitation)
                        pendingInvitation = nil
                    }
                },
                onDecline: {
                    Task {
                        _ = try? await EventParticipantService().respondToInvitation(
                            participantID: invitation.participantID, accept: false
                        )
                        pendingInvitation = nil
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedTab) { _, _ in
            Task { await updateSocialBadge() }
        }
        #endif
    }

    // MARK: - Floating Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 4) {
                            Image(systemName: selectedTab == tab ? tab.selectedIcon : tab.icon)
                                .font(.system(size: 18, weight: selectedTab == tab ? .semibold : .regular))
                                .symbolEffect(.bounce, value: selectedTab == tab)
                                .foregroundStyle(selectedTab == tab ? AppTheme.accent : .secondary)

                            if selectedTab == tab {
                                Text(tab.label)
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.accent)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                        // Badge for social tab
                        if tab == .social && socialBadgeCount > 0 {
                            Text("\(socialBadgeCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.red, in: Circle())
                                .offset(x: -8, y: 2)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    @Environment(\.modelContext) private var modelContext

    private func acceptInvitation(_ invitation: EventInvitation) async {
        do {
            let service = EventParticipantService()
            _ = try await service.respondToInvitation(
                participantID: invitation.participantID, accept: true
            )

            // Fetch the cloned event from Supabase and save to local SwiftData
            let userID = authService.currentUser?.id ?? UUID()
            let events: [FullEventResponse] = try await SupabaseService.shared.client
                .from("events")
                .select()
                .eq("owner_id", value: userID.uuidString.lowercased())
                .eq("title", value: invitation.event.title)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            if let remote = events.first {
                let colorStr = remote.color ?? "#007AFF"
                let colorTag = LocalTag(ownerID: remote.owner_id, name: "", color: colorStr)
                let localEvent = LocalEvent(
                    id: remote.id,
                    ownerID: remote.owner_id,
                    title: remote.title,
                    eventDescription: remote.description,
                    startAt: remote.start_at,
                    endAt: remote.end_at,
                    isAllDay: remote.is_all_day,
                    locationName: remote.location_name,
                    locationAddress: remote.location_address,
                    locationLat: remote.location_lat,
                    locationLng: remote.location_lng,
                    locationPlaceID: remote.location_place_id,
                    alarms: remote.alarms ?? [],
                    tags: [colorTag]
                )
                modelContext.insert(localEvent)
                try? modelContext.save()
                print("[Invitation] Event saved to local calendar: \(remote.title)")
            }
        } catch {
            print("[Invitation] Accept error: \(error)")
        }
    }

    private func updateSocialBadge() async {
        var count = 0
        do {
            let friendRequests = try await FriendshipService().fetchPendingRequests()
            count += friendRequests.count
        } catch {}
        do {
            let invitations = try await EventParticipantService().fetchPendingInvitations()
            count += invitations.count
        } catch {}
        do {
            let assignments = try await TodoSharingService().fetchPendingAssignments()
            count += assignments.count
        } catch {}
        socialBadgeCount = count
    }

    private func checkPendingInvitations() async {
        do {
            print("[Invitation] Checking pending invitations...")
            let invitations = try await EventParticipantService().fetchPendingInvitations()
            print("[Invitation] Found: \(invitations.count)")
            if let first = invitations.first {
                print("[Invitation] Showing popup for: \(first.event.title)")
                pendingInvitation = first
            }
        } catch {
            print("[Invitation] Error: \(error)")
        }
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .calendar:
            CalendarContainerView()
        case .dailyTodo:
            DailyTodoView()
        case .weeklyTodo:
            WeeklyTodoView()
        case .social:
            SocialView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Placeholder Views

private struct DailyTodoPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text(L10n.dailyTodoPlaceholder)
                .navigationTitle(L10n.dailyTodoTab)
        }
    }
}

private struct WeeklyTodoPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text(L10n.weeklyTodoPlaceholder)
                .navigationTitle(L10n.weeklyTodoTab)
        }
    }
}

// MARK: - Invitation Popup

private struct InvitationPopupView: View {
    let invitation: EventInvitation
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.accent)

                Text(L10n.eventInvitationTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .padding(.top, 20)

            // 초대자
            HStack(spacing: 10) {
                ProfileAvatar(name: invitation.inviter.displayName, size: 32)
                Text("@\(invitation.inviter.username)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // 일정 상세 카드
            VStack(alignment: .leading, spacing: 10) {
                // 일정 이름
                Text(invitation.event.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Divider()

                // 날짜/시간
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        let dateFormatter: DateFormatter = {
                            let f = DateFormatter()
                            f.setLocalizedDateFormatFromTemplate("yyyy MMM d EEEE")
                            return f
                        }()
                        let timeFormatter: DateFormatter = {
                            let f = DateFormatter()
                            f.setLocalizedDateFormatFromTemplate("HH:mm")
                            return f
                        }()

                        Text(dateFormatter.string(from: invitation.event.start_at))
                            .font(.system(size: 14, weight: .medium, design: .rounded))

                        if !invitation.event.is_all_day {
                            Text("\(timeFormatter.string(from: invitation.event.start_at)) - \(timeFormatter.string(from: invitation.event.end_at))")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(L10n.allDay)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 위치
                if let location = invitation.event.location_name, !location.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .frame(width: 20)
                        Text(location)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)

            // 버튼
            HStack(spacing: 12) {
                Button(action: onDecline) {
                    Text(L10n.decline)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
                }

                Button(action: onAccept) {
                    Text(L10n.accept)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppTheme.accentGradient, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}
