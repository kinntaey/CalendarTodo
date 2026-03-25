import CalendarTodoCore
import SwiftUI

struct TodoRowView: View {
    let todo: LocalTodo
    let onToggle: () -> Void
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
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
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .stroke(priorityColor, lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .buttonStyle(.plain)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .strikethrough(todo.isCompleted, color: .secondary)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                if let desc = todo.todoDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Priority indicator
            if todo.priority > 0 && !todo.isCompleted {
                priorityBadge
            }

            // Edit button
            Button {
                onTap()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(L10n.delete, systemImage: "trash")
            }
        }
    }

    private var priorityColor: Color {
        switch todo.priority {
        case 3: return AppTheme.priorityHigh
        case 2: return AppTheme.priorityMedium
        case 1: return AppTheme.priorityLow
        default: return .secondary
        }
    }

    private var priorityBadge: some View {
        HStack(spacing: 2) {
            ForEach(0..<todo.priority, id: \.self) { _ in
                Image(systemName: "exclamationmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(priorityColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(priorityColor.opacity(0.1), in: Capsule())
    }
}
