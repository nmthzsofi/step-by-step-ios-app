import SwiftUI
import MapKit

struct MapView: View {
    @ObservedObject var goalManager: GoalManager
    @ObservedObject var userManager: UserManager
    @State private var showingAddActivity = false
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .bottom) {

            if !goalManager.goals.isEmpty && goalManager.selectedGoalIndex < goalManager.goals.count {
                let selectedGoal = goalManager.goals[goalManager.selectedGoalIndex]

                Map(position: $cameraPosition, interactionModes: .all) {

                    // Destination marker
                    Annotation(selectedGoal.name, coordinate: selectedGoal.coordinates.toCoordinate) {
                        AnnotationView(goal: selectedGoal)
                    }

                    // Start marker
                    Marker("Start", systemImage: "figure.walk.circle", coordinate: selectedGoal.startCoordinate.toCoordinate)
                        .tint(.gray)

                    // Path line
                    MapPolyline(coordinates: [
                        selectedGoal.startCoordinate.toCoordinate,
                        selectedGoal.coordinates.toCoordinate
                    ])
                    .stroke(.blue.opacity(0.3), lineWidth: 4)

                    // Member bubbles
                    if selectedGoal.type == .race {
                        // Race: one bubble per member, each at their own progress
                        ForEach(selectedGoal.members) { member in
                            let progress = selectedGoal.totalSteps > 0
                                ? Double(member.steps) / Double(selectedGoal.totalSteps)
                                : 0
                            let coord = calculateProgressCoordinate(for: progress, goal: selectedGoal)
                            let firstName = member.firstName.components(separatedBy: " ").first ?? member.firstName

                            Annotation(firstName, coordinate: coord) {
                                MemberBubble(
                                    name: member.firstName,
                                    imageData: member.id == userManager.firebaseUser?.uid
                                        ? userManager.profileImageData   // FIX #1: use userManager image for current user
                                        : member.imageData,
                                    icon: nil,
                                    color: member.id == userManager.firebaseUser?.uid ? .orange : .blue
                                )
                                // FIX #3: force refresh when steps change
                                .id("race-\(member.id ?? "")-\(member.steps)")
                            }
                        }
                    } else {
                        // Individual or Cooperative: single bubble
                        let progress: Double = {
                            guard selectedGoal.totalSteps > 0 else { return 0 }
                            switch selectedGoal.type {
                            case .individual:
                                // FIX #2: calculate directly from members, not from currentSteps
                                let mySteps = selectedGoal.members
                                    .first(where: { $0.id == userManager.firebaseUser?.uid })?.steps ?? 0
                                return Double(mySteps) / Double(selectedGoal.totalSteps)
                            case .cooperative:
                                // FIX #2: sum all members directly
                                let totalSteps = selectedGoal.members.reduce(0) { $0 + $1.steps }
                                return Double(totalSteps) / Double(selectedGoal.totalSteps)
                            default:
                                return 0
                            }
                        }()

                        let coord = calculateProgressCoordinate(for: progress, goal: selectedGoal)
                        let myMember = selectedGoal.members.first(where: { $0.id == userManager.firebaseUser?.uid })
                            ?? selectedGoal.members.first
                        let displayName = myMember?.firstName.components(separatedBy: " ").first ?? "Explorer"

                        Annotation(
                            selectedGoal.type == .cooperative ? "Team" : displayName,
                            coordinate: coord
                        ) {
                            MemberBubble(
                                name: myMember?.firstName ?? "Me",
                                // FIX #1: always use userManager.profileImageData for current user
                                imageData: selectedGoal.type == .cooperative ? nil : userManager.profileImageData,
                                icon: selectedGoal.type == .cooperative ? selectedGoal.icon : nil,
                                color: .orange
                            )
                            // FIX #2 & #3: force refresh when progress changes
                            .id("bubble-\(selectedGoal.id ?? "")-\(progress)")
                        }
                    }
                }
                .mapStyle(.standard(emphasis: .muted))
                .edgesIgnoringSafeArea(.all)
                .onChange(of: goalManager.selectedGoalIndex) { _ in updateMapFocus() }
                .onAppear { updateMapFocus() }

            } else {
                ContentUnavailableView("Loading Adventure...", systemImage: "map.fill")
                    .background(Color(.systemBackground))
            }

            // UI overlay
            VStack(spacing: 0) {
                if !goalManager.goals.isEmpty {
                    TabView(selection: $goalManager.selectedGoalIndex) {
                        ForEach(0..<goalManager.goals.count, id: \.self) { index in
                            Button(action: { updateMapFocus() }) {
                                GoalProgressCard(goal: goalManager.goals[index])
                                    .padding(.horizontal)
                                    .environmentObject(userManager)
                                    .opacity(goalManager.selectedGoalIndex == index ? 1.0 : 0.6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .tag(index)
                        }
                    }
                    .frame(height: 150)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .padding(.top, 10)
                }

                Spacer()

                Button(action: { showingAddActivity = true }) {
                    Label("Add Activity", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 260, height: 60)
                        .background(Capsule().fill(Color.black))
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.bottom, 20)
                .disabled(goalManager.goals.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddActivity) {
            AddActivityView(manager: goalManager, userManager: userManager)
        }
    }

    private func calculateProgressCoordinate(for progress: Double, goal: Goal) -> CLLocationCoordinate2D {
        let p = max(0, min(progress, 1.0))
        let lat = goal.startCoordinate.latitude + (goal.coordinates.latitude - goal.startCoordinate.latitude) * p
        let lon = goal.startCoordinate.longitude + (goal.coordinates.longitude - goal.startCoordinate.longitude) * p
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func updateMapFocus() {
        guard !goalManager.goals.isEmpty,
              goalManager.selectedGoalIndex < goalManager.goals.count else { return }

        let goal = goalManager.goals[goalManager.selectedGoalIndex]
        let startPoint = MKMapPoint(goal.startCoordinate.toCoordinate)
        let endPoint   = MKMapPoint(goal.coordinates.toCoordinate)

        var rect = MKMapRect(origin: startPoint, size: MKMapSize(width: 0, height: 0))
        rect = rect.union(MKMapRect(origin: endPoint, size: MKMapSize(width: 0, height: 0)))

        let paddingFactor = 0.3
        let paddedRect = rect.insetBy(dx: -rect.width * paddingFactor, dy: -rect.height * paddingFactor)

        withAnimation(.easeInOut(duration: 1.2)) {
            cameraPosition = .rect(paddedRect)
        }
    }
}

// MARK: - Supporting Views

struct MemberBubble: View {
    let name: String
    let imageData: Data?
    var icon: String? = nil
    let color: Color

    var body: some View {
        ZStack {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
            } else if let iconName = icon {
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(color))
            }
        }
        .overlay(Circle().stroke(Color.white, lineWidth: 2))
        .shadow(radius: 2)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct AnnotationView: View {
    let goal: Goal
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: goal.icon)
                .padding(8)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())
                .shadow(radius: 3)

            Image(systemName: "triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10)
                .foregroundColor(.blue)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(goalManager: GoalManager(), userManager: UserManager())
    }
}
