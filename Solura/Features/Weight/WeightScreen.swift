import Charts
import SwiftData
import SwiftUI

struct WeightScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Entitlements.self) private var entitlements
    @Environment(\.modelContext) private var context

    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]

    @State private var showingEditor = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                SoluraBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        summaryCard
                        chartSection
                        entryList
                    }
                    .padding(Metrics.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("weight.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("weight.add")
                }
            }
            .sheet(isPresented: $showingEditor) { WeightEditor() }
            .sheet(isPresented: $showingPaywall) { PaywallScreen() }
        }
    }

    // MARK: Summary

    @ViewBuilder
    private var summaryCard: some View {
        if let latest = entries.first {
            VStack(alignment: .leading, spacing: 10) {
                Text("weight.current")
                    .font(Typography.overline)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.inkSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(WeightFormat.string(kilograms: latest.kilograms, unit: settings.weightUnit))
                        .font(Typography.screenTitle)
                        .foregroundStyle(Palette.ink)

                    if let change = changeSinceStart {
                        Pill(
                            text: WeightFormat.delta(kilograms: change, unit: settings.weightUnit),
                            symbol: change <= 0 ? "arrow.down" : "arrow.up",
                            tint: Palette.inkSecondary
                        )
                    }
                }

                Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }
            .card()
        } else {
            EmptyStateView(
                symbol: "scalemass",
                title: "weight.empty.title",
                message: "weight.empty.body"
            )
            .card()
        }
    }

    /// Difference between the first recorded weight and the latest. Deliberately
    /// presented without judgement — no green/red, no target line, no "goal
    /// weight". A fasting timer has no business assigning anyone a number.
    private var changeSinceStart: Double? {
        guard let first = entries.last, let latest = entries.first, entries.count > 1 else { return nil }
        return latest.kilograms - first.kilograms
    }

    // MARK: Chart

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "weight.chart.title")

            if !entitlements.hasFullAccess {
                LockedFeatureCard(
                    title: "weight.chart.locked.title",
                    message: "weight.chart.locked.body"
                ) { showingPaywall = true }
            } else if entries.count < 2 {
                EmptyStateView(
                    symbol: "chart.xyaxis.line",
                    title: "weight.chart.empty.title",
                    message: "weight.chart.empty.body"
                )
                .card()
            } else {
                Chart(entries) { entry in
                    LineMark(
                        x: .value("weight.chart.date", entry.date),
                        y: .value("weight.chart.value", settings.weightUnit.value(fromKilograms: entry.kilograms))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.fasting)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    PointMark(
                        x: .value("weight.chart.date", entry.date),
                        y: .value("weight.chart.value", settings.weightUnit.value(fromKilograms: entry.kilograms))
                    )
                    .foregroundStyle(Palette.accent)
                    .symbolSize(28)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Palette.hairline)
                        AxisValueLabel().foregroundStyle(Palette.inkTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel(format: .dateTime.day().month(.narrow))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
                .frame(height: 170)
                .card()
            }
        }
    }

    // MARK: List

    @ViewBuilder
    private var entryList: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "weight.entries")

                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(WeightFormat.string(kilograms: entry.kilograms, unit: settings.weightUnit))
                                    .font(Typography.cardTitle)
                                    .foregroundStyle(Palette.ink)
                                if !entry.note.isEmpty {
                                    Text(entry.note)
                                        .font(Typography.caption)
                                        .foregroundStyle(Palette.inkTertiary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(Typography.caption)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                        .card()
                        .contextMenu {
                            Button("common.delete", role: .destructive) {
                                context.delete(entry)
                                try? context.save()
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Editor

private struct WeightEditor: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var value: Double = 70
    @State private var date = Date.now
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ZStack {
                SoluraBackground()

                ScrollView {
                    VStack(spacing: Metrics.stackSpacing) {
                        VStack(spacing: 4) {
                            Text(WeightFormat.string(
                                kilograms: settings.weightUnit.kilograms(fromValue: value),
                                unit: settings.weightUnit
                            ))
                            .font(Typography.screenTitle)
                            .foregroundStyle(Palette.ink)

                            Slider(
                                value: $value,
                                in: settings.weightUnit.range,
                                step: 0.1
                            )
                            .tint(Palette.accentDeep)
                        }
                        .card()

                        DatePicker("weight.date", selection: $date, in: ...Date.now, displayedComponents: .date)
                            .tint(Palette.accentDeep)
                            .font(Typography.body)
                            .card()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("weight.note")
                                .font(Typography.cardTitle)
                                .foregroundStyle(Palette.ink)
                            TextField("weight.notePlaceholder", text: $note, axis: .vertical)
                                .lineLimit(2...4)
                                .font(Typography.body)
                        }
                        .card()
                    }
                    .padding(Metrics.screenPadding)
                }
            }
            .navigationTitle("weight.add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.save") { save() }.fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Seed the slider from the last reading so a daily weigh-in is two
            // taps rather than a hunt across the whole range.
            let descriptor = WeightEntry.allDescriptor
            if let last = try? context.fetch(descriptor).first {
                value = settings.weightUnit.value(fromKilograms: last.kilograms)
            } else {
                value = settings.weightUnit == .kilograms ? 70 : 154
            }
        }
    }

    private func save() {
        let entry = WeightEntry(
            date: date,
            kilograms: settings.weightUnit.kilograms(fromValue: value),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(entry)
        try? context.save()
        dismiss()
    }
}
