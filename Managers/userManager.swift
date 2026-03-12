import Foundation
import UIKit
import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

enum DisplayUnit: String, CaseIterable, Codable {
    case steps = "Steps"
    case kilometers = "Kilometers"
}

class UserManager: ObservableObject {
    private let db = Firestore.firestore()

    @Published var firebaseUser: FirebaseAuth.User?
    @Published var currentUserProfile: Member?
    @Published var isLoggedIn: Bool = false
    @Published var hasCompletedOnboarding: Bool = false

    @Published var userName: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var sex: String = "Other"
    @Published var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @Published var userHeight: Double = 170
    @Published var userWeight: Double = 70
    @Published var profileImageData: Data? = nil
    @Published var profileImageURL: String = ""
    @Published var displayUnit: DisplayUnit = .steps
    @Published var totalStepsAllTime: Int = 0
    @Published var hasTeamPlayerBadge: Bool = false

    let sexOptions = ["Male", "Female", "Non-binary", "Other"]

    // MARK: - Computed Properties

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    var strideLength: Double {
        (userHeight * 0.415) / 100
    }

    var earnedBadges: [Badge] {
        var badges: [Badge] = []
        if totalStepsAllTime > 0          { badges.append(.firstSteps) }
        if totalStepsAllTime >= 100_000   { badges.append(.century) }
        if totalStepsAllTime >= 1_000_000 { badges.append(.globetrotter) }
        if hasTeamPlayerBadge             { badges.append(.teamPlayer) }
        return badges
    }

    // MARK: - Init

