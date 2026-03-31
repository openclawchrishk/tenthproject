import Foundation

enum PublicLinks {
    static let baseURLString = "https://desker.hk"

    static func deskURL(deskId: UUID) -> URL {
        URL(string: "\(baseURLString)/desk/\(deskId.uuidString.lowercased())")!
    }

    static func profileURL(username: String) -> URL {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: "\(baseURLString)/u/\(u.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? u)")!
    }
}
