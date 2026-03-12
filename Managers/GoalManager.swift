import Foundation
import SwiftUI
import CoreLocation
import FirebaseFirestore

class GoalManager: ObservableObject {
    private var db = Firestore.firestore()

    @Published var selectedGoalIndex: Int = 0
    @Published var showCelebration: Bool = false
    @Published var celebrationTitle: String = ""
    @Published var celebrationMessage: String = ""
    @Published var goals: [Goal] = []

    var currentGoal: Goal? {
        guard selectedGoalIndex < goals.count else { return nil }
        return goals[selectedGoalIndex]
    }

    init() {
    }

    // MARK: - Steps

    func addSteps(_ steps: Int, userUID: String) {
        print("DEBUG addSteps: called with \(steps) steps, uid: \(userUID)")
        print("DEBUG addSteps: total goals: \(goals.count)")

        for i in goals.indices {
            print("DEBUG addSteps: goal[\(i)] has \(goals[i].members.count) members")
            for member in goals[i].members {
                print("DEBUG addSteps: member id: \(member.id ?? "nil"), firstName: \(member.firstName)")
                print("DEBUG addSteps: id match? \(member.id == userUID)")
            }
        }

        withAnimation(.easeInOut(duration: 1.0)) {
            for i in goals.indices {
                // FIX #5: skip fully completed goals
                if goals[i].isFullyCompleted { continue }

                if let userIndex = goals[i].members.firstIndex(where: { $0.id == userUID }) {
                    // FIX #5: skip if this member already finished
                    if goals[i].members[userIndex].hasFinished { continue }

                    print("DEBUG addSteps: FOUND user at index \(userIndex) in goal \(i)")
                    print("DEBUG addSteps: goal id = \(goals[i].id ?? "NIL")")
                    print("DEBUG addSteps: member id = \(goals[i].members[userIndex].id ?? "NIL")")

                    let oldSteps = goals[i].members[userIndex].steps
                    goals[i].members[userIndex].steps += steps

                    // FIX #1: check if member just finished and update flag locally
                    if oldSteps < goals[i].totalSteps && goals[i].members[userIndex].steps >= goals[i].totalSteps {
                        goals[i].members[userIndex].hasFinished = true
                        triggerCelebration(for: i, isWinner: true)
                    }

                    if let goalId = goals[i].id {
                        print("DEBUG addSteps: calling updateStepsInFirebase")
                        self.updateStepsInFirebase(goalId: goalId, memberUID: userUID, newSteps: steps)
                    } else {
                        print("DEBUG addSteps: SKIPPING updateSteps - goalId is NIL")
                    }
                } else {
                    print("DEBUG addSteps: user NOT found in goal \(i)")
                }
                updateGoalProgress(at: i, userUID: userUID)
                checkOverallCompletion(at: i)
            }
        }
        objectWillChange.send()
    }

    // MARK: - Firebase Functions

