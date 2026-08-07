import Charts
import SwiftData
import SwiftUI

struct HistoryScreen: View {
    @Environment(Entitlements.self) private var entitlements
    @Environment(FastingController.self) private var fasting
    @Environment(AppSettings.self) private var settings

    @Query(sort: \FastSession.startDate, order: .reverse) private var allSessions: [FastSession]

    @State private var showingPaywall = false
    @State private var editingSession: FastSession?
    @State private var monthAnchor = Date.now

    /// What the current tier is allowed to see. The gate is applied once, here,
    /// so every number below it agrees with the list the user can actually read.
    private var sessions: [FastSession] {
        Statistics.visible(allSessions, hasFullAccess: entitlements.hasFullAccess)
    }

    private var summary: Statistics.Summary {
        Statistics.summary(for: sessions)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SoluraBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        statsGrid

                        StreakCalendar(
                            anchor: $monthAnchor,
                            activeDays: Statistics.activeDays(for: sessions)
                        )
                        .card()

                        chartSection

                        if !entitlements.hasFullAccess {
                            lockedHistoryCard
                        }

                        sessionList
                    }
                    .padding(Metrics.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("history.title")
            .sheet(isPresented: $showingPaywall) { PaywallScreen() }
            .sheet(item: $editingSession) { session in
                SessionEditor(session: session)
            }
        }
    }

    // MARK: Stats

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            StatTile(
                title: "history.stat.streak",
                value: String(
                    localized: "history.stat.days",
                    defaultValue: "\(summary.currentStreak) d"
                ),
                symbol: "flame.fill",
                tint: Palette.accent
            )
            StatTile(
                title: "history.stat.totalFasts",
                value: "\(summary.totalFasts)",
                symbol: "checkmark.circle.fill",
                tint: Palette.success
            )
            StatTile(
                title: "history.stat.average",
                value: DurationFormat.compact(summary.averageSeconds),
                symbol: "chart.bar.fill",
                tint: Palette.accent
            )
            StatTile(
                title: "history.stat.totalHours",
                value: DurationFormat.hoursOnly(summary.totalSeconds),
                symbol: "clock.fill",
                tint: Palette.eating
            )
        }
    }

    // MARK: Chart

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "history.chart.title")

            if entitlements.hasFullAccess {
                let totals = Statistics.dailyTotals(for: sessions, days: 14)
                Chart(totals) { point in
                    BarMark(
                        x: .value("history.chart.day", point.day, unit: .day),
                        y: .value("history.chart.hours", point.seconds / 3600)
                    )
                    .foregroundStyle(.fasting)
                    .cornerRadius(5)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(Palette.hairline)
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text(verbatim: "\(Int(hours))h")
                                    .font(Typography.caption)
                                    .foregroundStyle(Palette.inkTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) { value in
                        AxisValueLabel(format: .dateTime.day().month(.narrow))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
                .frame(height: 160)
                .card()
            } else {
                LockedFeatureCard(
                    title: "history.chart.locked.title",
                    message: "history.chart.locked.body"
                ) { showingPaywall = true }
            }
        }
    }

    private var lockedHistoryCard: some View {
        LockedFeatureCard(
            title: "history.locked.title",
            message: "history.locked.body"
        ) { showingPaywall = true }
    }

    // MARK: List

    @ViewBuilder
    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "history.sessions")

            if sessions.isEmpty {
                EmptyStateView(
                    symbol: "calendar.badge.clock",
                    title: "history.empty.title",
                    message: "history.empty.body"
                )
                .card()
            } else {
                VStack(spacing: 10) {
                    ForEach(sessions) { session in
                        SessionRow(session: session)
                            .onTapGesture { editingSession = session }
                            .contextMenu {
                                Button("common.edit") { editingSession = session }
                                Button("common.delete", role: .destructive) {
                                    fasting.delete(session)
                                }
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Row

private struct SessionRow: View {
    let session: FastSession

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(session.isRunning ? AnyShapeStyle(LinearGradient.fasting) : AnyShapeStyle(barColor))
                .frame(width: 4, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(Typography.cardTitle)
                    .foregroundStyle(Palette.ink)

                HStack(spacing: 5) {
                    Text(session.startDate.formatted(date: .omitted, time: .shortened))
                    Image(systemName: "arrow.right").font(.system(size: 8, weight: .bold))
                    if let end = session.endDate {
                        Text(end.formatted(date: .omitted, time: .shortened))
                    } else {
                        Text("history.running")
                    }
                }
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)

                if !session.note.isEmpty {
                    Text(session.note)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                Text(DurationFormat.compact(session.duration ?? session.elapsed()))
                    .font(Typography.stat)
                    .foregroundStyle(Palette.ink)
                Text(session.fastingProtocol.rawValue)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
        .card()
    }

    /// A fast that stopped short is shown in a muted tone, never in red. Ending
    /// early is a normal thing to do and the history should not shout about it.
    private var barColor: Color {
        session.endedEarly ? Palette.hairline : Palette.accent
    }
}

// MARK: - Locked card

struct LockedFeatureCard: View {
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.accentDeep)
                    .frame(width: 32, height: 32)
                    .background(Palette.accent.opacity(0.14), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(Palette.ink)
                    Text(message)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session editor

private struct SessionEditor: View {
    @Environment(FastingController.self) private var fasting
    @Environment(\.dismiss) private var dismiss

    let session: FastSession
    @State private var note = ""
    @State private var feeling: Int?

    var body: some View {
        NavigationStack {
            ZStack {
                SoluraBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("history.editor.duration")
                                .font(Typography.overline)
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.inkSecondary)
                            Text(DurationFormat.compact(session.duration ?? session.elapsed()))
                                .font(Typography.screenTitle)
                                .foregroundStyle(Palette.ink)
                            Text(session.startDate.formatted(date: .long, time: .shortened))
                                .font(Typography.caption)
                                .foregroundStyle(Palette.inkTertiary)
                        }
                        .card()

                        VStack(alignment: .leading, spacing: 9) {
                            Text("history.editor.feeling")
                                .font(Typography.cardTitle)
                                .foregroundStyle(Palette.ink)
                            HStack(spacing: 9) {
                                ForEach(1...5, id: \.self) { value in
                                    Button {
                                        feeling = feeling == value ? nil : value
                                    } label: {
                                        Image(systemName: symbol(for: value))
                                            .font(.system(size: 22))
                                            .foregroundStyle(
                                                feeling == value ? Palette.accentDeep : Palette.inkTertiary
                                            )
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .card()

                        VStack(alignment: .leading, spacing: 9) {
                            Text("history.editor.note")
                                .font(Typography.cardTitle)
                                .foregroundStyle(Palette.ink)
                            TextField("history.editor.notePlaceholder", text: $note, axis: .vertical)
                                .lineLimit(3...6)
                                .font(Typography.body)
                                .foregroundStyle(Palette.ink)
                        }
                        .card()

                        Button("common.delete", role: .destructive) {
                            fasting.delete(session)
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .foregroundStyle(Palette.caution)
                    }
                    .padding(Metrics.screenPadding)
                }
            }
            .navigationTitle("history.editor.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.save") {
                        fasting.update(session, note: note, feeling: feeling)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            note = session.note
            feeling = session.feeling
        }
    }

    private func symbol(for value: Int) -> String {
        switch value {
        case 1: "cloud.rain"
        case 2: "cloud"
        case 3: "cloud.sun"
        case 4: "sun.max"
        default: "sparkles"
        }
    }
}
