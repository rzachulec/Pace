//
//  AppearanceSettingsView.swift
//  Pace
//
//  Created by jan on 21/02/2025.
//

import SwiftUI

// MARK: - Colour name → Color resolution (single source of truth used by both
//         AppearanceSettingsView and PaceApp when applying .tint())

extension Color {
    static func fromAccentName(_ name: String) -> Color {
        switch name {
        case "indigo": return .indigo
        case "purple": return .purple
        case "teal":   return .teal
        case "green":  return .green
        case "mint":   return .mint
        case "orange": return .orange
        case "pink":   return .pink
        case "red":    return .red
        default:       return .blue
        }
    }
}

// MARK: - View

public struct AppearanceSettingsView: View {

    // Same UserDefaults key as PaceApp — changing it here instantly updates the root .tint()
    @AppStorage("accentColorName") private var accentColorName: String = "blue"

    private struct PaletteEntry: Identifiable {
        let id: String      // storage key
        let color: Color
        let label: String
    }

    private let palette: [PaletteEntry] = [
        .init(id: "blue",   color: .blue,   label: "Blue"),
        .init(id: "indigo", color: .indigo, label: "Indigo"),
        .init(id: "purple", color: .purple, label: "Purple"),
        .init(id: "teal",   color: .teal,   label: "Teal"),
        .init(id: "green",  color: .green,  label: "Green"),
        .init(id: "mint",   color: .mint,   label: "Mint"),
        .init(id: "orange", color: .orange, label: "Orange"),
        .init(id: "pink",   color: .pink,   label: "Pink"),
        .init(id: "red",    color: .red,    label: "Red"),
    ]

    private let columns = Array(repeating: GridItem(.flexible()), count: 3)

    public var body: some View {
        Form {
            Section {
                previewRow
            } header: {
                Text("Preview")
            }

            Section {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(palette) { entry in
                        colourSwatch(entry)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Accent Colour")
            }
        }
        .navigationTitle("Appearance")
    }

    // MARK: - Sub-views

    private var previewRow: some View {
        HStack(spacing: 16) {
            // Shows how the accent colour looks on a button and a toggle.
            // Apply .tint() locally so the button reacts to @AppStorage immediately,
            // without waiting for the environment .tint() to propagate from PaceApp.
            Button("Add Task") {}
                .buttonStyle(.borderedProminent)
                .tint(Color.fromAccentName(accentColorName))

            Toggle("Notifications", isOn: .constant(true))
                .labelsHidden()
                .tint(Color.fromAccentName(accentColorName))

            Spacer()

            // Colour swatch of the active selection
            Circle()
                .fill(Color.fromAccentName(accentColorName))
                .frame(width: 32, height: 32)
                .shadow(color: Color.fromAccentName(accentColorName).opacity(0.5), radius: 6)
        }
        .padding(.vertical, 4)
    }

    private func colourSwatch(_ entry: PaletteEntry) -> some View {
        let isSelected = accentColorName == entry.id
        return Button {
            accentColorName = entry.id
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(entry.color)
                        .frame(width: 52, height: 52)
                        .shadow(
                            color: entry.color.opacity(isSelected ? 0.5 : 0),
                            radius: isSelected ? 10 : 0
                        )
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                Text(entry.label)
                    .font(.caption)
                    .foregroundColor(isSelected ? entry.color : .secondary)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25), value: accentColorName)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
