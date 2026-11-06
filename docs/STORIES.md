# Productimer stories

## M1 Usable timer

### S-001 Start and pause an activity
As the user, I start a focus period and pause/resume it.
Screens: 03-long-break.png; timer, paused snapshots.
Acceptance:
- [unit] Paused time does not elapse; resume retains remaining time.
- [snap] Activity name, large countdown, progress dots, and primary action stay visible.
UX:
- Flow: Start → Pause → Resume in the same window; Timer menu offers the same action.
- Surface: centered controls in one countdown window; ready, running, and paused labels.
- Access: labeled buttons, Command-Shift-P, monospaced timer readout.
Status: done

### S-002 Follow a configurable cycle
As the user, I alternate focus periods and breaks, with a long break after the configured count.
Screens: 03-long-break.png; break snapshots.
Acceptance:
- [unit] Completed focuses count toward the cycle; skipped focuses do not.
- [unit] Long break occurs after N focuses; finishing it resets the cycle.
- [unit] Automatic starts follow the independent focus/break settings.
UX:
- Flow: completion → ready next activity or automatic start; state text shows which happened.
- Surface: same window; words identify activity in addition to color.
- Access: progress dots have a combined spoken description.
Status: done

### S-003 Reset or skip an activity
As the user, I reset the current period or skip to the next one.
Screens: timer.
Acceptance:
- [unit] Reset stops and restores the full configured duration.
- [unit] Skip advances without crediting an unfinished focus and leaves the next period ready.
UX:
- Flow: toolbar or Timer menu → reset/skip → visible ready state.
- Surface: inline buttons; tooltips explain the action. Reset Cycle is a separate menu action.
Status: done

### S-004 Change time periods
As the user, I edit durations and cycle length in Settings.
Screens: 01-settings.png; settings-timer.
Acceptance:
- [unit] Durations validate to 1–180 minutes and cycle length to 1–12 focuses.
- [self] Saved preferences survive reopening; a running period retains its current deadline.
- [snap] Native labeled controls show units, auto-start options, and the rule for pending changes.
UX:
- Flow: Command-comma → Timer tab → edit → saved immediately; close returns to timer.
- Surface: grouped Settings form, with numeric steppers and clear units.
Status: done

### S-005 Recover the timer after relaunch or sleep
As the user, I keep my progress when the app closes or the Mac sleeps.
Screens: timer.
Acceptance:
- [unit] A saved deadline determines elapsed time on restore, with at most one completion.
- [self] Paused state, cycle progress, and preferences round-trip through local storage.
UX:
- Flow: relaunch → current countdown or next activity ready with completion message.
- Surface: inline status; no modal or catch-up sound storm.
Status: done

### S-006 Customize sound signals
As the user, I choose signals for the start and end of each activity.
Screens: 02-notifications.png; settings-sounds.
Acceptance:
- [self] Six independent cues persist, with mute, volume, and preview.
- [self] Imported audio is validated, copied locally, and remains usable after the source moves.
- [unit] Completion and start each emit once; pause/resume/reset do not repeat a start cue.
- [manual] Listen to playback at both activity boundaries and verify perceived volume.
UX:
- Flow: Settings → Sounds → choose/preview; Import Audio… → file picker → saved selection.
- Surface: grouped form; import/play errors shown inline with a recovery action.
- Access: every picker and preview has an activity/boundary label.
Status: doing (implemented; perceived sound loudness remains a manual check)

### S-007 Use native entry points
As the user, I view and control the timer from the menu bar and keyboard.
Screens: timer; menu-bar.
Acceptance:
- [self] Timer menu actions call the same functions as the window.
- [manual] Menu bar countdown remains available after closing the main window; Show Timer restores it.
- [snap] Timer and all Settings tabs render in light and dark appearance.
UX:
- Flow: menu bar extra → start/pause/skip or Show Timer; Command-comma opens Settings.
- Surface: native menu and Settings window; Quit exits explicitly.
Status: doing (implemented; keyboard and close/restore checks remain)

## Dropped
- Blocking, commitment mode: explicitly excluded by the user.
- Tags, motivational quotes, subscriptions, accounts, calendar and timer sync: outside timer-only scope.
- Exact proprietary branding and icon: replaced with Productimer art and system symbols.

## M2 Activity history

### S-008 Record historical activity
As the user, I retain focus and break activity when periods complete, are skipped, or reset.
Acceptance:
- [unit] Pauses are excluded, midnight/DST allocation is correct, and restored completion records once.
- [unit] Old preferences/audio/timer JSON migrates without invented history.
- [self] Real app actions persist partial and completed history through relaunch.
UX:
- Surface: automatic local recording; no prompt or account.
- Words: Completed / Skipped / Reset outcomes; legacy periods marked as beginning before tracking.
Status: done

### S-009 Review statistics
As the user, I inspect historical activity by day, week, month, or year.
Screens: statistics-day, statistics-week, statistics-month, statistics-year, statistics-empty.
Acceptance:
- [snap] Native window shows period navigation, three totals, chart, and activity log in both appearances.
- [unit] Summary time clips to selected calendar range; completed-focus counts exclude skipped/reset periods.
- [manual] Statistics opens from the toolbar, Window menu (Command-2), and menu bar extra.
UX:
- Flow: Show Statistics → period/date → chart and log; close returns to timer.
- Surface: independent window alongside timer.
- States: empty “No Activity Yet”; scrollable activity log; persisted history survives restart.
- Access: native labeled controls, chart labels, semantic colors, text outcomes, no motion.
Status: doing (implemented; final verification recorded in STATISTICS.md)

## M3 Flow history import

### S-010 Import a Flow CSV timesheet
As the user, I preview and merge exported history into Productimer without replacing existing activity.
Screens: import-columns-light/dark, import-preview-light/dark, native-reimport-light.
Acceptance:
- [unit] Quoted CSV, common encodings/delimiters, explicit date/timezone/duration mapping and invalid rows behave as documented in IMPORTER.md.
- [unit] Duplicates inside a file, overlapping exports and existing native records are skipped; imported active time is allocated proportionally when pause positions are unknown.
- [self] Import backs up the store, saves metadata/history, preserves the active timer and preferences, and leaves memory unchanged on save failure.
- [manual] Native Choose CSV → Preview → explicit Skip invalid rows → Import updates Statistics; reimport adds no duplicates.
- [snap] Mapping and preview are readable in both appearances.
UX:
- Surface: native sheet with Columns & Dates and Preview tabs; inline validation and loading state.
- Flow: Statistics/File > Import Flow CSV… (⇧⌘I) → file → mapping → Preview → Import N Activities; Cancel/Escape exits before writing.
- Access: native labeled controls, textual row errors/counts, explicit estimated-timing note, duplicate/invalid counts; keyboard/VoiceOver audit pending.
Status: done (synthetic CSV compatibility; authentic Flow export verification pending)
