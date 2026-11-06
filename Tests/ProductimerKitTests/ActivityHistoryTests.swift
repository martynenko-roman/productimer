import Foundation
import Testing
@testable import ProductimerKit

private let start = Date(timeIntervalSince1970: 1_700_000_000)
private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

@Test func historyExcludesPausesAndCompletesOnce() throws {
    var saved = SavedTimer()
    saved.toggle(at: start)
    saved.toggle(at: start.addingTimeInterval(300))
    saved.toggle(at: start.addingTimeInterval(900))
    let encoded = try JSONEncoder().encode(saved)
    saved = try JSONDecoder().decode(SavedTimer.self, from: encoded)
    saved.tick(at: start.addingTimeInterval(3000), allowAutoStart: false)
    #expect(saved.history.count == 1)
    #expect(saved.history[0].seconds == 1500)
    #expect(saved.history[0].endedAt == start.addingTimeInterval(2100))
    #expect(saved.history[0].outcome == .completed)
    #expect(saved.history[0].intervals.count == 2)
    saved.tick(at: start.addingTimeInterval(6000))
    #expect(saved.history.count == 1)
    #expect(saved.activeSession == nil)
}

@Test func partialActivitiesAndReadyActions() {
    var saved = SavedTimer()
    saved.skip(at: start) // ready focus: no record
    saved.resetCycle(at: start)
    #expect(saved.history.isEmpty)
    saved.toggle(at: start)
    saved.toggle(at: start.addingTimeInterval(120))
    saved.skip(at: start.addingTimeInterval(900))
    #expect(saved.history.count == 1)
    #expect(saved.history[0].seconds == 120)
    #expect(saved.history[0].outcome == .skipped)
    #expect(saved.engine.completedFocus == 0)
    saved.toggle(at: start.addingTimeInterval(1000)) // break
    saved.resetCycle(at: start.addingTimeInterval(1060))
    #expect(saved.history.count == 2)
    #expect(saved.history[1].activity == .shortBreak)
    #expect(saved.history[1].outcome == .reset)
    #expect(saved.history[1].seconds == 60)
    #expect(saved.engine.activity == .focus)
}

@Test func autoStartCreatesDistinctSessionAndExpiredSkipDoesNotDoubleAdvance() {
    var saved = SavedTimer()
    saved.preferences.autoStartBreaks = true
    saved.toggle(at: start)
    saved.tick(at: start.addingTimeInterval(1500))
    #expect(saved.history.count == 1)
    #expect(saved.activeSession?.activity == .shortBreak)
    #expect(saved.activeSession?.id != saved.history[0].id)
    saved.tick(at: start.addingTimeInterval(1800))
    #expect(saved.history.count == 2)
    #expect(saved.history[1].seconds == 300)
    saved.toggle(at: start.addingTimeInterval(2000))
    saved.skip(at: start.addingTimeInterval(4000))
    #expect(saved.history.count == 3)
    #expect(saved.history[2].outcome == .completed)
    #expect(saved.engine.activity == .shortBreak)
    #expect(saved.engine.status == .ready)
}

@Test func oldSaveMigratesWithoutInventingHistory() throws {
    var old = SavedTimer()
    old.engine.toggle(at: start, preferences: old.preferences)
    let data = try JSONEncoder().encode(old)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object.removeValue(forKey: "history"); object.removeValue(forKey: "activeSession")
    var migrated = try JSONDecoder().decode(SavedTimer.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(migrated.history.isEmpty)
    #expect(migrated.preferences == old.preferences)
    migrated.prepareHistory(at: start.addingTimeInterval(1000))
    migrated.tick(at: start.addingTimeInterval(1500), allowAutoStart: false)
    #expect(migrated.history.count == 1)
    #expect(migrated.history[0].seconds == 500)
    #expect(migrated.history[0].beganBeforeTracking)
    var expired = try JSONDecoder().decode(SavedTimer.self, from: JSONSerialization.data(withJSONObject: object))
    expired.tick(at: start.addingTimeInterval(9000), allowAutoStart: false)
    #expect(expired.history.isEmpty)
}

@Test func midnightAllocationAndCompletionDate() {
    let midnight = utc.startOfDay(for: start)
    let record = ActivityRecord(activity: .focus, startedAt: midnight.addingTimeInterval(-600), endedAt: midnight.addingTimeInterval(900),
        outcome: .completed, intervals: [.init(start: midnight.addingTimeInterval(-600), end: midnight.addingTimeInterval(900))])
    let today = DateInterval(start: midnight, duration: 86400)
    let yesterday = DateInterval(start: midnight.addingTimeInterval(-86400), duration: 86400)
    #expect(ActivitySummary(records: [record], range: today).focusSeconds == 900)
    #expect(ActivitySummary(records: [record], range: yesterday).focusSeconds == 600)
    #expect(ActivitySummary(records: [record], range: today).completedFocuses == 1)
    #expect(ActivitySummary(records: [record], range: yesterday).completedFocuses == 0)
    #expect(ActivityStatistics.records([record], in: yesterday).count == 1)
}

@Test func daylightSavingBucketsPreserveTime() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    for (month, day, expectedHours) in [(3, 8, 23), (11, 1, 25)] {
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day)))
        let range = StatisticsPeriod.day.interval(containing: date, calendar: calendar)
        let record = ActivityRecord(activity: .focus, startedAt: range.start, endedAt: range.end, outcome: .completed,
                                    intervals: [.init(start: range.start, end: range.end)])
        let buckets = ActivityStatistics.buckets(records: [record], range: range, period: .day, calendar: calendar)
        #expect(buckets.count == expectedHours)
        #expect(buckets.reduce(0) { $0 + $1.focusSeconds } == range.duration)
    }
}

@Test func summarySeparatesFocusBreakAndOutcomes() {
    let range = DateInterval(start: start, duration: 86400)
    let records = [
        ActivityRecord(activity: .focus, startedAt: start, endedAt: start.addingTimeInterval(300), outcome: .skipped,
                       intervals: [.init(start: start, end: start.addingTimeInterval(300))]),
        ActivityRecord(activity: .shortBreak, startedAt: start, endedAt: start.addingTimeInterval(60), outcome: .completed,
                       intervals: [.init(start: start, end: start.addingTimeInterval(60))])
    ]
    let summary = ActivitySummary(records: records, range: range)
    #expect(summary.focusSeconds == 300)
    #expect(summary.breakSeconds == 60)
    #expect(summary.completedFocuses == 0)
}
