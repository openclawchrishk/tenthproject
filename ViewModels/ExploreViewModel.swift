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
            pickCurrentDesk(excluding: nil)
        } catch {
            errorMessage = error.localizedDescription
            desks = []
            currentDesk = nil
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
                return
            }
            if desks.count > 1, let prev = previousId {
                let others = desks.filter { $0.id != prev }
                currentDesk = others.randomElement() ?? desks.randomElement()
            } else {
                // Single item: still re-assign so SwiftUI refreshes bound subviews.
                currentDesk = desks.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pickCurrentDesk(excluding: UUID?) {
        guard !desks.isEmpty else {
            currentDesk = nil
            return
        }
        if let ex = excluding, desks.count > 1 {
            let others = desks.filter { $0.id != ex }
            currentDesk = others.randomElement() ?? desks.randomElement()
        } else {
            currentDesk = desks.randomElement()
        }
    }
}
