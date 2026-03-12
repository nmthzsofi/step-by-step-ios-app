import SwiftUI

struct MiniLeaderboard: View {
    let members: [Member]
    @EnvironmentObject var userManager: UserManager  // FIX: needed for unit formatting

    var topThree: [Member] {
        Array(members.sorted { $0.steps > $1.steps }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(topThree.indices, id: \.self) { index in
                HStack {
                    Text("\(index + 1).")
                        .font(.caption2).bold()
                    Text(topThree[index].firstName)
                        .font(.caption2)
                    Spacer()
                    // FIX #5: respect unit preference
                    Text(userManager.formatProgress(steps: topThree[index].steps))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}
