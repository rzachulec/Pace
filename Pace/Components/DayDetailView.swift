//
//  DayDetailView.swift
//  Pace
//
//  Created by jan on 19/02/2025.
//

import SwiftUI

struct DayDetailView: View {
    @Binding var showDayView: Bool
    let date: Date
    
    func dayOfWeek(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Full name of the day
        return formatter.string(from: date)
    }
    
    func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short // Concise date format
        return formatter.string(from: date)
    }
        
    var body: some View {
        Text("")
            .sheet(isPresented: $showDayView) {
                VStack(spacing: 20) {
                    Text(dayOfWeek(from: date) + ", " + formattedDate(from: date))
                        .font(.headline)
                    HStack{
                        Text("Tasks:")
                        Spacer()
                    }
                    UpcomingTasksList(date: date)
                }
                .overlay(
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                self.showDayView = false
                            }) {
                                Text("Done")
                                    .font(.title3)
                            }
                        }
                        Spacer()
                    }
                )
                .padding()
                .padding(.top)
                .presentationDetents([.medium, .large])
                .presentationBackground(.thinMaterial)
            }
    }
}
