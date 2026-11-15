---
name: bxrig-desktop
description: "Use this skill when working with the BxRig desktop: Hyprland and Noctalia, KDE Plasma panels and tiling, shortcuts and Mac-style keys, screenshots, notifications and Do Not Disturb, night shift, the overview, force quit, emoji, trackpad gestures, or the control center menu."
---

# BxRig: the desktop

## Two desktops, one command set

- Hyprland + Noctalia is the main desktop (`bxrig setup hyprland`). KDE Plasma stays installed; `bxrig setup plasma` adds HyprKwin tiling (`bxrig tiling on|off|status|layout NAME`).
- Plasma panels: `bxrig plasma panels apply|undo|status` (top status panel, bottom dock, Panel Colorizer islands; backed up first). `bxrig plasma desktops N` sets virtual desktops. Workspaces default to 4.

## Shortcuts

- One table drives xremap, Hyprland and Plasma, in two styles (Traditional, Omarchy-like; Mac, Cmd-style). `bxrig keys show|search TEXT|run ID|sheet|check|conflicts`, `keys set ID COMBO --yes`, `keys reset ID --yes`, `keys style traditional|mac [--keyboard=pc|apple] [--swap=on|off] --yes`. Never edit `bxrig.lua` by hand.
- xremap is always installed: `Super+C V X A` copy, paste, cut and select all in both styles. In the Mac style the other Cmd keys (Super plus Z S F T N O P R W L B I U comma) become Ctrl keys in apps, and on a PC keyboard Alt and Win are swapped (Alt acts as Cmd). Terminals keep shell keys safe.
- Useful: `Super+Space` control center, `Super+K` cheat sheet, `Print` region screenshot (Mac style also `Super+Shift+3/4/5`), `Super+Print` color picker, `Super+Ctrl+E` emoji, `Super+Alt+Escape` force quit, `Super+Ctrl+Up` overview, `Super+H` minimize, `Super+Ctrl+H` Hardware menu, `Super+Shift+Grave` quake console, `Super+Alt+Shift+B` private browser window, `Super+Alt+Shift+F` file manager here.

## Everyday commands

- Screenshots: `screenshot screen|region|window [--edit]`, `screenshot ocr`, `screenshot qr`, `qr TEXT`. Color picker: `screenshot color`. Recording: `record toggle [--region] [--audio=desktop|mic]`. Webcam preview: `webcam toggle`. Clipboard: `clipboard pick`. Dictation: `dictation toggle`.
- Themes: `theme list|show NAME|set NAME [--mode=theme|dark|light|auto]|random|next|mode M|install GIT_URL|import PATH|remove NAME|status`. Omarchy-format themes (15 bundled, others found on disk or installed from git) colour Noctalia, terminals, btop, Hyprland borders and Neovim; it acts at once, `--dry-run` shows the plan.
- Notifications: `notify dnd on|off|toggle`, `notify snooze 30m`, `notify clear`, and notices `notify time|battery|weather`. Night shift: `nightshift on|off|toggle`.
- `emoji`, `forcequit`, `window minimize|restore|quake [send]`, `browser private [URL]`, `files here [DIR]`, `overview`, `input gestures --yes`, `airplay on|off`.
- Bar, dock (`appearance dock toggle`), windows, fonts, monitors, power, time zone: see the `bxrig-system` skill.
- `bxrig menu` is the control center (`menu search TEXT` finds an entry); `bxrig apps` the all-apps window; `bxrig runner` chooses the launcher and menu program.
