import SwiftUI

struct AddActivityView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var manager: GoalManager
    @ObservedObject var userManager: UserManager  // FIX #1: needed for UID

    @State private var selectedActivity = "Running"
    @State private var duration: Double = 30
    @State private var intensity = 1

    let activities = ["Running", "Swimming", "Tennis", "Cycling", "Walking"]

    var calculatedSteps: Int {
        let baseMultiplier: Double
        switch selectedActivity {
        case "Running": baseMultiplier = 150
        case "Swimming": baseMultiplier = 120
        case "Tennis": baseMultiplier = 100
        case "Cycling": baseMultiplier = 80
        default: baseMultiplier = 100
        }
        let intensityFactor = Double(intensity + 1) * 0.5 + 0.5
        return Int(duration * baseMultiplier * intensityFactor)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise Details")) {
                    Picker("Activity", selection: $selectedActivity) {
                        ForEach(activities, id: \.self) { Text($0) }
                    }

                    VStack(alignment: .leading) {
                        Text("Duration: \(Int(duration)) minutes")
                        Slider(value: $duration, in: 5...120, step: 5)
                    }

                    Picker("Intensity", selection: $intensity) {
                        Text("Low").tag(0)
                        Text("Medium").tag(1)
                        Text("High").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Estimated Progress")) {
                    HStack {
                        Image(systemName: "shoeprints.fill")
                        // FIX #5: use formatProgress for steps/km display
                        Text(userManager.formatProgress(steps: calculatedSteps))
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }

                Section {
                    Button(action: {
                        // FIX #1: pass the user's UID so the correct member is found
                        if let uid = userManager.firebaseUser?.uid {
                            manager.addSteps(calculatedSteps, userUID: uid)
                        }
                        dismiss()
                    }) {
                        Text("Add to \(manager.currentGoal?.name ?? "Goal")")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.bold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                }
            }
            .navigationTitle("New Activity")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct AddActivityView_Previews: PreviewProvider {
    static var previews: some View {
        AddActivityView(manager: GoalManager(), userManager: UserManager())
    }
}
