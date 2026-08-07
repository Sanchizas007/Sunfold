import SwiftUI

// MARK: - Cards

nonisolated struct CardBackground: ViewModifier {
    var padding: CGFloat = Metrics.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: .rect(cornerRadius: Metrics.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            )
            // A warm, low shadow — enough to lift the card off the sand
            // background without the hard grey drop shadow that would make the
            // whole screen read cold.
            .shadow(color: Color(red: 0.42, green: 0.29, blue: 0.20).opacity(0.06), radius: 10, y: 4)
    }
}

extension View {
    nonisolated func card(padding: CGFloat = Metrics.cardPadding) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

// MARK: - Buttons

nonisolated struct PrimaryButtonStyle: ButtonStyle {
    var tint: LinearGradient?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.cardTitle)
            .foregroundStyle(Palette.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if let tint {
                    RoundedRectangle(cornerRadius: Metrics.controlRadius).fill(tint)
                } else {
                    RoundedRectangle(cornerRadius: Metrics.controlRadius).fill(Palette.accentDeep)
                }
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

nonisolated struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.cardTitle)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Palette.surfaceAlt, in: .rect(cornerRadius: Metrics.controlRadius))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

nonisolated struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.captionStrong)
            .foregroundStyle(Palette.accentDeep)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Pieces

/// The uppercase micro-label + big number pairing used across history.
nonisolated struct StatTile: View {
    var title: LocalizedStringKey
    var value: String
    var symbol: String?
    var tint: Color = Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(Typography.overline)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Text(value)
                .font(Typography.stat)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

nonisolated struct SectionHeader: View {
    var title: LocalizedStringKey
    var action: (() -> Void)?
    var actionTitle: LocalizedStringKey?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.sectionTitle)
                .foregroundStyle(Palette.ink)
            Spacer()
            if let action, let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(QuietButtonStyle())
            }
        }
    }
}

/// A soft warm chip, used for phase names and protocol badges.
nonisolated struct Pill: View {
    var text: String
    var symbol: String?
    var tint: Color

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
            }
            Text(text).font(Typography.captionStrong)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(tint.opacity(0.13), in: .capsule)
    }
}

/// The standing health notice. Shown in onboarding, on the phases screen and in
/// settings — Solura is an educational timer, not a clinician, and says so
/// wherever it talks about the body.
nonisolated struct DisclaimerNote: View {
    var text: LocalizedStringKey
    var symbol: String = "info.circle"

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Standard empty state: a soft symbol, a line of explanation, no scolding.
nonisolated struct EmptyStateView: View {
    var symbol: String
    var title: LocalizedStringKey
    var message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Palette.accent.opacity(0.7))
            Text(title)
                .font(Typography.cardTitle)
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

/// The app's background, used by every screen so the warm field is unbroken.
nonisolated struct SoluraBackground: View {
    var body: some View {
        Palette.canvas
            .overlay(alignment: .top) {
                // A barely-there warm bloom behind the top of the screen; it
                // stops the large empty areas of the timer screen reading flat.
                LinearGradient(
                    colors: [Palette.accent.opacity(0.13), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 320)
            }
            .ignoresSafeArea()
    }
}
