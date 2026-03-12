import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AuthView: View {
    @ObservedObject var userManager: UserManager
    @ObservedObject var goalManager: GoalManager

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var body: some View {
        VStack(spacing: 25) {
            VStack(spacing: 10) {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text(isSignUp ? "Create Account" : "Welcome Back")
                    .font(.system(.title, design: .rounded)).bold()

                Text(isSignUp ? "Start your fitness journey today." : "Log in to track your progress.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 50)

            VStack(spacing: 15) {
                if isSignUp {
                    customTextField("Username", text: $username, icon: "at", isSecure: false)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                customTextField("Email", text: $email, icon: "envelope", isSecure: false)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)

                customTextField("Password", text: $password, icon: "lock", isSecure: true)
                    .textContentType(.oneTimeCode)

                if isSignUp {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue)
                            .frame(width: 25)
                        SecureField(String(localized: "Confirm Password"), text: $confirmPassword)
                            .textContentType(.oneTimeCode)

                        if !confirmPassword.isEmpty {
                            Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(passwordsMatch ? .green : .red)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    .animation(.easeInOut(duration: 0.2), value: confirmPassword)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                !confirmPassword.isEmpty && !passwordsMatch ? Color.red.opacity(0.5) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                }
            }
            .padding(.horizontal)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }

            Button(action: handleAuth) {
                HStack {
                    if isLoading { ProgressView().tint(.white) }
                    Text(isSignUp ? "Sign Up" : "Login").bold()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(15)
            }
            .padding(.horizontal)
            .disabled(isLoading)

            Button(action: {
                withAnimation {
                    isSignUp.toggle()
                    errorMessage = ""
                    confirmPassword = ""
                }
            }) {
                Text(isSignUp ? "Already have an account? Login" : "Don't have an account? Sign Up")
                    .font(.footnote)
                    .foregroundColor(.blue)
            }

            Spacer()
        }
    }

    func customTextField(_ placeholder: LocalizedStringKey, text: Binding<String>, icon: String, isSecure: Bool) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 25)
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    func handleAuth() {
        isLoading = true
        errorMessage = ""

        if isSignUp {
            let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if cleanUsername.isEmpty {
                errorMessage = String(localized: "Please enter a username.")
                isLoading = false
                return
            }

            guard passwordsMatch else {
                errorMessage = String(localized: "Passwords don't match. Please try again.")
                isLoading = false
                return
            }

            guard password.count >= 6 else {
                errorMessage = String(localized: "Password must be at least 6 characters.")
                isLoading = false
                return
            }

            userManager.isUsernameAvailable(cleanUsername) { isAvailable in
                guard isAvailable else {
                    DispatchQueue.main.async {
                        self.errorMessage = String(format: String(localized: "Username '@%@' is already taken."), cleanUsername)
                        self.isLoading = false
                    }
                    return
                }

                Auth.auth().createUser(withEmail: self.email, password: self.password) { result, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.errorMessage = error.localizedDescription
                            self.isLoading = false
                        }
                        return
                    }

                    guard let uid = result?.user.uid else {
                        DispatchQueue.main.async {
                            self.errorMessage = String(localized: "Signup failed. Please try again.")
                            self.isLoading = false
                        }
                        return
                    }

                    let db = Firestore.firestore()
                    db.collection("users").document(uid).setData([
                        "userName": cleanUsername,
                        "totalStepsAllTime": 0,
                        "hasTeamPlayerBadge": false,
                        "hasCompletedOnboarding": false
                    ], merge: true) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self.errorMessage = error.localizedDescription
                                self.isLoading = false
                            } else {
                                self.userManager.userName = cleanUsername
                                self.isLoading = false
                            }
                        }
                    }
                }
            }

        } else {
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if error != nil {
                        self.errorMessage = String(localized: "Incorrect email or password. Please try again.")
                    }
                }
            }
        }
    }
}
