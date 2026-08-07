import SwiftData
import SwiftUI
import UIKit

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Entitlements.self) private var entitlements
    @Environment(FastingController.self) private var fasting
    @Environment(\.openURL) private var openURL

    @Query private var sessions: [FastSession]
    @Query private var weights: [WeightEntry]

    @State private var showingPaywall = false
    @State private var showingDeleteConfirmation = false
    @State private var showingPrivacy = false
    @State private var showingDisclaimer = false
    @State private var exportURL: URL?

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            ZStack {
                SunfoldBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        proCard

                        group("settings.section.fasting") {
                            NavigationLink {
                                ProtocolSettingsPage()
                            } label: {
                                row(
                                    icon: settings.selectedProtocol.symbol,
                                    title: "settings.protocol",
                                    value: settings.protocolLabel
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        group("settings.section.notifications") {
                            toggle("settings.notify.complete", isOn: $settings.notifyOnFastComplete)
                            divider
                            toggle("settings.notify.before", isOn: $settings.notifyBeforeFastEnds)
                            divider
                            toggle("settings.notify.window", isOn: $settings.notifyOnEatingWindowEnd)
                            divider
                            toggle("settings.liveActivity", isOn: Binding(
                                get: { settings.liveActivityEnabled },
                                set: { newValue in
                                    settings.liveActivityEnabled = newValue
                                    if !newValue { LiveActivityController.shared.endAll() }
                                }
                            ))

                            if NotificationService.shared.authorizationStatus == .denied {
                                divider
                                Button {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        openURL(url)
                                    }
                                } label: {
                                    row(
                                        icon: "exclamationmark.triangle",
                                        title: "settings.notify.denied",
                                        value: nil,
                                        tint: Palette.caution
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onChange(of: settings.notifyOnFastComplete) { _, _ in fasting.syncExternalState() }
                        .onChange(of: settings.notifyBeforeFastEnds) { _, _ in fasting.syncExternalState() }
                        .onChange(of: settings.notifyOnEatingWindowEnd) { _, _ in fasting.syncExternalState() }

                        group("settings.section.appearance") {
                            picker("settings.theme", selection: $settings.appearance) {
                                ForEach(AppearanceSetting.allCases) { option in
                                    Text(String(localized: option.titleKey)).tag(option)
                                }
                            }
                            divider
                            picker("settings.units", selection: $settings.weightUnit) {
                                ForEach(WeightUnit.allCases) { option in
                                    Text(String(localized: option.titleKey)).tag(option)
                                }
                            }
                        }

                        group("settings.section.data") {
                            if let exportURL {
                                ShareLink(item: exportURL) {
                                    row(icon: "square.and.arrow.up", title: "settings.export", value: nil)
                                }
                                .buttonStyle(.plain)
                            } else {
                                row(icon: "square.and.arrow.up", title: "settings.export", value: nil)
                                    .opacity(0.5)
                            }
                            divider
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                row(
                                    icon: "trash",
                                    title: "settings.deleteAll",
                                    value: nil,
                                    tint: Palette.caution
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        group("settings.section.about") {
                            Button { showingDisclaimer = true } label: {
                                row(icon: "heart.text.square", title: "settings.disclaimer", value: nil)
                            }
                            .buttonStyle(.plain)
                            divider
                            Button { showingPrivacy = true } label: {
                                row(icon: "hand.raised", title: "settings.privacy", value: nil)
                            }
                            .buttonStyle(.plain)
                            divider
                            Button { openURL(Legal.termsURL) } label: {
                                row(icon: "doc.text", title: "settings.terms", value: nil)
                            }
                            .buttonStyle(.plain)
                            divider
                            Button {
                                openURL(URL(string: "mailto:\(Legal.supportEmail)") ?? Legal.supportURL)
                            } label: {
                                row(icon: "envelope", title: "settings.support", value: nil)
                            }
                            .buttonStyle(.plain)
                            divider
                            row(icon: "info.circle", title: "settings.version", value: versionString)
                        }

                        Text("settings.footer")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.inkTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding(Metrics.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("settings.title")
            .sheet(isPresented: $showingPaywall) { PaywallScreen() }
            .sheet(isPresented: $showingPrivacy) { PrivacyPolicyScreen() }
            .sheet(isPresented: $showingDisclaimer) { HealthDisclaimerScreen() }
            .confirmationDialog(
                "settings.deleteAll.confirm.title",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("settings.deleteAll.confirm.action", role: .destructive) {
                    fasting.deleteAllData()
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("settings.deleteAll.confirm.message")
            }
            .task(id: sessions.count + weights.count) {
                exportURL = ExportService.writeTemporaryFile(
                    sessions: sessions,
                    weights: weights,
                    unit: settings.weightUnit
                )
            }
        }
    }

    // MARK: Pro card

    private var proCard: some View {
        Button { showingPaywall = true } label: {
            HStack(spacing: 13) {
                Image(systemName: entitlements.isPro ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 42, height: 42)
                    .background(LinearGradient.fasting, in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entitlements.isPro ? "settings.pro.active" : "settings.pro.title")
                        .font(Typography.cardTitle)
                        .foregroundStyle(Palette.ink)
                    Text(proSubtitle)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
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

    private var proSubtitle: LocalizedStringKey {
        if entitlements.isPro { return "settings.pro.activeBody" }
        if entitlements.isInFullAccessPeriod { return "settings.pro.trialBody" }
        return "settings.pro.body"
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: Building blocks

    private func group<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Typography.overline)
                .textCase(.uppercase)
                .foregroundStyle(Palette.inkSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) { content() }
                .card(padding: 0)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 1)
            .padding(.leading, 48)
    }

    private func row(
        icon: String,
        title: LocalizedStringKey,
        value: String?,
        tint: Color = Palette.inkSecondary
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(title)
                .font(Typography.body)
                .foregroundStyle(tint == Palette.caution ? Palette.caution : Palette.ink)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(Typography.body)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .padding(.horizontal, Metrics.cardPadding)
        .frame(minHeight: Self.rowHeight)
        .contentShape(.rect)
    }

    /// One height for every kind of settings row — plain, toggle and picker —
    /// so the dividers land on an even rhythm instead of following whatever
    /// each control happens to measure.
    private static let rowHeight: CGFloat = 50

    private func toggle(_ title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
        }
        .tint(Palette.accentDeep)
        .padding(.horizontal, Metrics.cardPadding)
        .frame(minHeight: Self.rowHeight)
    }

    private func picker<Value: Hashable, Content: View>(
        _ title: LocalizedStringKey,
        selection: Binding<Value>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        // Laid out by hand rather than relying on Picker's own label: outside a
        // Form, a menu-style Picker draws only its value, which left the row
        // showing "Kilograms" with nothing to say what it referred to.
        HStack(spacing: 12) {
            Text(title)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            Picker(selection: selection) {
                content()
            } label: {
                EmptyView()
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Palette.accentDeep)
            // Without this the selected value wraps onto a second line and
            // pushes through the divider below it.
            .lineLimit(1)
            .fixedSize()
        }
        .padding(.horizontal, Metrics.cardPadding)
        .frame(minHeight: Self.rowHeight)
    }
}

/// Protocol picker reached from settings rather than from the ring.
private struct ProtocolSettingsPage: View {
    var body: some View {
        ProtocolPickerScreen()
    }
}
