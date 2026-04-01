import Foundation
import Supabase

@MainActor
final class ReferralRepository {
    private let client = SupabaseManager.shared.client

    func fetchReferrals(for referrerId: UUID) async throws -> [Referral] {
        do {
            return try await client
                .from("referrals")
                .select()
                .eq("referrer_id", value: referrerId)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ReferralRepository.fetchReferrals")
        }
    }

    func fetchReferralCount(for referrerId: UUID) async throws -> Int {
        let rows: [Referral] = try await fetchReferrals(for: referrerId)
        return rows.count
    }
}
