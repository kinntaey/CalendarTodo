import Foundation
import Supabase
import SwiftData

@MainActor
public final class SyncService {
    public static let shared = SyncService()
    private let supabase = SupabaseService.shared.client

    private init() {}

    // MARK: - Full Sync

    public func syncAll(modelContext: ModelContext, ownerID: UUID) async {
        let ownerStr = ownerID.uuidString.lowercased()
        print("[Sync] Starting full sync for \(ownerStr)")

        await uploadEvents(modelContext: modelContext, ownerID: ownerID, ownerStr: ownerStr)
        await downloadEvents(modelContext: modelContext, ownerID: ownerID, ownerStr: ownerStr)
        await uploadTodos(modelContext: modelContext, ownerID: ownerID, ownerStr: ownerStr)
        await downloadTodos(modelContext: modelContext, ownerID: ownerID, ownerStr: ownerStr)
        await uploadTodoLists(modelContext: modelContext, ownerID: ownerID, ownerStr: ownerStr)

        print("[Sync] Full sync complete")
    }

    // MARK: - Upload Events

    private func uploadEvents(modelContext: ModelContext, ownerID: UUID, ownerStr: String) async {
        let allEvents: [LocalEvent] = (try? modelContext.fetch(
            FetchDescriptor<LocalEvent>()
        )) ?? []

        let pendingEvents = allEvents.filter { $0.ownerID == ownerID && $0.syncStatus == "pendingUpload" }
        print("[Sync] Events to upload: \(pendingEvents.count)")

        for event in pendingEvents {
            do {
                let colorStr = event.tags?.first?.color ?? "#007AFF"

                struct EventUpsert: Encodable {
                    let id: String
                    let owner_id: String
                    let title: String
                    let description: String?
                    let start_at: Date
                    let end_at: Date
                    let is_all_day: Bool
                    let location_name: String?
                    let location_address: String?
                    let location_lat: Double?
                    let location_lng: Double?
                    let location_place_id: String?
                    let alarms: [Int]
                    let color: String
                    let status: String
                    let is_deleted: Bool
                }

                try await supabase
                    .from("events")
                    .upsert(EventUpsert(
                        id: event.id.uuidString.lowercased(),
                        owner_id: ownerStr,
                        title: event.title,
                        description: event.eventDescription,
                        start_at: event.startAt,
                        end_at: event.endAt,
                        is_all_day: event.isAllDay,
                        location_name: event.locationName,
                        location_address: event.locationAddress,
                        location_lat: event.locationLat,
                        location_lng: event.locationLng,
                        location_place_id: event.locationPlaceID,
                        alarms: event.alarms,
                        color: colorStr,
                        status: event.status,
                        is_deleted: event.isDeleted
                    ))
                    .execute()

                event.syncStatus = "synced"
                try? modelContext.save()
            } catch {
                print("[Sync] Upload event error: \(error)")
            }
        }
    }

    // MARK: - Download Events

    private func downloadEvents(modelContext: ModelContext, ownerID: UUID, ownerStr: String) async {
        do {
            struct RemoteEvent: Decodable {
                let id: UUID
                let owner_id: UUID
                let title: String
                let description: String?
                let start_at: Date
                let end_at: Date
                let is_all_day: Bool
                let location_name: String?
                let location_address: String?
                let location_lat: Double?
                let location_lng: Double?
                let location_place_id: String?
                let alarms: [Int]?
                let color: String?
                let status: String
                let is_deleted: Bool
                let updated_at: Date
            }

            let remoteEvents: [RemoteEvent] = try await supabase
                .from("events")
                .select()
                .eq("owner_id", value: ownerStr)
                .eq("is_deleted", value: false)
                .execute()
                .value

            print("[Sync] Remote events found: \(remoteEvents.count)")

            // Get all local event IDs (including all owners to prevent any duplicates)
            let allLocal: [LocalEvent] = (try? modelContext.fetch(FetchDescriptor<LocalEvent>())) ?? []
            let localIDs = Set(allLocal.map { $0.id })

            for remote in remoteEvents {
                if !localIDs.contains(remote.id) {
                    // New event from server - insert locally
                    let colorStr = remote.color ?? "#007AFF"
                    let colorTag = LocalTag(ownerID: remote.owner_id, name: "", color: colorStr)
                    let local = LocalEvent(
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
                        tags: [colorTag],
                        syncStatus: "synced"
                    )
                    modelContext.insert(local)
                }
            }
            try? modelContext.save()
        } catch {
            print("[Sync] Download events error: \(error)")
        }
    }

    // MARK: - Upload Todos

