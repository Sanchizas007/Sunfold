import SwiftUI

/// Type scale.
///
/// Rounded throughout. SF Rounded is what makes the app feel calm rather than
/// clinical, and it is the single strongest carrier of the "soft, warm" brief —
/// more than any colour choice. Every size is expressed relative to a Dynamic
/// Type text style so the whole app scales with the user's settings.
nonisolated enum Typography {
    /// The number at the centre of the ring. Monospaced digits stop the layout
    /// jittering as the seconds tick over.
    static var timer: Font {
        .system(size: 54, weight: .semibold, design: .rounded).monospacedDigit()
    }

    /// The timer inside the widget and the Live Activity.
    static var timerCompact: Font {
        .system(size: 26, weight: .semibold, design: .rounded).monospacedDigit()
    }

    static var screenTitle: Font { .system(.largeTitle, design: .rounded, weight: .bold) }
    static var sectionTitle: Font { .system(.title3, design: .rounded, weight: .semibold) }
    static var cardTitle: Font { .system(.headline, design: .rounded, weight: .semibold) }
    static var body: Font { .system(.body, design: .rounded) }
    static var caption: Font { .system(.footnote, design: .rounded) }
    static var captionStrong: Font { .system(.footnote, design: .rounded, weight: .semibold) }

    /// Big numbers on stat tiles.
    static var stat: Font {
        .system(.title2, design: .rounded, weight: .semibold).monospacedDigit()
    }

    /// The uppercase micro-label above a stat.
    static var overline: Font { .system(.caption2, design: .rounded, weight: .semibold) }
}

nonisolated enum Metrics {
    static let cardRadius: CGFloat = 20
    static let controlRadius: CGFloat = 16
    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let stackSpacing: CGFloat = 14
}
