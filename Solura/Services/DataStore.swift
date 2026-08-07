import Foundation
import SwiftData

/// The app's SwiftData stack.
///
/// The store lives in the shared app group so that a future extension can read
/// it directly. If the group container is unavailable — which in practice means
/// the App Groups capability is missing from the provisioning profile — Solura
/// falls back to a local store rather than crashing on launch. Losing widget
/// sync is recoverable; a launch crash on a reviewer's device is not.
nonisolated enum DataStore {
    static let schema = Schema([FastSession.self, WeightEntry.self])

    static func makeContainer() -> ModelContainer {
        let shared = ModelConfiguration(
            "Solura",
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .none
        )

        if let container = try? ModelContainer(for: schema, configurations: [shared]) {
            return container
        }

        let local = ModelConfiguration("Solura", schema: schema, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: [local]) {
            return container
        }

        // Last resort: an in-memory store. The app stays usable for the session
        // instead of dying at launch, and the UI surfaces nothing scary — a
        // user who cannot write to disk has bigger problems than lost history.
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [memory])
        } catch {
            fatalError("Could not create any model container: \(error)")
        }
    }
}

extension FastSession {
    /// The fast currently in progress, if there is one.
    static var runningDescriptor: FetchDescriptor<FastSession> {
        var descriptor = FetchDescriptor<FastSession>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }

    /// Every fast, newest first.
    static var allDescriptor: FetchDescriptor<FastSession> {
        FetchDescriptor<FastSession>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
    }

    /// The most recently finished fast, used to derive the eating window.
    static var lastFinishedDescriptor: FetchDescriptor<FastSession> {
        var descriptor = FetchDescriptor<FastSession>(
            predicate: #Predicate { $0.endDate != nil },
            sortBy: [SortDescriptor(\.endDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }
}

extension WeightEntry {
    static var allDescriptor: FetchDescriptor<WeightEntry> {
        FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
    }
}
