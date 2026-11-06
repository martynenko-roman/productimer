import AppKit
import SwiftUI
import ProductimerKit

@main
struct ProductimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()
    var body: some Scene {
        Window("Productimer", id: "main") {
            ContentView().environment(model).themed()
                .frame(minWidth: 480, minHeight: 420)
        }
        .defaultSize(width: 560, height: 480)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .importExport) { ImportFlowButton().environment(model) }
            CommandMenu("Timer") {
                Button("Start / Pause / Resume") { model.toggle() }.keyboardShortcut("p", modifiers: [.command, .shift])
                Divider()
                Button("Reset Period") { model.resetPeriod() }.keyboardShortcut("r")
                Button("Skip Period") { model.skip() }.keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Reset Cycle") { model.resetCycle() }.keyboardShortcut("r", modifiers: [.command, .shift])
            }
            CommandGroup(after: .windowArrangement) { ShowTimerButton(); ShowStatisticsButton() }
            if Store.verification == "manual" || Store.verification == "importer-review" {
                CommandMenu("Verification") {
                    Button("Light Appearance") { NSApp.appearance = NSAppearance(named: .aqua) }
                    Button("Dark Appearance") { NSApp.appearance = NSAppearance(named: .darkAqua) }
                    Button("Sample Statistics") { model.seedStatisticsForQA() }
                    Button("Empty Statistics") { model.seedStatisticsForQA(empty: true) }
                    Divider()
                    ForEach(["timer", "paused", "short-break", "long-break"], id: \.self) { page in
                        Button(page) { model.snapshotState(page) }
                    }
                }
            }
        }
        Settings { SettingsView().environment(model).themed() }
            .windowResizability(.contentSize)
        Window("Statistics", id: "statistics") {
            StatisticsView().environment(model).themed()
        }
        .defaultSize(width: 760, height: 680)
        MenuBarExtra {
            Text("\(model.engine.activity.title) · \(model.timeText)")
            Text(model.engine.status.rawValue.capitalized)
            Button(model.primaryTitle) { model.toggle() }
            Button("Skip Period") { model.skip() }
            Divider()
            ShowTimerButton()
            ShowStatisticsButton()
            SettingsLink { Text("Settings…") }
            Divider()
            Button("Quit Productimer") { NSApp.terminate(nil) }
        } label: {
            Label(model.timeText, systemImage: model.engine.status == .running ? "timer" : "pause.circle")
                .monospacedDigit()
        }
    }
}

struct ShowTimerButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Show Timer") { openWindow(id: "main"); NSApp.activate() }.keyboardShortcut("1")
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}
