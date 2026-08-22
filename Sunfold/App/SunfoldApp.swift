import SwiftData
import SwiftUI

@main
struct SunfoldApp: App {
    @State private var settings = AppSettings.shared
    @State private var entitlements = Entitlements()
    @State private var fasting: FastingController

    private let container: ModelContainer

    init() {
        let container = DataStore.makeContainer()
        self.container = container

        #if DEBUG
        // Screenshot seeding, gated behind a launch argument. Runs before the
        // controller reads state so the first frame already has history.
        if DemoData.isRequested {
            DemoData.seed(into: container.mainContext)
        }
        #endif

        _fasting = State(initialValue: FastingController(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(entitlements)
                .environment(fasting)
                .modelContainer(container)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Palette.accentDeep)
        }
    }
}

struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Entitlements.self) private var entitlements
    @Environment(FastingController.self) private var fasting
    @Environment(\.scenePhase) private var scenePhase

    /// `.timer` for every real launch; the screenshot run asks for a tab by
    /// name so a whole set can be shot without tapping through the app.
    @State private var selectedTab: Tab = .fromDemoScreen(DemoData.requestedScreen)

    enum Tab: Hashable {
        case timer, history, weight, settings

        static func fromDemoScreen(_ screen: DemoData.Screen?) -> Tab {
            switch screen {
            case .history: .history
            case .weight: .weight
            case .settings: .settings
            default: .timer
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TimerScreen()
                .tabItem { Label("tab.timer", systemImage: "timer") }
                .tag(Tab.timer)

            HistoryScreen()
                .tabItem { Label("tab.history", systemImage: "calendar") }
                .tag(Tab.history)

            WeightScreen()
                .tabItem { Label("tab.weight", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.weight)

            SettingsScreen()
                .tabItem { Label("tab.settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .fullScreenCover(isPresented: .constant(!settings.hasCompletedOnboarding)) {
            OnboardingScreen()
        }
        .task {
            await entitlements.refresh()
            await NotificationService.shared.refreshStatus()
        }
        .onOpenURL { url in
            // sunfold://timer — tapping the widget or the Live Activity.
            guard url.scheme == "sunfold" else { return }
            switch url.host {
            case "history": selectedTab = .history
            case "weight": selectedTab = .weight
            default: selectedTab = .timer
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Everything that can go stale while the app is away: the fast may
            // have passed its goal, the access period may have lapsed, and a
            // purchase may have been made on another device.
            fasting.refreshOnForeground()
            entitlements.revalidate()
            Task { await entitlements.refresh() }
        }
    }
}
