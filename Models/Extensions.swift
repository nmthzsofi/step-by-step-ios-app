//
//  Extensions.swift
//  lepesrol-lepesre
//
//  Created by Zsófia Németh on 2026. 03. 05..
//
import SwiftUI
import CoreLocation
import FirebaseFirestore

extension CLLocationCoordinate2D: Codable {
    public enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
extension CLLocationCoordinate2D {
    var toGeoPoint: GeoPoint {
        return GeoPoint(latitude: self.latitude, longitude: self.longitude)
    }
}

extension GeoPoint {
    var toCoordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
}

extension Goal {
    // This makes the binding code in your View much cleaner
    var startCoordinateAsCLLocation: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
    }
}
