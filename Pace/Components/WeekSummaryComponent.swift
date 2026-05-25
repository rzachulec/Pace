//
//  dayEvents.swift
//  Pace
//
//  Created by jan on 20/02/2025.
//

import SwiftUI

struct WeekSummaryComponent: View {

    // Changed from @Binding to let — these values come from Binding.constant() in the parent,
    // meaning they are read-only and never written back. Plain let makes the contract explicit.
    let day: String
    let date: Date
    let events: [EventData]

    @Binding var selectedDate: Date?
    @Binding var showDayView: Bool

    var body: some View {
        let totalDuration = events.reduce(0.0) { sum, e in
            guard let start = e.startDate, let end = e.endDate else { return sum }
            return sum + end.timeIntervalSince(start)
        } / 3600

        Button(action: {
            selectedDate = date
            showDayView = true
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.gray.opacity(0), lineWidth: 4)
                    .frame(height: 55)
                    .overlay(
                        HStack(spacing: 0) {
                            let barColor: Color = events.first?.ekEvent?.calendar.cgColor.map { Color(cgColor: $0) } ?? .accentColor
                            Rectangle()
                                .fill(barColor.opacity(0.7))
                                .frame(width: CGFloat(totalDuration) * 20)
                            Spacer()
                        }
                    )
                HStack {
                    Text(day).font(.title3)
                    Spacer()
                    Text("\(events.count) tasks, \(String(format: "%.0f", totalDuration)) h")
                }
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.gray, lineWidth: 1))
                .foregroundColor(.primary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
