//
//  LocationSelectionSheet.swift
//  Pace
//
//  Created by jan on 25/05/2026.
//

import SwiftUI
import MapKit
import SwiftData

struct LocationSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Binding var selection: MKMapItem?

    /// Shared LocationManager passed in from the parent that may already hold a
    /// pre-fetched result. If nil, the sheet creates its own instance (fallback).
    @ObservedObject var locationManager: LocationManager

    @Query(sort: \SavedLocation.name) private var savedLocations: [SavedLocation]
    @StateObject private var searchViewModel = LocationSearchViewModel()

    @State private var searchText = ""
    @State private var isFetchingLocation = false
    @State private var isResolvingSearch = false
    
    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        Button {
                            if let prefetched = locationManager.prefetchedLocation {
                                // Pre-fetch already completed — resolve instantly.
                                selection = prefetched
                                dismiss()
                            } else {
                                // Either prefetch is still in-flight or wasn't started
                                // (e.g. permission not yet granted). Request normally.
                                Task {
                                    isFetchingLocation = true
                                    if let item = await locationManager.requestCurrentLocation() {
                                        selection = item
                                        dismiss()
                                    }
                                    isFetchingLocation = false
                                }
                            }
                        } label: {
                            HStack {
                                Label("Use Current Location", systemImage: "location.fill")
                                Spacer()
                                if locationManager.isPrefetching || isFetchingLocation {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isFetchingLocation)
                    }
                    
                    Section("Saved Places") {
                        ForEach(savedLocations) { location in
                            Button {
                                let item = MKMapItem(
                                    location: CLLocation(latitude: location.coordinate.latitude,
                                                         longitude: location.coordinate.longitude),
                                    address: nil)
                                item.name = location.name
                                selection = item
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(location.name)
                                            .font(.body)
                                        Text(location.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteSavedLocations)
                        
                        if savedLocations.isEmpty {
                            Text("No saved places yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section("Search Results") {
                        ForEach(searchViewModel.completions, id: \.self) { completion in
                            HStack {
                                Button {
                                    resolveAndSelect(completion, shouldSave: false)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(completion.title)
                                            .foregroundStyle(.primary)
                                        if !completion.subtitle.isEmpty {
                                            Text(completion.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Button {
                                    resolveAndSelect(completion, shouldSave: true)
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.blue)
                                        .padding(.leading, 8)
                                }
                            }
                        }
                        
                        if searchViewModel.completions.isEmpty && !searchViewModel.isSearching {
                            Text("No results found")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search for a place")
            .onChange(of: searchText) { _, newValue in
                searchViewModel.updateQuery(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                if !searchText.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        if isResolvingSearch {
                            ProgressView()
                        }
                    }
                }
            }
            .overlay {
                if isResolvingSearch {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Resolving location...")
                                .padding()
                                .background(.thinMaterial)
                                .cornerRadius(10)
                        }
                }
            }
        }
    }
    
    private func resolveAndSelect(_ completion: MKLocalSearchCompletion, shouldSave: Bool) {
        isResolvingSearch = true
        Task {
            if let item = await searchViewModel.resolve(completion) {
                selection = item
                if shouldSave {
                    saveLocation(item)
                }
                dismiss()
            }
            isResolvingSearch = false
        }
    }
    
    private func saveLocation(_ item: MKMapItem) {
        let name = item.name ?? "Unknown Location"
        let address = item.address?.fullAddress ?? ""
        let lat = item.location.coordinate.latitude
        let lon = item.location.coordinate.longitude
        
        // Check if already saved
        if !savedLocations.contains(where: { $0.latitude == lat && $0.longitude == lon }) {
            let newLocation = SavedLocation(name: name, address: address, latitude: lat, longitude: lon)
            modelContext.insert(newLocation)
        }
    }
    
    private func deleteSavedLocations(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(savedLocations[index])
        }
    }
}

// MARK: - Search View Model (reusing logic from LocationSearchField)

@MainActor
class LocationSearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var completions: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    // Pre-create the completer so it's ready when the View creates the VM.
    // Making it static ensures one shared instance across the app lifecycle.
    private static let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        Self.completer.delegate = self
        Self.completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ query: String) {
        Self.completer.queryFragment = query
        isSearching = !query.isEmpty
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first
        } catch {
            print("Search resolution failed: \(error.localizedDescription)")
            return nil
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.completions = results
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
        }
    }
}
