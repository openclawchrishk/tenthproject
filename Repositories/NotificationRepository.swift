import Foundation
import os
import Supabase

@MainActor
final class NotificationRepository {
    private let client = SupabaseManager.shared.client

    func fetchNotifications(for userId: UUID) async throws -> [AppNotification] {
        try await fetchNotifications(userId: userId)
    }

    func fetchNotifications(userId: UUID) async throws -> [AppNotification] {
        do {
            return try await client
                .from("notifications")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "NotificationRepository.fetchNotifications")
        }
    }

    func markRead(notificationId: UUID) async throws {
        try await markAsRead(notificationId: notificationId)
    }

    func markAsRead(notificationId: UUID) async throws {
        struct Patch: Encodable {
            let read: Bool
        }
        do {
            try await client
                .from("notifications")
                .update(Patch(read: true))
                .eq("id", value: notificationId)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "NotificationRepository.markAsRead")
        }
    }

    func markAllRead(for userId: UUID) async throws {
        try await markAllAsRead(userId: userId)
    }

    func markAllAsRead(userId: UUID) async throws {
        struct Patch: Encodable {
            let read: Bool
        }
        do {
            try await client
                .from("notifications")
                .update(Patch(read: true))
                .eq("user_id", value: userId)
                .eq("read", value: false)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "NotificationRepository.markAllAsRead")
        }
    }

    func deleteNotification(id: UUID) async throws {
        do {
            try await client
                .from("notifications")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "NotificationRepository.deleteNotification")
        }
    }

    /// Unread total via `HEAD` + `Prefer: count=exact` (no row payload).
    func unreadCount(userId: UUID) async throws -> Int {
        do {
            let response = try await client
                .from("notifications")
                .select("*", head: true, count: .exact)
                .eq("user_id", value: userId)
                .eq("read", value: false)
                .execute()
            return response.count ?? 0
        } catch {
            throw RepositoryErrorMapping.map(error, context: "NotificationRepository.unreadCount")
        }
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
                repositoryLogger.error("Notification realtime subscribe failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            for await _ in inserts {
                onChange()
            }
        }
    }
}
