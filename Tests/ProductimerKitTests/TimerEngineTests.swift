import Foundation
import Testing
@testable import ProductimerKit

private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

@Test func pauseResumeDoesNotRepeatStart() {
    var engine = TimerEngine()
    let preferences = TimerPreferences()
    #expect(engine.toggle(at: epoch, preferences: preferences) == [.started(.focus)])
    #expect(engine.toggle(at: epoch.addingTimeInterval(30), preferences: preferences).isEmpty)
    #expect(engine.secondsRemaining(at: epoch.addingTimeInterval(900)) == 1470)
    #expect(engine.toggle(at: epoch.addingTimeInterval(900), preferences: preferences).isEmpty)
    #expect(engine.secondsRemaining(at: epoch.addingTimeInterval(910)) == 1460)
}

@Test func cycleAndExactlyOnceCompletion() {
    var preferences = TimerPreferences()
    preferences.cycleLength = 2
    var engine = TimerEngine(preferences: preferences)
    engine.toggle(at: epoch, preferences: preferences)
    #expect(engine.tick(at: epoch.addingTimeInterval(1500), preferences: preferences) == [.ended(.focus)])
    #expect(engine.activity == .shortBreak)
    #expect(engine.completedFocus == 1)
    #expect(engine.tick(at: epoch.addingTimeInterval(9000), preferences: preferences).isEmpty)
    engine.skip(preferences: preferences)
    engine.toggle(at: epoch, preferences: preferences)
    engine.tick(at: epoch.addingTimeInterval(1500), preferences: preferences)
    #expect(engine.activity == .longBreak)
    engine.toggle(at: epoch, preferences: preferences)
    engine.tick(at: epoch.addingTimeInterval(1200), preferences: preferences)
    #expect(engine.activity == .focus)
    #expect(engine.completedFocus == 0)
}

@Test func skipAndResetDoNotGrantFocusCredit() {
    let preferences = TimerPreferences()
    var engine = TimerEngine()
    engine.toggle(at: epoch, preferences: preferences)
    engine.skip(preferences: preferences)
    #expect(engine.completedFocus == 0)
    #expect(engine.activity == .shortBreak)
    #expect(engine.status == .ready)
    engine.resetCycle(preferences: preferences)
    #expect(engine == TimerEngine())
}

@Test func automaticBoundariesAndSleepCatchUp() {
    var preferences = TimerPreferences()
    preferences.autoStartBreaks = true
    preferences.autoStartFocus = true
    var engine = TimerEngine()
    engine.toggle(at: epoch, preferences: preferences)
    let wake = epoch.addingTimeInterval(86400)
    #expect(engine.tick(at: wake, preferences: preferences) == [.ended(.focus), .started(.shortBreak)])
    #expect(engine.secondsRemaining(at: wake) == 300)
    #expect(engine.tick(at: wake, preferences: preferences).isEmpty)
    var restored = TimerEngine()
    restored.toggle(at: epoch, preferences: preferences)
    #expect(restored.tick(at: wake, preferences: preferences, allowAutoStart: false) == [.ended(.focus)])
    #expect(restored.status == .ready)
}

@Test func preferencesDoNotChangeCurrentDeadline() {
    var preferences = TimerPreferences()
    var engine = TimerEngine()
    engine.toggle(at: epoch, preferences: preferences)
    preferences.focusMinutes = 45
    engine.updateReadyDuration(preferences: preferences)
    #expect(engine.secondsRemaining(at: epoch) == 1500)
    engine.resetPeriod(preferences: preferences)
    #expect(engine.secondsRemaining(at: epoch) == 2700)
}

@Test func validationAndPersistence() throws {
    var preferences = TimerPreferences()
    preferences.focusMinutes = -20; preferences.shortBreakMinutes = 500; preferences.cycleLength = 0
    #expect(preferences.validated().focusMinutes == 1)
    #expect(preferences.validated().shortBreakMinutes == 180)
    #expect(preferences.validated().cycleLength == 1)
    var engine = TimerEngine()
    engine.toggle(at: epoch, preferences: .init())
    engine.toggle(at: epoch.addingTimeInterval(43), preferences: .init())
    let saved = SavedTimer(preferences: preferences, engine: engine,
                           cues: [SavedTimer.cueKey(.focus, .start): .init(selection: "Ping", volume: 0.3)])
    let decoded = try JSONDecoder().decode(SavedTimer.self, from: JSONEncoder().encode(saved))
    #expect(decoded == saved)
    #expect(decoded.engine.secondsRemaining(at: epoch.addingTimeInterval(300)) == 1457)
}
