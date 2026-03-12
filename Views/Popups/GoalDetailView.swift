import SwiftUI
import MapKit

struct GoalDetailView: View {
    @Binding var goal: Goal
    @ObservedObject var goalManager: GoalManager  // renamed
    @ObservedObject var userManager: UserManager

    @State private var startAddress: String = "Loading..."
    @State private var endAddress: String = "Loading..."
    @State private var showingDeleteConfirmation = false
    @State private var showingFullLeaderboard = false
    @Environment(\.dismiss) var dismiss

    let icons = ["figure.walk", "beach.umbrella.fill", "mountain.2.fill", "airplane", "figure.outdoor.cycle", "tent.fill"]

    var body: some View {
        Form {
            generalSection
            if goal.isGroupGoal { leaderboardSection }
            iconSection
            routeSection
            deleteSection
        }
        .navigationTitle("Edit Journey")
        .sheet(isPresented: $showingFullLeaderboard) {
            FullLeaderboardView(members: goal.members, userManager: userManager)
        }
        .confirmationDialog("Are you sure?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button(goal.isGroupGoal ? "Exit Group" : "Delete Journey", role: .destructive) { confirmDeletion() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(goal.isGroupGoal ? "You will lose your progress in this group." : "This will permanently delete this journey.")
        }
        .onAppear { updateAddresses() }
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section(header: Text("General")) {
            TextField("Journey Name", text: $goal.name)

            Picker("Journey Type", selection: $goal.type) {
                ForEach(GoalType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: goal.type) { newType in
                goal.isGroupGoal = (newType != .individual)
                if goal.isGroupGoal && goal.shareCode.isEmpty {
                    goal.shareCode = goalManager.generateRandomCode()  // renamed
                }
            }

            if goal.isGroupGoal {
                HStack {
                    Text("Group Code")
                    Spacer()
                    Text(goal.shareCode)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Button(action: { UIPasteboard.general.string = goal.shareCode }) {
                        Image(systemName: "doc.on.doc").font(.caption)
                    }
                }
            }
        }
    }

    private var leaderboardSection: some View {
        Section(header: Text("Leaderboard")) {
            let sortedMembers = goal.members.sorted { $0.steps > $1.steps }
            let topFive = Array(sortedMembers.prefix(5))

            ForEach(topFive.indices, id: \.self) { index in
                HStack {
                    ZStack {
                        Circle().fill(rankColor(for: index)).frame(width: 24, height: 24)
                        Text("\(index + 1)").font(.caption2).bold().foregroundColor(.white)
                    }
                    // Highlight current user
                    Text(topFive[index].firstName)
                        .fontWeight(topFive[index].id == userManager.firebaseUser?.uid ? .bold : .regular)
                    Spacer()
                    // FIX #5: use formatProgress for steps/km
                    Text(userManager.formatProgress(steps: topFive[index].steps))
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }

            if goal.members.count > 5 {
                Button("View All Members (\(goal.members.count))") {
                    showingFullLeaderboard = true
                }
                .font(.footnote)
                .foregroundColor(.blue)
            }
        }
    }

    private var iconSection: some View {
        Section(header: Text("Journey Icon")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(icons, id: \.self) { iconName in
                        Image(systemName: iconName)
                            .font(.title2)
                            .padding(10)
                            .background(goal.icon == iconName ? Color.blue.opacity(0.2) : Color.clear)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(goal.icon == iconName ? Color.blue : Color.clear, lineWidth: 2))
                            .onTapGesture { goal.icon = iconName }
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }

    private var routeSection: some View {
        Section(header: Text("Route")) {
            let startBinding = Binding<CLLocationCoordinate2D>(
                get: { goal.startCoordinate.toCoordinate },
                set: { goal.startCoordinate = $0.toGeoPoint }
            )
            let destinationBinding = Binding<CLLocationCoordinate2D>(
                get: { goal.coordinates.toCoordinate },
                set: { goal.coordinates = $0.toGeoPoint }
            )

            NavigationLink(destination: LocationSearchView(selectedCoordinate: startBinding)) {
                VStack(alignment: .leading) {
                    Text("Start Point").font(.caption).foregroundColor(.secondary)
                    Text(startAddress)
                }
            }

            NavigationLink(destination: LocationSearchView(selectedCoordinate: destinationBinding)) {
                VStack(alignment: .leading) {
                    Text("Destination").font(.caption).foregroundColor(.secondary)
                    Text(endAddress)
                }
            }

            HStack {
                Text("Total Steps")
                Spacer()
                Text(userManager.formatProgress(steps: goal.totalSteps))  // FIX #5
                    .foregroundColor(.secondary)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text(goal.isGroupGoal ? "Exit Group" : "Delete Journey")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .orange
        default: return .blue
        }
    }

    func updateAddresses() {
        lookUpAddress(for: goal.startCoordinate.toCoordinate) { startAddress = $0 }
        lookUpAddress(for: goal.coordinates.toCoordinate) { endAddress = $0 }
    }

    func lookUpAddress(for coord: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            if let p = placemarks?.first {
                let city = p.locality ?? p.administrativeArea ?? ""
                let country = p.country ?? ""
                completion("\(city), \(country)")
            } else {
                completion("Unknown Location")
            }
        }
    }

    private func confirmDeletion() {
        let idToDelete = goal.id
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let index = goalManager.goals.firstIndex(where: { $0.id == idToDelete }) {
                goalManager.goals.remove(at: index)
            }
        }
    }
}

// MARK: - Full Leaderboard

struct FullLeaderboardView: View {
    let members: [Member]
    let userManager: UserManager  // added for formatting
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(members.sorted { $0.steps > $1.steps }) { member in
                    HStack {
                        Text(member.firstName).bold()
                        Spacer()
                        Text(userManager.formatProgress(steps: member.steps))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("All Members")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
