import Foundation

/// Queues DM sends that failed due to network; flushed when connectivity returns.
@MainActor
final class OfflineDirectMessageQueue {
    static let shared = OfflineDirectMessageQueue()

    private let defaults = UserDefaults.standard
    private let key = "desker.offline.pendingDMs.v1"

    struct Item: Codable, Identifiable {
        let id: UUID
        let conversationId: UUID
        let senderId: UUID
        let content: String
    }

    private init() {}

    func enqueue(conversationId: UUID, senderId: UUID, content: String) {
        var items = load()
        items.append(Item(id: UUID(), conversationId: conversationId, senderId: senderId, content: content))
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }

    func loadPending() -> [Item] { load() }

    private func load() -> [Item] {
        guard let data = defaults.data(forKey: key),
              let items = try? JSONDecoder().decode([Item].self, from: data)
        else { return [] }
        return items
    }

    private func save(_ items: [Item]) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }

    /// Sends queued messages in order; keeps failed items for a later retry.
    func flush(using dm: DMRepository) async {
        var items = load()
        guard !items.isEmpty else { return }
        var remaining: [Item] = []
        for item in items {
            do {
                try await dm.sendMessage(
                    conversationId: item.conversationId,
                    senderId: item.senderId,
                    content: item.content
                )
            } catch {
                remaining.append(item)
            }
        }
        save(remaining)
    }
}

enum NetworkFailureDetection {
    static func isConnectivityFailure(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost,
                 NSURLErrorTimedOut, NSURLErrorDataNotAllowed, NSURLErrorInternationalRoamingOff,
                 NSURLErrorCallIsActive, NSURLErrorDNSLookupFailed:
                return true
            default:
                break
            }
        }
        if let u = error as? URLError {
            switch u.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .timedOut, .dataNotAllowed,
                 .dnsLookupFailed, .internationalRoamingOff, .callIsActive:
                return true
            default:
                break
            }
        }
        return false
    }
}