    private func uploadTodos(modelContext: ModelContext, ownerID: UUID, ownerStr: String) async {
        let allTodos: [LocalTodo] = (try? modelContext.fetch(FetchDescriptor<LocalTodo>())) ?? []
        let pendingTodos = allTodos.filter { $0.ownerID == ownerID && $0.syncStatus == "pendingUpload" }
        print("[Sync] Todos to upload: \(pendingTodos.count)")

        for todo in pendingTodos {
            do {
                struct TodoUpsert: Encodable {
                    let id: String
                    let owner_id: String
                    let todo_list_id: String?
                    let title: String
                    let description: String?
                    let is_completed: Bool
                    let assigned_date: String?
                    let due_date: String?
                    let priority: Int
                    let sort_order: Int
                    let is_deleted: Bool
                }

                let localDateFormatter = DateFormatter()
                localDateFormatter.dateFormat = "yyyy-MM-dd"
                let assignedStr = todo.assignedDate.map { localDateFormatter.string(from: $0) }
                let dueStr = todo.dueDate.map { ISO8601DateFormatter().string(from: $0) }
                let listIDStr = todo.todoListID?.uuidString.lowercased()

                try await supabase
                    .from("todos")
                    .upsert(TodoUpsert(
                        id: todo.id.uuidString.lowercased(),
                        owner_id: ownerStr,
                        todo_list_id: listIDStr,
                        title: todo.title,
                        description: todo.todoDescription,
                        is_completed: todo.isCompleted,
                        assigned_date: assignedStr,
                        due_date: dueStr,
                        priority: todo.priority,
                        sort_order: todo.sortOrder,
                        is_deleted: todo.isDeleted
                    ))
                    .execute()

                todo.syncStatus = "synced"
                try? modelContext.save()
            } catch {
                print("[Sync] Upload todo error: \(error)")
            }
        }
    }

    // MARK: - Download Todos

    private func downloadTodos(modelContext: ModelContext, ownerID: UUID, ownerStr: String) async {
        do {
            struct RemoteTodoItem: Decodable {
                let id: UUID
                let owner_id: UUID
                let title: String
                let description: String?
                let is_completed: Bool
                let assigned_date: String?
                let due_date: String?
                let priority: Int
                let sort_order: Int
                let is_deleted: Bool
            }

            let remoteTodos: [RemoteTodoItem] = try await supabase
                .from("todos")
                .select("id, owner_id, title, description, is_completed, assigned_date, due_date, priority, sort_order, is_deleted")
                .eq("owner_id", value: ownerStr)
                .eq("is_deleted", value: false)
                .execute()
                .value

            print("[Sync] Remote todos found: \(remoteTodos.count)")

            let allLocal: [LocalTodo] = (try? modelContext.fetch(FetchDescriptor<LocalTodo>())) ?? []
            let localIDs = Set(allLocal.filter { $0.ownerID == ownerID }.map { $0.id })

            let dateFormatter = ISO8601DateFormatter()

            for remote in remoteTodos {
                if !localIDs.contains(remote.id) {
                    let local = LocalTodo(
                        id: remote.id,
                        ownerID: remote.owner_id,
                        title: remote.title,
                        todoDescription: remote.description,
                        isCompleted: remote.is_completed,
                        assignedDate: remote.assigned_date.flatMap { dateFormatter.date(from: $0) },
                        dueDate: remote.due_date.flatMap { dateFormatter.date(from: $0) },
                        priority: remote.priority,
                        sortOrder: remote.sort_order,
                        syncStatus: "synced"
                    )
                    modelContext.insert(local)
                }
            }
            try? modelContext.save()
        } catch {
            print("[Sync] Download todos error: \(error)")
        }
    }

    // MARK: - Upload Todo Lists

    private func uploadTodoLists(modelContext: ModelContext, ownerID: UUID, ownerStr: String) async {
        let allLists: [LocalTodoList] = (try? modelContext.fetch(FetchDescriptor<LocalTodoList>())) ?? []
        let pendingLists = allLists.filter { $0.ownerID == ownerID && $0.syncStatus == "pendingUpload" && $0.listType == "custom" }
        print("[Sync] Todo lists to upload: \(pendingLists.count)")

        for list in pendingLists {
            do {
                struct ListUpsert: Encodable {
                    let id: String
                    let owner_id: String
                    let title: String
                    let list_type: String
                    let is_shared: Bool
                    let is_deleted: Bool
                }

                try await supabase
                    .from("todo_lists")
                    .upsert(ListUpsert(
                        id: list.id.uuidString.lowercased(),
                        owner_id: ownerStr,
                        title: list.title,
                        list_type: list.listType,
                        is_shared: list.isPublic,
                        is_deleted: list.isDeleted
                    ))
                    .execute()

                list.syncStatus = "synced"
                try? modelContext.save()
            } catch {
                print("[Sync] Upload list error: \(error)")
            }
        }
    }
}
