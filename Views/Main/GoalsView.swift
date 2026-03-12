import SwiftUI

struct GoalsView: View {
    @ObservedObject var goalManager: GoalManager
    @ObservedObject var userManager: UserManager

    @State private var showingCreateGoal = false
    @State private var showingJoinGoal = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    ForEach($goalManager.goals) { $goal in
                        NavigationLink(
                            destination: GoalDetailView(
                                goal: $goal,
                                goalManager: goalManager,
                                userManager: userManager
                            )
                        ) {
                            GoalCard(goal: goal, isSelected: false)
                                .environmentObject(userManager)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle(Text("Your Goals"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingCreateGoal = true }) {
                            Label(String(localized: "Create New Journey"), systemImage: "plus.circle")
                        }
                        Button(action: { showingJoinGoal = true }) {
                            Label(String(localized: "Join Existing Group"), systemImage: "person.2.badge.key")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingCreateGoal) {
                CreateGoalView(goalManager: goalManager, userManager: userManager)
            }
            .sheet(isPresented: $showingJoinGoal) {
                JoinGroupView(goalManager: goalManager, userManager: userManager)
            }
        }
    }
}

struct GoalsView_Previews: PreviewProvider {
    static var previews: some View {
        GoalsView(goalManager: GoalManager(), userManager: UserManager())
    }
}
