//
//  SettingDetailView.swift
//  Pace
//
//  Created by jan on 19/02/2025.
//

import SwiftUI

struct SettingDetailView: View {
    let title: String
    
    var body: some View {
        VStack {
            Text("\(title) Settings")
                .font(.largeTitle)
                .padding()
            Spacer()
        }
        .navigationTitle(title)
    }
}
