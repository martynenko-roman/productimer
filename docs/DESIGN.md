# Design plan

Archetype: single countdown window plus menu bar extra and native Settings.
Information architecture: Timer window; Timer, Sounds, Appearance Settings tabs.
Feeling: calm and legible, with one obvious start/pause action.
Empty state: ready Focus countdown and Start Focus button; no sample tasks.

## Commands
| Action | Surface | Shortcut |
| --- | --- | --- |
| Start / Pause / Resume | Timer menu, window, menu bar | Command-Shift-P |
| Reset Period | Timer menu, window | Command-R |
| Skip Period | Timer menu, window, menu bar | Command-Shift-S |
| Reset Cycle | Timer menu | Command-Shift-R |
| Show Timer | Window/menu bar | Command-1 |
| Settings | App menu/window | Command-comma |
| Quit | App menu/menu bar | Command-Q |

Timer uses system fonts, centered activity, large thin monospaced digits, cycle dots, and standard labeled controls. Native chrome and an adaptive subtle accent surface intentionally adapt Flow's iPad-like saturated window to Mac conventions. This is a behavioral and structural clone; pixel identity is not an acceptance target.
