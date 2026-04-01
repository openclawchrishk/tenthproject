import Foundation

enum PublicLinks {
    static let baseURLString = "https://desker.hk"

    static let termsURL = URL(string: "\(baseURLString)/terms")!
    static let privacyURL = URL(string: "\(baseURLString)/privacy")!

    static func deskURL(deskId: UUID) -> URL {
        URL(string: "\(baseURLString)/desk/\(deskId.uuidString.lowercased())")!
    }

    static func profileURL(username: String) -> URL {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: "\(baseURLString)/u/\(u.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? u)")!
    }

    /// Public profile URL for IG cards and sharing (username path, or UUID fallback).
    static func profilePublicURL(for user: UserProfile) -> URL {
        let handle = user.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !handle.isEmpty {
            return profileURL(username: handle)
        }
        return URL(string: "\(baseURLString)/u/\(user.id.uuidString.lowercased())")!
    }
}
