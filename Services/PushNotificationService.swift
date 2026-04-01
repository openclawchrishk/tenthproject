import Foundation
import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

/// Local + remote notification routing (tabs / segments). Call `configure` from the main shell when the user session is active.
///
/// **Expected `userInfo` keys for rich pushes (server / marketing reference):**
/// - `type` or `notification_type`: `connection_request` | `desk_application` | `new_message` | `desk_invite` | `desk_milestone`
/// - `conversation_id` / `conversationId` — DM deep link
/// - For connection requests: include `sender_avatar_url`, `sender_name` (displayed in in-app notification list when mapped in payload `data`)
/// - For desk applications: `applicant_name`, `desk_name`
/// - For messages: `sender_name`, `preview` (message body preview)
/// - For desk milestones: `desk_id`, `member_count` (e.g. 5), celebration tone in `title`/`body`
final class PushNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationService()

    private weak var tabRouter: MainTabRouter?
    private weak var authRepository: AuthRepository?

    func configure(tabRouter: MainTabRouter, auth: AuthRepository) {
        self.tabRouter = tabRouter
        self.authRepository = auth
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        return granted
    }

    @MainActor
    func handleNotification(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String ?? userInfo["notification_type"] as? String else {
            return
        }
        guard let tabRouter else { return }
        HapticFeedback.medium()
        switch type {
        case "connection_request":
            withAnimation(DeskerAnimation.tabCrossFade) {
                tabRouter.selectedTab = 2
                tabRouter.messagesSegmentToSelect = 3
            }
        case "desk_application":
            withAnimation(DeskerAnimation.tabCrossFade) {
                tabRouter.selectedTab = 1
            }
        case "new_message":
            withAnimation(DeskerAnimation.tabCrossFade) {
                tabRouter.selectedTab = 2
                tabRouter.messagesSegmentToSelect = 0
            }
            if let conv = userInfo["conversation_id"] as? String ?? userInfo["conversationId"] as? String,
               let id = UUID(uuidString: conv) {
                tabRouter.pendingDMConversationId = id
            }
        case "desk_invite":
            withAnimation(DeskerAnimation.tabCrossFade) {
                tabRouter.selectedTab = 2
                tabRouter.messagesSegmentToSelect = 2
            }
        default:
            break
        }
        if let auth = authRepository {
            Task { await MainTabBadgeCoordinator.refreshAppIconBadge(auth: auth) }
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Foreground: banner + badge update; omit sound to reduce disruption and battery use.
        completionHandler([.banner, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            handleNotification(userInfo: userInfo)
            completionHandler()
        }
    }
}
