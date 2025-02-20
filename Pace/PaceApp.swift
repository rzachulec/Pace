//
//  PaceApp.swift
//  Pace
//
//  Created by jan on 11/02/2025.
//

import SwiftUI

@main
struct PaceApp: App {
    @StateObject var calendarManager = CalendarManager()
    @StateObject var animationHandler = AnimationHandler()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarManager)
                .environmentObject(animationHandler)
                .onAppear {
                    animationHandler.startAnimation()
                }
        }
    }
}
