import SwiftUI

struct GoalProgressCard: View {
    let goal: Goal
    @EnvironmentObject var userManager: UserManager

    // FIX #3: match by firebaseUser uid directly, not currentUserProfile.id which can be stale
    private var personalSteps: Int {
        goal.members.first(where: { $0.id == userManager.firebaseUser?.uid })?.steps ?? 0
    }

    private var personalProgress: Double {
        goal.totalSteps > 0 ? Double(personalSteps) / Double(goal.totalSteps) : 0
    }

    // FIX #2: for cooperative, calculate directly from members sum
    private var cooperativeProgress: Double {
        guard goal.totalSteps > 0 else { return 0 }
        let total = goal.members.reduce(0) { $0 + $1.steps }
        return Double(total) / Double(goal.totalSteps)
    }

    private var isMeFinished: Bool {
        goal.totalSteps > 0 && personalSteps >= goal.totalSteps
    }

    private var displayProgress: Double {
        switch goal.type {
        case .race:        return personalProgress
        case .cooperative: return cooperativeProgress
        case .individual:  return personalProgress
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSection

            let safeProgress = min(max(displayProgress, 0.0), 1.0)
            ProgressView(value: safeProgress)
                .tint(goal.isFullyCompleted ? .green : (goal.type == .race ? .orange : .blue))
                .scaleEffect(x: 1, y: 1.2)

            if goal.isGroupGoal {
                leaderboardPreview
            }

            footerStats
        }
        .padding()
        .background(Color.white.opacity(0.95))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(goal.isFullyCompleted ? Color.green : Color.clear, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    // MARK: - Sub-Views

    private var headerSection: some View {
        HStack {
            let showCheck = isMeFinished || (goal.type == .cooperative && cooperativeProgress >= 1.0)

            Image(systemName: showCheck ? "checkmark.circle.fill" : goal.icon)
                .foregroundColor(showCheck ? .green : .blue)

            VStack(alignment: .leading, spacing: 0) {
                Text(goal.name)
                    .font(.system(.headline, design: .rounded))
                if goal.type == .race {
                    Text("Race Mode")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Text("\(Int(min(displayProgress, 1.0) * 100))%")
                .fontWeight(.bold)
                .foregroundColor(goal.isFullyCompleted ? .green : (goal.type == .race ? .orange : .blue))
        }
    }

    private var leaderboardPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().padding(.vertical, 2)

            let topThree = goal.members.sorted { $0.steps > $1.steps }.prefix(3)

            HStack(spacing: 12) {
                ForEach(Array(topThree.enumerated()), id: \.element.id) { index, member in
                    HStack(spacing: 4) {
                        if member.steps >= goal.totalSteps {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.green)
                        } else {
                            Circle()
                                .fill(rankColor(for: index))
                                .frame(width: 12, height: 12)
                        }
                        Text(member.firstName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var footerStats: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(goal.type == .race ? "My Progress" : "Team Progress")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                let displaySteps = goal.type == .cooperative
                    ? goal.members.reduce(0) { $0 + $1.steps }
                    : personalSteps

                Text(userManager.formatProgress(steps: displaySteps))
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundColor(isMeFinished ? .green : .primary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("Target")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Text(userManager.formatProgress(steps: goal.totalSteps))
                    .font(.system(.subheadline, weight: .bold))
            }
        }
    }

    func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .orange
        default: return .blue
        }
    }
}
