import CalendarTodoCore
import SwiftUI
import WidgetKit

struct DailyTodoWidget: Widget {
    let kind = "DailyTodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyTodoProvider()) { entry in
            DailyTodoWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("오늘 할 일")
        .description("오늘의 할 일 목록을 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DailyTodoEntry: TimelineEntry {
    let date: Date
    let todos: [TodoWidgetItem]
}

struct TodoWidgetItem: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
}

struct DailyTodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyTodoEntry {
        DailyTodoEntry(date: .now, todos: [
            TodoWidgetItem(id: UUID(), title: "샘플 할 일", isCompleted: false),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyTodoEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyTodoEntry>) -> Void) {
        // TODO: Read from SwiftData via App Group
        let entry = DailyTodoEntry(date: .now, todos: [])
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 30)))
        completion(timeline)
    }
}

struct DailyTodoWidgetView: View {
    let entry: DailyTodoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                Text("오늘 할 일")
                    .font(.headline)
            }

            if entry.todos.isEmpty {
                Text("할 일이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.todos.prefix(5)) { todo in
                    HStack(spacing: 6) {
                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(todo.isCompleted ? .green : .secondary)
                        Text(todo.title)
                            .font(.caption)
                            .strikethrough(todo.isCompleted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
