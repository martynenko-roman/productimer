import Foundation

public enum ActivityOutcome: String, Codable, Sendable { case completed, skipped, reset }
public struct ActivityImportDetails: Codable, Equatable, Sendable {
    public let sourceID: String?
    public let title: String?
    public let tag: String?
    public let interruptions: Int?
    public let estimatedTiming: Bool
    public init(sourceID: String? = nil, title: String? = nil, tag: String? = nil,
                interruptions: Int? = nil, estimatedTiming: Bool = false) {
        self.sourceID = sourceID; self.title = title; self.tag = tag
        self.interruptions = interruptions; self.estimatedTiming = estimatedTiming
    }
}
public struct RunningInterval: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date
    public init(start: Date, end: Date) { self.start = start; self.end = max(start, end) }
    public var seconds: TimeInterval { end.timeIntervalSince(start) }
    public func seconds(in range: DateInterval) -> TimeInterval {
        max(0, min(end, range.end).timeIntervalSince(max(start, range.start)))
    }
}
public struct ActivityRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let activity: Activity
    public let startedAt: Date
    public let endedAt: Date
    public let outcome: ActivityOutcome
    public let intervals: [RunningInterval]
    public let beganBeforeTracking: Bool
    public let importDetails: ActivityImportDetails?
    public var seconds: TimeInterval { intervals.reduce(0) { $0 + $1.seconds } }
    public init(id: UUID = UUID(), activity: Activity, startedAt: Date, endedAt: Date,
                outcome: ActivityOutcome, intervals: [RunningInterval], beganBeforeTracking: Bool = false,
                importDetails: ActivityImportDetails? = nil) {
        self.id = id; self.activity = activity; self.startedAt = startedAt; self.endedAt = endedAt
        self.outcome = outcome; self.intervals = intervals; self.beganBeforeTracking = beganBeforeTracking
        self.importDetails = importDetails
    }
    public func seconds(in range: DateInterval) -> TimeInterval {
        let total = intervals.reduce(0) { $0 + $1.seconds(in: range) }
        guard importDetails?.estimatedTiming == true else { return total }
        // Imported active time is represented separately from elapsed wall time.
        let elapsed = endedAt.timeIntervalSince(startedAt)
        guard elapsed > 0 else { return 0 }
        return max(0, min(endedAt, range.end).timeIntervalSince(max(startedAt, range.start))) * seconds / elapsed
    }
}
public struct ActiveSession: Codable, Equatable, Sendable {
    public let id: UUID
    public let activity: Activity
    public let startedAt: Date
    public var intervals: [RunningInterval]
    public var resumedAt: Date?
    public let beganBeforeTracking: Bool
    init(activity: Activity, at date: Date, running: Bool = true, legacy: Bool = false) {
        id = UUID(); self.activity = activity; startedAt = date; intervals = []
        resumedAt = running ? date : nil; beganBeforeTracking = legacy
    }
    mutating func stop(at date: Date) {
        if let resumedAt { intervals.append(.init(start: resumedAt, end: max(resumedAt, date))) }
        resumedAt = nil
    }
}

