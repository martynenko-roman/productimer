# Productimer

A native macOS 26+ focus timer inspired by Flow, built with SwiftUI. No app or website blocking, account, or server. Source and issues: [github.com/martynenko-roman/productimer](https://github.com/martynenko-roman/productimer).

- Configurable focus, short-break and long-break periods (1–180 minutes).
- Configurable cycle length (1–12 focuses), with separate automatic starts for focus and breaks.
- Start, pause, resume, reset, skip, and menu-bar countdown.
- Separate start/end sounds for each activity: built-in sounds, mute, per-cue volume, preview, and imported audio.
- Local persistence of preferences, imported audio, the current timer, and activity history.
- Statistics by day, week, month and year, with focus/break totals, charts, and a dated activity log.

## Run

```sh
./build.sh
open build/Productimer.app
```

The signed app bundle stays in `build/`. Drag it to Applications if desired. Swift 6.2+ and macOS 26+ are required. Full Xcode enables Liquid Glass icon compilation; Command Line Tools use the included standard ICNS fallback.

The build wrapper keeps compiler caches in `/private/tmp/productimer-toolchain` and works around stale private SwiftPM interfaces found in this Mac's mixed Command Line Tools installation, without modifying system files.

## Use

Click **Start Focus**, then pause/resume as needed. **Settings → Timer** controls durations, cycle length, and automatic starts. **Settings → Sounds** configures six separate start/end cues. Choose **None (mute)** to silence a cue, or **Import…** to copy your own audio into Productimer. Imports must be decodable audio up to 60 seconds and 20 MB.

Changes affect ready/future periods. Reset Period applies the new duration to the current period. Resume preserves its remaining time. Skip gives no focus credit and leaves the next activity ready. Closing the window keeps the menu-bar timer running; **Quit Productimer** exits.

A running deadline survives relaunch. After sleep or relaunch, one elapsed activity completes and the next waits for you; the app does not run through an unattended chain of sessions.

| Action | Shortcut |
| --- | --- |
| Start / Pause / Resume | ⇧⌘P |
| Reset Period | ⌘R |
| Skip Period | ⇧⌘S |
| Reset Cycle | ⇧⌘R |
| Show Timer | ⌘1 |
| Settings | ⌘, |

Data lives at `~/Library/Application Support/Productimer/timer.json`, with imported audio under `Sounds/` beside it. The app works offline.

## Statistics

Open **Show Statistics** from the timer toolbar, Window menu, or menu bar extra (⌘2). Choose Day, Week, Month, or Year, then browse dates. Focus/break time includes actual running time from completed, skipped, and reset periods; pauses are excluded. Completed focuses counts only periods that finish. Current periods appear after they end.

History starts with this update and is retained locally in the timer JSON. Earlier Flow activity can be imported from a CSV timesheet with **Statistics → Import Flow CSV…** (⇧⌘I). Existing Productimer preferences and sounds migrate automatically; an activity that began before this update records only its time after tracking begins.

## Import Flow history

1. Export a CSV timesheet from Flow.
2. Open **Statistics → Import Flow CSV…**, choose the CSV, and check the detected columns.
3. Select the date format, time zone and numeric duration unit. Optional columns preserve session titles, tags and interruption counts.
4. Click **Preview**. Review interpreted dates/durations, duplicates, invalid rows and estimated timing. Invalid rows block import unless you enable **Skip invalid rows**.
5. Click **Import N Activities**. Existing history and the current timer are preserved; duplicate rows are skipped. A backup named `timer-before-import-<UUID>.json` is saved beside the existing timer file before changing it.

Comma, semicolon and tab separators, quoted fields, UTF-8 and BOM-marked UTF-16 are supported. Files are limited to 20 MB and 100,000 records. Imports with active durations but no exact pause intervals preserve total active time and estimate its distribution across the recorded interval. CSV layouts vary: column mapping and custom date patterns are available. This version was tested with synthetic fixtures; an authentic Flow export has not yet been supplied for compatibility verification. See [import rules and evidence](docs/IMPORTER.md).

## Verify

```sh
./tools/swift.sh test
tools/selftest.sh
tools/snap.sh
tools/grid-lint.sh
```

For GUI launches restricted by a shell sandbox, `tools/make-qa.sh selftest`, `snapshots`, or `manual` creates a separate QA bundle using fresh temporary data. Open the generated bundle through a GUI launcher. See [verification evidence](docs/VERIFICATION.md), [brief](docs/BRIEF.md), and [stories](docs/STORIES.md).
