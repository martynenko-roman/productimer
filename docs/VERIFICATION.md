# Verification — 2026-11-05

## Passed

- Swift 6 debug and release builds completed with no compiler warnings. Release bundle passed strict code-signature verification and Info.plist validation.
- Six Swift Testing tests: pause/resume without duplicate start, cycle/long-break progression, exactly-once completion, skip/reset without credit, automatic starts and sleep catch-up, preference validation and JSON round-trip. See `qa/unit-tests.txt`.
- Eleven in-app self-test checks on a unique temporary store: real start/pause/resume/skip actions; timer/preferences persistence; six independent cues; validation and copying of a real AIFF; invalid-audio rejection; installed built-in sound files; live timer/audio smoke path. See `qa/selftest.txt`.
- Source grid lint and layout JSON checks passed. The custom timer has a container probe; Settings are native forms. Layout JSON files are in `/private/tmp/Productimer-shots`.
- Computer use: Start Focus changed to RUNNING/Pause, menu Start/Pause/Resume changed to PAUSED/Resume, focus duration incremented 25 → 26 in the QA copy, and Preview was invoked without an app error.
- Real computer-use screenshots reviewed: paused timer in light appearance; Timer, Sounds, and Appearance Settings in light and dark. Saved under `shots/manual-*.png`. Timer numeric fields have one label and fit on one line. Sound controls show all six independent selections/volume controls; a short scroll reveals explanatory text. Appearance shows timer preview and accent swatches.
- Original hourglass icon source and standard ICNS fallback; icon preview inspected, `sips` recognizes ICNS format.

## Scope and remaining manual checks

- Automated snapshots used view-hierarchy fallback because the app process could not obtain screen captures. These are useful for layout, but glass/chrome and inactive controls are not full visual verification. The `manual-*.png` files are real computer-use captures and supersede the earlier Settings fallback captures.
- Main timer dark appearance and both break states were reviewed in fallback images; a complete set of active-window real captures was not obtained. The final sound-button change uses `Palette.accentText` for better dark-mode contrast; that small color adjustment is build-checked, not recaptured.
- A keyboard shortcut attempt returned `frontmostApplicationChanged`. Later computer-use calls timed out after Settings closed, preventing close-window/menu-bar restore checks and further keyboard checks. Menu-driven pause itself passed.
- Perceived audio loudness and end-to-end listening at every boundary, actual Mac sleep/wake, VoiceOver and Accessibility Inspector remain human checks. Fixed-clock tests cover deadline behavior; live smoke covered real timer and playback initialization.
- Full Xcode is absent, so Liquid Glass icon compilation/contact-sheet review is unavailable. The app ships a valid standard icon fallback and retains editable Icon Composer source.
- Git initialization was attempted and denied: `.git: Operation not permitted`. No commit was created in this protected checkout.

QA bundles have separate bundle IDs and fresh `/private/tmp` stores. Flow's running timer and preferences were left unchanged. The production bundle contains no verification menu and has no blocking capabilities.

## Statistics update
See `STATISTICS.md` for the new history contract and its test/visual evidence. The rebuilt release includes Statistics; 13 unit tests and 13 app self-test checks passed.

## Flow CSV importer
See `IMPORTER.md` for scope and evidence. Release build, 26 unit tests, 20 self-checks and native import/reimport with a synthetic CSV passed. Authentic Flow export compatibility remains unverified.
