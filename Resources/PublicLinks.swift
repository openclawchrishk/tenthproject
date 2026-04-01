import Foundation

enum PublicLinks {
    static let baseURLString = "https://desker.hk"

    private static func requireURL(_ string: String) -> URL {
        guard let u = URL(string: string) else {
            return URL(string: baseURLString) ?? URL(fileURLWithPath: "/")
        }
        return u
    }

    static let termsURL = requireURL("\(baseURLString)/terms")
    static let privacyURL = requireURL("\(baseURLString)/privacy")

    static func deskURL(deskId: UUID) -> URL {
        requireURL("\(baseURLString)/desk/\(deskId.uuidString.lowercased())")
    }

    static func profileURL(username: String) -> URL {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = u.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? u
        return requireURL("\(baseURLString)/u/\(path)")
    }

    /// Public profile URL for IG cards and sharing (username path, or UUID fallback).
    static func profilePublicURL(for user: UserProfile) -> URL {
        let handle = user.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !handle.isEmpty {
            return profileURL(username: handle)
        }
        return requireURL("\(baseURLString)/u/\(user.id.uuidString.lowercased())")
    }

    static func inviteURL(invitationCode: String) -> URL {
        let code = invitationCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? invitationCode
        return requireURL("\(baseURLString)/join?code=\(code)")
    }
}
