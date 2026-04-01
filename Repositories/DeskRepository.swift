import Foundation
import Supabase

@MainActor
final class DeskRepository {
    private let client = SupabaseManager.shared.client

    /// Explorer feed: newest first. Prefer `fetchDesksForExplorer` for server-side filters.
    func fetchExploreDesks() async throws -> [Desk] {
        try await fetchDesksForExplorer()
    }

    /// Lists desks with optional `status` and `industry` filters (maps to `desks.status` / `desks.industries`).
    func fetchDesksForExplorer(
        status: DeskStatus? = nil,
        industry: String? = nil,
        limit: Int = 200
    ) async throws -> [Desk] {
        do {
            var q = client
                .from("desks")
                .select()
            if let status {
                q = q.eq("status", value: status.rawValue)
            }
            if let industry, !industry.trimmingCharacters(in: .whitespaces).isEmpty {
                let tag = industry.trimmingCharacters(in: .whitespaces)
                q = q.contains("industries", value: [tag])
            }
            let rows: [Desk] = try await q
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.fetchDesksForExplorer")
        }
    }

    func fetchDesk(id: UUID) async throws -> Desk {
        do {
            return try await client
                .from("desks")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.fetchDesk id=\(id)")
        }
    }

    func fetchDesksForFounder(founderId: UUID) async throws -> [Desk] {
        do {
            return try await client
                .from("desks")
                .select()
                .eq("founder_id", value: founderId)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.fetchDesksForFounder")
        }
    }

    /// Alias for audit/API consistency (`founderId` == `userId` for founders).
    func fetchDesksForFounder(userId: UUID) async throws -> [Desk] {
        try await fetchDesksForFounder(founderId: userId)
    }

    func updateDesk(id: UUID, patch: DeskPartialPatch) async throws {
        do {
            try await client
                .from("desks")
                .update(patch)
                .eq("id", value: id)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.updateDesk id=\(id)")
        }
    }

    func deleteDesk(id: UUID) async throws {
        do {
            try await client
                .from("desks")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.deleteDesk id=\(id)")
        }
    }

    func fetchApplicationsForDesk(deskId: UUID) async throws -> [DeskApplication] {
        do {
            return try await client
                .from("desk_applications")
                .select()
                .eq("desk_id", value: deskId)
                .order("id", ascending: false)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.fetchApplicationsForDesk")
        }
    }

    /// All applications for desks owned by the founder (incoming queue).
    func fetchApplicationsForFounder(founderId: UUID) async throws -> [DeskApplicationItem] {
        let desks: [Desk]
        do {
            desks = try await fetchDesksForFounder(founderId: founderId)
        } catch {
            throw error
        }
        guard !desks.isEmpty else { return [] }
        let deskIds = desks.map(\.id)
        let deskMap = Dictionary(uniqueKeysWithValues: desks.map { ($0.id, $0.name) })

        let apps: [DeskApplication]
        do {
            apps = try await client
                .from("desk_applications")
                .select()
                .in("desk_id", values: deskIds)
                .order("id", ascending: false)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.fetchApplicationsForFounder apps")
        }

        let applicantIds = Array(Set(apps.map(\.applicantId)))
        var userById: [UUID: UserProfile] = [:]
        if !applicantIds.isEmpty {
            let users: [UserProfile] = try await client
                .from("users")
                .select()
                .in("id", values: applicantIds)
                .execute()
                .value
            userById = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        }

        var items: [DeskApplicationItem] = []
        for app in apps {
            let name: String
            var avatar: String?
            var skills: [String] = []
            if let applicant = userById[app.applicantId] {
                name = applicant.displayName.isEmpty ? "使用者" : applicant.displayName
                avatar = applicant.avatarUrl
                skills = applicant.skills
            } else {
                name = "使用者"
                avatar = nil
            }
            let deskName = deskMap[app.deskId] ?? "專案"
            items.append(
                DeskApplicationItem(
                    application: app,
                    applicantDisplayName: name,
                    deskName: deskName,
                    applicantAvatarUrl: avatar,
                    applicantSkills: skills
                )
            )
        }
        return items
    }

    func updateApplicationStatus(applicationId: UUID, status: ApplicationStatus) async throws {
        struct Patch: Encodable {
            let status: String
        }
        do {
            try await client
                .from("desk_applications")
                .update(Patch(status: status.databaseValue))
                .eq("id", value: applicationId)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.updateApplicationStatus")
        }
    }

