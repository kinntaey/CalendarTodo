import CalendarTodoCore
import SwiftUI

struct EventDetailView: View {
    let event: LocalEvent
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text(event.title)
                    .font(.title2.bold())

                // Date & Time
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        if event.isAllDay {
                            Text(DateHelpers.dateFormatter.string(from: event.startAt) + " (종일)")
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DateHelpers.dateFormatter.string(from: event.startAt))
                                Text("\(DateHelpers.timeFormatter.string(from: event.startAt)) - \(DateHelpers.timeFormatter.string(from: event.endAt))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundStyle(.blue)
                    }
                }

                // Location
                if let locationName = event.locationName, !locationName.isEmpty {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(locationName)
                            if let address = event.locationAddress, !address.isEmpty {
                                Text(address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.red)
                    }
                }

                // Description
                if let desc = event.eventDescription, !desc.isEmpty {
                    Label {
                        Text(desc)
                    } icon: {
                        Image(systemName: "text.alignleft")
                            .foregroundStyle(.secondary)
                    }
                }

                // Alarms
                if !event.alarms.isEmpty {
                    Label {
                        Text(event.alarms.sorted().map { alarmLabel(minutes: $0) }.joined(separator: ", "))
                    } icon: {
                        Image(systemName: "bell")
                            .foregroundStyle(.orange)
                    }
                }

                // Recurrence
                if let rule = event.recurrenceRule {
                    Label {
                        Text(recurrenceDescription(rule))
                    } icon: {
                        Image(systemName: "repeat")
                            .foregroundStyle(.green)
                    }
                }

                // Tags
                if let tags = event.tags, !tags.isEmpty {
                    Label {
                        FlowLayout(spacing: 6) {
                            ForEach(tags, id: \.id) { tag in
                                Text(tag.name)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: tag.color).opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: "tag")
                            .foregroundStyle(.purple)
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { onEdit() } label: {
                        Label("수정", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("이벤트를 삭제하시겠습니까?", isPresented: $showDeleteConfirm) {
            Button("삭제", role: .destructive) { onDelete() }
            Button("취소", role: .cancel) {}
        }
    }

    private func alarmLabel(minutes: Int) -> String {
        switch minutes {
        case 0: "이벤트 시간"
        case 10: "10분 전"
        case 30: "30분 전"
        case 60: "1시간 전"
        case 120: "2시간 전"
        case 1440: "1일 전"
        case 10080: "1주일 전"
        case 20160: "2주일 전"
        case 43200: "1개월 전"
        default: "\(minutes)분 전"
        }
    }

    private func recurrenceDescription(_ rule: RecurrenceRule) -> String {
        switch rule.frequency {
        case .daily: return "매일"
        case .weekly:
            if let days = rule.daysOfWeek {
                let names = ["월","화","수","목","금","토","일"]
                let selected = days.sorted().compactMap { d in
                    (1...7).contains(d) ? names[d - 1] : nil
                }
                return "매주 " + selected.joined(separator: ", ")
            }
            return "매주"
        case .monthly: return "매달"
        case .yearly: return "매년"
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
