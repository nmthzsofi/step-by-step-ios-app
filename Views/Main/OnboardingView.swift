import SwiftUI
import PhotosUI
import FirebaseFirestore

struct OnboardingView: View {
    @ObservedObject var goalManager: GoalManager
    @ObservedObject var userManager: UserManager
    
    // Local state for the form
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var selectedSex: String = "Other"
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var height: Double = 170
    @State private var weight: Double = 70
    @State private var profileImageData: Data?
    @State private var selectedItem: PhotosPickerItem?
    
    // State for loading and errors
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // 1. Header & Photo
                VStack(spacing: 15) {
                    Text("Create Profile")
                        .font(.system(.title, design: .rounded)).bold()
                    
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let data = profileImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.gray.opacity(0.3))
                        }
                    }
                }
                
                // 2. Form Fields
                VStack(alignment: .leading, spacing: 20) {
                    customTextField("First Name", text: $firstName, icon: "person")
                    customTextField("Last Name", text: $lastName, icon: "person")
                    
                    HStack {
                        Image(systemName: "person.and.arrow.left.and.arrow.right").foregroundColor(.blue)
                        Picker("Sex", selection: $selectedSex) {
                            ForEach(userManager.sexOptions, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)

                    DatePicker("Birthdate", selection: $birthDate, displayedComponents: .date)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    
                    VStack {
                        HStack {
                            Text("Height: \(Int(height)) cm")
                            Spacer()
                            Slider(value: $height, in: 100...250, step: 1)
                        }
                        HStack {
                            Text("Weight: \(Int(weight)) kg")
                            Spacer()
                            Slider(value: $weight, in: 30...200, step: 1)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Error Message Display
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // 3. Submit
                Button(action: completeOnboarding) {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Start Journey")
                                .font(.headline).foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity).frame(height: 55)
                    .background(formIsValid ? Color.blue : Color.gray)
                    .cornerRadius(15)
                }
                .padding(.horizontal)
                .disabled(!formIsValid || isLoading)
            }
            .padding(.bottom, 30)
        }
        .onChange(of: selectedItem) { _ in
            Task {
                if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                    profileImageData = data
                }
            }
        }
    }
    
    // Simple validation (Username removed)
    var formIsValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty
    }
    
    // Helper for clean text fields
    func customTextField(_ placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.blue)
            TextField(placeholder, text: text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    func completeOnboarding() {
        isLoading = true
        errorMessage = ""

        guard let uid = userManager.firebaseUser?.uid else {
            errorMessage = "Authentication error. Please sign out and try again."
            isLoading = false
            return
        }

        // Save the Member snapshot for goal subcollections
        let newProfile = Member(
            id: uid,
            firstName: self.firstName,
            imageData: self.profileImageData,
            steps: 0,
            hasFinished: false
        )
        userManager.saveProfile(profile: newProfile)

        // Save all the remaining user details directly to the users document
        userManager.saveUserDetails(
            userName: userManager.userName,
            firstName: self.firstName,
            lastName: self.lastName,
            sex: self.selectedSex,
            birthDate: self.birthDate,
            height: self.height,
            weight: self.weight
        )

        // Mark onboarding complete in Firestore so fetchProfile doesn't reset it
        let db = Firestore.firestore()
        db.collection("users").document(uid).setData([
            "hasCompletedOnboarding": true
        ], merge: true) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Failed to save profile. Please try again."
                    self.isLoading = false
                    print("Error completing onboarding: \(error)")
                } else {
                    withAnimation {
                        self.userManager.hasCompletedOnboarding = true
                    }
                    self.isLoading = false
                }
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(goalManager: GoalManager(), userManager: UserManager())
    }
}
