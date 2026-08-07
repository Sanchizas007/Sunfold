import Foundation

/// The app group shared by Sunfold and its widget extension.
nonisolated enum AppGroup {
    static let identifier = "group.app.sunfold"

    /// Defaults shared with the widget. Falls back to `.standard` if the group
    /// is unavailable (which only happens if the entitlement is missing) so the
    /// app still works rather than crashing on launch.
    ///
    /// Computed rather than stored: `UserDefaults` is not `Sendable`, and the
    /// system already caches suite instances, so this costs nothing.
    static var defaults: UserDefaults { UserDefaults(suiteName: identifier) ?? .standard }
}

/// The minimum the widget and the Live Activity need to draw the current state.
///
/// The widget deliberately reads this snapshot rather than opening the SwiftData
/// store: it renders in a memory-constrained process on a tight budget, and a
/// few hundred bytes of JSON is both faster and impossible to corrupt.
nonisolated struct FastingSnapshot: Codable, Sendable, Equatable {
    enum Mode: String, Codable, Sendable {
        /// A fast is running.
        case fasting
        /// The last fast is finished and the eating window is counting down.
        case eating
        /// Nothing scheduled.
        case idle
    }

    var mode: Mode = .idle
    /// Start of the running fast, or of the eating window.
    var startDate: Date?
    /// Goal end of the running fast, or end of the eating window.
    var endDate: Date?
    var protocolLabel: String = FastingProtocol.sixteenEight.rawValue
    var streakDays: Int = 0
    /// Whether the widget may draw the live timer. The widget cannot ask
    /// RevenueCat itself, so the app writes the answer here.
    var hasFullAccess: Bool = true
    var updatedAt: Date = .distantPast

    static let idle = FastingSnapshot()

    /// Fraction of the way through the current fast or window, 0…1.
    func progress(at now: Date) -> Double {
        guard let startDate, let endDate else { return 0 }
        let total = endDate.timeIntervalSince(startDate)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(startDate) / total))
    }

    func elapsed(at now: Date) -> TimeInterval {
        guard let startDate else { return 0 }
        return max(0, now.timeIntervalSince(startDate))
    }

    var phase: MetabolicPhase? {
        guard mode == .fasting, let startDate else { return nil }
        return MetabolicPhase.phase(forElapsed: Date.now.timeIntervalSince(startDate))
    }
}

/// Whether the user currently has full access, mirrored into the shared
/// container so the widget can decide what to draw without talking to the store.
nonisolated enum AccessStore {
    private static let key = "access.hasFullAccess.v1"

    static var hasFullAccess: Bool {
        get {
            // Absent means "not yet written" — during the intro period on a
            // fresh install that is the truth, so default to granted.
            AppGroup.defaults.object(forKey: key) as? Bool ?? true
        }
        set { AppGroup.defaults.set(newValue, forKey: key) }
    }
}

/// Reads and writes the snapshot in the shared container.
nonisolated enum SnapshotStore {
    private static let key = "fasting.snapshot.v1"

    static func load() -> FastingSnapshot {
        guard
            let data = AppGroup.defaults.data(forKey: key),
            let snapshot = try? JSONDecoder.sunfold.decode(FastingSnapshot.self, from: data)
        else { return .idle }
        return snapshot
    }

    static func save(_ snapshot: FastingSnapshot) {
        guard let data = try? JSONEncoder.sunfold.encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: key)
    }
}

extension JSONEncoder {
    nonisolated static var sunfold: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    nonisolated static var sunfold: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
