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
}
