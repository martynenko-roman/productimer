import Foundation
import Testing
@testable import ProductimerKit

private func csv(_ text: String) throws -> CSVDocument { try .read(Data(text.utf8)) }
private func preview(_ text: String, configure: (inout FlowColumnMapping) -> Void = { _ in }) throws -> FlowImportPreview {
    let document = try csv(text)
    var mapping = FlowColumnMapping(headers: document.headers)
    mapping.timeZoneID = "UTC"
    configure(&mapping)
    return try FlowCSVImporter.preview(document, mapping: mapping, existing: [])
}

@Test func quotedCSVWithBOMUnicodeEscapesAndMultiline() throws {
    let document = try csv("\u{FEFF}Start,Duration,Title\r\n2026-11-05T09:00:00Z,25,\"Review, \"\"Swift\"\"\nнаука\"\r\n")
    #expect(document.rows.count == 1)
    #expect(document.rows[0][2] == "Review, \"Swift\"\nнаука")
    let result = try FlowCSVImporter.preview(document, mapping: .init(headers: document.headers), existing: [])
    #expect(result.records.count == 1)
    #expect(result.records[0].importDetails?.title == document.rows[0][2])
}

@Test func semicolonTabAndUTF16() throws {
    for separator in [";", "\t"] {
        let text = "Start\(separator)Duration Seconds\n2026-11-05T09:00:00Z\(separator)1500"
        let result = try preview(text)
        #expect(result.records[0].seconds == 1500)
    }
    let data = try #require("Start,Duration\n2026-11-05T09:00:00Z,25".data(using: .utf16))
    let document = try CSVDocument.read(data)
    #expect(document.headers == ["Start", "Duration"])
}

@Test func importedMetadataAndProportionalPauseAllocation() throws {
    let result = try preview("""
    Start,End,Duration,Type,Status,Tag,Interruptions,ID
    2026-11-05T23:45:00Z,2026-11-06T00:15:00Z,20,Flow,Completed,Work,2,flow-42
    """)
    let record = try #require(result.records.first)
    #expect(record.seconds == 1200)
    #expect(record.importDetails?.sourceID == "flow-42")
    #expect(record.importDetails?.tag == "Work")
    #expect(record.importDetails?.interruptions == 2)
    #expect(record.importDetails?.estimatedTiming == true)
    let midnight = try #require(ISO8601DateFormatter().date(from: "2026-11-06T00:00:00Z"))
    #expect(record.seconds(in: DateInterval(start: midnight, duration: 86400)) == 600)
    #expect(record.seconds(in: DateInterval(start: midnight.addingTimeInterval(-86400), duration: 86400)) == 600)
    #expect(try JSONDecoder().decode(ActivityRecord.self, from: JSONEncoder().encode(record)) == record)
}

@Test func deduplicatesRepeatedOverlappingAndNativeHistory() throws {
    let text = "Start,End,Duration,ID\n2026-11-05T09:00:00Z,2026-11-05T09:25:00Z,25,42\n2026-11-05T09:00:00Z,2026-11-05T09:25:00Z,25,42"
    let first = try preview(text)
    #expect(first.records.count == 1)
    #expect(first.duplicateCount == 1)
    let document = try csv(text)
    let repeated = try FlowCSVImporter.preview(document, mapping: .init(headers: document.headers), existing: first.records)
    #expect(repeated.records.isEmpty)
    #expect(repeated.duplicateCount == 2)
    let imported = first.records[0]
    let native = ActivityRecord(activity: imported.activity, startedAt: imported.startedAt, endedAt: imported.endedAt,
                                outcome: imported.outcome, intervals: imported.intervals)
    #expect(FlowCSVImporter.merge(first.records, existing: [native]).duplicateCount == 1)
    let changed = try preview("Start,End,Duration,ID\n2026-11-05T10:00:00Z,2026-11-05T10:25:00Z,25,42")
    #expect(FlowCSVImporter.merge(changed.records, existing: first.records).records.isEmpty)
}

@Test func dateMappingOffsetsAndDefaults() throws {
    let local = try preview("Started At,Duration\n2026-11-05 09:00:00,25") {
        $0.dateFormat = .yearFirst; $0.timeZoneID = "America/New_York"
        $0.defaultActivity = .longBreak; $0.defaultOutcome = .skipped
    }
    let expected = try #require(ISO8601DateFormatter().date(from: "2026-11-05T14:00:00Z"))
    #expect(local.records[0].startedAt == expected)
    #expect(local.records[0].activity == .longBreak)
    #expect(local.records[0].outcome == .skipped)
    let explicit = try preview("Start,Duration\n2026-11-05T09:00:00-05:00,25")
    #expect(explicit.records[0].startedAt == expected)
    let us = try preview("Start,Duration\n11/05/2026 9:00 AM,25") { $0.dateFormat = .monthFirst }
    let eu = try preview("Start,Duration\n05/11/2026 09:00,25") { $0.dateFormat = .dayFirst }
    #expect(us.records[0].startedAt == eu.records[0].startedAt)
    let custom = try preview("Start,Duration\n05.11.2026 09:00,25") {
        $0.dateFormat = .custom; $0.customDateFormat = "dd.MM.yyyy HH:mm"
    }
    #expect(custom.records[0].startedAt == eu.records[0].startedAt)
}

