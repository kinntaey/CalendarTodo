import CalendarTodoCore
import SwiftUI

enum RecurringDeleteOption {
    case thisOnly
    case thisAndFuture
    case all
}

struct EventDetailView: View {
    let event: LocalEvent
    var onEdit: () -> Void
    var onDelete: (_ option: RecurringDeleteOption?) -> Void

    @State private var showDeleteConfirm = false
    @State private var showRecurringDeleteOptions = false
    @State private var participants: [ParticipantWithProfile] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text(event.title)
                    .font(AppTheme.titleFont)

                // Date & Time
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        if event.isAllDay {
                            Text(DateHelpers.dateFormatter.string(from: event.startAt) + " (\(L10n.allDay))")
                                .font(AppTheme.bodyFont)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DateHelpers.dateFormatter.string(from: event.startAt))
                                    .font(AppTheme.bodyFont)
                                Text("\(DateHelpers.timeFormatter.string(from: event.startAt)) - \(DateHelpers.timeFormatter.string(from: event.endAt))")
                                    .font(AppTheme.captionFont)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                // Location
                if let locationName = event.locationName, !locationName.isEmpty {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(locationName)
                                .font(AppTheme.bodyFont)
                            if let address = event.locationAddress, !address.isEmpty {
                                Text(address)
                                    .font(AppTheme.captionFont)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(AppTheme.priorityHigh)
                    }
                }

                // Description
                if let desc = event.eventDescription, !desc.isEmpty {
                    Label {
                        Text(desc)
                            .font(AppTheme.bodyFont)
                    } icon: {
                        Image(systemName: "text.alignleft")
                            .foregroundStyle(.secondary)
                    }
                }

                // Alarms
                if !event.alarms.isEmpty {
                    Label {
                        Text(event.alarms.sorted().map { L10n.alarmLabel(minutes: $0) }.joined(separator: ", "))
                            .font(AppTheme.bodyFont)
                    } icon: {
                        Image(systemName: "bell")
                            .foregroundStyle(AppTheme.priorityMedium)
                    }
                }

                // Recurrence
                if let rule = event.recurrenceRule {
                    Label {
                        Text(recurrenceDescription(rule))
                            .font(AppTheme.bodyFont)
                    } icon: {
                        Image(systemName: "repeat")
                            .foregroundStyle(.green)
                    }
                }

                // Participants
                if !participants.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text(L10n.participants)
                                .font(AppTheme.bodyFont)
                        } icon: {
                            Image(systemName: "person.2")
                                .foregroundStyle(AppTheme.accent)
                        }

                        HStack(spacing: 16) {
                            ForEach(participants) { p in
                                VStack(spacing: 4) {
                                    ProfileAvatar(name: p.profile.displayName, size: 36)
                                    Text("@\(p.profile.username)")
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundStyle(.secondary)
                                    if p.status == "owner" {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.primary)
                                    } else {
                                        Text(p.status == "accepted" ? "✓" : "⏳")
                                            .font(.system(size: 10))
                                    }
                                }
                            }
                        }
                        .padding(.leading, 28)
                    }
                }

                // Color tag
                if let tags = event.tags, let firstTag = tags.first {
                    Label {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: firstTag.color).opacity(0.08))
                                .frame(width: 14, height: 14)
                            if !firstTag.name.isEmpty {
                                Text(firstTag.name)
                                    .font(AppTheme.captionFont)
                            }
                        }
                        .padding(.leading, 4)
                    } icon: {
                        Image(systemName: "paintpalette")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .task {
            do {
                // Try to fetch participants from Supabase using event title
                // (since local events don't have Supabase IDs mapped yet)
                participants = try await EventParticipantService().fetchParticipantsForTitle(event.title)
            } catch {}
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { onEdit() } label: {
                        Label(L10n.edit, systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        if event.recurrenceRule != nil {
                            showRecurringDeleteOptions = true
                        } else {
                            showDeleteConfirm = true
                        }
                    } label: {
                        Label(L10n.delete, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .alert(L10n.deleteEventConfirm, isPresented: $showDeleteConfirm) {
            Button(L10n.delete, role: .destructive) { onDelete(nil) }
            Button(L10n.cancel, role: .cancel) {}
        }
        .confirmationDialog(L10n.deleteRecurringTitle, isPresented: $showRecurringDeleteOptions, titleVisibility: .visible) {
            Button(L10n.deleteThisOnly, role: .destructive) { onDelete(.thisOnly) }
            Button(L10n.deleteThisAndFuture, role: .destructive) { onDelete(.thisAndFuture) }
            Button(L10n.deleteAll, role: .destructive) { onDelete(.all) }
            Button(L10n.cancel, role: .cancel) {}
        }
    }

    private func recurrenceDescription(_ rule: RecurrenceRule) -> String {
        switch rule.frequency {
        case .daily: return L10n.daily
        case .weekly:
            if let days = rule.daysOfWeek {
                let names = L10n.weekDayHeaders
                let selected = days.sorted().compactMap { d in
                    (1...7).contains(d) ? names[d - 1] : nil
                }
                return L10n.weekly + " " + selected.joined(separator: ", ")
            }
            return L10n.weekly
        case .monthly: return L10n.monthly
        case .yearly: return L10n.yearly
        }
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: currentY + lineHeight))
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