    func fetchAllGoalsFromFirebase(userUID: String) {
        db.collection("goals")
            .whereField("memberUIDs", arrayContains: userUID)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else {
                    print("DEBUG fetchAllGoals: No goal documents found")
                    return
                }
                DispatchQueue.main.async {
                    self.goals = docs.compactMap { try? $0.data(as: Goal.self) }
                    print("DEBUG fetchAllGoals: fetched \(self.goals.count) goals")
                    for goal in self.goals {
                        print("DEBUG fetchAllGoals: goal \(goal.id ?? "nil") has \(goal.members.count) members")
                        if let id = goal.id {
                            self.listenToGoalUpdates(goalId: id)
                        }
                    }
                }
            }
    }

    func clearGoals() {
        self.goals = []
        self.selectedGoalIndex = 0
    }

    func updateStepsInFirebase(goalId: String, memberUID: String, newSteps: Int) {
        print("DEBUG updateSteps: called for goalId: \(goalId), memberUID: \(memberUID), newSteps: \(newSteps)")

        let goalRef = db.collection("goals").document(goalId)

        goalRef.getDocument { snapshot, error in
            if let error = error {
                print("DEBUG updateSteps: error fetching goal: \(error)")
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                print("DEBUG updateSteps: goal document does not exist")
                return
            }
            guard let goal = try? snapshot.data(as: Goal.self) else {
                print("DEBUG updateSteps: could not decode goal")
                print("DEBUG updateSteps: raw data: \(snapshot.data() ?? [:])")
                return
            }

            print("DEBUG updateSteps: goal decoded, members count: \(goal.members.count)")
            for m in goal.members {
                print("DEBUG updateSteps: member in fetched goal - id: \(m.id ?? "nil"), steps: \(m.steps)")
            }

            var updatedMembers = goal.members
            guard let memberIndex = updatedMembers.firstIndex(where: { $0.id == memberUID }) else {
                print("DEBUG updateSteps: member \(memberUID) NOT FOUND in fetched goal")
                return
            }

            print("DEBUG updateSteps: found member at index \(memberIndex), current steps: \(updatedMembers[memberIndex].steps)")
            updatedMembers[memberIndex].steps += newSteps
            print("DEBUG updateSteps: new steps will be: \(updatedMembers[memberIndex].steps)")

            // FIX #1: check and update hasFinished inside Firestore too
            let memberJustFinished = updatedMembers[memberIndex].steps >= goal.totalSteps
            if memberJustFinished {
                updatedMembers[memberIndex].hasFinished = true
                print("DEBUG updateSteps: member has finished the goal")
            }

            // FIX #3: check if ALL members finished so isFullyCompleted can be set
            let allFinished = goal.totalSteps > 0 && updatedMembers.allSatisfy { $0.steps >= goal.totalSteps }

            let encodedMembers = updatedMembers.map { member -> [String: Any] in
                var dict: [String: Any] = [
                    "firstName": member.firstName,
                    "steps": member.steps,
                    "hasFinished": member.hasFinished
                ]
                if let id = member.id { dict["id"] = id }
                if let imageData = member.imageData { dict["imageData"] = imageData }
                return dict
            }

            // FIX #1 & #3: write members AND isFullyCompleted in one atomic update
            var updatePayload: [String: Any] = ["members": encodedMembers]
            if allFinished {
                updatePayload["isFullyCompleted"] = true
                print("DEBUG updateSteps: all members finished, setting isFullyCompleted = true")
            }

            goalRef.updateData(updatePayload) { error in
                if let error = error {
                    print("DEBUG updateSteps: ERROR writing to Firestore: \(error)")
                } else {
                    print("DEBUG updateSteps: SUCCESS writing steps to Firestore")
                }
            }

            // Update lifetime steps on user document
            self.db.collection("users").document(memberUID).setData([
                "totalStepsAllTime": FieldValue.increment(Int64(newSteps))
            ], merge: true) { error in
                if let error = error {
                    print("DEBUG updateSteps: ERROR updating totalStepsAllTime: \(error)")
                } else {
                    print("DEBUG updateSteps: SUCCESS updating totalStepsAllTime")
                }
            }
        }
    }
    func listenToGoalUpdates(goalId: String) {
        db.collection("goals").document(goalId)
            .addSnapshotListener { snapshot, error in
                guard let document = snapshot, document.exists,
                      let updatedGoal = try? document.data(as: Goal.self) else { return }

                DispatchQueue.main.async {
                    if let index = self.goals.firstIndex(where: { $0.id == goalId }) {
                        self.goals[index] = updatedGoal

                        switch self.goals[index].type {
                        case .individual:
                            self.goals[index].currentSteps = updatedGoal.members.first?.steps ?? 0
                        case .cooperative:
                            self.goals[index].currentSteps = updatedGoal.members.reduce(0) { $0 + $1.steps }
                        case .race:
                            self.goals[index].currentSteps = updatedGoal.members.map { $0.steps }.max() ?? 0
                        }
                    }
                }
            }
    }

    func joinGoal(code: String, userProfile: Member) {
        db.collection("goals").whereField("shareCode", isEqualTo: code).getDocuments { snapshot, error in
            guard let document = snapshot?.documents.first else {
                print("Goal not found!")
                return
            }

            let goalId = document.documentID

            self.db.collection("goals").document(goalId).getDocument { snapshot, error in
                guard var goal = try? snapshot?.data(as: Goal.self) else { return }

                if goal.members.contains(where: { $0.id == userProfile.id }) {
                    print("User already a member of this goal")
                    return
                }

                goal.members.append(userProfile)

                let encodedMembers = goal.members.map { member -> [String: Any] in
                    var dict: [String: Any] = [
                        "firstName": member.firstName,
                        "steps": member.steps,
                        "hasFinished": member.hasFinished
                    ]
                    if let id = member.id { dict["id"] = id }
                    if let imageData = member.imageData { dict["imageData"] = imageData }
                    return dict
                }

                // NEW: also append the new UID to memberUIDs
                let memberUIDs = goal.members.compactMap { $0.id }

                self.db.collection("goals").document(goalId).updateData([
                    "members": encodedMembers,
                    "memberUIDs": memberUIDs
                ]) { error in
                    if let error = error {
                        print("Error joining goal: \(error)")
                    } else {
                        self.listenToGoalUpdates(goalId: goalId)
                    }
                }
            }
        }
    }
    
    func saveGoalToFirebase(goal: Goal) {
        print("DEBUG saveGoal: member id being saved: \(goal.members.first?.id ?? "nil")")

        let memberUIDs = goal.members.compactMap { $0.id }

        let encodedMembers = goal.members.map { member -> [String: Any] in
            var dict: [String: Any] = [
                "firstName": member.firstName,
                "steps": member.steps,
                "hasFinished": member.hasFinished
            ]
            if let id = member.id { dict["id"] = id }
            if let imageData = member.imageData { dict["imageData"] = imageData }
            return dict
        }

        // Build the entire goal dictionary manually — no Encoder needed
        let goalData: [String: Any] = [
            "name": goal.name,
            "startCoordinate": goal.startCoordinate,
            "coordinates": goal.coordinates,
            "totalSteps": goal.totalSteps,
            "currentSteps": goal.currentSteps,
            "icon": goal.icon,
            "isGroupGoal": goal.isGroupGoal,
            "shareCode": goal.shareCode,
            "type": goal.type.rawValue,
            "isFullyCompleted": goal.isFullyCompleted,
            "hasShownCelebration": goal.hasShownCelebration,
            "members": encodedMembers,
            "memberUIDs": memberUIDs
        ]

        let ref = db.collection("goals").addDocument(data: goalData) { error in
            if let error = error {
                print("DEBUG saveGoal: Firebase Save Error: \(error.localizedDescription)")
            } else {
                print("DEBUG saveGoal: Successfully synced to Firebase!")
            }
        }

        var localGoal = goal
        localGoal.id = ref.documentID

        DispatchQueue.main.async {
            self.goals.append(localGoal)
            self.selectedGoalIndex = self.goals.count - 1
            self.listenToGoalUpdates(goalId: ref.documentID)
        }
    }
    // MARK: - Internal Logic

    private func updateGoalProgress(at index: Int, userUID: String) {
        switch goals[index].type {
        case .individual:
            goals[index].currentSteps = goals[index].members.first(where: { $0.id == userUID })?.steps ?? 0
        case .cooperative:
            goals[index].currentSteps = goals[index].members.reduce(0) { $0 + $1.steps }
        case .race:
            goals[index].currentSteps = goals[index].members.map { $0.steps }.max() ?? 0
            for mIndex in goals[index].members.indices {
                let member = goals[index].members[mIndex]
                if member.id != userUID && member.steps >= goals[index].totalSteps && !member.hasFinished {
                    goals[index].members[mIndex].hasFinished = true
                    triggerCelebration(for: index, isWinner: false, finisherName: member.firstName)
                }
            }
        }
    }

    private func checkOverallCompletion(at index: Int) {
        guard goals[index].totalSteps > 0 else { return }
        let allFinished = goals[index].members.allSatisfy { $0.steps >= goals[index].totalSteps }
        if allFinished && !goals[index].isFullyCompleted {
            goals[index].isFullyCompleted = true
        }
    }

    private func triggerCelebration(for goalIndex: Int, isWinner: Bool, finisherName: String? = nil) {
        let goal = goals[goalIndex]
        guard !goal.hasShownCelebration else { return }

        if goal.type == .race {
            if isWinner {
                celebrationTitle = "Champion! 🏆"
                celebrationMessage = "You crossed the finish line first in \(goal.name)!"
            } else {
                celebrationTitle = "Someone Arrived! 🏁"
                celebrationMessage = "\(finisherName ?? "A friend") reached the destination!"
            }
        } else {
            celebrationTitle = "Goal Reached! 🎉"
            celebrationMessage = "Congratulations! You've completed the \(goal.name) journey."
        }

        self.showCelebration = true
        goals[goalIndex].hasShownCelebration = true
    }

    func createNewGoal(userProfile: Member) {
        let newGoal = Goal(
            name: "New Adventure",
            startCoordinate: CLLocationCoordinate2D(latitude: 45.1, longitude: 15.2).toGeoPoint,
            coordinates: CLLocationCoordinate2D(latitude: 45.1, longitude: 15.2).toGeoPoint,
            totalSteps: 100000,
            currentSteps: 0,
            icon: "figure.walk",
            isGroupGoal: false,
            shareCode: generateRandomCode(),
            type: .individual,
            members: [userProfile]
        )
        saveGoalToFirebase(goal: newGoal)
    }

    func calculateSteps(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Int {
        let start = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let end = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return Int(start.distance(from: end) / 0.76)
    }

    func generateRandomCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}
