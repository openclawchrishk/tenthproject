import Foundation
import SwiftUI

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published private(set) var desks: [Desk] = []
    @Published private(set) var currentDesk: Desk?
    /// Resolved founder for `currentDesk` (Explore card).
    @Published private(set) var currentFounder: UserProfile?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    /// Changing this forces card content to refresh (再看一次).
    @Published private(set) var refreshGeneration = UUID()

    @Published var searchText = ""
    /// `nil` or `"全部"` means no industry/status filter; otherwise industry tag or `"招募中"`.
    @Published var selectedFilterChip: String = "全部"

    private let repository = DeskRepository()
    private let users = UserRepository()

    /// Chips shown above the list (探索篩選).
    static let filterChipOptions: [String] = [
        "全部", "招募中", "金融科技", "教育", "醫療健康", "電商", "SaaS", "AI / 數據", "區塊鏈", "消費品牌",
    ]

    var filteredDesks: [Desk] {
        var list = desks
        let chip = selectedFilterChip.trimmingCharacters(in: .whitespacesAndNewlines)
        if chip == "招募中" {
            list = list.filter { $0.status == .recruiting }
        } else if !chip.isEmpty, chip != "全部" {
            list = list.filter { $0.industryTags.contains(chip) }
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            list = list.filter { desk in
                desk.name.localizedCaseInsensitiveContains(q)
                    || desk.pitch.localizedCaseInsensitiveContains(q)
                    || desk.industryTags.contains { $0.localizedCaseInsensitiveContains(q) }
            }
        }
        return list
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let list = try await repository.fetchExploreDesks()
            desks = list
            pickCurrentDesk(excluding: nil)
            await refreshFounderForCurrentDesk()
        } catch {
            errorMessage = error.localizedDescription
            desks = []
            currentDesk = nil
            currentFounder = nil
        }
    }

    /// Call when search or filter changes to keep `currentDesk` inside the filtered set.
    func applyFiltersReselectingIfNeeded() {
        let pool = filteredDesks
        guard !pool.isEmpty else {
            currentDesk = nil
            currentFounder = nil
            return
        }
        if let cur = currentDesk, pool.contains(where: { $0.id == cur.id }) {
            return
        }
        currentDesk = pool.randomElement()
        Task { await refreshFounderForCurrentDesk() }
    }

    /// Reloads from the server and shows another card when possible so **再看一次** always refreshes content.
    func viewAgain() async {
        refreshGeneration = UUID()
        let previousId = currentDesk?.id
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let list = try await repository.fetchExploreDesks()
            desks = list
            let pool = filteredDesks
            if pool.isEmpty {
                currentDesk = nil
                currentFounder = nil
                return
            }
            if pool.count > 1, let prev = previousId {
                let others = pool.filter { $0.id != prev }
                currentDesk = others.randomElement() ?? pool.randomElement()
            } else {
                // Single item: still re-assign so SwiftUI refreshes bound subviews.
                currentDesk = pool.first
            }
            await refreshFounderForCurrentDesk()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pickCurrentDesk(excluding: UUID?) {
        let pool = filteredDesks
        guard !pool.isEmpty else {
            currentDesk = nil
            currentFounder = nil
            return
        }
        if let ex = excluding, pool.count > 1 {
            let others = pool.filter { $0.id != ex }
            currentDesk = others.randomElement() ?? pool.randomElement()
        } else {
            currentDesk = pool.randomElement()
        }
    }

    private func refreshFounderForCurrentDesk() async {
        guard let d = currentDesk else {
            currentFounder = nil
            return
        }
        currentFounder = try? await users.fetchUser(id: d.founderId)
    }
}
