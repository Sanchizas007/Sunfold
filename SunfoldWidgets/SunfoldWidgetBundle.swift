import SwiftUI
import WidgetKit

@main
struct SunfoldWidgetBundle: WidgetBundle {
    var body: some Widget {
        FastingTimerWidget()
        FastingLiveActivity()
    }
}
