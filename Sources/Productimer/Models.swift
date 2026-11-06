import AppKit
import AVFoundation
import Observation
import ProductimerKit

@Observable
final class AppModel {
    private(set) var saved = SavedTimer()
    private(set) var history: [ActivityRecord] = []
    var isImportingFlow = false
    var statisticsMessage: String?
    var now = Date.now
    var statisticsPeriod: StatisticsPeriod = .week
    var statisticsDate = Date.now
    var settingsTab: SettingsTab = .timer
    var message = "Ready when you are."
    var errorMessage: String?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private let audio = CuePlayer()
    @ObservationIgnored let storeURL: URL

    var preferences: TimerPreferences { saved.preferences }
    var engine: TimerEngine { saved.engine }
    var seconds: Int { engine.secondsRemaining(at: now) }
    var timeText: String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
    var primaryTitle: String {
        switch engine.status {
        case .ready: "Start \(engine.activity.title)"
        case .running: "Pause"
        case .paused: "Resume"
        }
    }
    var soundDirectory: URL { storeURL.deletingLastPathComponent().appending(path: "Sounds") }
    var importedSounds: [String: String] { saved.importedSounds }
    static let builtInSounds = ["Glass", "Ping", "Pop", "Purr", "Hero", "Submarine", "Tink", "Blow", "Bottle", "Frog", "Funk", "Morse", "Sosumi", "Basso"]

    init(storeURL: URL = Store.url, startTicker: Bool = true) {
        self.storeURL = storeURL
        do {
            if FileManager.default.fileExists(atPath: storeURL.path) {
                saved = try JSONDecoder().decode(SavedTimer.self, from: Data(contentsOf: storeURL))
            }
        } catch { errorMessage = "Unable to read saved timer. Your saved file was kept. \(error.localizedDescription)" }
        saved.preferences = saved.preferences.validated()
        saved.engine.validate(preferences: preferences)
        let originalSession = saved.activeSession
        let elapsed = saved.tick(at: now, allowAutoStart: false)
        if originalSession != saved.activeSession { persist() }
        if !elapsed.isEmpty { message = "Previous activity finished. Start \(engine.activity.title.lowercased()) when ready."; persist() }
        history = saved.history
        if startTicker {
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled, let self else { break }
                    self.tick()
                }
            }
        }
        audio.onError = { [weak self] text in self?.errorMessage = text }
    }

    func tick(at date: Date = .now) {
        now = date
        // Sleep gaps finish one period and leave the next ready.
        let gap = date.timeIntervalSince(lastTick)
        lastTick = date
        let events = saved.tick(at: date, allowAutoStart: gap < 5)
        if !events.isEmpty { handle(events); persist() }
    }
    @ObservationIgnored private var lastTick = Date.now

    func toggle() { toggle(at: .now) }
    func toggle(at date: Date) {
        now = date
        let events = saved.toggle(at: now)
        handle(events)
        if events.isEmpty { message = engine.status == .paused ? "Paused. Take your time." : "One thing at a time." }
        persist()
    }
    func resetPeriod() { saved.resetPeriod(at: .now); message = "Period reset. Ready when you are."; persist() }
    func resetCycle() { saved.resetCycle(at: .now); message = "A fresh cycle. Ready when you are."; persist() }
    func skip() { saved.skip(at: .now); message = "Skipped. Start the next activity when ready."; persist() }

    func setPreferences(_ preferences: TimerPreferences) {
        saved.preferences = preferences.validated()
        saved.engine.updateReadyDuration(preferences: saved.preferences)
        persist()
    }
    func cue(_ activity: Activity, _ boundary: Boundary) -> SoundCue {
        saved.cues[SavedTimer.cueKey(activity, boundary)] ?? SoundCue(selection: boundary == .start ? "Pop" : "Glass")
    }
    func setCue(_ cue: SoundCue, activity: Activity, boundary: Boundary) {
        var valid = cue
        valid.volume = cue.volume.isFinite ? min(1, max(0, cue.volume)) : 0.6
        saved.cues[SavedTimer.cueKey(activity, boundary)] = valid
        persist()
    }
    func preview(_ activity: Activity, _ boundary: Boundary) {
        errorMessage = nil
        audio.play(cue(activity, boundary), directory: soundDirectory, preview: true)
    }
    @discardableResult
    func importSound(from source: URL, activity: Activity, boundary: Boundary) -> Bool {
        do {
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 20 * 1024 * 1024 else { throw SoundImportError.tooLarge }
            // Decode before copying so corrupt or unsupported files never become choices.
            let probe = try AVAudioPlayer(contentsOf: source)
            guard probe.duration > 0, probe.duration <= 60 else { throw SoundImportError.tooLong }
            try FileManager.default.createDirectory(at: soundDirectory, withIntermediateDirectories: true)
            let filename = UUID().uuidString + "." + source.pathExtension.lowercased()
            try FileManager.default.copyItem(at: source, to: soundDirectory.appending(path: filename))
            saved.importedSounds[filename] = source.deletingPathExtension().lastPathComponent
            var selection = cue(activity, boundary)
            selection.selection = "file:" + filename
            setCue(selection, activity: activity, boundary: boundary)
            errorMessage = nil
            return true
        } catch { errorMessage = "Unable to import audio. Choose a supported file up to 60 seconds and 20 MB. \(error.localizedDescription)"; return false }
    }
    func persist() {
        if history != saved.history { history = saved.history }
        do {
            try writeState(saved)
        } catch { errorMessage = "Unable to save timer. Check folder permissions and free space. \(error.localizedDescription)" }
    }
    private func writeState(_ state: SavedTimer) throws {
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: storeURL, options: .atomic)
    }
    @discardableResult
    func importFlow(_ preview: FlowImportPreview, skipInvalid: Bool) throws -> Int {
        guard preview.issues.isEmpty || skipInvalid else { throw ImportFailure("Resolve invalid rows or enable Skip invalid rows before importing.") }
        let merge = FlowCSVImporter.merge(preview.records, existing: saved.history)
        guard !merge.records.isEmpty else {
            statisticsMessage = "No new activities to import. Existing activities were kept."
            return 0
        }
        var candidate = saved
        candidate.history.append(contentsOf: merge.records)
        if FileManager.default.fileExists(atPath: storeURL.path) {
            let backup = storeURL.deletingLastPathComponent().appending(path: "timer-before-import-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: storeURL, to: backup)
        }
        // Save first: a failed write leaves both the running timer and in-memory history unchanged.
        try writeState(candidate)
        saved = candidate
        history = candidate.history
        let duplicates = preview.duplicateCount + merge.duplicateCount
        statisticsMessage = "Imported \(merge.records.count) \(merge.records.count == 1 ? "activity" : "activities"). Skipped \(duplicates) \(duplicates == 1 ? "duplicate" : "duplicates") and \(preview.issues.count) invalid \(preview.issues.count == 1 ? "row" : "rows")."
        if let latest = merge.records.map(\.startedAt).max() { statisticsDate = latest }
        return merge.records.count
    }
    func installQAHistory(_ seed: SavedTimer) {
        guard Store.isOverridden else { return }
        saved.history = seed.history
        history = seed.history
    }
    func snapshotState(_ page: String) {
        guard Store.isOverridden else { return }
        ticker?.cancel()
        saved = SavedTimer()
        now = .now
        switch page {
        case "paused":
            saved.engine.toggle(at: now.addingTimeInterval(-120), preferences: preferences)
            saved.engine.toggle(at: now, preferences: preferences)
            message = "Paused. Take your time."
        case "short-break":
            saved.engine.toggle(at: now.addingTimeInterval(-1500), preferences: preferences)
            saved.engine.tick(at: now, preferences: preferences)
            message = "Focus finished. Short Break is ready."
        case "long-break":
            for _ in 0..<4 {
                if saved.engine.activity != .focus { saved.engine.skip(preferences: preferences) }
                saved.engine.toggle(at: now.addingTimeInterval(-1500), preferences: preferences)
                saved.engine.tick(at: now, preferences: preferences)
            }
            message = "Cycle complete. Take a longer break."
        default: message = "Ready when you are."
        }
    }
    private func handle(_ events: [TimerEvent]) {
        for event in events {
            switch event {
            case .started(let activity):
                message = activity == .focus ? "One thing at a time." : "Step away. Come back refreshed."
                audio.play(cue(activity, .start), directory: soundDirectory)
            case .ended(let activity):
                message = "\(activity.title) finished. \(engine.activity.title) is ready."
                audio.play(cue(activity, .end), directory: soundDirectory)
            }
        }
    }
}

