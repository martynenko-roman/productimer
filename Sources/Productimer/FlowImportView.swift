import SwiftUI
import UniformTypeIdentifiers
import ProductimerKit

struct FlowImportView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var choosingFile = false
    @State private var filename: String?
    @State private var document: CSVDocument?
    @State private var mapping = FlowColumnMapping(headers: [])
    @State private var preview: FlowImportPreview?
    @State private var tab = 0
    @State private var skipInvalid = false
    @State private var working = false
    @State private var error: String?
    @State private var operation: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Import Flow CSV").font(.title2.weight(.semibold))
            HStack(spacing: Space.md) {
                Button("Choose CSV…") { choosingFile = true }.foregroundStyle(Palette.accentText).disabled(working)
                Text(filename ?? "Choose an exported Flow timesheet.")
                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).help(filename ?? "")
                Spacer(minLength: 0)
                if working { ProgressView().controlSize(.small) }
            }
            if let document {
                TabView(selection: $tab) {
                    setup(document).tabItem { Text("Columns & Dates") }.tag(0)
                    previewContent.tabItem { Text("Preview") }.tag(1)
                }
            } else {
                ContentUnavailableView("Choose a CSV Export", systemImage: "square.and.arrow.down",
                    description: Text("Map its columns, review the activities, then import them into your local history. The source file stays unchanged."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let error { Text(error).font(.callout).foregroundStyle(.red).textSelection(.enabled).lineLimit(4) }
            HStack(spacing: Space.md) {
                Text("No history changes until you click Import.").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: Space.sm)
                Button("Cancel") { operation?.cancel(); dismiss() }.foregroundStyle(Palette.accentText).keyboardShortcut(.cancelAction)
                if tab == 0 || preview == nil {
                    Button("Preview") { buildPreview() }.disabled(document == nil || working)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Import \(preview?.records.count ?? 0) Activities") { commit() }
                        .buttonStyle(.borderedProminent)
                        .disabled(working || (preview?.records.isEmpty ?? true) || (!(preview?.issues.isEmpty ?? true) && !skipInvalid))
                }
            }
        }
        .gridProbe("importer-body", area: "importer", edge: nil)
        .padding(Space.xl)
        .gridArea("importer")
        .frame(width: 720, height: 680)
        .noInitialFocus()
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            switch result {
            case .success(let url): load(url)
            case .failure(let failure):
                if (failure as NSError).code != NSUserCancelledError { error = "Unable to open CSV: \(failure.localizedDescription)" }
            }
        }
        .onChange(of: mapping) { preview = nil; skipInvalid = false }
        .onDisappear { operation?.cancel() }
        .task { await runQAIfRequested() }
    }
    private func setup(_ document: CSVDocument) -> some View {
        Form {
            Section("Columns") {
                column("Start date", selection: $mapping.start, document: document)
                column("Separate start time", selection: $mapping.startTime, document: document)
                column("End date or time", selection: $mapping.end, document: document)
                column("Active duration", selection: $mapping.duration, document: document)
                column("Activity type", selection: $mapping.activity, document: document)
                column("Outcome / completed", selection: $mapping.outcome, document: document)
                column("Session title", selection: $mapping.title, document: document)
                column("Tag", selection: $mapping.tag, document: document)
                column("Interruption count", selection: $mapping.interruptions, document: document)
                column("Session ID", selection: $mapping.sourceID, document: document)
            }
            Section("Interpretation") {
                Picker("Date format", selection: $mapping.dateFormat) {
                    ForEach(ImportDateFormat.allCases) { Text($0.title).tag($0) }
                }
                if mapping.dateFormat == .custom { TextField("Date pattern", text: $mapping.customDateFormat) }
                TextField("Time zone", text: $mapping.timeZoneID)
                Text("Used for dates without a UTC offset. Example: America/New_York or UTC.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Numeric duration unit", selection: $mapping.durationUnit) {
                    ForEach(ImportDurationUnit.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                Text("Clock durations use MM:SS or HH:MM:SS. Numeric decimals use a period. Choose active duration, excluding pauses, when available.")
                    .font(.caption).foregroundStyle(.secondary)
                if mapping.activity == nil {
                    Picker("Default activity", selection: $mapping.defaultActivity) {
                        ForEach(Activity.allCases) { Text($0.title).tag($0) }
                    }
                }
                if mapping.outcome == nil {
                    Picker("Default outcome", selection: $mapping.defaultOutcome) {
                        ForEach([ActivityOutcome.completed, .skipped, .reset], id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .disabled(working)
    }
    private func column(_ title: String, selection: Binding<Int?>, document: CSVDocument) -> some View {
        Picker(title, selection: selection) {
            Text("Not mapped").tag(Optional<Int>.none)
            ForEach(document.headers.indices, id: \.self) { index in
                Text("\(index + 1): \(document.headers[index])").tag(Optional(index))
            }
        }
    }
    @ViewBuilder private var previewContent: some View {
        if let preview {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("\(preview.records.count) new · \(preview.duplicateCount) \(preview.duplicateCount == 1 ? "duplicate" : "duplicates") · \(preview.issues.count) invalid")
                    .font(.headline)
                Text("Dates below use your Mac’s time zone. Duplicate activities will be skipped.")
                    .font(.caption).foregroundStyle(.secondary)
                if preview.estimatedCount > 0 {
                    Text("\(preview.estimatedCount) \(preview.estimatedCount == 1 ? "activity has" : "activities have") estimated timing. Active duration is preserved; exact pause positions are unavailable, so time is spread across the recorded interval.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if !preview.issues.isEmpty {
                    Toggle("Skip invalid rows", isOn: $skipInvalid)
                    Text("Otherwise, correct the file or mapping before importing.").font(.caption).foregroundStyle(.secondary)
                }
                List {
                    if !preview.issues.isEmpty {
                        Section("Invalid records (first 100)") {
                            ForEach(Array(preview.issues.prefix(100))) { issue in
                                Text("Record \(issue.row): \(issue.reason)").foregroundStyle(.red)
                            }
                        }
                    }
                    Section("Activities to import (first 200)") {
                        ForEach(Array(preview.records.prefix(200))) { record in
                            VStack(alignment: .leading, spacing: Space.xs) {
                                HStack {
                                    Text(record.activity.title).fontWeight(.medium)
                                    Spacer()
                                    Text("\(record.seconds / 60, specifier: "%.2f") min").monospacedDigit()
                                }
                                Text(record.startedAt.formatted(date: .abbreviated, time: .standard) + " → " + record.endedAt.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption)
                                Text([record.outcome.rawValue.capitalized, record.importDetails?.title, record.importDetails?.tag].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
            .padding(Space.lg)
        } else {
            ContentUnavailableView("Preview Required", systemImage: "tablecells",
                description: Text("Choose the columns and date format, then click Preview."))
        }
    }
    private func load(_ url: URL) {
        operation?.cancel(); working = true; error = nil; preview = nil; document = nil; tab = 0
        operation = Task {
            do {
                let worker = Task.detached {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 20 * 1024 * 1024 else { throw ImportFailure("CSV files must be 20 MB or smaller.") }
                    return try CSVDocument.read(Data(contentsOf: url))
                }
                let loaded = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                document = loaded; mapping = FlowColumnMapping(headers: loaded.headers); filename = url.lastPathComponent
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
            working = false
        }
    }
    private func buildPreview() {
        guard let document else { return }
        operation?.cancel(); working = true; error = nil
        let interpretation = mapping, existing = model.history
        operation = Task {
            do {
                let worker = Task.detached { try FlowCSVImporter.preview(document, mapping: interpretation, existing: existing) }
                let result = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                preview = result; tab = 1; skipInvalid = false
            } catch is CancellationError {} catch { self.error = error.localizedDescription }
            working = false
        }
    }
    private func commit() {
        guard let preview else { return }
        do { try model.importFlow(preview, skipInvalid: skipInvalid); dismiss() }
        catch { self.error = "Unable to import activities. History was kept unchanged. \(error.localizedDescription)" }
    }
    private func runQAIfRequested() async {
        guard Store.verification == "importer" || Store.verification == "importer-review" else { return }
        do {
            let loaded = try CSVDocument.read(Data(FlowImportFixture.csv.utf8))
            document = loaded; mapping = FlowColumnMapping(headers: loaded.headers); filename = "Flow-sample.csv"
            if Store.verification == "importer-review" { return }
            let dir = "/private/tmp/Productimer-importer-shots"
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                tab = 0
                try? await Task.sleep(for: .milliseconds(800))
                if let sheet = NSApp.windows.first(where: { $0.identifier?.rawValue == "statistics" })?.attachedSheet {
                    await Snapshot.capture(to: "\(dir)/import-columns-\(mode).png", window: sheet)
                }
                preview = try FlowCSVImporter.preview(loaded, mapping: mapping, existing: [])
                tab = 1
                try? await Task.sleep(for: .milliseconds(800))
                if let sheet = NSApp.windows.first(where: { $0.identifier?.rawValue == "statistics" })?.attachedSheet {
                    await Snapshot.capture(to: "\(dir)/import-preview-\(mode).png", window: sheet)
                }
            }
        } catch { self.error = error.localizedDescription }
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}

struct ImportFlowButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Import Flow CSV…", systemImage: "square.and.arrow.down") {
            openWindow(id: "statistics")
            model.isImportingFlow = true
            NSApp.activate()
        }
        .keyboardShortcut("i", modifiers: [.command, .shift])
        .help("Import activity history from a Flow CSV export (⇧⌘I)")
    }
}

enum FlowImportFixture {
    static let csv = """
    Start,End,Duration,Type,Status,Title,Tag,Interruptions
    2026-11-03T09:00:00-05:00,2026-11-03T09:30:00-05:00,25,Flow,Completed,"Write, review",Work,1
    2026-11-03T09:00:00-05:00,2026-11-03T09:30:00-05:00,25,Flow,Completed,"Write, review",Work,1
    2026-11-04T11:00:00-05:00,2026-11-04T11:05:00-05:00,5,Short Break,Completed,Coffee,,0
    invalid,2026-11-04T12:00:00-05:00,25,Flow,Completed,Fix date,Work,0
    """
}