@Test func separateDateAndTimeHandlesMidnight() throws {
    let result = try preview("Date,Start Time,End Time\n2026-11-05,23:50:00,00:10:00") {
        $0.start = 0; $0.startTime = 1; $0.end = 2; $0.dateFormat = .yearFirst
    }
    #expect(result.records[0].seconds == 1200)
    #expect(result.records[0].endedAt > result.records[0].startedAt)
}

@Test func rejectsInvalidLocalDatesAndAcceptsMinutePrecisionOffsets() throws {
    for text in ["2026-02-30 09:00:00", "2026-11-05 09:00:00 garbage", "2026-11-05 25:00:00"] {
        let result = try preview("Start,Duration\n\(text),25") { $0.dateFormat = .yearFirst }
        #expect(result.records.isEmpty)
        #expect(result.issues.count == 1)
    }
    let result = try preview("Start,Duration\n2026-11-05T09:00-05:00,25")
    let expected = try #require(ISO8601DateFormatter().date(from: "2026-11-05T14:00:00Z"))
    #expect(result.records.first?.startedAt == expected)
}

@Test(arguments: [("25", 1500.0), ("25:00", 1500.0), ("00:25:00", 1500.0), ("1:02:03", 3723.0), ("1.5", 90.0)])
func clockAndNumericDurations(_ value: String, _ expected: Double) throws {
    let result = try preview("Start,Duration\n2026-11-05T09:00:00Z,\(value)")
    #expect(result.records[0].seconds == expected)
}

@Test(arguments: ["-1", "0", "NaN", "inf", "1e3", "25:70", "00:70:00", "1:2:3:4", "", "1,5", "9999999999999999999999999999999"])
func rejectsInvalidDurations(_ value: String) throws {
    let result = try preview("Start,Duration\n2026-11-05T09:00:00Z,\"\(value)\"")
    #expect(result.records.isEmpty)
    #expect(result.issues.count == 1)
}

@Test(arguments: ["invalid", "2026-11-05", "2026-13-05T09:00:00Z", "2026-02-30T09:00:00Z", "2026-11-05T25:00:00Z", "2026-11-05T09:00:00Z garbage"])
func rejectsInvalidDates(_ value: String) throws {
    let result = try preview("Start,Duration\n\(value),25")
    #expect(result.records.isEmpty)
    #expect(result.issues.count == 1)
}

@Test func rejectsInvalidRowsWithoutLosingValidRows() throws {
    let result = try preview("""
    Start,End,Duration,Type,Status
    2026-11-05T09:00:00Z,2026-11-05T09:25:00Z,25,Flow,Completed
    2026-11-05T10:00:00Z,2026-11-05T10:10:00Z,25,Flow,Completed
    2026-11-05T10:00:00Z,2026-11-05T09:10:00Z,5,Flow,Completed
    2026-11-05T10:00:00Z,2026-11-05T10:10:00Z,5,Unknown,Completed
    2026-11-05T10:00:00Z,2026-11-05T10:10:00Z,5,Flow,Maybe
    too,few
    """)
    #expect(result.records.count == 1)
    #expect(result.issues.map(\.row) == [3, 4, 5, 6, 7])
}

@Test func rejectsMalformedCSVAndConfiguration() throws {
    for text in ["", "OnlyOneColumn", "Start,Duration\n\"unfinished,25", "Start,Duration\n\"start\"oops,25", "Start,Duration\nsta\"rt,25"] {
        #expect(throws: ImportFailure.self) { try csv(text) }
    }
    #expect(throws: ImportFailure.self) { try CSVDocument.read(Data([0xff, 0xff])) }
    #expect(throws: ImportFailure.self) { try csv(Array(repeating: "x", count: 257).joined(separator: ",")) }
    let document = try csv("Mystery,Duration\n2026-11-05T09:00:00Z,25")
    var mapping = FlowColumnMapping(headers: document.headers)
    #expect(throws: ImportFailure.self) { try FlowCSVImporter.preview(document, mapping: mapping, existing: []) }
    mapping.start = 0; mapping.timeZoneID = "not/a/timezone"
    #expect(throws: ImportFailure.self) { try FlowCSVImporter.preview(document, mapping: mapping, existing: []) }
}

@Test func existingRecordJSONMigratesWithNoImportMetadata() throws {
    let record = ActivityRecord(activity: .focus, startedAt: .now, endedAt: .now, outcome: .completed, intervals: [])
    var value = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
    value.removeValue(forKey: "importDetails")
    let restored = try JSONDecoder().decode(ActivityRecord.self, from: JSONSerialization.data(withJSONObject: value))
    #expect(restored.importDetails == nil)
    #expect(restored.id == record.id)
}
