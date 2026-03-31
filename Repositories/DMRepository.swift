import Foundation
import Supabase

@MainActor
final class DMRepository {
    private let client = SupabaseManager.shared.client
    private let connections = ConnectionRepository()

    func fetchConversations(for userId: UUID) async throws -> [Conversation] {
        let uid = userId.uuidString
        let orFilter = "participant_a_id.eq.\(uid),participant_b_id.eq.\(uid)"
        do {
            return try await client
                .from("conversations")
                .select()
                .or(orFilter)
                .order("last_message_at", ascending: false, nullsFirst: false)
                .execute()
                .value
        } catch {
            return try await fetchConversationsLegacy(for: userId)
        }
    }

    private func fetchConversationsLegacy(for userId: UUID) async throws -> [Conversation] {
        let a: [Conversation] = try await client
            .from("conversations")
            .select()
            .eq("participant_a_id", value: userId)
            .order("updated_at", ascending: false, nullsFirst: false)
            .execute()
            .value
        let b: [Conversation] = try await client
            .from("conversations")
            .select()
            .eq("participant_b_id", value: userId)
            .order("updated_at", ascending: false, nullsFirst: false)
            .execute()
            .value
        var byId: [UUID: Conversation] = [:]
        for c in a + b { byId[c.id] = c }
        return byId.values.sorted { $0.sortDate > $1.sortDate }
    }

    func fetchDirectMessages(conversationId: UUID) async throws -> [DirectMessage] {
        try await client
            .from("direct_messages")
            .select()
            .eq("conversation_id", value: conversationId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    /// Opens or creates a DM conversation if the two users are connected.
    func getOrCreateConversation(currentUserId: UUID, peerId: UUID) async throws -> Conversation {
        guard try await connections.areConnected(currentUserId, peerId) else {
            struct Err: LocalizedError { var errorDescription: String? { "只能與已連接的用戶私訊" } }
            throw Err()
        }
        let (pa, pb) = ConnectionPair.normalizedUserIds(currentUserId, peerId)
        let existing: [Conversation] = try await client
            .from("conversations")
            .select()
            .eq("participant_a_id", value: pa)
            .eq("participant_b_id", value: pb)
            .limit(1)
            .execute()
            .value
        if let c = existing.first { return c }

        struct Insert: Encodable {
            let id: UUID
            let participant_a_id: UUID
            let participant_b_id: UUID
        }
        let id = UUID()
        let row = Insert(id: id, participant_a_id: pa, participant_b_id: pb)
        try await client.from("conversations").insert(row).execute()
        return try await client
            .from("conversations")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func sendDirectMessage(conversationId: UUID, senderId: UUID, content: String) async throws {
        struct Insert: Encodable {
            let id: UUID
            let conversation_id: UUID
            let sender_id: UUID
            let content: String
        }
        let row = Insert(
            id: UUID(),
            conversation_id: conversationId,
            sender_id: senderId,
            content: content
        )
        try await client.from("direct_messages").insert(row).execute()

        struct ConvPatch: Encodable {
            let last_message_at: String
        }
        let iso = ISO8601DateFormatter().string(from: Date())
        try await client
            .from("conversations")
            .update(ConvPatch(last_message_at: iso))
            .eq("id", value: conversationId)
            .execute()
    }

    func fetchRecentDMPreviews(for userId: UUID) async throws -> [MessageListItem] {
        let conversations = try await fetchConversations(for: userId)
        var items: [MessageListItem] = []
        for conv in conversations {
            let messages: [DirectMessage] = try await client
                .from("direct_messages")
                .select()
                .eq("conversation_id", value: conv.id)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            guard let last = messages.first else { continue }
            let peerId = conv.otherUser(than: userId)
            let peerName: String
            do {
                let peer: UserProfile = try await client
                    .from("users")
                    .select()
                    .eq("id", value: peerId)
                    .single()
                    .execute()
                    .value
                peerName = peer.displayName.isEmpty ? "聯絡人" : peer.displayName
            } catch {
                peerName = "聯絡人"
            }
            items.append(MessageListItem(message: last, peerDisplayName: peerName, conversation: conv))
        }
        items.sort { ($0.message.createdAt ?? .distantPast) > ($1.message.createdAt ?? .distantPast) }
        return items
    }

    // MARK: - Realtime (Supabase Realtime v2)

    /// Subscribe to new rows in `direct_messages` for this conversation. Call `postgres` hooks before `subscribe`.
    func subscribeToDirectMessages(
        conversationId: UUID,
        onInsert: @escaping @Sendable @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            await client.realtimeV2.connect()
            let channel = client.realtimeV2.channel("dm-\(conversationId.uuidString)")
            let stream = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "direct_messages",
                filter: .eq("conversation_id", value: conversationId)
            )
            do {
                try await channel.subscribeWithError()
            } catch {
                return
            }
            for await _ in stream {
                onInsert()
            }
        }
    }
}
