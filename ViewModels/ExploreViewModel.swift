import Foundation
import SwiftUI

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published private(set) var desks: [Desk] = []
    @Published private(set) var currentDesk: Desk?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    /// Changing this forces card content to refresh (再看一次).
    @Published private(set) var refreshGeneration = UUID()

    private let repository = DeskRepository()

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let list = try await repository.fetchExploreDesks()
            desks = list
            pickCurrentDesk()
        } catch {
            errorMessage = error.localizedDescription
            desks = []
            currentDesk = nil
        }
    }

    /// Reloads pool and picks another desk (or reshuffles) so the card shows fresh content.
    func viewAgain() async {
        refreshGeneration = UUID()
        errorMessage = nil
        do {
            let list = try await repository.fetchExploreDesks()
            desks = list
            if desks.count > 1 {
                let previous = currentDesk?.id
                let others = desks.filter { $0.id != previous }
                currentDesk = others.randomElement() ?? desks.randomElement()
            } else {
                currentDesk = desks.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pickCurrentDesk() {
        currentDesk = desks.randomElement()
    }
}
