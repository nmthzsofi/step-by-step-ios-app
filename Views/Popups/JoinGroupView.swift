import SwiftUI

struct JoinGroupView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var goalManager: GoalManager   // renamed
    @ObservedObject var userManager: UserManager   // added
    @State private var invitationCode = ""
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Image(systemName: "person.2.badge.key.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Join a Group Journey")
                        .font(.title2).bold()

                    Text("Enter the 6-digit code shared by your friend to join their progress.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 40)

                TextField("E.G. XY-789", text: $invitationCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 50)
                    .onChange(of: invitationCode) { newValue in
                        if newValue.count > 6 { invitationCode = String(newValue.prefix(6)) }
                    }

                if let error = errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }

                Spacer()

                Button(action: validateAndJoin) {
                    if isSearching {
                        ProgressView().tint(.white)
                    } else {
                        Text("Join Journey")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(invitationCode.count < 6 ? Color.gray : Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                }
                .disabled(invitationCode.count < 6 || isSearching)
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    func validateAndJoin() {
        // FIX: require a real profile before joining
        guard let profile = userManager.currentUserProfile else {
            errorMessage = "Profile not loaded. Please try again."
            return
        }

        isSearching = true
        errorMessage = nil

        // FIX: pass real user profile instead of UserDefaults string
        goalManager.joinGoal(code: invitationCode.uppercased(), userProfile: profile)

        // FIX: grant team player badge
        userManager.grantTeamPlayerBadge()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSearching = false
            let success = goalManager.goals.contains(where: { $0.shareCode == invitationCode.uppercased() })
            if success {
                dismiss()
            } else {
                errorMessage = "No journey found with this code. Please check and try again."
            }
        }
    }
}
