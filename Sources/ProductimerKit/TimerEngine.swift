import Foundation

public enum Activity: String, Codable, CaseIterable, Sendable, Identifiable {
    case focus, shortBreak, longBreak
    public var id: String { rawValue }
    public var title: String {
        switch self { case .focus: "Focus"; case .shortBreak: "Short Break"; case .longBreak: "Long Break" }
    }
}

public enum Boundary: String, Codable, CaseIterable, Sendable { case start, end }
public enum TimerStatus: String, Codable, Sendable { case ready, running, paused }
public enum TimerEvent: Equatable, Sendable { case started(Activity), ended(Activity) }

public struct TimerPreferences: Codable, Equatable, Sendable {
    public var focusMinutes = 25
    public var shortBreakMinutes = 5
    public var longBreakMinutes = 20
    public var cycleLength = 4
    public var autoStartBreaks = false
    public var autoStartFocus = false
    public init() {}
    public func validated() -> Self {
        var copy = self
        copy.focusMinutes = min(180, max(1, focusMinutes))
        copy.shortBreakMinutes = min(180, max(1, shortBreakMinutes))
        copy.longBreakMinutes = min(180, max(1, longBreakMinutes))
        copy.cycleLength = min(12, max(1, cycleLength))
        return copy
    }
    public func duration(for activity: Activity) -> TimeInterval {
        let valid = validated()
        let minutes = switch activity {
        case .focus: valid.focusMinutes * 60
        case .shortBreak: valid.shortBreakMinutes * 60
        case .longBreak: valid.longBreakMinutes * 60
        }
        return TimeInterval(minutes)
    }
}

/// Deadline-based timing avoids drift when the run loop stalls or the Mac sleeps.
public struct TimerEngine: Codable, Equatable, Sendable {
    public private(set) var activity: Activity = .focus
    public private(set) var status: TimerStatus = .ready
    public private(set) var remaining: TimeInterval = 25 * 60
    public private(set) var deadline: Date?
    public private(set) var completedFocus = 0
    public init(preferences: TimerPreferences = .init()) { remaining = preferences.duration(for: .focus) }

    public func secondsRemaining(at now: Date) -> Int {
        let seconds = status == .running ? deadline?.timeIntervalSince(now) ?? remaining : remaining
        guard seconds.isFinite else { return 0 }
        return Int(ceil(min(180 * 60, max(0, seconds))))
    }

    @discardableResult
    public mutating func toggle(at now: Date, preferences: TimerPreferences) -> [TimerEvent] {
        switch status {
        case .running:
            if let deadline, deadline <= now { return tick(at: now, preferences: preferences) }
            remaining = max(0, deadline?.timeIntervalSince(now) ?? remaining)
            deadline = nil
            status = .paused
            return []
        case .paused:
            deadline = now.addingTimeInterval(remaining)
            status = .running
            return []
        case .ready:
            remaining = preferences.duration(for: activity)
            deadline = now.addingTimeInterval(remaining)
            status = .running
            return [.started(activity)]
        }
    }

    @discardableResult
    public mutating func tick(at now: Date, preferences: TimerPreferences, allowAutoStart: Bool = true) -> [TimerEvent] {
        guard status == .running, let deadline, deadline <= now else { return [] }
        let finished = activity
        if finished == .focus { completedFocus += 1 }
        advance(preferences: preferences)
        var events: [TimerEvent] = [.ended(finished)]
        let automatic = activity == .focus ? preferences.autoStartFocus : preferences.autoStartBreaks
        // Never walk through unseen periods; the next deadline starts at this observation.
        if allowAutoStart && automatic { events += toggle(at: now, preferences: preferences) }
        return events
    }

    public mutating func skip(preferences: TimerPreferences) { advance(preferences: preferences) }
    public mutating func resetPeriod(preferences: TimerPreferences) {
        remaining = preferences.duration(for: activity)
        status = .ready
        deadline = nil
    }
    public mutating func resetCycle(preferences: TimerPreferences) { self = Self(preferences: preferences) }
    public mutating func updateReadyDuration(preferences: TimerPreferences) {
        if status == .ready { remaining = preferences.duration(for: activity) }
    }
    public mutating func validate(preferences: TimerPreferences) {
        completedFocus = min(12, max(0, completedFocus))
        if !remaining.isFinite || remaining < 0 || remaining > 180 * 60 { resetPeriod(preferences: preferences) }
        if status == .running && deadline == nil { status = .paused }
    }
    private mutating func advance(preferences: TimerPreferences) {
        if activity == .focus {
            activity = completedFocus >= preferences.validated().cycleLength ? .longBreak : .shortBreak
        } else {
            if activity == .longBreak { completedFocus = 0 }
            activity = .focus
        }
        resetPeriod(preferences: preferences)
    }
}

public struct SoundCue: Codable, Equatable, Sendable {
    public var selection: String
    public var volume: Float
    public init(selection: String = "Glass", volume: Float = 0.6) {
        self.selection = selection
        self.volume = volume
    }
}

public struct SavedTimer: Codable, Equatable, Sendable {
    public var preferences: TimerPreferences
    public var engine: TimerEngine
    public var cues: [String: SoundCue]
    public var importedSounds: [String: String]
    public var history: [ActivityRecord] = []
    public var activeSession: ActiveSession?
    public init(preferences: TimerPreferences = .init(), engine: TimerEngine = .init(),
                cues: [String: SoundCue] = [:], importedSounds: [String: String] = [:]) {
        self.preferences = preferences; self.engine = engine; self.cues = cues; self.importedSounds = importedSounds
    }
    public static func cueKey(_ activity: Activity, _ boundary: Boundary) -> String { activity.rawValue + "." + boundary.rawValue }

    private enum CodingKeys: String, CodingKey { case preferences, engine, cues, importedSounds, history, activeSession }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        preferences = try values.decode(TimerPreferences.self, forKey: .preferences)
        engine = try values.decode(TimerEngine.self, forKey: .engine)
        cues = try values.decode([String: SoundCue].self, forKey: .cues)
        importedSounds = try values.decode([String: String].self, forKey: .importedSounds)
        history = try values.decodeIfPresent([ActivityRecord].self, forKey: .history) ?? []
        activeSession = try values.decodeIfPresent(ActiveSession.self, forKey: .activeSession)
    }
}
