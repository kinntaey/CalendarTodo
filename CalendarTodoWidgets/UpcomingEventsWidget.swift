import SwiftUI
import WidgetKit

struct UpcomingEventsWidget: Widget {
    let kind = "UpcomingEventsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpcomingEventsProvider()) { entry in
            UpcomingEventsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("다가오는 일정")
        .description("다가오는 일정을 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct EventEntry: TimelineEntry {
    let date: Date
    let events: [EventWidgetItem]
}

struct EventWidgetItem: Identifiable {
    let id: UUID
    let title: String
    let startAt: Date
    let locationName: String?
}

struct UpcomingEventsProvider: TimelineProvider {
    func placeholder(in context: Context) -> EventEntry {
        EventEntry(date: .now, events: [
            EventWidgetItem(id: UUID(), title: "샘플 일정", startAt: .now, locationName: nil),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (EventEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventEntry>) -> Void) {
        // TODO: Read from SwiftData via App Group
        let entry = EventEntry(date: .now, events: [])
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 15)))
        completion(timeline)
    }
}

struct UpcomingEventsWidgetView: View {
    let entry: EventEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                Text("다가오는 일정")
                    .font(.headline)
            }

            if entry.events.isEmpty {
                Text("예정된 일정이 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.events.prefix(5)) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.caption.bold())
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(event.startAt, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let location = event.locationName {
                                Text("- \(location)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