private enum SoundImportError: LocalizedError {
    case tooLarge, tooLong
    var errorDescription: String? { self == .tooLarge ? "The file is larger than 20 MB." : "The audio must be between 0 and 60 seconds." }
}

final class CuePlayer: NSObject, AVAudioPlayerDelegate {
    var onError: ((String) -> Void)?
    private var player: AVAudioPlayer?
    private var queue: [(SoundCue, URL)] = []
    func play(_ cue: SoundCue, directory: URL, preview: Bool = false) {
        guard cue.selection != "none", cue.volume > 0 else { return }
        if preview { player?.stop(); player = nil; queue.removeAll() }
        queue.append((cue, directory))
        if player == nil { playNext() }
    }
    private func playNext() {
        guard !queue.isEmpty else { player = nil; return }
        let (cue, directory) = queue.removeFirst()
        let url: URL
        if cue.selection.hasPrefix("file:") {
            let filename = String(cue.selection.dropFirst(5))
            guard filename == URL(fileURLWithPath: filename).lastPathComponent, !filename.contains("..") else { return }
            url = directory.appending(path: filename)
        } else {
            guard AppModel.builtInSounds.contains(cue.selection) else { return }
            url = URL(fileURLWithPath: "/System/Library/Sounds/\(cue.selection).aiff")
        }
        do {
            let next = try AVAudioPlayer(contentsOf: url)
            next.volume = min(1, max(0, cue.volume)); next.delegate = self
            player = next
            guard next.play() else { throw CocoaError(.fileReadUnknown) }
        } catch {
            player = nil
            onError?("Unable to play sound. Choose another sound or import the file again. \(error.localizedDescription)")
            playNext()
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.player = nil; self?.playNext() }
    }
}

enum Store {
    static var verification: String? { Bundle.main.object(forInfoDictionaryKey: "ProductimerVerification") as? String }
    static var isOverridden: Bool { ProcessInfo.processInfo.environment["APP_STORE"] != nil || verification != nil }
    private static let verificationURL = URL(fileURLWithPath: "/private/tmp/Productimer-QA-\(UUID().uuidString)/timer.json")
    static var url: URL {
        if let path = ProcessInfo.processInfo.environment["APP_STORE"] { return URL(fileURLWithPath: path) }
        if verification != nil { return verificationURL }
        return URL.applicationSupportDirectory.appending(path: "Productimer/timer.json")
    }
}
