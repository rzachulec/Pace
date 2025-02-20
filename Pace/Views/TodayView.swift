//
//  HomeView.swift
//  Pace
//
//  Created by jan on 13/02/2025.
//

import SwiftUI
import Foundation
import EventKit

struct TodayView: View {
    
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var animationHandler: AnimationHandler
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .compact && verticalSizeClass == .regular {
            VStack {
                ZStack(alignment: .trailing) {
                    Image("Background")
                        .resizable()
                        .scaledToFill()
                        .clipShape(Rectangle())
                        .frame(height: 130)
                        .offset(y: animationHandler.offsetY)
                        .padding(-10)
                        .blur(radius: 15)
                        .brightness(-0.1)
                        .mask(
                            HStack {
                                Text("Today: \n \(calendarManager.totalTasks) scheduled \n \(calendarManager.completedTasks) completed")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                Spacer()
                                RoundedRectangle(cornerRadius: 20)
                                    .frame(width: 115, height: 100)
                            }
                        )
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .frame(width: 115, height: 100)
                            .opacity(0.01)
                        VStack {
                            Text("Day progress")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(animationHandler.percentageOfDay)%")
                                .font(.system(size: 36, weight: .bold))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
                    
                    CurrentTask(offsetY: animationHandler.offsetY, material: .ultraThinMaterial)
                    
                    VStack {
                        HStack{
                            Text("Upcoming Tasks:")
                            Spacer()
                        }
                        .padding()
                        UpcomingTasksList()
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(.gray, lineWidth: 1)
                    )
                    .padding(.bottom, 15)
                    
                    AddTask()
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.gray, lineWidth: 1)
                        )
                Spacer()
            }
            .padding()
            .onAppear {
                calendarManager.updateTaskCounts()
                Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                    calendarManager.updateTaskCounts()
                }
            }
        } else {
            HStack {
                VStack {
                    ZStack(alignment: .trailing) {
                        Image("Background")
                            .resizable()
                            .scaledToFill()
                            .clipShape(Rectangle())
                            .frame(height: 130)
                            .offset(y: animationHandler.offsetY)
                            .padding(-10)
                            .blur(radius: 15)
                            .brightness(-0.1)
                            .mask(
                                HStack {
                                    Text("Today: \n \(calendarManager.totalTasks) scheduled \n \(calendarManager.completedTasks) completed")
                                        .font(.title)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 20)
                                        .frame(width: 115, height: 100)
                                }
                            )
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .frame(width: 115, height: 100)
                                .opacity(0.01)
                            VStack {
                                Text("Day progress")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(animationHandler.percentageOfDay)%")
                                    .font(.system(size: 36, weight: .bold))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    CurrentTask(offsetY: animationHandler.offsetY, material: .ultraThinMaterial)
                        .padding(.bottom, 10)
                    
                    AddTask()
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.gray, lineWidth: 1)
                        )
                    
                }
                VStack {
                    
                    VStack {
                        HStack{
                            Text("Upcoming Tasks:")
                            Spacer()
                        }
                        .padding()
                        UpcomingTasksList()
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(.gray, lineWidth: 1)
                    )
                }
                .padding()
                .onAppear {
                    calendarManager.updateTaskCounts()
                    Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                        calendarManager.updateTaskCounts()
                    }
                }
            }
        }
    }
}


#Preview {
    TodayView()
        .environmentObject(CalendarManager())
        .environmentObject(AnimationHandler())
}
