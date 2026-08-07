import Foundation
import SwiftData

/// CSV export.
///
/// The user's history belongs to the user. Since Solura has no account and no
/// server, an export is the only way to move data to another device or keep it
/// after uninstalling — and being able to leave is part of being trustworthy.
nonisolated enum ExportService {

    static func csv(sessions: [FastSession], weights: [WeightEntry], unit: WeightUnit) -> String {
        var lines: [String] = []

        lines.append("type,start,end,duration_minutes,target_minutes,protocol,reached_goal,feeling,note")
        for session in sessions.sorted(by: { $0.startDate < $1.startDate }) {
            let duration = session.duration.map { String(Int($0 / 60)) } ?? ""
            lines.append([
                "fast",
                iso(session.startDate),
                session.endDate.map(iso) ?? "",
                duration,
                String(Int(session.targetSeconds / 60)),
                session.protocolRaw,
                session.endDate == nil ? "" : (session.endedEarly ? "no" : "yes"),
                session.feeling.map(String.init) ?? "",
                escape(session.note)
            ].joined(separator: ","))
        }

        lines.append("")
        lines.append("type,date,weight_\(unit.rawValue),note")
        for entry in weights.sorted(by: { $0.date < $1.date }) {
            let value = unit.value(fromKilograms: entry.kilograms)
            lines.append([
                "weight",
                iso(entry.date),
                String(format: "%.2f", value),
                escape(entry.note)
            ].joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    /// Writes the CSV to a temporary file and returns its URL, ready for
    /// `ShareLink`. Returns `nil` rather than throwing — a failed export should
    /// disable the button, not interrupt the user.
    static func writeTemporaryFile(
        sessions: [FastSession],
        weights: [WeightEntry],
        unit: WeightUnit
    ) -> URL? {
        let text = csv(sessions: sessions, weights: weights, unit: unit)
        let name = "solura-export-\(fileStamp(Date.now)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func iso(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day().dateSeparator(.dash)
            .time(includingFractionalSeconds: false).timeSeparator(.colon))
    }

    private static func fileStamp(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }

    /// Quotes a CSV field only when it needs it.
    private static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
