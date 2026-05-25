//
//  DayDetailView.swift
//  Pace
//
//  Created by jan on 19/02/2025.
//

import SwiftUI

// Pure content view — the sheet presentation is owned by ScheduleView,
// which is always in the hierarchy and can reliably trigger the sheet.
// Using @Environment(\.dismiss) instead of a @Binding var showDayView
// keeps the dismissal self-contained without requiring the parent's state.

struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let date: Date

    // Static formatters — DateFormatter is expensive; was being recreated
    // on every body call when they lived in plain instance methods.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack {
                    Text("Tasks:")
                    Spacer()
                }
                UpcomingTasksList(date: date, upcomingOnly: false)
            }
            .padding()
            .navigationTitle(Self.dayFormatter.string(from: date) + ", " + Self.dateFormatter.string(from: date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(role: .close) { dismiss() }
            }
        }
    }
}
