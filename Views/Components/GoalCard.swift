import SwiftUI

struct GoalCard: View {
    let goal: Goal
    let isSelected: Bool
    
    // 1. Access the global settings from UserManager
    @EnvironmentObject var userManager: UserManager
    
    
    // Determine the theme color based on completion
    private var themeColor: Color {
        goal.isFullyCompleted && goal.totalSteps > 0 ? .green : .blue
    }
    
    // 2. Helper to calculate remaining distance/steps
    private var remainingText: String {
        let remainingSteps = max(0, goal.totalSteps - goal.currentSteps)
        if remainingSteps == 0 && goal.totalSteps > 0 {
            return "Goal Reached!"
        }
        return userManager.formatProgress(steps: remainingSteps) + " left"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 15) {
                // ICON - Swaps to green when finished
                Image(systemName: goal.isFullyCompleted ? "checkmark.seal.fill" : goal.icon)
                    .font(.title2)
                    .foregroundColor(themeColor)
                    .frame(width: 50, height: 50)
                    .background(themeColor.opacity(0.1))
                    .cornerRadius(12)
                
                // TITLE & DYNAMIC SUBTITLE
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Shows "5,000 steps left" or "3.45 km left"
                    Text(remainingText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                // PROGRESS PERCENTAGE
                Text("\(Int(min(goal.progress, 1.0) * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(themeColor)
            }
            
            // MAIN PROGRESS BAR
            ProgressView(value: goal.totalSteps > 0 ? min(goal.progress, 1.0) : 0)
                .tint(themeColor)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
            
            // TOP ACHIEVERS PREVIEW
            if goal.type == .race && !goal.members.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Leaderboard")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    let topThree = Array(goal.members.sorted(by: { $0.steps > $1.steps }).prefix(3))
                    
                    ForEach(topThree.indices, id: \.self) { index in
                        HStack(spacing: 8) {
                            // Rank Circle
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(rankColor(for: index))
                                .clipShape(Circle())
                            
                            Text(topThree[index].firstName)
                                .font(.caption2)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // NEW: Also show the leader's progress in the chosen unit
                            Text(userManager.formatProgress(steps: topThree[index].steps))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(goal.isFullyCompleted ? Color.green : (isSelected ? Color.blue : Color.clear), lineWidth: 2)
        )
        .shadow(color: goal.isFullyCompleted ? .green.opacity(0.1) : .black.opacity(0.05), radius: 8, y: 4)
    }
    
    func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return .yellow // Gold
        case 1: return .gray.opacity(0.7) // Silver
        case 2: return .orange.opacity(0.8) // Bronze
        default: return .blue
        }
    }
}
