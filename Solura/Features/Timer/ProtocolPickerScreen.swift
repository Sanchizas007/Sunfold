import SwiftUI

struct ProtocolPickerScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Entitlements.self) private var entitlements
    @Environment(FastingController.self) private var fasting
    @Environment(\.dismiss) private var dismiss

    @State private var showingPaywall = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            ZStack {
                SoluraBackground()

                ScrollView {
                    VStack(spacing: Metrics.stackSpacing) {
                        ForEach(FastingProtocol.allCases) { item in
                            row(for: item)
                        }

                        if settings.selectedProtocol == .custom, entitlements.hasFullAccess {
                            customLengthCard(settings: settings)
                        }

                        DisclaimerNote(text: "protocols.disclaimer", symbol: "heart.text.square")
                            .padding(.top, 4)
                    }
                    .padding(Metrics.screenPadding)
                }
            }
            .navigationTitle("protocols.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPaywall) { PaywallScreen() }
        }
    }

    private func row(for item: FastingProtocol) -> some View {
        let locked = !entitlements.canUse(item)
        let selected = settings.selectedProtocol == item

        return Button {
            if locked {
                showingPaywall = true
            } else {
                select(item)
            }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: item.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(selected ? Palette.accentDeep : Palette.inkSecondary)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(String(localized: item.titleKey))
                            .font(Typography.cardTitle)
                            .foregroundStyle(Palette.ink)
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Palette.inkTertiary)
                        }
                    }
                    Text(String(localized: item.subtitleKey))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                    Text(String(localized: item.blurbKey))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? Palette.accentDeep : Palette.hairline)
            }
            .card()
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .strokeBorder(selected ? Palette.accent.opacity(0.55) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func customLengthCard(settings: AppSettings) -> some View {
        @Bindable var settings = settings

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("protocols.custom.length")
                    .font(Typography.cardTitle)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(DurationFormat.compact(Double(settings.customFastMinutes) * 60))
                    .font(Typography.stat)
                    .foregroundStyle(Palette.accentDeep)
            }

            Slider(
                value: Binding(
                    get: { Double(settings.customFastMinutes) },
                    set: { newValue in
                        let step = Double(CustomFastLimits.stepMinutes)
                        settings.customFastMinutes = Int((newValue / step).rounded() * step)
                        applyToActiveFast()
                    }
                ),
                in: Double(CustomFastLimits.minimumMinutes)...Double(CustomFastLimits.maximumMinutes)
            )
            .tint(Palette.accentDeep)

            HStack {
                Text(DurationFormat.compact(Double(CustomFastLimits.minimumMinutes) * 60))
                Spacer()
                Text(DurationFormat.compact(Double(CustomFastLimits.maximumMinutes) * 60))
            }
            .font(Typography.caption)
            .foregroundStyle(Palette.inkTertiary)

            if Double(settings.customFastMinutes) * 60 >= CustomFastLimits.advisorySeconds {
                DisclaimerNote(text: "protocols.custom.longNotice", symbol: "exclamationmark.triangle")
            }
        }
        .card()
    }

    private func select(_ item: FastingProtocol) {
        settings.selectedProtocol = item
        applyToActiveFast()
    }

    /// Changing schedule mid-fast moves the goal rather than forcing a restart —
    /// the fast that has already happened is real either way.
    private func applyToActiveFast() {
        guard fasting.active != nil else {
            fasting.syncExternalState()
            return
        }
        fasting.retargetActiveFast()
    }
}
