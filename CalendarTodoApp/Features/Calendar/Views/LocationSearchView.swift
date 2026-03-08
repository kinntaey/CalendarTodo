import MapKit
import SwiftUI

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var locationName: String
    @Binding var locationAddress: String
    @Binding var locationLat: Double?
    @Binding var locationLng: Double?
    @Binding var locationPlaceID: String?

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.978),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("장소 검색", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { search() }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 10))
                .padding()

                if isSearching {
                    ProgressView()
                        .padding()
                }

                // Results
                List(searchResults, id: \.self) { item in
                    Button {
                        selectLocation(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name ?? "알 수 없는 장소")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)

                            if let address = item.placemark.formattedAddress {
                                Text(address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("위치 검색")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    private func search() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            if let response {
                searchResults = response.mapItems
            }
        }
    }

    private func selectLocation(_ item: MKMapItem) {
        locationName = item.name ?? ""
        locationAddress = item.placemark.formattedAddress ?? ""
        locationLat = item.placemark.coordinate.latitude
        locationLng = item.placemark.coordinate.longitude
        locationPlaceID = nil // MKMapItem doesn't provide Google Place ID
        dismiss()
    }
}

extension CLPlacemark {
    var formattedAddress: String? {
        let components = [
            subThoroughfare,
            thoroughfare,
            locality,
            administrativeArea,
            country,
        ].compactMap { $0 }

        return components.isEmpty ? nil : components.joined(separator: " ")
    }
}
