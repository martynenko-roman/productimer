import AppKit
import IOKit.pwr_mgt
import SwiftUI
import ProductimerKit

/// Screenshot mode for agents.
///   APP_STORE=/tmp/test.store APP_SNAPSHOT=/tmp/shots ~/Applications/Productimer.app/Contents/MacOS/Productimer
/// writes <page>-light.png and <page>-dark.png for every sidebar page, and
/// settings-<tab>-light.png and settings-<tab>-dark.png for every Settings tab, then quits.
/// Each PNG gets a <page>-<mode>-layout.json with the grid probes (tools/check-layout.swift).
/// APP_SNAPSHOT_PAGES=all,starred limits the pages. Add "settings" to include Settings.
/// Add APP_ACCENT=<id> to see the pages in another accent.
enum Snapshot {
    static func runIfRequested(model: AppModel, openSettings: OpenSettingsAction) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["APP_SNAPSHOT"] ?? (Store.verification == "snapshots" ? "/private/tmp/Productimer-shots" : nil), !dir.isEmpty else { return }
        // Snapshots never run against the real database.
        guard Store.isOverridden else {
            print("SNAPSHOT refused: set APP_STORE to a file in /tmp")
            NSApp.terminate(nil)
            return
        }
        let only = env["APP_SNAPSHOT_PAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        Task {
            // A sleeping display gives screencapture nothing. Declaring user
            // activity wakes it; the assertion keeps it on until the run quits.
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            var awake: IOPMAssertionID = 0
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn), "Snapshots" as CFString, &awake)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(1.5))
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                for page in ["timer", "paused", "short-break", "long-break"] where only?.contains(page) ?? true {
                    model.snapshotState(page)
                    try? await Task.sleep(for: .seconds(0.8))
                    await capture(to: "\(dir)/\(page)-\(mode).png")
                }
            }
            if only == nil || only?.contains("settings") == true {
                openSettings()
                try? await Task.sleep(for: .seconds(1))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    for tab in SettingsTab.allCases {
                        model.settingsTab = tab
                        try? await Task.sleep(for: .seconds(0.8))
                        let settings = NSApp.windows.first { $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" }
                        await capture(to: "\(dir)/settings-\(tab.rawValue)-\(mode).png", window: settings)
                    }
                }
            }
            print("SNAPSHOT done \(dir)")
            // An open sheet refuses terminate, and the run would wait forever.
            for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
            NSApp.terminate(nil)
        }
    }

    static func runStatisticsIfRequested(model: AppModel) async {
        guard Store.verification == "statistics" else { return }
        let dir = "/private/tmp/Productimer-statistics-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for mode in ["light", "dark"] {
            NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
            model.seedStatisticsForQA()
            for period in StatisticsPeriod.allCases {
                model.statisticsPeriod = period
                try? await Task.sleep(for: .milliseconds(800))
                let window = NSApp.windows.first { $0.identifier?.rawValue == "statistics" }
                await capture(to: "\(dir)/statistics-\(period.rawValue)-\(mode).png", window: window)
            }
            model.seedStatisticsForQA(empty: true)
            try? await Task.sleep(for: .milliseconds(800))
            let window = NSApp.windows.first { $0.identifier?.rawValue == "statistics" }
            await capture(to: "\(dir)/statistics-empty-\(mode).png", window: window)
        }
        NSApp.terminate(nil)
    }

    /// Captures the real window with screencapture, so glass, sidebars, and
    /// materials look exactly as on screen. That needs Screen Recording
    /// permission for the app that started this one (your terminal, or Claude).
    /// Without it, falls back to drawing the view hierarchy, which leaves
    /// sidebars and glass blank.
    static func capture(to path: String, window: NSWindow? = nil) async {
        // Another app can hide this one while snapshots run (computer use hides
        // apps it does not control). Hidden windows cannot be captured.
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        guard let window = window ?? NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) else {
            print("SNAPSHOT no window")
            return
        }
        // Active, like a window someone is using: real accent colors and focus rings.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        try? await Task.sleep(for: .milliseconds(300))
        let size = window.contentView?.bounds.size ?? .zero
        GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"), window: size)
        try? FileManager.default.removeItem(atPath: path)
        // The first capture of a run sometimes misses the window. Try three times.
        for _ in 1...3 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                shot.terminationHandler = { _ in continuation.resume() }
                do { try shot.run() } catch { continuation.resume() }
            }
            if FileManager.default.fileExists(atPath: path) {
                print("SNAPSHOT \(path) key=\(window.isKeyWindow) active=\(NSApp.isActive)")
                try? "key=\(window.isKeyWindow) active=\(NSApp.isActive) window=\(window.title)\n".write(
                    toFile: path.replacingOccurrences(of: ".png", with: "-capture.txt"), atomically: true, encoding: .utf8)
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path) (fallback: no Screen Recording permission, sidebars and glass are blank)")
        }
    }
}
