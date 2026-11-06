import SwiftUI
import UniformTypeIdentifiers
import ProductimerKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case timer, sounds, appearance
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self { case .timer: "timer"; case .sounds: "speaker.wave.2"; case .appearance: "paintpalette" }
    }
}
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.settingsTab) {
            ForEach(SettingsTab.allCases) { tab in
                Form {
                    switch tab {
                    case .timer: TimerSettings()
                    case .sounds: SoundSettings()
                    case .appearance: AppearanceSettings()
                    }
                }
                .formStyle(.grouped).fitsContent()
                .frame(width: Layout.settingsWidth)
                .tabItem { Label(tab.title, systemImage: tab.symbol) }.tag(tab)
            }
        }
        .noInitialFocus()
    }
}
struct TimerSettings: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Section("Time periods") {
            minutes("Focus", key: \.focusMinutes)
            minutes("Short break", key: \.shortBreakMinutes)
            minutes("Long break", key: \.longBreakMinutes)
            LabeledContent("Focuses per cycle") {
                HStack(spacing: Space.sm) {
                    Text("\(model.preferences.cycleLength)").monospacedDigit().frame(width: 56, alignment: .trailing)
                    Stepper("Focuses per cycle", value: preference(\.cycleLength), in: 1...12).labelsHidden()
                }
            }
        }
        Section("Automatic starts") {
            Toggle("Start breaks automatically", isOn: preference(\.autoStartBreaks))
            Toggle("Start focus automatically", isOn: preference(\.autoStartFocus))
            Text("After sleep or reopening the app, an elapsed activity finishes and the next one waits for you.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section {
            Text("Changes apply to ready and future periods. Pause/resume keeps the current duration. Reset Period applies the new duration immediately.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func minutes(_ title: String, key: WritableKeyPath<TimerPreferences, Int>) -> some View {
        LabeledContent(title) {
            HStack(spacing: Space.sm) {
                TextField("\(title) minutes", value: preference(key), format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing).frame(width: 56)
                    .accessibilityLabel("\(title) duration in minutes")
                Text("min").foregroundStyle(.secondary)
                Stepper(title, value: preference(key), in: 1...180).labelsHidden()
                    .accessibilityLabel("\(title) duration")
            }
        }
    }
    private func preference<T>(_ key: WritableKeyPath<TimerPreferences, T>) -> Binding<T> {
        Binding(get: { model.preferences[keyPath: key] }, set: { value in
            var next = model.preferences; next[keyPath: key] = value; model.setPreferences(next)
        })
    }
}
struct SoundSettings: View {
    @Environment(AppModel.self) private var model
    @State private var importTarget: ImportTarget?
    @State private var importing = false
    var body: some View {
        ForEach(Activity.allCases) { activity in
            Section(activity.title) {
                soundRow(activity, .start)
                soundRow(activity, .end)
            }
        }
        Section {
            Text("Sounds play once when an activity starts or finishes. Resume and Skip are silent. Imported audio is copied into Productimer; supported files must be at most 60 seconds and 20 MB.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                Button("Dismiss Error") { model.errorMessage = nil }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            guard let target = importTarget else { return }
            switch result {
            case .success(let url): model.importSound(from: url, activity: target.activity, boundary: target.boundary)
            case .failure(let error): model.errorMessage = "Unable to open audio file. \(error.localizedDescription)"
            }
            importTarget = nil
        }
    }
    private func soundRow(_ activity: Activity, _ boundary: Boundary) -> some View {
        let title = boundary == .start ? "On start" : "On end"
        let cue = Binding(get: { model.cue(activity, boundary) }, set: { model.setCue($0, activity: activity, boundary: boundary) })
        return VStack(spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Picker(title, selection: cue.selection) {
                    Text("None (mute)").tag("none")
                    ForEach(AppModel.builtInSounds, id: \.self) { Text($0).tag($0) }
                    ForEach(model.importedSounds.keys.sorted(), id: \.self) { filename in
                        Text(model.importedSounds[filename] ?? filename).tag("file:" + filename)
                    }
                }
                .accessibilityLabel("\(activity.title) \(title) sound")
                Button("Preview", systemImage: "play.circle") { model.preview(activity, boundary) }
                    .foregroundStyle(Palette.accentText)
                    .labelStyle(.iconOnly).disabled(cue.wrappedValue.selection == "none")
                    .help("Preview \(activity.title.lowercased()) \(boundary.rawValue) sound")
                    .accessibilityLabel("Preview \(activity.title) \(title) sound")
                Button("Import…") { importTarget = ImportTarget(activity: activity, boundary: boundary); importing = true }
                    .foregroundStyle(Palette.accentText)
                    .help("Import audio for \(activity.title.lowercased()) \(boundary.rawValue)")
            }
            HStack(spacing: Space.sm) {
                Text("Volume").foregroundStyle(.secondary).font(.caption)
                Slider(value: cue.volume, in: 0...1)
                    .accessibilityLabel("\(activity.title) \(title) volume")
                Text("\(Int(cue.wrappedValue.volume * 100))%")
                    .font(.caption).monospacedDigit().frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.vertical, Space.xs)
    }
    private struct ImportTarget { let activity: Activity; let boundary: Boundary }
}
