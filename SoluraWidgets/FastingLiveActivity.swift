import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity: a Lock Screen card and the Dynamic Island presentations.
///
/// This is the single strongest signal that Solura is a native app rather than a
/// wrapped web page, so it gets the same care as the main screen — the same
/// ring, the same warm gradient, the same rounded numerals.
struct FastingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastingActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Palette.canvas)
                .activitySystemActionForegroundColor(Palette.accentDeep)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ProgressRing(
                            progress: context.state.progress(at: .now),
                            colors: ringColors(context.state),
                            lineWidth: 5,
                            showsHead: false
                        )
                        .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(context.attributes.protocolLabel)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.ink)
                            Text(caption(context.state))
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    timerText(context.state)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: 96, alignment: .trailing)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let phase = context.state.phase, !context.state.isEatingWindow {
                            Label {
                                Text(String(localized: phase.titleKey))
                            } icon: {
                                Image(systemName: phase.symbol)
                            }
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(phase.color)
                        }

                        Spacer(minLength: 8)

                        Text(goalLabel(context.state))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.trailing, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isEatingWindow ? "fork.knife" : "timer")
                    .foregroundStyle(context.state.isEatingWindow ? Palette.eating : Palette.accent)
            } compactTrailing: {
                timerText(context.state)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: 52)
            } minimal: {
                ProgressRing(
                    progress: context.state.progress(at: .now),
                    colors: ringColors(context.state),
                    lineWidth: 3.5,
                    showsHead: false
                )
            }
            .widgetURL(URL(string: "solura://timer"))
            .keylineTint(Palette.accent)
        }
    }

    // MARK: Lock Screen

    private func lockScreen(_ context: ActivityViewContext<FastingActivityAttributes>) -> some View {
        HStack(spacing: 15) {
            ProgressRing(
                progress: context.state.progress(at: .now),
                colors: ringColors(context.state),
                lineWidth: 8,
                showsHead: false
            ) {
                Text(context.attributes.protocolLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.inkSecondary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 3) {
                Text(caption(context.state))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.inkSecondary)

                timerText(context.state)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let phase = context.state.phase, !context.state.isEatingWindow {
                        Label {
                            Text(String(localized: phase.titleKey))
                        } icon: {
                            Image(systemName: phase.symbol)
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(phase.color)
                    }
                    Text(goalLabel(context.state))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Palette.inkTertiary)
                }
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Pieces

    private func ringColors(_ state: FastingActivityAttributes.ContentState) -> [Color] {
        state.isEatingWindow ? Palette.eatingGradient : Palette.fastingGradient
    }

    @ViewBuilder
    private func timerText(_ state: FastingActivityAttributes.ContentState) -> some View {
        if state.isEatingWindow {
            Text(timerInterval: state.startDate...state.endDate, countsDown: true)
        } else {
            // Counts up, with a range wide enough that an overrun fast keeps
            // counting instead of freezing at the goal.
            Text(
                timerInterval: state.startDate...state.startDate.addingTimeInterval(48 * 3600),
                countsDown: false
            )
        }
    }

    private func caption(_ state: FastingActivityAttributes.ContentState) -> LocalizedStringKey {
        state.isEatingWindow ? "timer.caption.eating" : "timer.caption.elapsed"
    }

    private func goalLabel(_ state: FastingActivityAttributes.ContentState) -> String {
        String(
            localized: "activity.goalAt",
            defaultValue: "Goal \(state.endDate.formatted(date: .omitted, time: .shortened))"
        )
    }
}
