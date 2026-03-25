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
    @State private var selectedItem: MKMapItem?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.978),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(L10n.searchLocation, text: $searchText)
                        .font(.system(size: 15, design: .rounded))
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .onSubmit { search() }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: searchText) { _, _ in
                    search()
                }

                // Map preview
                Map(position: $cameraPosition) {
                    if let item = selectedItem {
                        Marker(item.name ?? "", coordinate: item.placemark.coordinate)
                    }
                    ForEach(searchResults, id: \.self) { item in
                        Marker(item.name ?? "", coordinate: item.placemark.coordinate)
                            .tint(.red)
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

                // Results
                List(searchResults, id: \.self) { item in
                    Button {
                        selectLocation(item)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.red)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? L10n.unknownPlace)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)

                                if let address = item.placemark.formattedAddress {
                                    Text(address)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(L10n.locationSearch)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
    }

    private func search() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            if let response {
                searchResults = response.mapItems
                // 첫 결과로 지도 이동
                if let first = response.mapItems.first {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: first.placemark.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            }
        }
    }

    private func selectLocation(_ item: MKMapItem) {
        locationName = item.name ?? ""
        locationAddress = item.placemark.formattedAddress ?? ""
        locationLat = item.placemark.coordinate.latitude
        locationLng = item.placemark.coordinate.longitude
        locationPlaceID = nil
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
