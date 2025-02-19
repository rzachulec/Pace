//
//  SettingsView.swift
//  Pace
//
//  Created by jan on 13/02/2025.
//

import SwiftUI

struct SettingsView: View {
    
    @State private var searchText = ""
    @State private var filteredOptions: [(String, String)] = []

    
    private let settingsOptions = [
        ("General", "gear"),
        ("Schedule", "calendar"),
        ("Appearance", "paintbrush"),
        ("Notifications", "bell"),
        ("Privacy", "lock.shield"),
        ("Your Data", "person.circle"),
        ("Help & Support", "questionmark.circle")
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(filteredOptions, id: \.0) { option in
                        NavigationLink(destination: SettingDetailView(title: option.0)) {
                            Label(option.0, systemImage: option.1)
                        }
                    }
                }
                //                    Section {
                //                        HStack {
                //                            Spacer(minLength: 0)
                //                            Image("Image")
                //                                .resizable()
                //                                .frame(width: 100, height: 100)
                //                            VStack(alignment: .leading, spacing: 10) {
                //                                Text("Pace 2025")
                //                                Text("pace.com")
                //                            }
                //                            Spacer()
                //                        }
                //                    }
            }
            .navigationTitle("Settings")
            .searchable(text: $searchText, prompt: "Search Settings")
        }
        .onAppear {
            filteredOptions = settingsOptions
        }
        .onChange(of: searchText) { oldValue, newValue in
            filteredOptions = newValue.isEmpty ? settingsOptions :
                settingsOptions.filter { $0.0.localizedCaseInsensitiveContains(newValue) }
        }
    }
}



#Preview {
    SettingsView()
}
