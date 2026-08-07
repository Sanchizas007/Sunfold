import SwiftUI
import WidgetKit

@main
struct SoluraWidgetBundle: WidgetBundle {
    var body: some Widget {
        FastingTimerWidget()
        FastingLiveActivity()
    }
}
