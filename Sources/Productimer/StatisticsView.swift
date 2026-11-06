import SwiftUI
import Charts
import ProductimerKit

struct StatisticsView: View {
    @Environment(AppModel.self) private var model
    private var period: StatisticsPeriod { model.statisticsPeriod }
    private var selectedDate: Date { model.statisticsDate }
    private var calendar: Calendar { .current }
    private var range: DateInterval { period.interval(containing: selectedDate, calendar: calendar) }
    private var records: [ActivityRecord] { ActivityStatistics.records(model.history, in: range) }
    private var summary: ActivitySummary { .init(records: model.history, range: range) }

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: Space.xl) {
            navigation
            if let message = model.statisticsMessage {
                Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
            HStack(spacing: Space.xl) {
                metric("Focus time", value: duration(summary.focusSeconds))
                metric("Completed focuses", value: "\(summary.completedFocuses)")
                metric("Break time", value: duration(summary.breakSeconds))
            }
            .gridProbe("statistics-totals", area: "statistics", edge: "leading")
            if records.isEmpty {
                ContentUnavailableView("No Activity Yet", systemImage: "chart.bar.xaxis",
                    description: Text("Activities appear here when they finish, are skipped, or reset. Browse another date to see earlier activity."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                chart
                Text("Activity log").font(.headline)
                List(records) { record in
                    HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                        Label(record.activity.title, systemImage: record.activity == .focus ? "circle.dotted" : "cup.and.saucer")
                            .frame(width: 136, alignment: .leading)
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                            Text(record.outcome.rawValue.capitalized + (record.beganBeforeTracking ? " · Started before history tracking" : ""))
                                .font(.caption).foregroundStyle(.secondary)
                            if let imported = record.importDetails {
                                Text(["Flow CSV", imported.estimatedTiming ? "Estimated timing" : nil, imported.title, imported.tag]
                                    .compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                        Spacer(minLength: Space.sm)
                        Text(duration(record.seconds)).monospacedDigit()
                            .help("Full activity duration excluding pauses; totals above include only time within the selected dates.")
                    }
                    .padding(.vertical, Space.xs)
                }
                .listStyle(.inset).frame(minHeight: 144)
            }
            Text("Focus and break time include recorded activity from all outcomes, excluding pauses. Current activities appear after they end. History stays on this Mac.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(Space.margin)
        .gridArea("statistics")
        .frame(minWidth: 680, minHeight: 600)
        .noInitialFocus()
        .toolbar { ImportFlowButton() }
        .sheet(isPresented: $model.isImportingFlow) { FlowImportView().environment(model).themed() }
        .task { await Snapshot.runStatisticsIfRequested(model: model) }
    }
    private var navigation: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Picker("Period", selection: Binding(get: { period }, set: { model.statisticsPeriod = $0 })) {
                ForEach(StatisticsPeriod.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented).frame(maxWidth: 360)
            HStack(spacing: Space.md) {
                Button("Previous Period", systemImage: "chevron.left") { move(-1) }
                    .foregroundStyle(Palette.accentText)
                    .labelStyle(.iconOnly).help("Show the previous \(period.rawValue)")
                Text(dateTitle).font(.title3.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
                DatePicker("Date", selection: Binding(get: { selectedDate }, set: { model.statisticsDate = $0 }), displayedComponents: .date).labelsHidden()
                    .accessibilityLabel("Statistics date")
                Button("Today") { model.statisticsDate = .now }
                    .foregroundStyle(Palette.accentText)
                Button("Next Period", systemImage: "chevron.right") { move(1) }
                    .foregroundStyle(Palette.accentText)
                    .labelStyle(.iconOnly).help("Show the next \(period.rawValue)")
            }
        }
        .gridProbe("statistics-navigation", area: "statistics", edge: "leading")
    }
    private var chart: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Focus time").font(.headline)
            Chart(ActivityStatistics.buckets(records: model.history, range: range, period: period, calendar: calendar)) { bucket in
                BarMark(x: .value("Date", bucket.start, unit: period == .day ? .hour : period == .year ? .month : .day),
                        y: .value("Minutes", bucket.focusSeconds / 60), width: .ratio(0.7))
                    .foregroundStyle(Palette.accentText)
                    .accessibilityLabel(bucket.start.formatted(date: .abbreviated, time: period == .day ? .shortened : .omitted))
                    .accessibilityValue(duration(bucket.focusSeconds))
            }
            .chartYScale(domain: 0...max(1, ActivityStatistics.buckets(records: model.history, range: range, period: period, calendar: calendar).map { $0.focusSeconds / 60 }.max() ?? 1))
            .chartYAxisLabel("Minutes").frame(height: 160)
        }
    }
    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.medium)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
    private var dateTitle: String {
        switch period {
        case .day: selectedDate.formatted(date: .complete, time: .omitted)
        case .month: selectedDate.formatted(.dateTime.month(.wide).year())
        case .year: selectedDate.formatted(.dateTime.year())
        case .week:
            range.start.formatted(.dateTime.month(.abbreviated).day()) + " – " + range.end.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day().year())
        }
    }
    private func move(_ step: Int) {
        model.statisticsDate = calendar.date(byAdding: period.component, value: step, to: range.start) ?? selectedDate
    }
    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        if seconds > 0, seconds < 60 { return "<1 min" }
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes) min"
    }
}

struct ShowStatisticsButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Show Statistics", systemImage: "chart.bar.xaxis") {
            openWindow(id: "statistics")
            NSApp.activate()
        }
        .keyboardShortcut("2")
        .help("Review activity history (⌘2)")
    }
}