    /// Approves a pending application and adds the applicant to `desk_members` (idempotent if already a member).
    func approveApplication(applicationId: UUID, actingFounderId: UUID) async throws {
        let app: DeskApplication
        do {
            app = try await client
                .from("desk_applications")
                .select()
                .eq("id", value: applicationId)
                .single()
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.approveApplication load app")
        }

        let desk: Desk
        do {
            desk = try await fetchDesk(id: app.deskId)
        } catch {
            throw error
        }
        guard desk.founderId == actingFounderId else {
            throw RepositoryError.serverError("只有創辦人可以批准申請")
        }
        guard app.status == .pending else { return }

        try await updateApplicationStatus(applicationId: applicationId, status: .accepted)

        if try await !isUserMemberOfDesk(deskId: app.deskId, userId: app.applicantId) {
            struct MemberInsert: Encodable {
                let id: UUID
                let desk_id: UUID
                let user_id: UUID
                let status: String
            }
            let row = MemberInsert(
                id: UUID(),
                desk_id: app.deskId,
                user_id: app.applicantId,
                status: "active"
            )
            do {
                try await client.from("desk_members").insert(row).execute()
            } catch {
                throw RepositoryErrorMapping.map(error, context: "DeskRepository.approveApplication insert member")
            }
        }
    }

    /// Declines a pending application (founder only).
    func rejectApplication(applicationId: UUID, actingFounderId: UUID) async throws {
        let app: DeskApplication
        do {
            app = try await client
                .from("desk_applications")
                .select()
                .eq("id", value: applicationId)
                .single()
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.rejectApplication load app")
        }
        let desk = try await fetchDesk(id: app.deskId)
        guard desk.founderId == actingFounderId else {
            throw RepositoryError.serverError("只有創辦人可以拒絕申請")
        }
        guard app.status == .pending else { return }
        try await updateApplicationStatus(applicationId: applicationId, status: .declined)
    }

    /// Latest application from this user for the desk, if any.
    func fetchMyApplication(deskId: UUID, applicantId: UUID) async throws -> DeskApplication? {
        do {
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
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.fetchMyApplication")
        }
    }

    func fetchDeskMembers(deskId: UUID) async throws -> [DeskMember] {
        do {
            return try await client
                .from("desk_members")
                .select()
                .eq("desk_id", value: deskId)
                .eq("status", value: "active")
                .order("joined_at", ascending: true)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.fetchDeskMembers")
        }
    }

    func isUserMemberOfDesk(deskId: UUID, userId: UUID) async throws -> Bool {
        struct Row: Decodable { let id: UUID }
        do {
            let rows: [Row] = try await client
                .from("desk_members")
                .select("id")
                .eq("desk_id", value: deskId)
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            return !rows.isEmpty
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.isUserMemberOfDesk")
        }
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
            throw RepositoryError.serverError("只有創辦人可以移除成員")
        }
        guard memberUserId != founderId else {
            throw RepositoryError.serverError("無法移除創辦人")
        }
        do {
            try await client
                .from("desk_members")
                .delete()
                .eq("desk_id", value: deskId)
                .eq("user_id", value: memberUserId)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.removeDeskMember")
        }
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
        do {
            try await client.from("desk_applications").insert(row).execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.submitApplication")
        }
    }

    /// Create a new Desk, `desk_roles` rows, and founder membership (`SUPABASE_SCHEMA.sql`).
    func createDesk(
        founderId: UUID,
        name: String,
        pitch: String,
        industries: [String],
        region: String,
        recruitingRoles: [DeskRole],
        description: String?,
        fundingNeeds: String?,
        expectations: String?
    ) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ProfileFieldValidation.isValidDeskName(trimmedName) else {
            throw RepositoryError.serverError("Desk 名稱須為 1–\(ProfileFieldValidation.deskNameMaxLength) 字")
        }
        let memberLimit = recruitingRoles.reduce(1) { $0 + $1.count }

        struct DeskInsert: Encodable {
            let id: UUID
            let founder_id: UUID
            let name: String
            let pitch: String
            let industries: [String]
            let region: String
            let languages: [String]
            let description: String?
            let funding_needs: String?
            let expectations: String?
            let status: String
            let member_limit: Int
        }

        let deskId = UUID()
        let deskRow = DeskInsert(
            id: deskId,
            founder_id: founderId,
            name: trimmedName,
            pitch: pitch.trimmingCharacters(in: .whitespacesAndNewlines),
            industries: industries,
            region: region,
            languages: [],
            description: description,
            funding_needs: fundingNeeds,
            expectations: expectations,
            status: DeskStatus.recruiting.rawValue,
            member_limit: memberLimit
        )

        do {
            try await client.from("desks").insert(deskRow).execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.createDesk insert desk")
        }

        for role in recruitingRoles {
            struct RoleInsert: Encodable {
                let id: UUID
                let desk_id: UUID
                let title: String
                let count: Int
                let skills_description: String?
            }
            let ri = RoleInsert(
                id: role.id,
                desk_id: deskId,
                title: role.title,
                count: role.count,
                skills_description: role.skillDescription
            )
            do {
                try await client.from("desk_roles").insert(ri).execute()
            } catch {
                throw RepositoryErrorMapping.map(error, context: "DeskRepository.createDesk insert role")
            }
        }

        struct MemberInsert: Encodable {
            let id: UUID
            let desk_id: UUID
            let user_id: UUID
            let status: String
        }
        let memberRow = MemberInsert(
            id: UUID(),
            desk_id: deskId,
            user_id: founderId,
            status: "active"
        )
        do {
            try await client.from("desk_members").insert(memberRow).execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "DeskRepository.createDesk insert founder member")
        }
    }
}
