//
//  WeekSplitComponent.swift
//  Pace
//
//  Created by jan on 20/02/2025.
//

import SwiftUI

struct WeekSplitComponent: View {
    @EnvironmentObject var stateManager: StateManager

    // Changed from @Binding to let — these values come from Binding.constant() in the parent,
    // meaning they are read-only and never written back. Plain let makes the contract explicit.
    let day: String
    let date: Date
    let events: [EventData]

    @Binding var selectedDay: SelectedDay?
    var isToday: Bool
    var rowHeight: CGFloat = 55

    var body: some View {
        let now = Date()
        let wakeDate = Calendar.current.date(byAdding: .hour, value: Int(stateManager.wakeUpTime), to: Calendar.current.startOfDay(for: date))!
        let sleepDate = Calendar.current.date(byAdding: .hour, value: Int(stateManager.sleepTime), to: Calendar.current.startOfDay(for: date))!
        let getDayLength = stateManager.dayLength

        Button(action: {
            selectedDay = SelectedDay(date: date)
        }) {
            let eventsFiltered = events.filter {
                guard let start = $0.startDate, let end = $0.endDate else { return false }
                return start + Double(60 * 15) > wakeDate && end < sleepDate - Double(60 * 15)
            }
            GeometryReader { geometry in
                let scaler = geometry.size.width / CGFloat(getDayLength)
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(lineWidth: 0)
                        .frame(height: rowHeight)
                        .overlay(
                            HStack(spacing: 0) {
                                if let firstEvent = eventsFiltered.first, let firstStart = firstEvent.startDate {
                                    let initialGap = firstStart.timeIntervalSince(wakeDate) / 3600
                                    if initialGap > 0 {
                                        Spacer().frame(width: CGFloat(initialGap) * scaler)
                                    }
                                }

                                // Using eventsFiltered.indices (Range<Int>) avoids the Array()
                                // allocation that was here previously. EventData is Identifiable
                                // but we still need the index to calculate inter-event gaps.
                                ForEach(eventsFiltered.indices, id: \.self) { index in
                                    let event = eventsFiltered[index]
                                    if let start = event.startDate, let end = event.endDate {
                                        let eventDuration = end.timeIntervalSince(start) / 3600
                                        let eventWidth = CGFloat(eventDuration) * scaler
                                        let isDynamic = event.placementType == "Dynamic"
                                        let eventColor: Color = event.ekEvent?.calendar.cgColor.map { Color(cgColor: $0) } ?? .accentColor
                                        ZStack {
                                            Rectangle()
                                                .fill(eventColor.opacity(isDynamic ? 0.25 : 0.85))
                                            if isDynamic {
                                                Rectangle()
                                                    .stroke(eventColor.opacity(0.75), lineWidth: 2)
                                            }
                                        }
                                        .frame(width: eventWidth, height: rowHeight)

                                        if index < eventsFiltered.count - 1,
                                           let nextStart = eventsFiltered[index + 1].startDate {
                                            let gapDuration = nextStart.timeIntervalSince(end) / 3600
                                            let gapWidth = CGFloat(gapDuration) * scaler
                                            if gapWidth > 0 {
                                                Spacer().frame(width: gapWidth)
                                            }
                                        }
                                    }
                                }
                                Spacer()
                            }
                        )

                    if isToday {
                        let nowHours = now.timeIntervalSince(wakeDate) / 3600
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 2, height: rowHeight)
                            .shadow(color: Color.primary.opacity(0.9), radius: 4)
                            .shadow(color: Color.primary.opacity(0.5), radius: 8)
                            .offset(x: nowHours * scaler - geometry.size.width / 2)
                    }

                    HStack {
                        Text(day).font(.title3)
                        Spacer()
                        Text("\(eventsFiltered.count) tasks, \(String(format: "%.0f", eventsFiltered.reduce(0) { $0 + ($1.endDate?.timeIntervalSince($1.startDate ?? Date()) ?? 0) } / 3600)) h")
                    }
                    .padding(.horizontal)
                    .frame(height: rowHeight)
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.gray, lineWidth: 1))
                    .foregroundColor(.primary)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .frame(height: rowHeight)
    }
}
