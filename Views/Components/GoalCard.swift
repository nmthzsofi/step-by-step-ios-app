import SwiftUI

struct GoalCard: View {
    let goal: Goal
    let isSelected: Bool

    @EnvironmentObject var userManager: UserManager

    private var themeColor: Color {
        goal.isFullyCompleted && goal.totalSteps > 0 ? .green : .blue
    }

    private var remainingText: String {
        let remainingSteps = max(0, goal.totalSteps - goal.currentSteps)
        if remainingSteps == 0 && goal.totalSteps > 0 {
            return String(localized: "Goal Reached!")
        }
        let formatted = userManager.formatProgress(steps: remainingSteps)
        return String(format: String(localized: "%@ remaining"), formatted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 15) {
                Image(systemName: goal.isFullyCompleted ? "checkmark.seal.fill" : goal.icon)
                    .font(.title2)
                    .foregroundColor(themeColor)
                    .frame(width: 50, height: 50)
                    .background(themeColor.opacity(0.1))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(remainingText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }

                Spacer()

                Text("\(Int(min(goal.progress, 1.0) * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(themeColor)
            }

            ProgressView(value: goal.totalSteps > 0 ? min(goal.progress, 1.0) : 0)
                .tint(themeColor)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)

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
        case 0: return .yellow
        case 1: return .gray.opacity(0.7)
        case 2: return .orange.opacity(0.8)
        default: return .blue
        }
    }
}
