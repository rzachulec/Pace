//
//  PaceTests.swift
//  PaceTests
//
//  Created by jan on 11/02/2025.
//

import Testing
@testable import Pace

// MARK: - StateManager unit tests

@Suite("StateManager — day boundary calculations")
struct StateManagerTests {

    // Each test creates a fresh instance so @AppStorage writes to UserDefaults.standard
    // don't carry state between tests. Both wakeUpTime and sleepTime are always set
    // explicitly, making each case fully self-contained.

    @Test("Day length equals sleepTime minus wakeUpTime")
    func dayLengthBasic() {
        let sm = StateManager()
        sm.wakeUpTime = 8
        sm.sleepTime  = 24
        #expect(sm.dayLength == 16)
    }

    @Test("Early-riser schedule produces correct day length")
    func dayLengthEarlyRiser() {
        let sm = StateManager()
        sm.wakeUpTime = 5
        sm.sleepTime  = 21
        #expect(sm.dayLength == 16)
    }

    @Test("Night-owl sleep time past midnight still computes correctly")
    func dayLengthNightOwl() {
        let sm = StateManager()
        sm.wakeUpTime = 8
        sm.sleepTime  = 26   // 2 AM next day
        #expect(sm.dayLength == 18)
    }

    @Test("Percentage of day is always in the range 0 – 100")
    func percentageIsWithinBounds() {
        let sm = StateManager()
        sm.wakeUpTime = 8
        sm.sleepTime  = 24
        #expect(sm.percentageOfDay >= 0)
        #expect(sm.percentageOfDay <= 100)
    }

    @Test("Working-days bool array round-trips through the string representation")
    func workingDaysRoundTrip() {
        let sm = StateManager()
        sm.workingDays = [true, false, true, true, true, false, false]
        #expect(sm.workingDaysString == "1011100")
    }

    @Test("Changing wake time updates day length immediately")
    func wakeTimeChangeUpdatesLength() {
        let sm = StateManager()
        sm.wakeUpTime = 9
        sm.sleepTime  = 23
        let before = sm.dayLength          // 23 - 9 = 14
        sm.wakeUpTime = 7
        let after  = sm.dayLength          // 23 - 7 = 16
        #expect(before == 14)
        #expect(after  == 16)
    }
}
