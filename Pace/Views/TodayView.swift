//
//  HomeView.swift
//  Pace
//
//  Created by jan on 13/02/2025.
//

import SwiftUI
import Foundation

// MARK: - Day progress badge
//
// Extracted into its own struct so it has stable SwiftUI identity.
// When it lived as a computed property on TodayView, every 3-second
// updateTaskCounts() call rebuilt the Button + its .sheet modifier,
// letting SwiftUI see an intermediate state and briefly flash the
// @AppStorage default colour before UserDefaults was re-read.
// A dedicated struct is identity-tracked by its type + position, so
// re-renders of TodayView no longer touch the badge internals at all.

private struct DayProgressBadge: View {

    @EnvironmentObject private var stateManager: StateManager
    // Color.accentColor reads the asset-catalogue AccentColor, not the
    // runtime .tint() value.  Reading the AppStorage key directly gives
    // us the live selected colour without waiting for environment propagation.
    @AppStorage("accentColorName") private var accentColorName: String = "blue"
    @State private var showScheduleSettings = false

    // MARK: - Animation state
    // Both properties start at zero on every appear so the fill sweeps up
    // from empty each time the tab is opened.  Two simultaneous effects
    // (height growth + opacity fade-in) satisfy the assignment requirement
    // for at least two custom transition effects in a single programmed animation.
    @State private var animatedPct: Double = 0
    @State private var colorOpacity: Double = 0

    // Tune these to adjust the animation at the demo:
    private static let appearDuration: Double = 1.0
    private static let appearBounce:   Double = 0.15
    private static let appearDelay:    Double = 0.3

    var body: some View {
        let sleepHour = stateManager.sleepTime % 24

        Button(action: { showScheduleSettings = true }) {
            VStack(spacing: 2) {
                Text("\(stateManager.wakeUpTime):00–\(sleepHour):00")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text("\(stateManager.percentageOfDay)%")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.5), value: stateManager.percentageOfDay)
            }
            .frame(width: 115, height: 100)
            .background(
                // Plain Color (no corner radius of its own) fills from the bottom;
                // the outer clipShape applies the rounding to the whole badge at once,
                // so there's no floating rounded rectangle at partial fill levels.
                ZStack(alignment: .bottom) {
                    Color.gray.opacity(0.5)
                    Color.fromAccentName(accentColorName).opacity(colorOpacity)
                        .frame(height: 100 * animatedPct)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .onAppear {
            animatedPct  = 0
            colorOpacity = 0
            let target = Double(stateManager.percentageOfDay) / 100.0
            withAnimation(
                .spring(duration: Self.appearDuration, bounce: Self.appearBounce)
                .delay(Self.appearDelay)
            ) {
                animatedPct  = target
                colorOpacity = 0.35
            }
        }
        .onChange(of: stateManager.percentageOfDay) { _, newVal in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedPct = Double(newVal) / 100.0
            }
        }
        .sheet(isPresented: $showScheduleSettings) {
            NavigationStack {
                ScheduleSettingsView()
                    .environmentObject(stateManager)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showScheduleSettings = false }
                        }
                    }
            }
        }
    }
}

// MARK: - TodayView

struct TodayView: View {

    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var stateManager: StateManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    // MARK: - Shared sub-views (were duplicated verbatim across both layout branches)

    private var statsHeader: some View {
        HStack {
            Text("Today: \n \(calendarManager.totalTasks) scheduled \n \(calendarManager.completedTasks) completed")
                .font(.title)
                .fontWeight(.semibold)
            Spacer()
            DayProgressBadge()
        }
    }

    private var upcomingTasksSection: some View {
        VStack {
            HStack {
                Text("Upcoming Tasks:")
                Spacer()
            }
            .padding()
            UpcomingTasksList(date: Date())
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.gray, lineWidth: 1)
        )
    }

    // MARK: - Layout branches

    private var compactLayout: some View {
        VStack {
            statsHeader
            CurrentTask()
                .padding(.bottom, 13)
            upcomingTasksSection
                .padding(.bottom, 15)
            AddTask()
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.gray, lineWidth: 1)
                )
            Spacer()
        }
        .padding()
    }

    private var regularLayout: some View {
        HStack {
            VStack {
                statsHeader
                CurrentTask()
                    .padding(.bottom, 10)
                Spacer()
                AddTask()
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(.gray, lineWidth: 1)
                    )
            }
            .padding(.vertical)

            VStack {
                upcomingTasksSection
                    .padding(.top)
                Spacer()
            }
            .padding(.leading)
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if horizontalSizeClass == .compact && verticalSizeClass == .regular {
                compactLayout
            } else {
                regularLayout
            }
        }
        // Replace Timer (created fresh on every onAppear, never invalidated → leak after each
        // tab switch) with a structured-concurrency task that cancels on disappear automatically.
        .task {
            calendarManager.updateTaskCounts()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                calendarManager.updateTaskCounts()
            }
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(CalendarManager.shared)
        .environmentObject(StateManager())
}
