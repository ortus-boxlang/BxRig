---
title: Appearance
order: 3
summary: The bar layouts, dock, app grid, windows, animations, fonts and backgrounds, one setting at a time.
---

# Appearance

`bxrig appearance` changes how the shell and the windows look. Each change acts at once, is remembered, and can be shown first with `--dry-run`. For colors, see [Themes](themes.md).

```bash
bxrig appearance status
bxrig appearance bar position bottom      # top, bottom, left, right
bxrig appearance bar style glassy         # opaque, glassy, clear
bxrig appearance bar clock iso            # ten clock formats (time-24h, sunday-12h, date-24h, iso ...)
bxrig appearance bar battery on           # the percentage next to the battery
bxrig appearance bar layout minimal       # minimal, standard (the default), dense, status
bxrig appearance dock off                 # on, off, toggle, status: the grid button moves between the dock and the bar
bxrig appearance appgrid launchpad        # launchpad, terminal, status
bxrig appearance battery-percent on       # laptops only
bxrig time format "%a %-I:%M %p"          # the bar clock's text; default "%b %-d - %H:%M" reads Nov 5 - 04:00
bxrig appearance dock mode autohide       # always, autohide, off
bxrig appearance windows gaps off         # no gaps and no borders
bxrig appearance windows corners sharp    # theme, rounded, sharp
bxrig appearance windows opacity glassy   # opaque, glassy
bxrig appearance animations off
bxrig appearance layout columns           # dwindle, master, columns, scrolling, monocle, floating
bxrig appearance windows snap off         # floating windows stop snapping to edges (on by default)
bxrig appearance font list
bxrig appearance font install cascadia --yes
bxrig appearance font cascadia            # Noctalia and the terminals follow
bxrig appearance background random        # or: list, set NAME, next
bxrig appearance apply                    # push everything you chose again
```

## The three bars

`bxrig appearance bar layout` picks one of three bars. Standard is the default. They all end with quick settings and then the control center, and they use bare icons coloured by the theme: only the logo button and the Launchpad grid carry a plate (a tile with an outline, so it stays visible on dark and Retro bars).

| Layout | Start | Center | End |
|---|---|---|---|
| Minimal | logo, workspaces, active window | clock | tray, network, volume, battery*, notifications, quick settings, control center |
| Standard | logo, workspaces, active window | clock, media | agents, capture, tray, clipboard history, network, Bluetooth, volume, battery*, notifications, quick settings, control center |
| Dense | as Standard | clock, weather, media | as Standard, plus brightness and caffeine |

\* The battery widget is written only when a battery is found (a laptop). It shows the percentage; `appearance battery-percent off` hides the number.

- **Logo** opens the BxRig menu (`bxrig menu`). **Clock** is one widget: the time as text, a popover with your local time, the other zones you follow (`bxrig time world`) and a Calendar button; right click opens the Noctalia calendar.
- **Dock** is on by default. The Launchpad grid is its first button, so the grid is not in the bar; with `dock off` the grid button returns to the bar, right after the logo.
- **Quick settings** is the theme switcher for now. Planned widgets that are not built yet and so are on no bar: System (updates, backups), Developer (databases, containers, VMs), VPN, a Power panel for the battery, and a real quick-settings popover.
- **App grid**: `launchpad` is the launcher's grid view. `terminal` (a Terminal-style grid) is only remembered for now: nothing draws it yet, so the launcher keeps the Launchpad grid.
- **Clock format** uses Noctalia's date format tokens (https://docs.noctalia.dev/noctalia/configuration/date-format-tokens/). A pattern without a `%`, like `MMM d - HH:mm`, is read as letters (yyyy MM dd HH mm ss a ...) and converted.

These five settings (`bar layout`, `dock on|off|toggle`, `appgrid`, `battery-percent`, `time format`) rewrite `~/.config/noctalia/config.toml` through the config service: the theme and wallpaper you have are kept, a backup is made, and a running Noctalia reloads the file. If the file has changes of your own, the command shows a plan and `--yes` replaces it (the backup keeps yours). Noctalia's own settings window stores its changes separately and wins over the file; if the bar does not follow a change, look at `~/.local/state/noctalia/settings.toml`. The plate images are written to `~/.local/share/bxrig/plates/`. Noctalia's own first-run wizard is turned off in this config.

## Where the changes go

