import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var manager: UserManager

    // FIX: local copy of all fields so we only save when user taps Done
    @State private var userName: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var sex: String = "Other"
    @State private var birthDate: Date = Date()
    @State private var userHeight: Double = 170
    @State private var userWeight: Double = 70
    @State private var displayUnit: DisplayUnit = .steps

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Public Identity")) {
                    HStack {
                        Text("Username").foregroundColor(.secondary)
                        Spacer()
                        Text("@").foregroundColor(.blue)
                        TextField("username", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    HStack {
                        Text("First Name").foregroundColor(.secondary)
                        Spacer()
                        TextField("Required", text: $firstName)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Last Name").foregroundColor(.secondary)
                        Spacer()
                        TextField("Required", text: $lastName)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Personal Details")) {
                    Picker("Sex", selection: $sex) {
                        ForEach(manager.sexOptions, id: \.self) { Text($0) }
                    }

                    DatePicker("Birthdate", selection: $birthDate, displayedComponents: .date)
                }

                Section(header: Text("Physical Measurements")) {
                    HStack {
                        Text("Height")
                        Spacer()
                        Stepper("\(Int(userHeight)) cm", value: $userHeight, in: 100...250)
                    }

                    HStack {
                        Text("Weight")
                        Spacer()
                        Stepper("\(Int(userWeight)) kg", value: $userWeight, in: 30...200)
                    }
                }

                // FIX #5: use DisplayUnit enum, bound to local state
                Section(header: Text("App Preferences")) {
                    Picker("Display Unit", selection: $displayUnit) {
                        ForEach(DisplayUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button(role: .destructive) {
                        manager.signOut()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out").fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            // FIX: populate local state from manager when view appears
            .onAppear {
                userName = manager.userName
                firstName = manager.firstName
                lastName = manager.lastName
                sex = manager.sex
                birthDate = manager.birthDate
                userHeight = manager.userHeight
                userWeight = manager.userWeight
                displayUnit = manager.displayUnit
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // FIX: Done now saves everything to Firebase before dismissing
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func saveChanges() {
        guard manager.firebaseUser?.uid != nil else { return }

        manager.saveUserDetails(
            userName: userName,
            firstName: firstName,
            lastName: lastName,
            sex: sex,
            birthDate: birthDate,
            height: userHeight,
            weight: userWeight
        )

        manager.saveDisplayUnit(displayUnit)
    }
}
