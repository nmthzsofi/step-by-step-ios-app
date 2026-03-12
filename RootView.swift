//
//  RootView.swift
//  lepesrol-lepesre
//
//  Created by Zsófia Németh on 2026. 03. 08..
//

import SwiftUI

struct RootView: View {
    @ObservedObject var userManager: UserManager
    @ObservedObject var goalManager: GoalManager

    var body: some View {
        Group {
            if !userManager.isLoggedIn {
                AuthView(userManager: userManager, goalManager: goalManager)
                    .onAppear {
                        // Clear goals when user lands on auth screen (after logout)
                        goalManager.clearGoals()
                    }
            } else if !userManager.hasCompletedOnboarding {
                OnboardingView(goalManager: goalManager, userManager: userManager)
            } else {
                ContentView()
                    .environmentObject(goalManager)
                    .environmentObject(userManager)
                    .onAppear {
                        // Fetch goals filtered by this user's UID
                        if let uid = userManager.firebaseUser?.uid {
                            goalManager.fetchAllGoalsFromFirebase(userUID: uid)
                        }
                    }
            }
        }
    }
}

#Preview("Logged Out State") {
    let userManager = UserManager()
    let goalManager = GoalManager()
    userManager.isLoggedIn = false
    return RootView(userManager: userManager, goalManager: goalManager)
        .environmentObject(userManager)
        .environmentObject(goalManager)
}

#Preview("Onboarding State") {
    let userManager = UserManager()
    let goalManager = GoalManager()
    userManager.isLoggedIn = true
    userManager.hasCompletedOnboarding = false
    return RootView(userManager: userManager, goalManager: goalManager)
        .environmentObject(userManager)
        .environmentObject(goalManager)
}

#Preview("Main Content State") {
    let userManager = UserManager()
    let goalManager = GoalManager()
    userManager.isLoggedIn = true
    userManager.hasCompletedOnboarding = true
    return RootView(userManager: userManager, goalManager: goalManager)
        .environmentObject(userManager)
        .environmentObject(goalManager)
}
