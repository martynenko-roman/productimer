# Flow CSV importer

## UX and scope
Statistics → Import Flow CSV… (or File menu, ⇧⌘I) → choose local CSV → map columns/date format/time zone/duration units → Preview → inspect new/duplicate/invalid counts and sample rows → Import N Activities or Cancel.

Native sheet, one file picker at a time, no writes before Import. Empty/loading/error/preview states stay in the sheet. Import rechecks duplicates against current history, backs up the previous store, and atomically saves the merged history while preserving the current timer and preferences. Invalid rows block import unless the user explicitly chooses Skip invalid rows. Repeating a file or importing overlapping exports skips duplicate activities.

No authentic Flow export was supplied when implementing this feature. Support is schema-driven and verified with synthetic fixtures, not claimed as verified against a particular Flow release. Common English headers are detected; column mapping and custom date formats handle variations. Missing activity/outcome columns use visible configurable defaults (Focus / Completed).

## Data rules
- UTF-8 (optional BOM), BOM-marked UTF-16; comma, semicolon, or tab separators; quoted delimiters, quotes and multiline fields. Limit 20 MB / 100,000 records / 256 columns.
- Require start timestamp and duration or end timestamp. ISO 8601 or explicitly selected date format; named time zone for timestamps without offsets. Date-only timestamps are rejected by default formats; custom date format is the user's explicit interpretation.
- Optional separate start-time column combines with start date. End time alone can reuse that date and roll into the next day. Preview exposes interpreted dates before import.
- Numeric durations use explicitly selected minutes/seconds; clock durations use MM:SS or HH:MM:SS. Negative, nonfinite, zero, malformed, or longer-than-seven-day activities are rejected. Numeric decimals use a period.
- If start/end and active duration are provided, duration must fit inside the elapsed interval. Active time is distributed proportionally over that interval because exact pause positions are unknown. Imported rows are labeled Flow CSV and Estimated timing when applicable. Source titles, tags, interruption counts and optional source IDs are retained when mapped.
- Duplicate identity uses source ID where available plus a semantic key of activity/start/end/active duration/outcome. Existing native records are compared too. Duplicate rows inside a file are detected. Edited source records with the same source ID do not overwrite existing history.
- Invalid rows show their record number and reason. Unsupported activity/status values are rejected rather than silently converted. Unknown columns are ignored.
- Import applies to this Mac only. No source files are modified or uploaded.

## Verification
- 26 unit tests passed, including parameterized malformed date/duration cases, CSV quoting/newlines/BOM/UTF-16/delimiters, timezone interpretation, separate date/time, semantic/source-ID deduplication, old-record migration, and proportional midnight allocation. A regression test caught and now prevents ISO8601DateFormatter normalizing February 30 into March 2.
- 20 in-app self-checks passed on temporary stores. Import checks cover invalid-row blocking, timer/preference preservation, persisted metadata, backup creation, reimport deduplication, and failure without in-memory changes when a target folder cannot be written.
- Native computer-use flow: Preview showed 2 new / 1 duplicate / 1 invalid; Import was disabled until Skip invalid rows was checked. Confirming produced 25 minutes focus, one completed focus, five minutes break, and labeled imported records in Statistics.
- Native file picker loaded the synthetic CSV from `/private/tmp`. Re-preview after import showed 0 new / 3 duplicates / 1 invalid and a disabled Import button. Cancel returned to Statistics without adding records.
- Inspected native mapping and preview captures in light/dark appearance, with no clipped controls or text; the mapping form intentionally scrolls. Automated sheet captures flatten the tab bar to a black rectangle and are scoped layout checks. Native captures supersede them. Screenshots are in `shots/importer/`.
- Grid lint and all four importer layout-probe checks passed. The release build, strict signature verification and Info.plist validation passed. Final text pluralization and semantic button-color refinements are build-checked after the native captures.
- An authentic Flow export, VoiceOver/Accessibility Inspector, and the keyboard shortcut itself remain unverified. All current CSV compatibility evidence uses synthetic fixtures. No real user history was imported in QA.
