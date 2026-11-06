import Foundation

public struct CSVDocument: Sendable {
    public let headers: [String]
    public let rows: [[String]]
    public let delimiter: String
    public let firstDataRecord: Int
    public static func read(_ data: Data) throws -> Self {
        guard data.count <= 20 * 1024 * 1024 else { throw ImportFailure("CSV files must be 20 MB or smaller.") }
        let text: String?
        if data.starts(with: [0xff, 0xfe]) || data.starts(with: [0xfe, 0xff]) {
            text = String(data: data, encoding: .utf16)
        } else { text = String(data: data, encoding: .utf8) }
        guard var text else { throw ImportFailure("Use a UTF-8 or BOM-marked UTF-16 CSV file.") }
        if text.first == "\u{FEFF}" { text.removeFirst() }
        let delimiter = detectDelimiter(text)
        let table = try parse(text, delimiter: delimiter)
        guard let headerIndex = table.firstIndex(where: { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }) else {
            throw ImportFailure("The CSV file is empty.")
        }
        let headers = table[headerIndex].enumerated().map { index, value in
            let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? "Column \(index + 1)" : name
        }
        guard headers.count > 1 else { throw ImportFailure("No CSV columns found. Use comma, semicolon, or tab separators.") }
        return Self(headers: headers, rows: Array(table.dropFirst(headerIndex + 1)), delimiter: String(UnicodeScalar(delimiter)), firstDataRecord: headerIndex + 2)
    }
    private static func detectDelimiter(_ text: String) -> UInt8 {
        var counts: [UInt8: Int] = [44: 0, 59: 0, 9: 0]
        var quoted = false
        for byte in text.utf8 {
            if byte == 34 { quoted.toggle() }
            if !quoted {
                if byte == 10 || byte == 13 { if counts.values.contains(where: { $0 > 0 }) { break } }
                if counts[byte] != nil { counts[byte, default: 0] += 1 }
            }
        }
        return [UInt8(44), 59, 9].max { counts[$0, default: 0] < counts[$1, default: 0] } ?? 44
    }
    private static func parse(_ text: String, delimiter: UInt8) throws -> [[String]] {
        let bytes = Array(text.utf8)
        var rows: [[String]] = [], row: [String] = [], field: [UInt8] = []
        var quoted = false, afterQuote = false, index = 0
        func appendField() throws {
            guard row.count < 256 else { throw ImportFailure("A CSV record has more than 256 columns.") }
            row.append(String(decoding: field, as: UTF8.self)); field.removeAll(keepingCapacity: true); afterQuote = false }
        func appendRow() throws {
            try appendField()
            guard row.count <= 256 else { throw ImportFailure("A CSV record has more than 256 columns.") }
            rows.append(row); row.removeAll(keepingCapacity: true)
            guard rows.count <= 100_001 else { throw ImportFailure("Import at most 100,000 activities at a time.") }
        }
        while index < bytes.count {
            if index % 4096 == 0 { try Task.checkCancellation() }
            let byte = bytes[index]
            if quoted {
                if byte == 34 {
                    if index + 1 < bytes.count, bytes[index + 1] == 34 { field.append(34); index += 1 }
                    else { quoted = false; afterQuote = true }
                } else { field.append(byte) }
            } else if byte == delimiter { try appendField() }
            else if byte == 10 || byte == 13 {
                try appendRow()
                if byte == 13, index + 1 < bytes.count, bytes[index + 1] == 10 { index += 1 }
            } else if byte == 34 {
                guard field.isEmpty, !afterQuote else { throw ImportFailure("Unexpected quote in CSV record \(rows.count + 1).") }
                quoted = true
            } else if afterQuote {
                guard byte == 32 || byte == 9 else { throw ImportFailure("Unexpected text after a closing quote in record \(rows.count + 1).") }
            } else { field.append(byte) }
            index += 1
        }
        guard !quoted else { throw ImportFailure("A quoted field is not closed. Check the end of the CSV file.") }
        if !field.isEmpty || !row.isEmpty || afterQuote { try appendRow() }
        return rows
    }
}

