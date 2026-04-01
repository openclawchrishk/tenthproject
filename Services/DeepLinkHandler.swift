import Foundation
import SwiftUI

/// Parses `desker://` custom URLs and `https://desker.hk/...` universal links, then updates `MainTabRouter`.
@MainActor
final class DeepLinkHandler: ObservableObject {
    func handle(_ url: URL, tabRouter: MainTabRouter) {
        Self.apply(url, tabRouter: tabRouter)
    }

    static func apply(_ url: URL, tabRouter: MainTabRouter) {
        guard let parsed = ParsedDeepLink.parse(url) else {
            return
        }
        HapticFeedback.selection()
        switch parsed {
        case .desk(let id):
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                tabRouter.selectedTab = 1
                tabRouter.pendingOpenDeskId = id
            }
        case .user(let id):
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                tabRouter.selectedTab = 0
                tabRouter.pendingExploreProfileUserId = id
                tabRouter.pendingExploreUsername = nil
            }
        case .username(let name):
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                tabRouter.selectedTab = 0
                tabRouter.pendingExploreUsername = name
                tabRouter.pendingExploreProfileUserId = nil
            }
        case .conversation(let id):
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                tabRouter.selectedTab = 2
                tabRouter.messagesSegmentToSelect = 0
                tabRouter.pendingDMConversationId = id
            }
        }
    }
}

// MARK: - Parsing

private enum ParsedDeepLink {
    case desk(UUID)
    case user(UUID)
    case username(String)
    case conversation(UUID)
}

private extension ParsedDeepLink {
    static func parse(_ url: URL) -> ParsedDeepLink? {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let segments = path.split(separator: "/").map(String.init)

        let isHTTPS = scheme == "https" && (host == "desker.hk" || host == "www.desker.hk")
        let isCustom = scheme == "desker"
        guard isHTTPS || isCustom else { return nil }

        if isCustom {
            return parseCustomScheme(host: host, pathSegments: segments)
        }
        return parseHTTPSHostPath(segments: segments)
    }

    /// `desker://desk/{id}`, `desker://user/{id}`, `desker://message/{conversation_id}`
    private static func parseCustomScheme(host: String, pathSegments: [String]) -> ParsedDeepLink? {
        switch host {
        case "desk":
            guard let raw = pathSegments.first, let id = uuidFromDeepLinkSegment(raw) else { return nil }
            return .desk(id)
        case "user":
            guard let raw = pathSegments.first else { return nil }
            if let id = uuidFromDeepLinkSegment(raw) { return .user(id) }
            let name = raw.removingPercentEncoding ?? raw
            guard !name.isEmpty else { return nil }
            return .username(name)
        case "message":
            guard let raw = pathSegments.first, let id = uuidFromDeepLinkSegment(raw) else { return nil }
            return .conversation(id)
        default:
            return nil
        }
    }

    /// `https://desker.hk/desk/{id}`, `https://desker.hk/u/{username_or_uuid}`
    private static func parseHTTPSHostPath(segments: [String]) -> ParsedDeepLink? {
        guard let first = segments.first else { return nil }
        switch first {
        case "desk":
            guard segments.count >= 2, let id = uuidFromDeepLinkSegment(segments[1]) else { return nil }
            return .desk(id)
        case "u":
            guard segments.count >= 2 else { return nil }
            let raw = segments[1].removingPercentEncoding ?? segments[1]
            if let id = uuidFromDeepLinkSegment(raw) { return .user(id) }
            guard !raw.isEmpty else { return nil }
            return .username(raw)
        case "message", "dm", "messages":
            guard segments.count >= 2, let id = uuidFromDeepLinkSegment(segments[1]) else { return nil }
            return .conversation(id)
        default:
            return nil
        }
    }

    private static func uuidFromDeepLinkSegment(_ s: String) -> UUID? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return UUID(uuidString: t)
    }
}
