//
//  CurrentTask.swift
//  Pace
//
//  Created by jan on 14/02/2025.
//

import SwiftUI
import EventKit

struct CurrentTask: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var stateManager: StateManager
    @AppStorage("accentColorName") private var accentColorName: String = "blue"

    @State private var minutesRemaining: Int = 0
    @State private var showEditTask = false

    // MARK: - Animation state
    // Driven from 0 on every appear; two simultaneous effects (width growth +
    // opacity fade-in) make this a custom programmed animation with two
    // transition effects as required by the assignment spec.
    @State private var animatedProgress: Double = 0
    @State private var fillOpacity: Double = 0

    // Tune these at the demo:
    private static let appearDuration: Double = 1.2
    private static let appearBounce:   Double = 0.10
    private static let appearDelay:    Double = 0.2

    // MARK: - Derived data

    private var currentEvent: EventData? {
        let now = Date()
        return calendarManager.events.first {
            guard !$0.isAllDay, let s = $0.startDate, let e = $0.endDate else { return false }
            return now >= s && now <= e
        }
    }

    private var nextEvent: EventData? {
        let now = Date()
        return calendarManager.events
            .filter {
                guard let s = $0.startDate else { return false }
                return s > now && s < stateManager.sleepDate
            }
            .min { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
    }

    private func updateRemainingTime() {
        minutesRemaining = currentEvent.flatMap(\.endDate).map {
            max(Int($0.timeIntervalSince(Date()) / 60), 0)
        } ?? 0
    }

    private func progressForCurrentEvent() -> Double {
        guard let event = currentEvent,
              let start = event.startDate,
              let end   = event.endDate else { return 0 }
        let total   = end.timeIntervalSince(start)
        let elapsed = Date().timeIntervalSince(start)
        return total > 0 ? min(max(elapsed / total, 0), 1) : 0
    }

    private func triggerFillAnimation() {
        let target = progressForCurrentEvent()
        animatedProgress = 0
        fillOpacity      = 0
        withAnimation(
            .spring(duration: Self.appearDuration, bounce: Self.appearBounce)
            .delay(Self.appearDelay)
        ) {
            animatedProgress = target
            fillOpacity      = target > 0 ? 0.3 : 0
        }
    }

    // MARK: - Body

    var body: some View {
        // Hoist once — each computed var does a linear scan of events.
        let current = currentEvent
        let next    = nextEvent

        tileContent(current: current, next: next)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background { fillBar(current: current) }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.gray, lineWidth: 1))
            .contentShape(Rectangle())
            // Direct tap to edit — no long-press required.
            // Context menu is still available for secondary actions.
            .onTapGesture {
                guard current != nil || next != nil else { return }
                showEditTask = true
            }
            .contextMenu { contextMenuItems(current: current, next: next) }
            // Re-animate whenever events are added or edited so progress is
            // immediately reflected without waiting for the next 30-second tick.
            // DayProgressBadge is unaffected — it only listens to stateManager.percentageOfDay.
            .onChange(of: calendarManager.events) { _, _ in
                triggerFillAnimation()
            }
            // Task hoisted to the outer view so the countdown keeps ticking even
            // while transitioning between current/next/empty branches.
            // The initial appear also fires the fill animation from zero.
            .task {
                updateRemainingTime()
                triggerFillAnimation()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    updateRemainingTime()
                    // Smooth ongoing nudge — no reset to 0 after the initial animation.
                    withAnimation(.easeInOut(duration: 0.5)) {
                        animatedProgress = progressForCurrentEvent()
                    }
                }
            }
            .sheet(isPresented: $showEditTask) {
                if let event = current ?? next {
                    EditTask(event: event)
                        .environmentObject(calendarManager)
                        .environmentObject(stateManager)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(.thinMaterial)
                }
            }
    }

    // MARK: - Text content

    @ViewBuilder
    private func tileContent(current: EventData?, next: EventData?) -> some View {
        if let event = current {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Task")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(event.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text("\(minutesRemaining) min remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Spacer()
				VStack(alignment: .trailing, spacing: 4) {
					Text("Tap for")
						.font(.caption)
					Text("details")
						.font(.caption)
				}
            }
            .padding()

        } else if let event = next, let start = event.startDate {
            let minutesUntil = max(Int(start.timeIntervalSince(Date()) / 60), 0)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Task")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(event.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    // Show countdown if < 1 h; otherwise show the clock time.
                    Text(minutesUntil < 60
                         ? "in \(minutesUntil) min"
                         : "at \(start.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()

        } else {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No upcoming tasks")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Add a task to get started.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Fill bar

    // Scoped to .background so the GeometryReader reads the tile's own width
    // without forcing the entire layout to go through an outer GeometryReader.
    // Plain Color fills left-to-right; the outer clipShape handles the rounding
    // so there is no floating rounded rectangle at partial progress levels.
    // Width (animatedProgress) and opacity (fillOpacity) are driven together
    // from triggerFillAnimation() — the two simultaneous effects for the
    // custom programmed animation.
    @ViewBuilder
    private func fillBar(current: EventData?) -> some View {
        if current != nil {
            GeometryReader { geo in
                Color.fromAccentName(accentColorName).opacity(fillOpacity)
                    .frame(width: geo.size.width * animatedProgress)
            }
        }
        // Empty else → no fill for "next task" or empty state
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenuItems(current: EventData?, next: EventData?) -> some View {
        if let event = current, let startDate = event.startDate {
            Button {
                calendarManager.openCalendarEvent(startDate: startDate)
            } label: {
                Label("View in Calendar", systemImage: "calendar")
            }

            Button { showEditTask = true } label: {
                Label("Edit", systemImage: "slider.horizontal.below.rectangle")
            }

            Divider()

            Button {
                calendarManager.updateEvent(
                    eventID:       event.id,
                    newTitle:      event.title,
                    newStartDate:  startDate,
                    newEndDate:    Date(),          // truncate end to now
                    placementType: event.placementType,
                    priority:      event.priority
                )
            } label: {
                Label("Mark Done", systemImage: "checkmark.circle")
            }

        } else if let event = next, let startDate = event.startDate {
            Button {
                calendarManager.openCalendarEvent(startDate: startDate)
            } label: {
                Label("View in Calendar", systemImage: "calendar")
            }

            Button { showEditTask = true } label: {
                Label("Edit", systemImage: "slider.horizontal.below.rectangle")
            }

            Divider()

            Button {
                guard let end = event.endDate else { return }
                let duration = end.timeIntervalSince(startDate)
                calendarManager.updateEvent(
                    eventID:       event.id,
                    newTitle:      event.title,
                    newStartDate:  Date(),
                    newEndDate:    Date().addingTimeInterval(duration),
                    placementType: event.placementType,
                    priority:      event.priority
                )
            } label: {
                Label("Start Now", systemImage: "stopwatch")
            }
        }
        // Empty else → no menu items when there are no events
    }
}

#Preview {
    CurrentTask()
        .environmentObject(CalendarManager.shared)
        .environmentObject(StateManager())
}
