import Foundation
import SwiftData

@MainActor
public final class EventRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD

    public func create(_ event: LocalEvent) {
        modelContext.insert(event)
        try? modelContext.save()
    }

    public func update(_ event: LocalEvent) {
        event.updatedAt = .now
        event.syncStatus = SyncStatus.pendingUpload.rawValue
        try? modelContext.save()
    }

    public func softDelete(_ event: LocalEvent) {
        event.isDeleted = true
        event.status = "cancelled"
        event.syncStatus = SyncStatus.pendingDelete.rawValue
        event.updatedAt = .now
        try? modelContext.save()
    }

    // MARK: - Queries

    public func fetchEvents(for date: Date) -> [LocalEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<LocalEvent> {
            $0.isDeleted == false
            && $0.startAt < endOfDay
            && $0.endAt >= startOfDay
        }

        let descriptor = FetchDescriptor<LocalEvent>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startAt)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func fetchEvents(from startDate: Date, to endDate: Date) -> [LocalEvent] {
        let predicate = #Predicate<LocalEvent> {
            $0.isDeleted == false
            && $0.startAt < endDate
            && $0.endAt >= startDate
        }

        let descriptor = FetchDescriptor<LocalEvent>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startAt)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func fetchEvent(by id: UUID) -> LocalEvent? {
        let predicate = #Predicate<LocalEvent> {
            $0.id == id && $0.isDeleted == false
        }
        var descriptor = FetchDescriptor<LocalEvent>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// Returns dates that have events in a given month
    public func datesWithEvents(in month: Date) -> Set<DateComponents> {
        let calendar = Calendar.current
        guard let monthRange = calendar.range(of: .day, in: .month, for: month),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)
        else { return [] }

        let events = fetchEvents(from: startOfMonth, to: endOfMonth)
        var dates = Set<DateComponents>()

        for event in events {
            let components = calendar.dateComponents([.year, .month, .day], from: event.startAt)
            dates.insert(components)
        }

        return dates
    }
}
