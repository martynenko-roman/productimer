# Statistics

Requested 2026-11-05: record historical activity similar to Flow.
Reference: https://www.flow.app/features describes session totals by day, week, month and year. Native Flow inspection failed with ScreenCaptureKit error -3811; no private reference history was captured.

## Contract
- Record focus, short break, and long break periods with stable IDs, start/end timestamps, actual running intervals, and Completed / Skipped / Reset outcomes.
- Pause time is excluded. Completion ends at the scheduled deadline, even when observed late; each period records once. Reset and Skip retain elapsed activity without granting completed focus credit. Never record a period that was only ready.
- Persist active tracking alongside the timer, so resume/relaunch cannot duplicate history. Older saved timers/preferences/audio load with empty history. An activity already running before this update records only time observed after the upgrade, with a legacy marker.
- Summary focus/break time includes recorded running time from all outcomes; completed focus count counts Completed focuses only. Intervals crossing midnight are split across local calendar boundaries, including DST.
- Statistics opens in a separate native window from the timer toolbar, Window menu (Command-2), and menu bar extra. Day/week/month/year picker, date navigation, focus-time chart, totals, and reverse chronological log. Current activities appear after completion, Skip, or Reset.
- History is retained locally with no automatic expiration. No cloud, manual additions, editing, deletion, or export. Flow CSV import was added subsequently; see `IMPORTER.md`. Existing timer/audio behavior remains.

## UX
Flow: Statistics button / Command-2 → current week → change range or browse dates → close returns to timer.
Surface: separate window; historical review can remain beside the running countdown.
Empty: “No Activity Yet” and explanation that records appear when periods finish, are skipped, or reset.
Words: Focus time, Break time, Completed focuses, Activity log; outcomes always text, not color alone.
Access: native picker/buttons/list, explicit chart labels, date and duration in each record. Readable light/dark styles with no decorative motion.

## Verification
- Final Swift 6 debug/release builds passed with no compiler warnings. Release signature and Info.plist validated.
- 13 unit tests passed: existing timer behavior plus pause-aware history, exactly-once restoration, completed/skipped/reset outcomes, automatic transitions, old-save migration, midnight allocation, DST bucket lengths, and focus/break summaries.
- 13 in-app checks passed on temporary stores, including real AppModel recording/persistence and completed-session relaunch deduplication. See `qa/statistics-selftest.txt`.
- Source grid lint and all ten Statistics layout-probe files passed.
- Inspected day/week/month/year and empty layouts in light/dark captures. Broad bars now align to calendar bins; totals/log remain readable with no clipping. Light layouts, dark day/year/empty were captured key/active. Dark week/month captures were inactive and are scoped layout checks, not complete active-window visual QA. Screenshots are in `shots/statistics/`.
- Native Accessibility confirmed the Statistics window and sample day totals (27 minutes focus, one completed focus, five minutes break) with dated completed/skipped entries.
- Keyboard entry point, every date-navigation action, VoiceOver and Accessibility Inspector have not been manually audited.
- Native Flow inspection returned ScreenCaptureKit error -3811; public feature documentation supplied the reference scope.
- Existing protected `.git` remains unavailable, so this change could not be committed.
