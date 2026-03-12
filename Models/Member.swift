import SwiftUI
import CoreLocation
import FirebaseFirestore

struct Member: Identifiable, Codable {
    var id: String?

    // Display snapshot — enough to render leaderboards and map bubbles
    var firstName: String
    var imageData: Data?

    // Goal-specific state
    var steps: Int
    var hasFinished: Bool = false
    
    enum CodingKeys: String, CodingKey {
            case id
            case firstName
            case imageData
            case steps
            case hasFinished
    }
}

// NEW: Badge system
enum Badge: String, CaseIterable, Hashable {
    case firstSteps = "First Steps"
    case century = "Century"
    case globetrotter = "Globetrotter"
    case teamPlayer = "Team Player"

    var localizedName: LocalizedStringKey { LocalizedStringKey(rawValue) }

    var icon: String {
        switch self {
        case .firstSteps: return "shoeprints.fill"
        case .century: return "star.fill"
        case .globetrotter: return "globe"
        case .teamPlayer: return "person.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .firstSteps: return .blue
        case .century: return .orange
        case .globetrotter: return .green
        case .teamPlayer: return .purple
        }
    }
}
