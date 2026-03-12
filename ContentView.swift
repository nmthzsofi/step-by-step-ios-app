import SwiftUI

struct ContentView: View {
    @EnvironmentObject var goalManager: GoalManager
    @EnvironmentObject var userManager: UserManager
    @State private var selectedTab = 0

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                MapView(goalManager: goalManager, userManager: userManager)
                    .tabItem { Label("Map", systemImage: "map.fill") }
                    .tag(0)

                GoalsView(goalManager: goalManager, userManager: userManager)
                    .tabItem { Label("Goals", systemImage: "flag.checkered") }
                    .tag(1)

                ProfileView(userManager: userManager, goalManager: goalManager)
                    .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                    .tag(2)
            }
            .accentColor(.black)

            if goalManager.showCelebration {
                CelebrationView(
                    title: goalManager.celebrationTitle,
                    message: goalManager.celebrationMessage
                ) {
                    withAnimation { goalManager.showCelebration = false }
                }
                .zIndex(2)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RootView(
                userManager: mockUserManager(loggedIn: false),
                goalManager: GoalManager()
            )
            .previewDisplayName("Login / Auth View")

            RootView(
                userManager: mockUserManager(loggedIn: true),
                goalManager: GoalManager()
            )
            .previewDisplayName("Onboarding View")

            RootView(
                userManager: mockUserManager(loggedIn: true, onboarded: true),
                goalManager: GoalManager()
            )
            .previewDisplayName("Main Goals View")
        }
    }

    static func mockUserManager(loggedIn: Bool, onboarded: Bool = false) -> UserManager {
        let manager = UserManager()
        manager.isLoggedIn = loggedIn
        manager.hasCompletedOnboarding = onboarded
        return manager
    }
}
