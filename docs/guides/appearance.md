---
title: Appearance
order: 3
summary: The bar, dock, windows, animations, fonts and backgrounds, one setting at a time.
---

# Appearance

`bxrig appearance` changes how the shell and the windows look. Each change acts at once, is remembered, and can be shown first with `--dry-run`. For colors, see [Themes](themes.md).

```bash
bxrig appearance status
bxrig appearance bar position bottom      # top, bottom, left, right
bxrig appearance bar style glassy         # opaque, glassy, clear
bxrig appearance bar clock iso            # ten clock formats (time-24h, sunday-12h, date-24h, iso ...)
bxrig appearance bar battery on           # the percentage next to the battery
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

## Where the changes go

- **Noctalia** (bar, dock, clock, battery, font, corner radius) is changed with `noctalia msg config-set`, so your `config.toml` is not edited. Without Noctalia the choice is saved and `appearance apply` pushes it later.
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
