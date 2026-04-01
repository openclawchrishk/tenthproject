import Foundation
import Supabase

@MainActor
final class DeskChatRepository {
    private let client = SupabaseManager.shared.client

    func fetchDeskMessages(deskId: UUID) async throws -> [DeskMessage] {
        try await fetchMessages(deskId: deskId)
    }

    func fetchMessages(deskId: UUID) async throws -> [DeskMessage] {
        do {
            return try await client
                .from("desk_messages")
                .select()
                .eq("desk_id", value: deskId)
                .order("created_at", ascending: true)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskChatRepository.fetchMessages")
        }
    }

    func sendDeskMessage(deskId: UUID, senderId: UUID, content: String) async throws {
        try await sendMessage(deskId: deskId, senderId: senderId, content: content)
    }

    func sendMessage(deskId: UUID, senderId: UUID, content: String) async throws {
        struct Insert: Encodable {
            let id: UUID
            let desk_id: UUID
            let sender_id: UUID
            let content: String
        }
        let row = Insert(id: UUID(), desk_id: deskId, sender_id: senderId, content: content)
        do {
            try await client.from("desk_messages").insert(row).execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskChatRepository.sendMessage")
        }
    }

    func subscribeToDeskMessages(
        deskId: UUID,
        onInsert: @escaping @Sendable @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await client.realtimeV2.connect()
            let channel = client.realtimeV2.channel("desk-chat-\(deskId.uuidString)")
            let stream = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "desk_messages",
                filter: .eq("desk_id", value: deskId)
            )
            do {
                try await channel.subscribeWithError()
            } catch {
                repositoryLogger.error("DeskChat realtime subscribe failed desk=\(deskId.uuidString): \(error.localizedDescription, privacy: .public)")
                return
            }
            for await _ in stream {
                onInsert()
            }
        }
    }
}
