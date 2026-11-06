# Productimer

A personal, offline macOS focus timer inspired by Flow, with configurable periods and start/end sounds.

## Replaces
Flow's timer capabilities. Bundle ID: `com.romanmartynenko.productimer`.

## Main jobs
1. Start, pause, resume, reset, and skip focus and break periods.
2. Set focus, short-break, long-break durations and focus periods per cycle.
3. Choose separate sounds when each kind of activity starts and ends, with preview, volume, mute, and custom audio imports.

4. Review day/week/month/year statistics and the dated activity log.

## Data
- Timer preferences: three durations, cycle length, automatic start choices.
- Sound cue: activity, boundary, built-in name or imported local audio, volume.
- Timer state: activity, remaining time, deadline, running state, cycle progress.
- Activity history: running intervals, timestamps, activity type, and completion/skip/reset outcome; persisted locally.

## Shape
One countdown window, menu bar extra, and Settings; macOS 26+. Local JSON persistence, no accounts or network. Existing lowercase repository name is retained.

## System hooks
Menu bar countdown, system audio playback, file picker for audio import. No blocking permissions.

## Reference
Installed Flow, observed 2026-11-05. Captures and scoped walkthrough in `screens/INDEX.md`.

## Look
Native Mac controls and chrome, with Flow's large centered countdown, cycle dots, compact actions, and calm teal accent. Follow system light/dark appearance. Use original Productimer branding.

## Not in version one
- App/website blocking or commitment restrictions.
- Accounts, sync, calendar, tags, and subscriptions.
- Background catch-up through multiple unseen periods: after sleep/relaunch, finish one elapsed period and wait for the next start.
