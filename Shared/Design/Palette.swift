import SwiftUI

/// Solura's colour system.
///
/// Colours live in code rather than an asset catalog so the app and the widget
/// extension share one definition without duplicating a catalog per target.
/// Every colour is defined for both appearances: light is a warm sand field,
/// dark is a warm charcoal — never pure black, which reads cold and harsh at
/// night, and this app is opened at 6am and 11pm more than any other hour.
nonisolated enum Palette {

    // MARK: Surfaces

    /// App background. Warm cream in light, warm charcoal in dark.
    static let canvas = dynamic(light: 0xFBF5EE, dark: 0x211B18)
    /// Card and sheet background, one step forward from the canvas.
    static let surface = dynamic(light: 0xFFFCF8, dark: 0x2C2421)
    /// Recessed fills: segmented controls, unfilled progress tracks, chips.
    static let surfaceAlt = dynamic(light: 0xF3E8DC, dark: 0x382E29)
    /// Hairline separators and card borders.
    static let hairline = dynamic(light: 0xEADCCC, dark: 0x40352F)

    // MARK: Text

    /// Primary text. A warm near-black, not #000.
    static let ink = dynamic(light: 0x3B2E27, dark: 0xF5EBE1)
    /// Secondary text: captions, units, inactive labels.
    static let inkSecondary = dynamic(light: 0x8B7668, dark: 0xB09C8E)
    /// Tertiary text: timestamps, footnotes, placeholder.
    static let inkTertiary = dynamic(light: 0xAE9C8D, dark: 0x87766B)

    // MARK: Accent

    /// Decorative accent — rings, icons, highlights. Not for small text.
    static let accent = dynamic(light: 0xE08A5F, dark: 0xF2A883)
    /// Accent for filled buttons and links, contrast-checked against `canvas`
    /// and against white button labels (≈5:1).
    static let accentDeep = dynamic(light: 0xB75E3D, dark: 0xF2A883)
    /// Label colour that sits on top of an `accentDeep` fill.
    static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x211B18)

    // MARK: Semantic

    /// The fasting ring. Apricot → terracotta.
    static let fastingGradient = [
        dynamic(light: 0xFFC078, dark: 0xFFC078),
        dynamic(light: 0xEE8163, dark: 0xF08E6E)
    ]

    /// The eating-window ring. Soft sage — calm and clearly "not fasting",
    /// without the alarm-red / go-green cliché.
    static let eatingGradient = [
        dynamic(light: 0xBFD4AC, dark: 0xA6C293),
        dynamic(light: 0x86AE86, dark: 0x7FA97F)
    ]

    /// Sage, for eating-window labels and icons.
    static let eating = dynamic(light: 0x6E9670, dark: 0x9DC29D)

    /// Positive/streak accent, used sparingly.
    static let success = dynamic(light: 0x6E9670, dark: 0x9DC29D)

    /// Cautionary tone for long-fast advisories. Deliberately muted: a warm
    /// clay rather than a red, so a health notice reads as care, not alarm.
    static let caution = dynamic(light: 0xB4674F, dark: 0xE39C7F)

    // MARK: - Construction

    /// Builds a colour that resolves per appearance.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    /// `nonisolated` so the dynamic-provider closure above — which UIKit may
    /// resolve on any thread as the trait collection changes — can build colours
    /// without hopping to the main actor.
    fileprivate nonisolated convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension ShapeStyle where Self == LinearGradient {
    /// The fasting ring gradient, oriented top-leading → bottom-trailing.
    static var fasting: LinearGradient {
        LinearGradient(
            colors: Palette.fastingGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// The eating-window ring gradient.
    static var eating: LinearGradient {
        LinearGradient(
            colors: Palette.eatingGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
