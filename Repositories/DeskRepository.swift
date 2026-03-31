import Foundation
import Supabase

@MainActor
final class DeskRepository {
    private let client = SupabaseManager.shared.client

    func fetchExploreDesks() async throws -> [Desk] {
        let rows: [Desk] = try await client
            .from("desks")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }

    func fetchDesk(id: UUID) async throws -> Desk {
        try await client
            .from("desks")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func fetchDesksForFounder(founderId: UUID) async throws -> [Desk] {
        try await client
            .from("desks")
            .select()
            .eq("founder_id", value: founderId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchApplicationsForDesk(deskId: UUID) async throws -> [DeskApplication] {
        try await client
            .from("desk_applications")
            .select()
            .eq("desk_id", value: deskId)
            .order("id", ascending: false)
            .execute()
            .value
    }

    /// All applications for desks owned by the founder (incoming queue).
    func fetchApplicationsForFounder(founderId: UUID) async throws -> [DeskApplicationItem] {
        let desks: [Desk] = try await fetchDesksForFounder(founderId: founderId)
        guard !desks.isEmpty else { return [] }
        let deskIds = desks.map(\.id)
        let deskMap = Dictionary(uniqueKeysWithValues: desks.map { ($0.id, $0.name) })

        let apps: [DeskApplication] = try await client
            .from("desk_applications")
            .select()
            .in("desk_id", values: deskIds)
            .order("id", ascending: false)
            .execute()
            .value

        var items: [DeskApplicationItem] = []
        for app in apps {
            let name: String
            do {
                let applicant: UserProfile = try await client
                    .from("users")
                    .select()
                    .eq("id", value: app.applicantId)
                    .single()
                    .execute()
                    .value
                name = applicant.displayName.isEmpty ? "使用者" : applicant.displayName
            } catch {
                name = "使用者"
            }
            let deskName = deskMap[app.deskId] ?? "專案"
            items.append(DeskApplicationItem(application: app, applicantDisplayName: name, deskName: deskName))
        }
        return items
    }

    func updateApplicationStatus(applicationId: UUID, status: ApplicationStatus) async throws {
        struct Patch: Encodable {
            let status: String
        }
        try await client
            .from("desk_applications")
            .update(Patch(status: status.databaseValue))
            .eq("id", value: applicationId)
            .execute()
    }

    /// Latest application from this user for the desk, if any.
    func fetchMyApplication(deskId: UUID, applicantId: UUID) async throws -> DeskApplication? {
        let rows: [DeskApplication] = try await client
            .from("desk_applications")
            .select()
            .eq("desk_id", value: deskId)
            .eq("applicant_id", value: applicantId)
            .order("id", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func fetchDeskMembers(deskId: UUID) async throws -> [DeskMember] {
        try await client
            .from("desk_members")
            .select()
            .eq("desk_id", value: deskId)
            .order("joined_at", ascending: true)
            .execute()
            .value
    }

    func isUserMemberOfDesk(deskId: UUID, userId: UUID) async throws -> Bool {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client
            .from("desk_members")
            .select("id")
            .eq("desk_id", value: deskId)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    /// Founder or listed desk member can access group chat.
    func canAccessDeskChat(deskId: UUID, userId: UUID, founderId: UUID) async throws -> Bool {
        if userId == founderId { return true }
        return try await isUserMemberOfDesk(deskId: deskId, userId: userId)
    }

    /// Founder removes another member (not themselves).
    func removeDeskMember(deskId: UUID, memberUserId: UUID, founderId: UUID) async throws {
        let desk: Desk = try await fetchDesk(id: deskId)
        guard desk.founderId == founderId else {
            struct Err: LocalizedError { var errorDescription: String? { "只有創辦人可以移除成員" } }
            throw Err()
        }
        guard memberUserId != founderId else {
            struct Err: LocalizedError { var errorDescription: String? { "無法移除創辦人" } }
            throw Err()
        }
        try await client
            .from("desk_members")
            .delete()
            .eq("desk_id", value: deskId)
            .eq("user_id", value: memberUserId)
            .execute()
    }

    func submitApplication(deskId: UUID, applicantId: UUID, selectedRole: String, statement: String) async throws {
        struct Insert: Encodable {
            let id: UUID
            let desk_id: UUID
            let applicant_id: UUID
            let selected_role: String
            let statement: String
            let status: String
        }
        let row = Insert(
            id: UUID(),
            desk_id: deskId,
            applicant_id: applicantId,
            selected_role: selectedRole,
            statement: statement,
            status: ApplicationStatus.pending.databaseValue
        )
        try await client.from("desk_applications").insert(row).execute()
    }
}
