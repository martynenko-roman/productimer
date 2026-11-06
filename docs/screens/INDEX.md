# Flow reference walkthrough

Observed installed Flow on 2026-11-05. A long break was running; no timer, preference, or user data was changed. Navigation was restored to the timer. Walkthrough deliberately covers timer and sound settings only. Menus, inactive/empty timer, dark appearance, and unrelated features were not exhaustively captured.

## 01-settings.png
Page: Settings, reached from countdown toolbar > Settings.
Layout: back control, title, grouped settings rows. Focus duration 25 minutes; break durations 5 and 20 minutes; cycle 4 focuses. Separate automatic start switches for breaks and focuses. System settings use rounded groups, labels left and values right.
Actions: edit duration and cycle; toggle automatic starts. Duration menu did not open through accessibility; exact allowed ranges were not observed.

## 02-notifications.png
Page: Notifications, reached from Settings > Notifications.
Layout: notifications switch and volume slider, separate completion sounds for focus and break, quote switch.
Actions: choose completion sound and adjust volume. Starting sounds are a requested Productimer addition.

## 03-long-break.png
Page: active Long Break. 776 × 584 captured pixels.
Layout: full teal content, centered activity label, very large thin countdown, four cycle dots, circular pause button; compact top actions.
Actions: pause, skip break, restart cycle, Settings. Statistics and tag controls are excluded.

## Navigation map
- Timer > Settings > duration/cycle rows.
- Settings > Notifications > sounds and volume.
- Back > Timer.

## Command map
- Observed toolbar: pause, skip break, restart cycle, Settings.
- Flow menus: Flow, File, Edit, View, Window, Help. Contents and shortcuts were not inspected.
- Productimer's planned commands are recorded in `../DESIGN.md`.

## Data model guess
Activity (focus, short break, long break), period duration, cycle length/progress, automatic start preferences, notification volume, completion sound.

## Coverage
S-001–S-005 cover countdown and duration settings; S-006 covers sounds; S-007 covers native entry points. Tags, statistics, quotes, blocking, sync, launch/calendar options are dropped.
