//
//  LocationSearchView.swift
//  lepesrol-lepesre
//
//  Created by Zsófia Németh on 2026. 03. 05..
//

import SwiftUI
import MapKit

struct LocationSearchView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCoordinate: CLLocationCoordinate2D
    @State private var searchText = ""
    @State private var results: [MKMapItem] = []

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { item in
                Button(action: {
                    selectedCoordinate = item.placemark.coordinate
                    dismiss()
                }) {
                    VStack(alignment: .leading) {
                        Text(item.name ?? "Unknown Location")
                            .font(.headline)
                        Text(item.placemark.title ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Search Location")
            .searchable(text: $searchText)
            .onChange(of: searchText) { newValue in
                search(query: newValue)
            }
        }
    }

    func search(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            self.results = response?.mapItems ?? []
        }
    }
}
