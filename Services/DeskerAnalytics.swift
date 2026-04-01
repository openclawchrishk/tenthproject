import Foundation
import os.log

/// Lightweight analytics preparation: single funnel + user snapshot for future SDK wiring.
enum DeskerAnalytics {
    private static let log = Logger(subsystem: "hk.desker.app", category: "analytics")

    enum Event: String {
        case userSignUp = "user_sign_up"
        case userCompleteOnboarding = "user_complete_onboarding"
        case userCreateDesk = "user_create_desk"
        case userApplyToDesk = "user_apply_to_desk"
        case userMakeConnection = "user_make_connection"
        case userSendMessage = "user_send_message"
        case userShareProfile = "user_share_profile"
        case userExportIGCard = "user_export_ig_card"
    }

    static func track(_ event: Event, parameters: [String: String] = [:]) {
        if parameters.isEmpty {
            log.info("event=\(event.rawValue, privacy: .public)")
        } else {
            let joined = parameters.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ",")
            log.info("event=\(event.rawValue, privacy: .public) \(joined, privacy: .public)")
        }
    }

    /// Call when profile or stats change to mirror user properties for future backends.
    static func updateUserSnapshot(
        userId: UUID,
        level: Int,
        completenessPercent: Int,
        connectionCount: Int,
        deskCount: Int
    ) {
        log.info(
            "user_snapshot id=\(userId.uuidString, privacy: .public) level=\(level) completeness=\(completenessPercent) connections=\(connectionCount) desks=\(deskCount)"
        )
    }
}
