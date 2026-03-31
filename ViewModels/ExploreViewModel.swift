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

    private let repository = DeskRepository()
    private let users = UserRepository()

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
            if desks.isEmpty {
                currentDesk = nil
                currentFounder = nil
                return
            }
            if desks.count > 1, let prev = previousId {
                let others = desks.filter { $0.id != prev }
                currentDesk = others.randomElement() ?? desks.randomElement()
            } else {
                // Single item: still re-assign so SwiftUI refreshes bound subviews.
                currentDesk = desks.first
            }
            await refreshFounderForCurrentDesk()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pickCurrentDesk(excluding: UUID?) {
        guard !desks.isEmpty else {
            currentDesk = nil
            currentFounder = nil
            return
        }
        if let ex = excluding, desks.count > 1 {
            let others = desks.filter { $0.id != ex }
            currentDesk = others.randomElement() ?? desks.randomElement()
        } else {
            currentDesk = desks.randomElement()
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