- **Noctalia** (bar position and style, dock mode and position, battery, font, corner radius) is changed with `noctalia msg config-set`, so your `config.toml` is not edited. Without Noctalia the choice is saved and `appearance apply` pushes it later.
- **Hyprland** window looks (gaps, corners, opacity, animations, layout) are one generated file, `~/.config/bxrig/theme/look.lua`, loaded by `bxrig.lua`. BxRig reloads Hyprland after a change. Your own `hyprland.lua` is never touched.
- **Fonts** come from seven Nerd Fonts. Changing the font also updates the terminal configs BxRig wrote, but never one you edited (it tells you which).
- **Backgrounds** are read from `~/Pictures/BxRig`, `~/Pictures` and the current theme's folder.

The menu has all of this under Appearance.

## Text in large letters

`bxrig ascii` draws text in large letters with FIGlet fonts, the way `figlet` and Omarchy's `omarchy ascii` do, and paints it with a colour or a gradient. The BxRig logo is drawn the same way, in DOS Rebel.

```bash
bxrig ascii BxRig                                  # DOS Rebel, the brand gradient
bxrig ascii Hello --font=ansi-shadow --gradient=sunset
bxrig ascii OK --font=calvin-s --color=#00ff78     # small letters, one colour
bxrig ascii Deploy --gradient=#ff5f6d,#ffc371,#00dbff --direction=diagonal
bxrig ascii Theme --gradient=theme                 # your theme's accent colours
echo "build ok" | bxrig ascii                      # the text from stdin
bxrig ascii fonts                                  # every font, in its own name
```

- **Fonts:** `dos-rebel` (the default, 8 rows), `ansi-shadow` (6 rows) and `calvin-s` (3 rows, for narrow terminals). They ship inside BxRig, so nothing is installed.
- **`--color`:** `#rrggbb`, `#rgb`, `theme` (your theme's accent) or a name: black, white, gray, red, orange, yellow, green, cyan, blue, purple, magenta, pink, boxlang, bxrig.
- **`--gradient`:** a preset (`brand`, `theme`, `sunset`, `ocean`, `fire`, `forest`, `candy`, `rainbow`) or your own two or more colours separated by commas. `--direction` runs it `horizontal` (the default), `vertical` or `diagonal`.
- **When it colours:** without `--color` or `--gradient` you get the brand gradient in a terminal and plain text in a pipe or file. `--color` and `--gradient` colour even in a pipe. `--plain` and the `NO_COLOR` variable always give plain text.
- `--json` returns the lines, the font and the size.

### Pictures as text

`bxrig ascii image` draws a PNG, JPEG, GIF, WebP or SVG in the terminal. BxRig reads it with the [bx-image](https://github.com/ortus-boxlang/bx-image) module, which is built into the binary, so there is nothing to install.

```bash
bxrig ascii image ~/Pictures/logo.png              # 48 columns, half blocks in full colour
bxrig ascii image logo.svg --width=80              # SVGs are drawn at the size you ask for, so they stay sharp
bxrig ascii image photo.jpg --style=ascii          # characters from a brightness ramp, in the picture's colours
```

- **`--style`:** `blocks` (the default) uses half blocks, two pixels per row in 24-bit colour. `ascii` uses one character per cell (` .:-=+*#%@`), coloured like the picture.
- **`--width`:** 4 to 300 columns; the height follows the picture's shape. Transparent pixels stay blank.
- Colour follows the same rules as text: on in a terminal, off in a pipe, with `--plain` or with `NO_COLOR`. `--json` returns the lines without colour.

## About this rig

`bxrig about` shows the BxRig laptop, with BX in DOS Rebel on its screen, beside three panels drawn by [fastfetch](https://github.com/fastfetch-cli/fastfetch):

- **rig:** host, CPU, GPU, memory, disk and display
- **stack:** BoxLang and MatchBox, Java, Node and pnpm, Git and gh, your editor
- **look:** OS, desktop, theme, shell and terminal

Under the laptop: *BXRIG powered by BoxLang* and www.boxlang.io. Open it from the BxRig menu (**About**), from the **BxRig About** launcher, or in any terminal:

```bash
bxrig about            # in your terminal
bxrig about --plain    # no colour
bxrig about --json     # version, theme and links as data
```

- **It follows your theme.** `bxrig theme set` redraws the laptop in the theme's colours (`~/.config/bxrig/theme/fastfetch-logo.ans`), and the panel labels use your terminal colours.
- **Plain `fastfetch` works too.** `bxrig setup shell` installs fastfetch and writes `~/.config/fastfetch/config.jsonc` once. After that it is yours to change; `bxrig about` keeps using its own copy in `~/.config/bxrig/fastfetch.jsonc`.
- Without fastfetch, `bxrig about` shows the laptop, the version and a hint to install it.
