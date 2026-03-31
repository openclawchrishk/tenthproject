import Foundation
import Supabase

@MainActor
final class MessageRepository {
    private let client = SupabaseManager.shared.client

    func fetchConversations(for userId: UUID) async throws -> [Conversation] {
        let a: [Conversation] = try await client
            .from("conversations")
            .select()
            .eq("participant_a", value: userId)
            .order("updated_at", ascending: false, nullsFirst: false)
            .execute()
            .value
        let b: [Conversation] = try await client
            .from("conversations")
            .select()
            .eq("participant_b", value: userId)
            .order("updated_at", ascending: false, nullsFirst: false)
            .execute()
            .value
        var byId: [UUID: Conversation] = [:]
        for c in a + b { byId[c.id] = c }
        return byId.values.sorted {
            ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
        }
    }

    func fetchMessages(conversationId: UUID) async throws -> [Message] {
        try await client
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    func fetchRecentMessagesPreview(for userId: UUID) async throws -> [MessageListItem] {
        let conversations = try await fetchConversations(for: userId)
        var items: [MessageListItem] = []
        for conv in conversations {
            let messages: [Message] = try await client
                .from("messages")
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
}
