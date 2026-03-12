import SwiftUI
import PhotosUI

struct ProfileView: View {
    @ObservedObject var userManager: UserManager
    @ObservedObject var goalManager: GoalManager
    @State private var selectedItem: PhotosPickerItem? = nil

    private var totalSteps: Int { userManager.totalStepsAllTime }
    private var completedGoals: Int { goalManager.goals.filter { $0.isFullyCompleted }.count }
    private var calories: Int { userManager.caloriesBurned(steps: totalSteps) }
    private var topBadge: Badge? { userManager.earnedBadges.last }

    var body: some View {
        NavigationView {
            List {
                // SECTION 1: HEADER
                Section {
                    VStack(alignment: .center, spacing: 12) {
                        HStack {
                            Spacer()
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                imageOverlay
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        headerText
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .listRowBackground(Color.clear)

                // SECTION 2: ACHIEVEMENTS
                Section("Your Progress") {
                    achievementsGrid
                }

                // SECTION 3: BADGES
                if !userManager.earnedBadges.isEmpty {
                    Section("Badges") {
                        ForEach(userManager.earnedBadges, id: \.self) { badge in
                            HStack {
                                Image(systemName: badge.icon)
                                    .foregroundColor(badge.color)
                                    .frame(width: 30)
                                Text(badge.rawValue)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                // SECTION 4: PHYSICAL STATS
                Section("Physical Stats") {
                    StatRow(title: "Age", value: "\(userManager.age)", icon: "calendar", color: .purple)
                    StatRow(title: "Height", value: "\(Int(userManager.userHeight)) cm", icon: "figure.walk", color: .blue)
                    StatRow(title: "Weight", value: "\(Int(userManager.userWeight)) kg", icon: "scalemass", color: .green)
                    StatRow(title: "Sex", value: userManager.sex, icon: "person.fill", color: .orange)
                }

                // SECTION 5: SETTINGS
                Section("Account Settings") {
                    NavigationLink("Edit Personal Details") {
                        SettingsView(manager: userManager)
                    }
                }
            }
            .navigationTitle("Profile")
            .onChange(of: selectedItem) { _ in handleImageSelection() }
        }
    }

    // MARK: - Subviews

    private var achievementsGrid: some View {
        VStack(spacing: 15) {
            HStack(spacing: 20) {
                AchievementTile(
                    title: "Total Steps",
                    value: formatLargeNumber(totalSteps),
                    icon: "figure.walk",
                    color: .blue
                )
                AchievementTile(
                    title: "Calories",
                    value: formatLargeNumber(calories),
                    icon: "flame.fill",
                    color: .orange
                )
            }
            HStack(spacing: 20) {
                AchievementTile(
                    title: "Top Badge",
                    value: topBadge?.rawValue ?? "None yet",
                    icon: topBadge?.icon ?? "laurel.leading",
                    color: topBadge?.color ?? .gray
                )
                AchievementTile(
                    title: "Goals Met",
                    value: "\(completedGoals)",
                    icon: "checkmark.seal.fill",
                    color: .green
                )
            }
        }
        .padding(.vertical, 8)
    }

    private var imageOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let data = userManager.profileImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())

            Image(systemName: "pencil.circle.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 30))
                .background(Color.white, in: Circle())
        }
    }

    private var headerText: some View {
        VStack(spacing: 4) {
            Text("\(userManager.firstName) \(userManager.lastName)")
                .font(.title2).bold()
            Text(userManager.userName.isEmpty ? "" : "@\(userManager.userName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func handleImageSelection() {
        Task {
            if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                await MainActor.run {
                    // FIX #4: use dedicated image upload function
                    userManager.saveProfileImage(data)
                }
            }
        }
    }

    private func formatLargeNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fk", Double(number) / 1_000)
        }
        return "\(number)"
    }
}

// MARK: - Supporting Views

struct AchievementTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(title).font(.caption).foregroundColor(.secondary)
            }
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 30)
            Text(title)
            Spacer()
            Text(value).fontWeight(.bold)
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(userManager: UserManager(), goalManager: GoalManager())
    }
}
