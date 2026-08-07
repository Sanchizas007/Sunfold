import SwiftUI

/// The metabolic phases, with the current one marked.
///
/// The copy throughout is hedged and educational. Sunfold describes what
/// research generally associates with each window of time; it never tells the
/// user what will happen to *them*, and the disclaimer at the top says so
/// before any of it is read.
struct PhasesScreen: View {
    @Environment(FastingController.self) private var fasting
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SunfoldBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                        DisclaimerNote(text: "phases.disclaimer", symbol: "heart.text.square")
                            .card()

                        ForEach(MetabolicPhase.allCases) { phase in
                            phaseCard(phase)
                        }
                    }
                    .padding(Metrics.screenPadding)
                }
            }
            .navigationTitle("phases.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private var elapsedHours: Double {
        (fasting.active?.elapsed() ?? 0) / 3600
    }

    private func phaseCard(_ phase: MetabolicPhase) -> some View {
        let isCurrent = fasting.mode == .fasting && MetabolicPhase.phase(atHours: elapsedHours) == phase
        let isPassed = elapsedHours >= phase.endHour && fasting.mode == .fasting

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: phase.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(phase.color)
                    .frame(width: 26, height: 26)
                    .background(phase.color.opacity(0.14), in: .circle)

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: phase.titleKey))
                        .font(Typography.cardTitle)
                        .foregroundStyle(Palette.ink)
                    Text(hourRange(phase))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }

                Spacer()

                if isCurrent {
                    Pill(text: String(localized: "phases.now"), symbol: nil, tint: phase.color)
                } else if isPassed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(phase.color.opacity(0.7))
                }
            }

            Text(String(localized: phase.summaryKey))
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(localized: phase.detailKey))
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .strokeBorder(isCurrent ? phase.color.opacity(0.5) : .clear, lineWidth: 1.5)
        )
    }

    private func hourRange(_ phase: MetabolicPhase) -> String {
        let start = Int(phase.startHour)
        if phase == .autophagy {
            return String(localized: "phases.range.open", defaultValue: "\(start)h+")
        }
        return String(
            localized: "phases.range",
            defaultValue: "\(start)–\(Int(phase.endHour)) h"
        )
    }
}
