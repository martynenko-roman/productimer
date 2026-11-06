import SwiftUI
import ProductimerKit

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        VStack(spacing: Space.xxl) {
            Spacer(minLength: Space.sm)
            VStack(spacing: Space.sm) {
                Label(model.engine.activity.title, systemImage: model.engine.activity == .focus ? "circle.dotted" : "cup.and.saucer")
                    .font(.title2.weight(.medium))
                Text(model.engine.status == .ready ? "READY" : model.engine.status.rawValue.uppercased())
                    .font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
            }
            Text(model.timeText)
                .font(.system(size: Layout.countdownSize, weight: .ultraLight, design: .rounded))
                .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                .accessibilityLabel("\(model.seconds / 60) minutes \(model.seconds % 60) seconds remaining")
                .frame(maxWidth: .infinity)
            VStack(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    ForEach(0..<model.preferences.cycleLength, id: \.self) { index in
                        Circle().fill(index < model.engine.completedFocus ? Palette.accent : Palette.accent.opacity(0.18))
                            .frame(width: 12, height: 12)
                    }
                }
                Text("\(model.engine.completedFocus) of \(model.preferences.cycleLength) focuses completed")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            Button(action: model.toggle) {
                Label(model.primaryTitle, systemImage: model.engine.status == .running ? "pause.fill" : "play.fill")
                    .frame(minWidth: 132)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .help("Start, pause, or resume the activity (⇧⌘P)")
            Text(model.message).font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            Spacer(minLength: Space.sm)
        }
        .gridProbe("countdown-content", area: "timer", edge: nil)
        .padding(Space.section)
        .background(Palette.accent.opacity(Surfaces.timerTint))
        .gridArea("timer", inset: Space.margin)
        .noInitialFocus()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShowStatisticsButton()
                Button("Reset Period", systemImage: "arrow.counterclockwise", action: model.resetPeriod)
                    .help("Reset this period (⌘R)")
                Button("Skip Period", systemImage: "forward.end", action: model.skip)
                    .help("Skip this period without focus credit (⇧⌘S)")
                SettingsLink { Label("Settings", systemImage: "gearshape") }.help("Open Settings (⌘,)")
            }
        }
        .task {
            if Store.verification == "importer" || Store.verification == "importer-review" {
                openWindow(id: "statistics")
                model.isImportingFlow = true
            } else if Store.verification == "statistics" {
                model.seedStatisticsForQA()
                openWindow(id: "statistics")
            } else if SelfTest.requested { await SelfTest.run(model: model) }
            else { Snapshot.runIfRequested(model: model, openSettings: openSettings) }
        }
    }
}
