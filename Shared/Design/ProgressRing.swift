import SwiftUI

/// The circular progress ring at the centre of the app.
///
/// Draws a track, a gradient arc trimmed to `progress`, a warm glow at the head
/// of the arc, and optional tick marks where the metabolic phases change. The
/// caller supplies the centre content, so the same ring serves the main timer,
/// the widget and the Live Activity at three different sizes.
nonisolated struct ProgressRing<Content: View>: View {
    var progress: Double
    var colors: [Color]
    var lineWidth: CGFloat = 22
    /// Fractions of the ring, 0…1, where a phase boundary falls.
    var phaseTicks: [Double] = []
    var showsHead: Bool = true
    @ViewBuilder var content: () -> Content

    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let radius = (side - lineWidth) / 2
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                Circle()
                    .stroke(Palette.surfaceAlt, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: side - lineWidth, height: side - lineWidth)

                ForEach(phaseTicks.filter { $0 > 0.001 && $0 < 0.999 }, id: \.self) { tick in
                    Capsule()
                        .fill(Palette.hairline)
                        .frame(width: 2, height: lineWidth * 0.44)
                        .offset(y: -radius)
                        .rotationEffect(.degrees(360 * tick))
                }

                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(
                        AngularGradient(
                            colors: colors + [colors.first ?? .clear],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: side - lineWidth, height: side - lineWidth)

                // Held back until the arc is long enough to read as an arc.
                // Below that the round cap and the dot overlap into a shape
                // that looks like a switch rather than a timer.
                if showsHead && clamped > 0.025 {
                    Circle()
                        .fill(.white)
                        .frame(width: lineWidth * 0.3, height: lineWidth * 0.3)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                        .offset(y: -radius)
                        .rotationEffect(.degrees(360 * clamped))
                        .opacity(0.9)
                }

                content()
                    .frame(width: side - lineWidth * 2.6)
                    .position(center)
                    // The arc animation below covers the whole stack, and the
                    // centre content changes in step with `clamped` — once a
                    // second, on the timer. Without this the seconds digit
                    // crossfades into the next one and reads as a smear.
                    .animation(nil, value: clamped)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeInOut(duration: 0.35), value: clamped)
    }
}

extension ProgressRing where Content == EmptyView {
    init(
        progress: Double,
        colors: [Color],
        lineWidth: CGFloat = 22,
        phaseTicks: [Double] = [],
        showsHead: Bool = true
    ) {
        self.init(
            progress: progress,
            colors: colors,
            lineWidth: lineWidth,
            phaseTicks: phaseTicks,
            showsHead: showsHead
        ) { EmptyView() }
    }
}

extension MetabolicPhase {
    /// Where each phase boundary falls on a ring of the given target length.
    /// Boundaries past the goal are dropped by the ring itself.
    static func tickFractions(targetSeconds: TimeInterval) -> [Double] {
        guard targetSeconds > 0 else { return [] }
        return allCases
            .dropFirst()
            .map { $0.startHour * 3600 / targetSeconds }
            .filter { $0 < 1 }
    }
}