public struct ImportFailure: LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
public enum ImportDateFormat: String, CaseIterable, Identifiable, Sendable {
    case iso8601, yearFirst, monthFirst, dayFirst, custom
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .iso8601: "ISO 8601"
        case .yearFirst: "Year first: 2026-11-05 09:00:00"
        case .monthFirst: "Month first: 11/05/2026 9:00 AM"
        case .dayFirst: "Day first: 05/11/2026 09:00"
        case .custom: "Custom date format"
        }
    }
}
public enum ImportDurationUnit: String, CaseIterable, Identifiable, Sendable {
    case minutes, seconds
    public var id: String { rawValue }
}
public struct FlowColumnMapping: Equatable, Sendable {
    public var start: Int?
    public var startTime: Int?
    public var end: Int?
    public var duration: Int?
    public var activity: Int?
    public var outcome: Int?
    public var title: Int?
    public var tag: Int?
    public var interruptions: Int?
    public var sourceID: Int?
    public var dateFormat: ImportDateFormat = .iso8601
    public var customDateFormat = "yyyy-MM-dd HH:mm:ss"
    public var timeZoneID = TimeZone.current.identifier
    public var durationUnit: ImportDurationUnit = .minutes
    public var defaultActivity: Activity = .focus
    public var defaultOutcome: ActivityOutcome = .completed
    public init(headers: [String]) {
        let normalized = headers.map { Self.normalize($0) }
        func find(_ names: [String]) -> Int? {
            for name in names {
                let matches = normalized.indices.filter { normalized[$0] == Self.normalize(name) }
                if matches.count == 1 { return matches[0] }
            }
            return nil
        }
        start = find(["start date", "start time", "started at", "start", "date", "begin"])
        end = find(["end date", "end time", "ended at", "end", "finish"])
        duration = find(["active duration", "duration seconds", "duration minutes", "duration", "focus time", "total time"])
        activity = find(["activity", "type", "session type"])
        outcome = find(["status", "outcome", "completed", "is completed"])
        title = find(["session name", "session title", "title", "name"])
        tag = find(["tag", "tags", "category"])
        interruptions = find(["interruptions", "interruption count"])
        sourceID = find(["session id", "id", "uuid"])
        if let duration, normalized[duration].contains("seconds") { durationUnit = .seconds }
    }
    static func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
public struct ImportRowIssue: Identifiable, Equatable, Sendable {
    public var id: Int { row }
    public let row: Int
    public let reason: String
}
public struct FlowImportPreview: Sendable {
    public let records: [ActivityRecord]
    public let duplicateCount: Int
    public let issues: [ImportRowIssue]
    public var estimatedCount: Int { records.filter { $0.importDetails?.estimatedTiming == true }.count }
}
public struct FlowImportMerge: Sendable {
    public let records: [ActivityRecord]
    public let duplicateCount: Int
}
public enum FlowCSVImporter {
    public static func preview(_ document: CSVDocument, mapping: FlowColumnMapping,
                               existing: [ActivityRecord]) throws -> FlowImportPreview {
        guard mapping.start != nil else { throw ImportFailure("Choose a start date column.") }
        guard mapping.end != nil || mapping.duration != nil else { throw ImportFailure("Choose an end date or duration column.") }
        guard let zone = TimeZone(identifier: mapping.timeZoneID) else { throw ImportFailure("Enter a valid time zone, such as America/New_York or UTC.") }
        guard mapping.dateFormat != .custom || !mapping.customDateFormat.isEmpty else { throw ImportFailure("Enter a custom date format.") }
        let indices = [mapping.start, mapping.startTime, mapping.end, mapping.duration, mapping.activity,
                       mapping.outcome, mapping.title, mapping.tag, mapping.interruptions, mapping.sourceID].compactMap { $0 }
        guard indices.allSatisfy({ document.headers.indices.contains($0) }) else { throw ImportFailure("A mapped column is missing. Choose the columns again.") }
        var records: [ActivityRecord] = [], issues: [ImportRowIssue] = []
        for (index, row) in document.rows.enumerated() {
            try Task.checkCancellation()
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
            do {
                guard row.count == document.headers.count else { throw ImportFailure("Expected \(document.headers.count) columns, found \(row.count).") }
                records.append(try record(row, mapping: mapping, zone: zone))
            } catch is CancellationError { throw CancellationError() }
            catch { issues.append(.init(row: index + document.firstDataRecord, reason: error.localizedDescription)) }
        }
        let result = merge(records, existing: existing)
        return .init(records: result.records, duplicateCount: result.duplicateCount, issues: issues)
    }
    public static func merge(_ candidates: [ActivityRecord], existing: [ActivityRecord]) -> FlowImportMerge {
        var semantic = Set(existing.map(fingerprint))
        var sourceIDs = Set(existing.compactMap { $0.importDetails?.sourceID })
        var accepted: [ActivityRecord] = [], duplicates = 0
        for record in candidates {
            let key = fingerprint(record)
            let sourceID = record.importDetails?.sourceID
            if semantic.contains(key) || sourceID.map({ sourceIDs.contains($0) }) == true { duplicates += 1; continue }
            semantic.insert(key)
            if let sourceID { sourceIDs.insert(sourceID) }
            accepted.append(record)
        }
        return .init(records: accepted, duplicateCount: duplicates)
    }
    private static func fingerprint(_ record: ActivityRecord) -> String {
        // Millisecond normalization makes decimal/clock representations deduplicate consistently.
        [record.activity.rawValue, record.outcome.rawValue,
         String((record.startedAt.timeIntervalSince1970 * 1000).rounded()),
         String((record.endedAt.timeIntervalSince1970 * 1000).rounded()),
         String((record.seconds * 1000).rounded())].joined(separator: "|")
    }
    private static func record(_ row: [String], mapping: FlowColumnMapping, zone: TimeZone) throws -> ActivityRecord {
        func cell(_ index: Int?) -> String? {
            guard let index else { return nil }
            let text = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        guard let startText = cell(mapping.start) else { throw ImportFailure("Start date is empty.") }
        let combinedStart = [startText, cell(mapping.startTime)].compactMap { $0 }.joined(separator: " ")
        guard let start = date(combinedStart, mapping: mapping, zone: zone) else { throw ImportFailure("Unable to read start date. Check the date format and time zone.") }
        var end: Date?
        if mapping.end != nil {
            guard let endText = cell(mapping.end) else { throw ImportFailure("End date is empty.") }
            end = date(endText, mapping: mapping, zone: zone)
            if end == nil, mapping.startTime != nil {
                end = date(startText + " " + endText, mapping: mapping, zone: zone)
                if let value = end, value < start {
                    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
                    end = calendar.date(byAdding: .day, value: 1, to: value)
                }
            }
            guard end != nil else { throw ImportFailure("Unable to read end date. Check the date format.") }
        }
        var duration: TimeInterval?
        if mapping.duration != nil {
            guard let value = cell(mapping.duration) else { throw ImportFailure("Duration is empty.") }
            duration = try seconds(value, unit: mapping.durationUnit)
        }
        if duration == nil, let end { duration = end.timeIntervalSince(start) }
        guard let duration, duration.isFinite, duration > 0, duration <= 7 * 86400 else {
            throw ImportFailure("Duration must be greater than zero and at most seven days.")
        }
        let finished = end ?? start.addingTimeInterval(duration)
        let elapsed = finished.timeIntervalSince(start)
        guard elapsed > 0, elapsed <= 7 * 86400, duration <= elapsed + 0.001 else {
            throw ImportFailure("End must follow start, and active duration must fit within that interval.")
        }
        let activity: Activity
        if mapping.activity != nil {
            switch FlowColumnMapping.normalize(cell(mapping.activity) ?? "") {
            case "focus", "flow", "work", "focussession", "flowsession": activity = .focus
            case "break", "shortbreak": activity = .shortBreak
            case "longbreak": activity = .longBreak
            default: throw ImportFailure("Unknown activity type. Map another column or choose a default activity.")
            }
        } else { activity = mapping.defaultActivity }
        let outcome: ActivityOutcome
        if mapping.outcome != nil {
            switch FlowColumnMapping.normalize(cell(mapping.outcome) ?? "") {
            case "completed", "complete", "finished", "true", "yes", "1": outcome = .completed
            case "skipped", "skip", "interrupted", "false", "no", "0": outcome = .skipped
            case "reset", "restarted", "cancelled", "canceled": outcome = .reset
            default: throw ImportFailure("Unknown outcome. Map another column or choose a default outcome.")
            }
        } else { outcome = mapping.defaultOutcome }
        var interruptions: Int?
        if let value = cell(mapping.interruptions) {
            guard let count = Int(value), count >= 0 else { throw ImportFailure("Interruptions must be a nonnegative whole number.") }
            interruptions = count
        }
        let estimated = end == nil || abs(elapsed - duration) > 0.001
        return ActivityRecord(activity: activity, startedAt: start, endedAt: finished, outcome: outcome,
            intervals: [.init(start: start, end: start.addingTimeInterval(duration))],
            importDetails: .init(sourceID: cell(mapping.sourceID), title: cell(mapping.title), tag: cell(mapping.tag),
                                 interruptions: interruptions, estimatedTiming: estimated))
    }
    private static func seconds(_ text: String, unit: ImportDurationUnit) throws -> TimeInterval {
        if text.contains(":") {
            let pieces = text.split(separator: ":", omittingEmptySubsequences: false)
            guard (2...3).contains(pieces.count), pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
                  let last = Double(pieces[pieces.count - 1]), last < 60,
                  let middle = Double(pieces[pieces.count - 2]), pieces.count == 2 || middle < 60,
                  let first = Double(pieces[0]) else { throw ImportFailure("Use MM:SS or HH:MM:SS for clock durations.") }
            return pieces.count == 3 ? first * 3600 + middle * 60 + last : first * 60 + last
        }
        guard text.range(of: "^[0-9]+(?:\\.[0-9]+)?$", options: .regularExpression) != nil, let value = Double(text), value.isFinite else {
            throw ImportFailure("Use numeric minutes/seconds with a decimal point, or MM:SS / HH:MM:SS.")
        }
        return value * (unit == .minutes ? 60 : 1)
    }
    private static func date(_ text: String, mapping: FlowColumnMapping, zone: TimeZone) -> Date? {
        if mapping.dateFormat == .iso8601 {
            guard text.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(?::[0-9]{2}(?:\\.[0-9]{1,9})?)?(?:Z|[+-][0-9]{2}:?[0-9]{2})?$", options: .regularExpression) != nil else { return nil }
            // ISO8601DateFormatter normalizes dates such as February 30; reject them before parsing.
            guard validISOComponents(text) else { return nil }
            let iso = ISO8601DateFormatter(); iso.timeZone = zone
            var normalized = text.replacingOccurrences(of: " ", with: "T")
            if normalized.count == 16 || normalized[normalized.index(normalized.startIndex, offsetBy: 16)] != ":" {
                normalized.insert(contentsOf: ":00", at: normalized.index(normalized.startIndex, offsetBy: 16))
            }
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let result = iso.date(from: normalized) { return result }
            iso.formatOptions = [.withInternetDateTime]
            if let result = iso.date(from: normalized) { return result }
            if normalized.hasSuffix("Z") || normalized.dropFirst(16).contains("+") || normalized.dropFirst(16).contains("-") { return nil }
            return formattedDate(normalized, patterns: ["yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"], zone: zone)
        }
        let patterns: [String] = switch mapping.dateFormat {
        case .yearFirst: ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"]
        case .monthFirst: ["M/d/yyyy h:mm:ss a", "M/d/yyyy h:mm a"]
        case .dayFirst: ["d/M/yyyy HH:mm:ss", "d/M/yyyy HH:mm"]
        case .custom: [mapping.customDateFormat]
        case .iso8601: []
        }
        return formattedDate(text, patterns: patterns, zone: zone)
    }
    private static func validISOComponents(_ text: String) -> Bool {
        let characters = Array(text)
        guard let year = Int(String(characters[0..<4])), let month = Int(String(characters[5..<7])),
              let day = Int(String(characters[8..<10])), let hour = Int(String(characters[11..<13])),
              let minute = Int(String(characters[14..<16])), (0...23).contains(hour), (0...59).contains(minute) else { return false }
        if characters.count > 16, characters[16] == ":" {
            guard let second = Int(String(characters[17..<19])), (0...59).contains(second) else { return false }
        }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard year > 0, let value = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return false }
        return calendar.component(.year, from: value) == year && calendar.component(.month, from: value) == month
            && calendar.component(.day, from: value) == day
    }
    private static func formattedDate(_ text: String, patterns: [String], zone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = zone; formatter.isLenient = false
        for pattern in patterns {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}
