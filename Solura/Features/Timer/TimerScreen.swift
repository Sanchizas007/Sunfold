import SwiftUI

/// The home screen: one ring, one number, one button.
///
/// Everything secondary is pushed below the fold or into a sheet. The ring is
/// the composition — the moment the user opens the app they should know whether
/// they are fasting and how far along they are, without reading a word.
struct TimerScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Entitlements.self) private var entitlements
    @Environment(FastingController.self) private var fasting

    @State private var showingProtocols = false
    @State private var showingPhases = false
    @State private var showingPaywall = false
    @State private var showingStartEditor = false
    @State private var showingLongFastNotice = false
    @State private var showingEndConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                SoluraBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        ring
                            .padding(.horizontal, 34)
                            .padding(.top, 4)

                        phasePill

                        scheduleCard

                        actionButton

                        protocolRow

                        if fasting.mode == .fasting, settings.targetFastSeconds >= CustomFastLimits.advisorySeconds {
                            DisclaimerNote(text: "timer.longFast.notice", symbol: "heart.text.square")
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, Metrics.screenPadding)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("app.name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AccessBadge(showingPaywall: $showingPaywall)
                }
            }
            .sheet(isPresented: $showingProtocols) { ProtocolPickerScreen() }
            .sheet(isPresented: $showingPhases) { PhasesScreen() }
            .sheet(isPresented: $showingPaywall) { PaywallScreen() }
            .sheet(isPresented: $showingStartEditor) { StartTimeEditor() }
            .confirmationDialog(
                "timer.end.confirm.title",
                isPresented: $showingEndConfirmation,
                titleVisibility: .visible
            ) {
                Button("timer.end.confirm.action", role: .destructive) { fasting.stop() }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("timer.end.confirm.message")
            }
            .alert("timer.longFast.title", isPresented: $showingLongFastNotice) {
                Button("timer.longFast.start") { startFast() }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("timer.longFast.message")
            }
        }
    }

    // MARK: Ring

    private var ring: some View {
        // A 1-second timeline drives the whole screen. Deriving elapsed time
        // from `context.date` rather than a stored counter means the display is
        // correct after any amount of time in the background.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ProgressRing(
                progress: fasting.progress(at: context.date),
                colors: ringColors,
                lineWidth: 24,
                phaseTicks: fasting.mode == .fasting
                    ? MetabolicPhase.tickFractions(targetSeconds: settings.targetFastSeconds)
                    : []
            ) {
                ringCenter(now: context.date)
            }
            .onChange(of: Int(context.date.timeIntervalSince1970) / 60) { _, _ in
                // Once a minute is often enough to notice a phase boundary.
                guard let session = fasting.active else { return }
                LiveActivityController.shared.updatePhaseIfNeeded(
                    startDate: session.startDate,
                    endDate: session.targetEndDate,
                    at: context.date
                )
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            guard fasting.mode == .fasting else { return }
            if entitlements.hasFullAccess {
                showingPhases = true
            } else {
                showingPaywall = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var ringColors: [Color] {
        switch fasting.mode {
        case .fasting: Palette.fastingGradient
        case .eating: Palette.eatingGradient
        case .idle: [Palette.surfaceAlt, Palette.surfaceAlt]
        }
    }

    @ViewBuilder
    private func ringCenter(now: Date) -> some View {
        VStack(spacing: 3) {
            Text(centerCaption)
                .font(Typography.overline)
                .textCase(.uppercase)
                .foregroundStyle(Palette.inkSecondary)

            Text(centerValue(now: now))
                .font(Typography.timer)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(centerSubtitle(now: now))
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
        }
        .multilineTextAlignment(.center)
    }

    private var centerCaption: LocalizedStringKey {
        switch fasting.mode {
        case .fasting: "timer.caption.elapsed"
        case .eating: "timer.caption.eating"
        case .idle: "timer.caption.ready"
        }
    }

    private func centerValue(now: Date) -> String {
        switch fasting.mode {
        case .fasting:
            DurationFormat.clock(fasting.active?.elapsed(at: now) ?? 0)
        case .eating:
            DurationFormat.clock(max(0, fasting.eatingWindowEnd?.timeIntervalSince(now) ?? 0))
        case .idle:
            settings.protocolLabel
        }
    }

    private func centerSubtitle(now: Date) -> String {
        switch fasting.mode {
        case .fasting:
            String(
                localized: "timer.subtitle.goal",
                defaultValue: "of \(DurationFormat.compact(settings.targetFastSeconds))"
            )
        case .eating:
            String(localized: "timer.subtitle.windowLeft")
        case .idle:
            DurationFormat.compact(settings.targetFastSeconds)
        }
    }

    private var accessibilitySummary: String {
        switch fasting.mode {
        case .fasting:
            String(localized: "a11y.fasting")
        case .eating:
            String(localized: "a11y.eating")
        case .idle:
            String(localized: "a11y.idle")
        }
    }

    // MARK: Phase

    @ViewBuilder
    private var phasePill: some View {
        if fasting.mode == .fasting, let session = fasting.active {
            let phase = session.phase()
            Button {
                if entitlements.hasFullAccess { showingPhases = true } else { showingPaywall = true }
            } label: {
                HStack(spacing: 6) {
                    Pill(
                        text: String(localized: phase.titleKey),
                        symbol: phase.symbol,
                        tint: phase.color
                    )
                    Image(systemName: entitlements.hasFullAccess ? "chevron.right" : "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Schedule

    @ViewBuilder
    private var scheduleCard: some View {
        switch fasting.mode {
        case .fasting:
            if let session = fasting.active {
                HStack(spacing: 0) {
                    scheduleColumn(
                        title: "timer.started",
                        value: session.startDate.formatted(date: .omitted, time: .shortened),
                        detail: session.startDate.formatted(.dateTime.weekday(.abbreviated))
                    )
                    Divider().frame(height: 34).overlay(Palette.hairline)
                    scheduleColumn(
                        title: "timer.goal",
                        value: session.targetEndDate.formatted(date: .omitted, time: .shortened),
                        detail: session.targetEndDate.formatted(.dateTime.weekday(.abbreviated))
                    )
                }
                .card()
                .overlay(alignment: .topTrailing) {
                    Button { showingStartEditor = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.inkTertiary)
                            .padding(10)
                    }
                    .accessibilityLabel("timer.editStart")
                }
            }

        case .eating:
            if let end = fasting.eatingWindowEnd {
                HStack(spacing: 0) {
                    scheduleColumn(
                        title: "timer.window.until",
                        value: end.formatted(date: .omitted, time: .shortened),
                        detail: end.formatted(.dateTime.weekday(.abbreviated))
                    )
                    Divider().frame(height: 34).overlay(Palette.hairline)
                    scheduleColumn(
                        title: "timer.lastFast",
                        value: DurationFormat.compact(fasting.lastFinished?.duration ?? 0),
                        detail: String(localized: "timer.completed")
                    )
                }
                .card()
            }

        case .idle:
            VStack(alignment: .leading, spacing: 6) {
                Text("timer.idle.title")
                    .font(Typography.cardTitle)
                    .foregroundStyle(Palette.ink)
                Text("timer.idle.body")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card()
        }
    }

    private func scheduleColumn(title: LocalizedStringKey, value: String, detail: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(Typography.overline)
                .textCase(.uppercase)
                .foregroundStyle(Palette.inkSecondary)
            Text(value)
                .font(Typography.stat)
                .foregroundStyle(Palette.ink)
            Text(detail)
                .font(Typography.caption)
                .foregroundStyle(Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Action

    private var actionButton: some View {
        Group {
            switch fasting.mode {
            case .fasting:
                Button("timer.end") { showingEndConfirmation = true }
                    .buttonStyle(SecondaryButtonStyle())
            case .eating, .idle:
                Button("timer.start") { attemptStart() }
                    .buttonStyle(PrimaryButtonStyle(tint: .fasting))
            }
        }
    }

    private var protocolRow: some View {
        Button { showingProtocols = true } label: {
            HStack(spacing: 6) {
                Image(systemName: settings.selectedProtocol.symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(settings.protocolLabel)
                    .font(Typography.captionStrong)
                Text("timer.changeProtocol")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }
            .foregroundStyle(Palette.accentDeep)
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func attemptStart() {
        if settings.targetFastSeconds >= CustomFastLimits.advisorySeconds {
            showingLongFastNotice = true
        } else {
            startFast()
        }
    }

    private func startFast() {
        fasting.start()
        // Permission is asked here, at the first moment a notification would
        // actually be useful, rather than on a cold launch.
        Task {
            let granted = await NotificationService.shared.requestAuthorizationIfNeeded()
            if granted { fasting.syncExternalState() }
        }
    }
}

/// The trailing badge: days left in the opening period, or a Pro mark.
private struct AccessBadge: View {
    @Environment(Entitlements.self) private var entitlements
    @Binding var showingPaywall: Bool

    var body: some View {
        Button { showingPaywall = true } label: {
            if entitlements.isPro {
                Pill(text: String(localized: "badge.pro"), symbol: "checkmark.seal.fill", tint: Palette.accentDeep)
            } else if entitlements.isInFullAccessPeriod {
                Pill(
                    text: String(
                        localized: "badge.daysLeft",
                        defaultValue: "\(entitlements.fullAccessDaysRemaining) d"
                    ),
                    symbol: "sparkles",
                    tint: Palette.accent
                )
            } else {
                Pill(text: String(localized: "badge.upgrade"), symbol: "lock.fill", tint: Palette.inkSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Lets the user move the start of a running fast backwards — "I actually
/// stopped eating at 8pm" — which is the single most requested correction in
/// every fasting app.
private struct StartTimeEditor: View {
    @Environment(FastingController.self) private var fasting
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            ZStack {
                SoluraBackground()
                VStack(spacing: 18) {
                    DatePicker(
                        "timer.editStart",
                        selection: $date,
                        in: earliest...Date.now,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .tint(Palette.accentDeep)
                    .card()

                    DisclaimerNote(text: "timer.editStart.note")

                    Spacer()

                    Button("common.save") {
                        fasting.adjustStart(to: date)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(Metrics.screenPadding)
            }
            .navigationTitle("timer.editStart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
        .onAppear { date = fasting.active?.startDate ?? .now }
    }

    /// Two days back is plenty for a correction and stops anyone backdating a
    /// fast into a fictional week-long streak.
    private var earliest: Date {
        Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
    }
}
