//
//  lepesrol_lepesreApp.swift
//  lepesrol-lepesre
//
//  Created by Zsófia Németh on 2026. 03. 05..
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct lepesrol_lepesreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Create the only two instances that should exist
    @StateObject var goalManager = GoalManager()
    @StateObject var userManager = UserManager()

    var body: some Scene {
        WindowGroup {
            // Use RootView here instead of duplicating the logic
            RootView(userManager: userManager, goalManager: goalManager)
                .environmentObject(goalManager)
                .environmentObject(userManager)
        }
    }
}
