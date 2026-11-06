# Productimer design system

- `UI/Theme.swift`: system accent by default, with a teal Productimer brand when the Mac uses Multicolor. Light/deep shades maintain accent text contrast. `Palette.onAccent` labels filled controls. Appearance swatches remain user-selectable; QA does not persist them.
- `UI/Grid.swift`: use `Space` on a four-point grid. Countdown margins are 32 points to allow the large numerals room; Settings uses native grouped forms. `gridArea` and `gridProbe` measure custom content.
- `UI/Layout.swift`: countdown font 104 points, Settings width 600 points, timer tint opacity 0.06. Timer digits are deliberately larger than body text for at-a-glance reading. No decorative motion; Reduce Motion needs no special path.
- Standard `Button`, `Picker`, `Slider`, `Stepper`, `Settings`, toolbar and menu controls retain native keyboard/accessibility behavior.
- Window chrome uses system backgrounds. Activity is always written as text, and cycle progress has a spoken label; color is supplemental.
- Icon: original hourglass silhouette with sand on teal. Editable SVG layers live in `Icon/AppIcon.icon`; Xcode compiles Liquid Glass variants when installed. The Command Line Tools fallback packages standard PNG sizes as an ICNS file.
