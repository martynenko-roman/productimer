# Productimer

Native SwiftUI timer. Timer rules and Codable state live in `Sources/ProductimerKit`; AppModel owns persistence and audio. UI design rules: `design/DESIGN-SYSTEM.md`. Use its tokens.

## Validation

- `./build.sh --debug` builds and signs `build/Productimer.app` inside this checkout. `./tools/swift.sh test` runs deterministic timer tests. The wrapper contains a local workaround for mismatched Command Line Tools manifest interfaces; it changes no system files.
- `tools/selftest.sh` runs real app functions against a fresh temporary store. `tools/snap.sh` captures timer states and all Settings tabs in both appearances. These require a GUI-capable launch context.
- If shell GUI launch is sandboxed, `tools/make-qa.sh selftest` or `snapshots` creates a separate bundle under `build/`. Launch that bundle through computer use. It uses a unique `/private/tmp` store. Self-test results go to `/private/tmp/Productimer-selftest-result.log`; snapshots go to `/private/tmp/Productimer-shots`.
- Run `tools/grid-lint.sh` and `CLANG_MODULE_CACHE_PATH=/private/tmp/productimer-toolchain/clang swift tools/check-layout.swift /private/tmp/Productimer-shots/*-layout.json` after layout changes, and inspect every light/dark PNG.
- Menu audit on `tools/make-qa.sh manual`: start/pause/resume from Timer menu; skip without credit; close main window and restore with menu bar > Show Timer. Keep user data separate from QA stores.

See `docs/BRIEF.md` for scope, `docs/STORIES.md` for acceptance criteria, and `docs/VERIFICATION.md` for evidence and remaining manual checks. Screenshots of Flow stay out of public Git history. Commit verified changes with concrete behavior in the message.
