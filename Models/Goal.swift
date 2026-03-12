//
//  Goal.swift
//  lepesrol-lepesre
//
//  Created by Zsófia Németh on 2026. 03. 05..
//
import SwiftUI
import CoreLocation
import FirebaseFirestore

enum GoalType: String, CaseIterable, Codable {
    case individual = "Individual"
    case cooperative = "Cooperative"
    case race = "Race"

    var localizedName: LocalizedStringKey { LocalizedStringKey(rawValue) }
}

struct Goal: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var startCoordinate: GeoPoint
    var coordinates: GeoPoint
    var totalSteps: Int
    var currentSteps: Int
    var icon: String
    var isGroupGoal: Bool
    var shareCode: String
    var type: GoalType = .individual
    var members: [Member] = []
    
    // NEW: True only when EVERY member reaches totalSteps
    var isFullyCompleted: Bool = false
    
    // NEW: Tracks if we already showed the "Congratulations" pop-up for this goal
    var hasShownCelebration: Bool = false
    
    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentSteps) / Double(totalSteps)
    }
}
