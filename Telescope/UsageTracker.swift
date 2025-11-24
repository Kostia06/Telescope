import Foundation

/// Tracks application usage statistics to prioritize frequently used apps
class UsageTracker {
    static let shared = UsageTracker()

    private let userDefaults = UserDefaults.standard
    private let usageKey = "com.telescope.appUsage"
    private var usageStats: [String: Int] = [:]
    private let queue = DispatchQueue(label: "com.telescope.usagetracker", attributes: .concurrent)

    private init() {
        loadUsageStats()
    }

    /// Load usage statistics from persistent storage
    private func loadUsageStats() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if let data = self.userDefaults.data(forKey: self.usageKey),
               let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
                self.usageStats = decoded
            }
        }
    }

    /// Save usage statistics to persistent storage
    private func saveUsageStats() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if let encoded = try? JSONEncoder().encode(self.usageStats) {
                self.userDefaults.set(encoded, forKey: self.usageKey)
            }
        }
    }

    /// Increment usage count for an app
    /// - Parameter appPath: The file path of the application
    func incrementUsage(for appPath: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let currentCount = self.usageStats[appPath, default: 0]
            self.usageStats[appPath] = currentCount + 1
            self.saveUsageStats()
        }
    }

    /// Get usage points for an app (thread-safe)
    /// - Parameter appPath: The file path of the application
    /// - Returns: The number of times the app has been used
    func getUsagePoints(for appPath: String) -> Int {
        var points = 0
        queue.sync {
            points = usageStats[appPath, default: 0]
        }
        return points
    }

    /// Get all usage statistics (for debugging)
    func getAllStats() -> [String: Int] {
        var stats: [String: Int] = [:]
        queue.sync {
            stats = usageStats
        }
        return stats
    }

    /// Clear all usage statistics
    func clearAllStats() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.usageStats.removeAll()
            self.saveUsageStats()
        }
    }
}