extension SavedTimer {
    /// Adopt a pre-history timer without inventing activity before this upgrade.
    public mutating func prepareHistory(at date: Date) {
        if activeSession == nil, engine.status != .ready {
            activeSession = ActiveSession(activity: engine.activity, at: date,
                                          running: engine.status == .running, legacy: true)
        }
    }
    @discardableResult
    public mutating func tick(at date: Date, allowAutoStart: Bool = true) -> [TimerEvent] {
        prepareHistory(at: date)
        let end = engine.deadline ?? date
        let events = engine.tick(at: date, preferences: preferences, allowAutoStart: allowAutoStart)
        if events.contains(where: { if case .ended = $0 { true } else { false } }) {
            finishHistory(at: end, outcome: .completed)
        }
        if events.contains(where: { if case .started = $0 { true } else { false } }) {
            activeSession = ActiveSession(activity: engine.activity, at: date)
        }
        return events
    }
    @discardableResult
    public mutating func toggle(at date: Date) -> [TimerEvent] {
        prepareHistory(at: date)
        if engine.status == .running, let deadline = engine.deadline, deadline <= date {
            return tick(at: date)
        }
        let previousStatus = engine.status
        let events = engine.toggle(at: date, preferences: preferences)
        switch previousStatus {
        case .ready: activeSession = ActiveSession(activity: engine.activity, at: date)
        case .running: activeSession?.stop(at: date)
        case .paused: activeSession?.resumedAt = date
        }
        return events
    }
    public mutating func skip(at date: Date) {
        if engine.status == .running, let deadline = engine.deadline, deadline <= date {
            _ = tick(at: date, allowAutoStart: false)
            return
        }
        settleBeforeInterruption(at: date, outcome: .skipped)
        engine.skip(preferences: preferences)
    }
    public mutating func resetPeriod(at date: Date) {
        settleBeforeInterruption(at: date, outcome: .reset)
        engine.resetPeriod(preferences: preferences)
    }
    public mutating func resetCycle(at date: Date) {
        settleBeforeInterruption(at: date, outcome: .reset)
        engine.resetCycle(preferences: preferences)
    }
    private mutating func settleBeforeInterruption(at date: Date, outcome: ActivityOutcome) {
        prepareHistory(at: date)
        if engine.status == .running, let deadline = engine.deadline, deadline <= date {
            // Credit the elapsed activity once before applying the user's next action.
            _ = tick(at: date, allowAutoStart: false)
        } else { finishHistory(at: date, outcome: outcome) }
    }
    private mutating func finishHistory(at date: Date, outcome: ActivityOutcome) {
        guard var session = activeSession else { return }
        session.stop(at: date)
        // Legacy expired timers have no observed running time. Do not backfill them.
        if !session.beganBeforeTracking || session.intervals.contains(where: { $0.seconds > 0 }) {
            let record = ActivityRecord(id: session.id, activity: session.activity, startedAt: session.startedAt,
                                        endedAt: max(session.startedAt, date), outcome: outcome,
                                        intervals: session.intervals, beganBeforeTracking: session.beganBeforeTracking)
            if !history.contains(where: { $0.id == record.id }) { history.append(record) }
        }
        activeSession = nil
    }
}

public enum StatisticsPeriod: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, year
    public var id: String { rawValue }
    public var component: Calendar.Component {
        switch self { case .day: .day; case .week: .weekOfYear; case .month: .month; case .year: .year }
    }
    public func interval(containing date: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: component, for: date) ?? DateInterval(start: date, duration: 86400)
    }
}
public struct ActivitySummary: Equatable, Sendable {
    public var focusSeconds: TimeInterval = 0
    public var breakSeconds: TimeInterval = 0
    public var completedFocuses = 0
    public init(records: [ActivityRecord], range: DateInterval) {
        for record in records {
            if record.activity == .focus {
                focusSeconds += record.seconds(in: range)
                if record.outcome == .completed && record.endedAt >= range.start && record.endedAt < range.end {
                    completedFocuses += 1
                }
            } else { breakSeconds += record.seconds(in: range) }
        }
    }
}
public struct ActivityBucket: Identifiable, Sendable {
    public var id: Date { start }
    public let start: Date
    public let focusSeconds: TimeInterval
}
public enum ActivityStatistics {
    public static func buckets(records: [ActivityRecord], range: DateInterval,
                               period: StatisticsPeriod, calendar: Calendar) -> [ActivityBucket] {
        let component: Calendar.Component = period == .day ? .hour : period == .year ? .month : .day
        var cursor = range.start
        var result: [ActivityBucket] = []
        while cursor < range.end {
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor), next > cursor else { break }
            let interval = DateInterval(start: cursor, end: min(next, range.end))
            let seconds = records.filter { $0.activity == .focus }.reduce(0) { $0 + $1.seconds(in: interval) }
            result.append(.init(start: cursor, focusSeconds: seconds))
            cursor = next
        }
        return result
    }
    public static func records(_ records: [ActivityRecord], in range: DateInterval) -> [ActivityRecord] {
        records.filter { $0.seconds(in: range) > 0 || ($0.endedAt >= range.start && $0.endedAt < range.end) }
            .sorted { $0.endedAt > $1.endedAt }
    }
}
