import AppKit
import ProductimerKit

enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") || Store.verification == "selftest" }
    static var exitCode: Int32 = 0
    static func run(model: AppModel) async {
        guard Store.isOverridden, model.storeURL.path.hasPrefix("/private/tmp/") || model.storeURL.path.hasPrefix("/tmp/") else {
            exitCode = 1; NSApp.terminate(nil); return
        }
        var passed = true
        var report = ""
        func check(_ value: Bool, _ title: String) {
            let line = "\(value ? "PASS" : "FAIL") \(title)"
            report += line + "\n"
            print(line)
            if !value { passed = false }
        }
        model.resetCycle()
        model.toggle()
        check(model.engine.status == .running, "start actual timer")
        model.toggle()
        check(model.engine.status == .paused, "pause actual timer")
        model.toggle()
        check(model.engine.status == .running, "resume actual timer")
        model.skip()
        check(model.engine.activity == .shortBreak && model.engine.completedFocus == 0, "skip without focus credit")
        for activity in Activity.allCases {
            for boundary in Boundary.allCases {
                model.setCue(.init(selection: "Ping", volume: 0.4), activity: activity, boundary: boundary)
            }
        }
        var preferences = model.preferences
        preferences.focusMinutes = 42; preferences.cycleLength = 3
        model.setPreferences(preferences)
        model.persist()
        let restored = AppModel(storeURL: model.storeURL, startTicker: false)
        check(restored.preferences == model.preferences && restored.engine == model.engine, "preferences and timer persist")
        check(restored.saved.cues.count == 6, "six independent cues persist")
        check(restored.history == model.history && !restored.history.isEmpty, "partial activity history persists through real app actions")
        let historyModel = AppModel(storeURL: model.storeURL.deletingLastPathComponent().appending(path: "history.json"), startTicker: false)
        for activity in Activity.allCases {
            for boundary in Boundary.allCases {
                historyModel.setCue(.init(selection: "none"), activity: activity, boundary: boundary)
            }
        }
        let completion = Date.now
        historyModel.toggle(at: completion.addingTimeInterval(-1500))
        historyModel.tick(at: completion)
        let historyRestored = AppModel(storeURL: historyModel.storeURL, startTicker: false)
        historyRestored.tick(at: completion.addingTimeInterval(1))
        check(historyRestored.history.count == 1 && historyRestored.history.first?.seconds == 1500,
              "completed history survives relaunch without duplicate completion")
        do {
            let document = try CSVDocument.read(Data(FlowImportFixture.csv.utf8))
            let plan = try FlowCSVImporter.preview(document, mapping: .init(headers: document.headers), existing: model.history)
            check(plan.records.count == 2 && plan.duplicateCount == 1 && plan.issues.count == 1, "CSV preview separates new, duplicate, and invalid rows")
            let before = model.history
            do { try model.importFlow(plan, skipInvalid: false); check(false, "invalid CSV rows block import by default") }
            catch { check(model.history == before, "invalid CSV rows block import by default") }
            model.toggle()
            let timer = model.engine, settings = model.preferences
            let imported = try model.importFlow(plan, skipInvalid: true)
            check(imported == 2 && model.engine == timer && model.preferences == settings, "CSV import preserves running timer and preferences")
            let reloaded = AppModel(storeURL: model.storeURL, startTicker: false)
            check(reloaded.history == model.history && reloaded.history.count == before.count + 2, "CSV metadata and history persist through relaunch")
            let backups = try FileManager.default.contentsOfDirectory(at: model.storeURL.deletingLastPathComponent(), includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix("timer-before-import-") }
            check(backups.count == 1, "CSV import backs up previous store")
            let after = model.history
            check(try model.importFlow(plan, skipInvalid: true) == 0 && model.history == after, "reimport rechecks duplicates without adding records")
            model.resetPeriod()
            let blocker = model.storeURL.deletingLastPathComponent().appending(path: "blocked-folder")
            try Data("keep".utf8).write(to: blocker)
            let failed = AppModel(storeURL: blocker.appending(path: "timer.json"), startTicker: false)
            do { try failed.importFlow(plan, skipInvalid: true); check(false, "failed CSV save leaves history unchanged") }
            catch { check(failed.history.isEmpty && (try? String(contentsOf: blocker, encoding: .utf8)) == "keep", "failed CSV save leaves history unchanged") }
        } catch { check(false, "CSV import integration: \(error.localizedDescription)") }
        let source = URL(fileURLWithPath: "/System/Library/Sounds/Ping.aiff")
        let imported = model.importSound(from: source, activity: .focus, boundary: .start)
        check(imported, "validate and import real audio")
        let filename = String(model.cue(.focus, .start).selection.dropFirst(5))
        check(FileManager.default.fileExists(atPath: model.soundDirectory.appending(path: filename).path), "imported sound copied locally")
        let invalid = model.importSound(from: model.storeURL, activity: .focus, boundary: .end)
        check(!invalid && model.errorMessage != nil, "reject invalid audio with actionable error")
        model.errorMessage = nil
        check(AppModel.builtInSounds.allSatisfy { FileManager.default.fileExists(atPath: "/System/Library/Sounds/\($0).aiff") }, "all built-in sounds exist")
        model.resetCycle()
        model.toggle()
        try? await Task.sleep(for: .seconds(1.2))
        check(model.engine.status == .running, "live timer and sound playback smoke test")
        model.resetCycle()
        exitCode = passed ? 0 : 1
        print(passed ? "SELFTEST PASS" : "SELFTEST FAIL")
        report += passed ? "SELFTEST PASS\n" : "SELFTEST FAIL\n"
        try? report.write(toFile: "/private/tmp/Productimer-selftest-result.log", atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }
}
