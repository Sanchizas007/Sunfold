import SwiftUI
import WidgetKit

/// Home Screen and Lock Screen widgets showing the running fast.
///
/// The whole widget is driven by the snapshot the app writes into the shared
/// container, so rendering never touches SwiftData and never blocks. The elapsed
/// time is a `Text(timerInterval:)`, which WidgetKit keeps ticking on its own —
/// the timeline exists only to move the progress ring and to catch the moment a
/// fast reaches its goal.
struct FastingEntry: TimelineEntry {
    let date: Date
    let snapshot: FastingSnapshot
}

struct FastingProvider: TimelineProvider {
    func placeholder(in context: Context) -> FastingEntry {
        FastingEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (FastingEntry) -> Void) {
        let snapshot = context.isPreview ? .preview : SnapshotStore.load()
        completion(FastingEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FastingEntry>) -> Void) {
        let snapshot = SnapshotStore.load()
        let now = Date.now

        // A point every ten minutes moves the ring smoothly enough to read, and
        // one extra point exactly at the goal so the widget flips to "complete"
        // the moment it happens rather than up to ten minutes late.
        var dates: [Date] = (0..<18).compactMap {
            Calendar.current.date(byAdding: .minute, value: $0 * 10, to: now)
        }
        if let end = snapshot.endDate, end > now, end < now.addingTimeInterval(3 * 3600) {
            dates.append(end)
            dates.sort()
        }

        let entries = dates.map { FastingEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

extension FastingSnapshot {
    /// Representative state for the widget gallery and previews.
    static var preview: FastingSnapshot {
        FastingSnapshot(
            mode: .fasting,
            startDate: Date.now.addingTimeInterval(-13 * 3600),
            endDate: Date.now.addingTimeInterval(3 * 3600),
            protocolLabel: "16:8",
            streakDays: 5,
            hasFullAccess: true,
            updatedAt: .now
        )
    }
}

struct FastingTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SoluraFastingTimer", provider: FastingProvider()) { entry in
            FastingWidgetView(entry: entry)
                .containerBackground(Palette.canvas, for: .widget)
        }
        .configurationDisplayName("widget.title")
        .description("widget.description")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct FastingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FastingEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circularAccessory
            case .accessoryRectangular: rectangularAccessory
            case .accessoryInline: inlineAccessory
            case .systemMedium: medium
            default: small
            }
        }
        .widgetURL(URL(string: "solura://timer"))
    }

    private var snapshot: FastingSnapshot { entry.snapshot }

    private var isLocked: Bool { !snapshot.hasFullAccess }

    private var colors: [Color] {
        switch snapshot.mode {
        case .fasting: Palette.fastingGradient
        case .eating: Palette.eatingGradient
        case .idle: [Palette.surfaceAlt, Palette.surfaceAlt]
        }
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(spacing: 7) {
            if isLocked {
                lockedContent
            } else {
                ProgressRing(
                    progress: snapshot.progress(at: entry.date),
                    colors: colors,
                    lineWidth: 9,
                    showsHead: false
                ) {
                    VStack(spacing: 0) {
                        timerText
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(caption)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }

                Text(footnote)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            if isLocked {
                lockedContent
            } else {
                ProgressRing(
                    progress: snapshot.progress(at: entry.date),
                    colors: colors,
                    lineWidth: 10,
                    showsHead: false
                ) {
                    Text(snapshot.protocolLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.inkSecondary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 5) {
                    Text(caption)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.inkSecondary)

                    timerText
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let phase = snapshot.phase, snapshot.mode == .fasting {
                            Label {
                                Text(String(localized: phase.titleKey))
                            } icon: {
                                Image(systemName: phase.symbol)
                            }
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(phase.color)
                        }

                        if snapshot.streakDays > 0 {
                            Label("\(snapshot.streakDays)", systemImage: "flame.fill")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Palette.accent)
                        }
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.accent)
            Text("widget.locked")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Lock Screen

    private var circularAccessory: some View {
        Gauge(value: snapshot.progress(at: entry.date)) {
            Image(systemName: snapshot.mode == .eating ? "fork.knife" : "timer")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangularAccessory: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(caption)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .textCase(.uppercase)
            timerText
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(footnote)
                .font(.system(size: 11, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inlineAccessory: some View {
        HStack(spacing: 3) {
            Image(systemName: snapshot.mode == .eating ? "fork.knife" : "timer")
            timerText
        }
    }

    // MARK: Shared pieces

    /// A self-ticking timer. WidgetKit updates this text without spending a
    /// timeline refresh, which is the only reason a per-second widget is
    /// possible at all.
    @ViewBuilder
    private var timerText: some View {
        switch snapshot.mode {
        case .fasting:
            if let start = snapshot.startDate {
                Text(timerInterval: start...start.addingTimeInterval(48 * 3600), countsDown: false)
            } else {
                Text(verbatim: "—")
            }
        case .eating:
            if let start = snapshot.startDate, let end = snapshot.endDate, end > start {
                Text(timerInterval: start...end, countsDown: true)
            } else {
                Text(verbatim: "—")
            }
        case .idle:
            Text("widget.idle.value")
        }
    }

    private var caption: LocalizedStringKey {
        switch snapshot.mode {
        case .fasting: "timer.caption.elapsed"
        case .eating: "timer.caption.eating"
        case .idle: "timer.caption.ready"
        }
    }

    private var footnote: String {
        switch snapshot.mode {
        case .fasting:
            snapshot.protocolLabel
        case .eating:
            String(localized: "widget.window")
        case .idle:
            String(localized: "widget.tapToStart")
        }
    }
}

#Preview("Small", as: .systemSmall) {
    FastingTimerWidget()
} timeline: {
    FastingEntry(date: .now, snapshot: .preview)
}

#Preview("Medium", as: .systemMedium) {
    FastingTimerWidget()
} timeline: {
    FastingEntry(date: .now, snapshot: .preview)
}
