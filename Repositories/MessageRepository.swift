import Foundation
import Supabase

/// Legacy facade — use `DMRepository` for direct messages (`direct_messages` table).
@MainActor
final class MessageRepository {
    private let dm = DMRepository()

    func fetchConversations(for userId: UUID) async throws -> [Conversation] {
        try await dm.fetchConversations(for: userId)
    }

    func fetchMessages(conversationId: UUID) async throws -> [DirectMessage] {
        try await dm.fetchDirectMessages(conversationId: conversationId)
    }

    func fetchRecentMessagesPreview(for userId: UUID) async throws -> [MessageListItem] {
        try await dm.fetchRecentDMPreviews(for: userId)
    }
}
