import Foundation
import SwiftUI
import os

/// CTA state for sending a **connection** invite (PRD §8 — 連接).
enum ExploreInviteCTAState: Equatable {
    case loading
    case needsLogin
    case selfProfile
    case connected
    case pendingConnectionInvite
    case ready
    case error(String)
}

private let exploreVMLog = Logger(subsystem: "hk.desker", category: "Explore")

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published private(set) var desks: [Desk] = []
    @Published private(set) var currentDesk: Desk?
    /// Resolved founder for `currentDesk` (Explore card).
    @Published private(set) var currentFounder: UserProfile?
    /// Desks owned by the current user (used elsewhere; connection flow does not require a Desk).
    @Published private(set) var myDesks: [Desk] = []
    @Published private(set) var inviteCTAState: ExploreInviteCTAState = .loading
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    /// Changing this forces card content to refresh (再看一次).
    @Published private(set) var refreshGeneration = UUID()

    @Published var searchText = ""
    /// `nil` or `"全部"` means no industry/status filter; otherwise industry tag or `"招募中"`.
    @Published var selectedFilterChip: String = "全部"

    private let repository = DeskRepository()
    private let users = UserRepository()

    /// Cancels stale `load()` / `viewAgain()` results when a newer request starts.
    private var loadRequestID = UUID()
    /// Cancels stale founder fetches when desk or filters change quickly.
    private var founderRequestID = UUID()

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
        let req = UUID()
        loadRequestID = req
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let list = try await repository.fetchExploreDesks()
            guard req == loadRequestID else { return }
            desks = list
            CriticalDataCache.saveExploreDesks(list)
            pickCurrentDesk(excluding: nil)
            await refreshFounderForCurrentDesk()
        } catch {
            exploreVMLog.error("load failed: \(error.localizedDescription, privacy: .public)")
            guard req == loadRequestID else { return }
            if desks.isEmpty, let cached = CriticalDataCache.loadExploreDesks(), !cached.isEmpty {
                desks = cached
                pickCurrentDesk(excluding: nil)
                await refreshFounderForCurrentDesk()
                errorMessage = "無網絡或伺服器暫時不可用 — 顯示上次快取的列表"
            } else {
                errorMessage = Self.userFacingMessage(for: error)
                if desks.isEmpty {
                    currentDesk = nil
                    currentFounder = nil
                }
            }
        }
    }

    /// Loads desks created by the current user (for 「發送邀請」 → `invites` table).
    func loadMyDesks(founderId: UUID?) async {
        guard let founderId else {
            myDesks = []
            return
        }
        do {
            myDesks = try await repository.fetchDesksForFounder(founderId: founderId)
        } catch {
            myDesks = []
        }
    }

    func refreshInviteCTAState(
        currentUserId: UUID?,
        connectionsRepo: ConnectionRepository
    ) async {
        guard let uid = currentUserId else {
            inviteCTAState = .needsLogin
            return
        }
        guard let founder = currentFounder else {
            inviteCTAState = .loading
            return
        }
        let founderId = founder.id
        if founderId == uid {
            inviteCTAState = .selfProfile
            return
        }
        do {
            if try await connectionsRepo.areConnected(uid, founderId) {
                inviteCTAState = .connected
                return
            }
            if try await connectionsRepo.outgoingPendingConnectionInvite(from: uid, to: founderId) != nil {
                inviteCTAState = .pendingConnectionInvite
                return
            }
            inviteCTAState = .ready
        } catch {
            exploreVMLog.error("refreshInviteCTAState failed: \(error.localizedDescription, privacy: .public)")
            inviteCTAState = .error("無法檢查邀請狀態")
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
        Task { [weak self] in
            await self?.refreshFounderForCurrentDesk()
        }
    }

    /// Reloads from the server and shows another card when possible so **再看一次** always refreshes content.
    func viewAgain() async {
        let req = UUID()
        loadRequestID = req
        refreshGeneration = UUID()
        let previousId = currentDesk?.id
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let list = try await repository.fetchExploreDesks()
            guard req == loadRequestID else { return }
            desks = list
            CriticalDataCache.saveExploreDesks(list)
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
            exploreVMLog.error("viewAgain failed: \(error.localizedDescription, privacy: .public)")
            guard req == loadRequestID else { return }
            if desks.isEmpty, let cached = CriticalDataCache.loadExploreDesks(), !cached.isEmpty {
                desks = cached
                let pool = filteredDesks
                if !pool.isEmpty {
                    currentDesk = pool.randomElement()
                    await refreshFounderForCurrentDesk()
                }
                errorMessage = "無網絡或伺服器暫時不可用 — 顯示上次快取的列表"
            } else {
                errorMessage = Self.userFacingMessage(for: error)
            }
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost,
                 NSURLErrorTimedOut, NSURLErrorDataNotAllowed:
                return "無網絡連接"
            default:
                break
            }
        }
        if let u = error as? URLError {
            switch u.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .timedOut, .dataNotAllowed:
                return "無網絡連接"
            default:
                break
            }
        }
        return error.localizedDescription
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
        let req = UUID()
        founderRequestID = req
        do {
            let profile = try await users.fetchUser(id: d.founderId)
            guard req == founderRequestID else { return }
            currentFounder = profile
        } catch {
            guard req == founderRequestID else { return }
            exploreVMLog.error("refreshFounder failed: \(error.localizedDescription, privacy: .public)")
            currentFounder = nil
        }
    }
}
