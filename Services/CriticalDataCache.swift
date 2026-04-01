import Foundation

/// Persists last successful explore feed for offline read.
enum CriticalDataCache {
    private static let exploreDesksKey = "desker.cache.exploreDesks.v1"

    static func saveExploreDesks(_ desks: [Desk]) {
        guard let data = try? JSONEncoder().encode(desks) else { return }
        UserDefaults.standard.set(data, forKey: exploreDesksKey)
    }

    static func loadExploreDesks() -> [Desk]? {
        guard let data = UserDefaults.standard.data(forKey: exploreDesksKey) else { return nil }
        return try? JSONDecoder().decode([Desk].self, from: data)
    }
}
