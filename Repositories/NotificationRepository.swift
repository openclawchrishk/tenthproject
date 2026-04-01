import Foundation
import Supabase

@MainActor
final class NotificationRepository {
    private let client = SupabaseManager.shared.client

    func fetchNotifications(for userId: UUID) async throws -> [AppNotification] {
        try await fetchNotifications(userId: userId)
    }

    func fetchNotifications(userId: UUID) async throws -> [AppNotification] {
        try await client
            .from("notifications")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func markRead(notificationId: UUID) async throws {
        try await markAsRead(notificationId: notificationId)
    }

    func markAsRead(notificationId: UUID) async throws {
        struct Patch: Encodable {
            let read: Bool
        }
        try await client
            .from("notifications")
            .update(Patch(read: true))
            .eq("id", value: notificationId)
            .execute()
    }

    func markAllRead(for userId: UUID) async throws {
        try await markAllAsRead(userId: userId)
    }

    func markAllAsRead(userId: UUID) async throws {
        struct Patch: Encodable {
            let read: Bool
        }
        try await client
            .from("notifications")
            .update(Patch(read: true))
            .eq("user_id", value: userId)
            .eq("read", value: false)
            .execute()
    }

    func subscribeToNotifications(
        userId: UUID,
        onChange: @escaping @Sendable @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            await client.realtimeV2.connect()
            let channel = client.realtimeV2.channel("notif-\(userId.uuidString)")
            let inserts = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "notifications",
                filter: .eq("user_id", value: userId)
            )
            do {
                try await channel.subscribeWithError()
            } catch {
                return
            }
            for await _ in inserts {
                onChange()
            }
        }
    }
}
