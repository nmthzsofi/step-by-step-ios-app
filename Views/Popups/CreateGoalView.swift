import SwiftUI
import MapKit
import CoreLocation

struct CreateGoalView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var goalManager: GoalManager
    @ObservedObject var userManager: UserManager

    @State private var goalName = ""
    @State private var selectedIcon = "figure.walk"
    @State private var selectedType: GoalType = .individual
    @State private var tempShareCode = ""

    @State private var fromText = ""
    @State private var toText = ""
    @State private var fromItem: MKMapItem?
    @State private var toItem: MKMapItem?

    @State private var searchResults: [MKMapItem] = []
    @State private var activeField: ActiveField = .to
    enum ActiveField { case from, to }

    let icons = ["figure.walk", "beach.umbrella.fill", "mountain.2.fill", "airplane", "figure.outdoor.cycle", "tent.fill"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // SECTION 1: THE SEARCH HEADER
                VStack(spacing: 10) {
                    searchField(
                        text: $fromText,
                        icon: "circle.circle.fill",
                        color: .blue,
                        placeholder: "From...",
                        field: .from
                    )
                    searchField(
                        text: $toText,
                        icon: "mappin.and.ellipse",
                        color: .red,
                        placeholder: "To...",
                        field: .to
                    )
                }
                .padding()
                .background(Color(.systemBackground))

                if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { item in
                        Button(action: { selectItem(item) }) {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "Unknown").font(.headline)
                                Text(item.placemark.title ?? "").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    Form {
                        Section(header: Text("Journey Details")) {
                            TextField("Name your trip (e.g. Summer Trek)", text: $goalName)
                        }

                        Section(header: Text("Journey Type")) {
                            Picker("Mode", selection: $selectedType) {
                                ForEach(GoalType.allCases, id: \.self) { type in
                                    Text(type.localizedName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: selectedType) { newType in
                                if newType != .individual && tempShareCode.isEmpty {
                                    tempShareCode = goalManager.generateRandomCode()
                                }
                            }
                        }

                        if selectedType != .individual {
                            Section(header: Text("Invite Friends")) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Share this code with your friends to let them join this \(selectedType.rawValue.lowercased()) journey.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    HStack {
                                        Text(tempShareCode)
                                            .font(.system(.title3, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)

                                        Spacer()

                                        Button(action: { UIPasteboard.general.string = tempShareCode }) {
                                            Label("Copy", systemImage: "doc.on.doc")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.blue)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        Section(header: Text("Choose an Icon")) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(icons, id: \.self) { icon in
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .padding(10)
                                            .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(selectedIcon == icon ? Color.blue : Color.clear, lineWidth: 2))
                                            .onTapGesture { selectedIcon = icon }
                                    }
                                }
                                .padding(.vertical, 5)
                            }
                        }

                        if toItem != nil {
                            Section(header: Text("Summary")) {
                                HStack {
                                    Text("Estimated Distance")
                                    Spacer()
                                    Text("\(estimatedSteps()) steps")
                                        .bold()
                                }
                            }
                        }
                    }
                }

                if toItem != nil && !goalName.isEmpty && searchResults.isEmpty {
                    Button(action: finalizeGoal) {
                        Text("Create Journey")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    .padding()
                }
            }
            .navigationTitle(Text("New Journey"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: fromText) { val in if activeField == .from { performSearch(query: val) } }
            .onChange(of: toText) { val in if activeField == .to { performSearch(query: val) } }
        }
    }

    // MARK: - Helpers & Functions

    private func searchField(text: Binding<String>, icon: String, color: Color, placeholder: LocalizedStringKey, field: ActiveField) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(color)
            TextField(placeholder, text: text, onEditingChanged: { _ in activeField = field })
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    func performSearch(query: String) {
        guard query.count > 2 else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        MKLocalSearch(request: request).start { res, _ in self.searchResults = res?.mapItems ?? [] }
    }

    func selectItem(_ item: MKMapItem) {
        if activeField == .from {
            fromItem = item
            fromText = item.name ?? ""
        } else {
            toItem = item
            toText = item.name ?? ""
            if goalName.isEmpty { goalName = item.name ?? "" }
        }
        searchResults = []
    }

    func estimatedSteps() -> Int {
        guard let to = toItem?.placemark.coordinate else { return 0 }
        let from = fromItem?.placemark.coordinate ?? CLLocationCoordinate2D(latitude: 47.49, longitude: 19.04)
        return goalManager.calculateSteps(from: from, to: to)
    }

    func finalizeGoal() {
        guard let to = toItem else { return }
        guard let profile = userManager.currentUserProfile else { return }

        let startLocation = fromItem?.placemark.coordinate
            ?? CLLocationCoordinate2D(latitude: 47.4979, longitude: 19.0402)

        let newMember = Member(
            id: userManager.firebaseUser?.uid,
            firstName: profile.firstName,
            imageData: profile.imageData,
            steps: 0,
            hasFinished: false
        )

        let newGoal = Goal(
            name: goalName,
            startCoordinate: startLocation.toGeoPoint,
            coordinates: to.placemark.coordinate.toGeoPoint,
            totalSteps: estimatedSteps(),
            currentSteps: 0,
            icon: selectedIcon,
            isGroupGoal: selectedType != .individual,
            shareCode: selectedType != .individual
                ? (tempShareCode.isEmpty ? goalManager.generateRandomCode() : tempShareCode)
                : "",
            type: selectedType,
            members: [newMember]
        )

        goalManager.saveGoalToFirebase(goal: newGoal)
        dismiss()
    }
}
