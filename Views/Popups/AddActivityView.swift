import SwiftUI

enum ActivityType: String, CaseIterable {
    case running = "Running"
    case swimming = "Swimming"
    case tennis = "Tennis"
    case cycling = "Cycling"
    case walking = "Walking"

    var localizedName: LocalizedStringKey { LocalizedStringKey(rawValue) }

    var baseMultiplier: Double {
        switch self {
        case .running: return 150
        case .swimming: return 120
        case .tennis: return 100
        case .cycling: return 80
        case .walking: return 100
        }
    }
}

struct AddActivityView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var manager: GoalManager
    @ObservedObject var userManager: UserManager

    @State private var selectedActivity: ActivityType = .running
    @State private var duration: Double = 30
    @State private var intensity = 1

    var calculatedSteps: Int {
        let intensityFactor = Double(intensity + 1) * 0.5 + 0.5
        return Int(duration * selectedActivity.baseMultiplier * intensityFactor)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise Details")) {
                    Picker("Activity", selection: $selectedActivity) {
                        ForEach(ActivityType.allCases, id: \.self) { activity in
                            Text(activity.localizedName).tag(activity)
                        }
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
                        Text(userManager.formatProgress(steps: calculatedSteps))
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }

                Section {
                    Button(action: {
                        if let uid = userManager.firebaseUser?.uid {
                            manager.addSteps(calculatedSteps, userUID: uid)
                        }
                        dismiss()
                    }) {
                        Text("Add Steps")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.bold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                }
            }
            .navigationTitle(Text("New Activity"))
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