    init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.firebaseUser = user
                self?.isLoggedIn = (user != nil)
                if let user = user {
                    self?.fetchProfile(uid: user.uid)
                } else {
                    self?.currentUserProfile = nil
                    self?.hasCompletedOnboarding = false
                }
            }
        }
    }

    // MARK: - Username Check

    func isUsernameAvailable(_ name: String, completion: @escaping (Bool) -> Void) {
        let lowerName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowerName.isEmpty else { completion(false); return }

        db.collection("users")
            .whereField("userName", isEqualTo: lowerName)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Username check error (treating as available): \(error)")
                    completion(true)
                    return
                }
                completion(snapshot?.documents.isEmpty ?? true)
            }
    }

    // MARK: - Fetch Profile

    func fetchProfile(uid: String) {
        print("DEBUG fetchProfile: fetching uid: \(uid)")

        db.collection("users").document(uid).addSnapshotListener { snapshot, error in
            guard let document = snapshot else { return }
            
            guard document.exists, let data = document.data() else {
                DispatchQueue.main.async {
                    self.hasCompletedOnboarding = false
                }
                return
            }

            print("DEBUG fetchProfile: document data keys: \(data.keys.sorted())")
            print("DEBUG fetchProfile: totalStepsAllTime = \(data["totalStepsAllTime"] ?? "MISSING")")

            DispatchQueue.main.async {
                self.userName            = data["userName"] as? String ?? ""
                self.firstName           = data["firstName"] as? String ?? ""
                self.lastName            = data["lastName"] as? String ?? ""
                self.sex                 = data["sex"] as? String ?? "Other"
                self.userHeight          = data["height"] as? Double ?? 170
                self.userWeight          = data["weight"] as? Double ?? 70
                self.totalStepsAllTime   = data["totalStepsAllTime"] as? Int ?? 0
                self.hasTeamPlayerBadge  = data["hasTeamPlayerBadge"] as? Bool ?? false

                if let timestamp = data["birthDate"] as? Timestamp {
                    self.birthDate = timestamp.dateValue()
                }

                if let unitRaw = data["displayUnit"] as? String,
                   let unit = DisplayUnit(rawValue: unitRaw) {
                    self.displayUnit = unit
                }

                // Build currentUserProfile from raw data (no @DocumentID confusion)
                self.currentUserProfile = Member(
                    id: uid,
                    firstName: self.firstName,
                    imageData: self.profileImageData, // keep existing image until download completes
                    steps: data["steps"] as? Int ?? 0,
                    hasFinished: data["hasFinished"] as? Bool ?? false
                )

                // Download profile image from Firebase Storage URL
                if let imageURL = data["profileImageURL"] as? String, !imageURL.isEmpty {
                    self.profileImageURL = imageURL
                    if let url = URL(string: imageURL) {
                        URLSession.shared.dataTask(with: url) { downloadedData, _, error in
                            if let downloadedData = downloadedData {
                                DispatchQueue.main.async {
                                    // FIX #1: update both profileImageData AND currentUserProfile.imageData
                                    self.profileImageData = downloadedData
                                    if var profile = self.currentUserProfile {
                                        profile.imageData = downloadedData
                                        self.currentUserProfile = profile
                                    }
                                }
                            }
                        }.resume()
                    }
                }

                self.hasCompletedOnboarding = data["hasCompletedOnboarding"] as? Bool ?? false

            }
        }
    }

    // MARK: - Save Profile (Member fields only)

    func saveProfile(profile: Member) {
        guard let uid = firebaseUser?.uid else { return }

        let data: [String: Any] = [
            "firstName": profile.firstName,
            "steps": profile.steps,
            "hasFinished": profile.hasFinished
        ]

        db.collection("users").document(uid).setData(data, merge: true) { error in
            if let error = error {
                print("Error saving profile: \(error)")
                return
            }
            DispatchQueue.main.async {
                self.firstName = profile.firstName
                // Preserve existing imageData when updating profile
                var updatedProfile = profile
                updatedProfile.imageData = self.profileImageData
                self.currentUserProfile = updatedProfile
            }
        }
    }

    // MARK: - Save User Details

    func saveUserDetails(userName: String, firstName: String, lastName: String, sex: String, birthDate: Date, height: Double, weight: Double) {
        guard let uid = firebaseUser?.uid else { return }

        self.userName    = userName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.firstName   = firstName
        self.lastName    = lastName
        self.sex         = sex
        self.birthDate   = birthDate
        self.userHeight  = height
        self.userWeight  = weight

        if var updatedProfile = currentUserProfile {
            updatedProfile.firstName = firstName
            currentUserProfile = updatedProfile
        }

        db.collection("users").document(uid).setData([
            "userName":           self.userName,
            "firstName":          firstName,
            "lastName":           lastName,
            "sex":                sex,
            "birthDate":          Timestamp(date: birthDate),
            "height":             height,
            "weight":             weight,
            "totalStepsAllTime":  totalStepsAllTime,
            "hasTeamPlayerBadge": hasTeamPlayerBadge
        ], merge: true) { error in
            if let error = error { print("Error saving user details: \(error)") }
        }
        
    }

    // MARK: - Profile Image

    func saveProfileImage(_ imageData: Data) {
        guard let uid = firebaseUser?.uid else {
            print("DEBUG saveProfileImage: NO UID")
            return
        }
        print("DEBUG saveProfileImage: starting upload, uid: \(uid), bytes: \(imageData.count)")
        guard let uid = firebaseUser?.uid else { return }

        // FIX #1: update locally immediately so UI reflects change right away
        DispatchQueue.main.async {
            self.profileImageData = imageData
            if var profile = self.currentUserProfile {
                profile.imageData = imageData
                self.currentUserProfile = profile
            }
        }

        let storageRef = Storage.storage().reference().child("profile_images/\(uid).jpg")

        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Error uploading image: \(error)")
                return
            }

            storageRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error)")
                    return
                }
                guard let downloadURL = url else { return }

                self.db.collection("users").document(uid).setData([
                    "profileImageURL": downloadURL.absoluteString
                ], merge: true) { error in
                    if let error = error {
                        print("Error saving image URL: \(error)")
                    } else {
                        print("Profile image uploaded and URL saved successfully")
                        DispatchQueue.main.async {
                            self.profileImageURL = downloadURL.absoluteString
                        }
                    }
                }
            }
        }
    }

    // MARK: - Display Unit

    func saveDisplayUnit(_ unit: DisplayUnit) {
        guard let uid = firebaseUser?.uid else { return }
        self.displayUnit = unit
        db.collection("users").document(uid).updateData(["displayUnit": unit.rawValue]) { error in
            if let error = error { print("Error saving display unit: \(error)") }
        }
    }

    // MARK: - Badges

    func grantTeamPlayerBadge() {
        guard let uid = firebaseUser?.uid else { return }
        db.collection("users").document(uid).setData(["hasTeamPlayerBadge": true], merge: true) { error in
            if let error = error {
                print("Error granting team player badge: \(error)")
            } else {
                DispatchQueue.main.async { self.hasTeamPlayerBadge = true }
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.isLoggedIn              = false
            self.firebaseUser            = nil
            self.currentUserProfile      = nil
            self.hasCompletedOnboarding  = false
            self.userName                = ""
            self.firstName               = ""
            self.lastName                = ""
            self.profileImageData        = nil
            self.profileImageURL         = ""
            self.totalStepsAllTime       = 0
            self.hasTeamPlayerBadge      = false
            self.displayUnit             = .steps
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    // MARK: - Formatting

    func formatProgress(steps: Int) -> String {
        switch displayUnit {
        case .steps:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let number = formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
            return String(format: String(localized: "%@ steps"), number)
        case .kilometers:
            let km = Double(steps) * 0.000762
            return String(format: String(localized: "%.2f km"), km)
        }
    }

    func caloriesBurned(steps: Int) -> Int {
        let distanceMeters = Double(steps) * strideLength
        let calories = distanceMeters * userWeight * 0.0005
        return Int(calories)
    }
}
