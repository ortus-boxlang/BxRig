---
title: Shortcuts and Mac keys
order: 3
summary: One table drives xremap, Hyprland and Plasma, in two styles.
---

# Shortcuts and Mac keys

BxRig keeps one shortcut table and renders it for xremap (Cmd-style keys, on both desktops), the Hyprland module (`~/.config/hypr/bxrig.lua`) and Plasma. Every key BxRig binds is a row, including the window, workspace, arrow, mouse, volume and brightness keys that the starter `hyprland.lua` used to hold. Press `Super+K` (or run `bxrig keys sheet`) to see every shortcut in your menu program.

## Two styles

| | Traditional | Mac |
|---|---|---|
| Idea | Omarchy-like keys | Cmd-style keys for apps |
| `Super+C V X A` | copy, paste, cut, select all (terminal aware) | same |
| `Super+Z S F T N O P R W L B I U` and `Super+,` | plain Super keys | send the Ctrl version (Undo, Save, Find, ...) |
| Browser | `Super+B`, `Super+Shift+Return` | `Super+Shift+Return` |
| Full screen | `Super+F` | `Super+Ctrl+F` |
| Float or tile | `Super+T` | `Super+Alt+T` |
| Window to workspace 3, 4, 5 | `Super+Shift+3/4/5` | `Super+Alt+Shift+3/4/5` |
| Close window | `Super+Q`, `Super+W` | `Super+Q` (`Super+W` is Close tab) |
| Input language | `Super+I`, `Super+Shift+I` | `Super+Alt+I`, `Super+Alt+Shift+I` |

On a PC keyboard the Mac style swaps Alt and Win (Alt acts as Cmd, Win as Option; the left keys only, Right Alt stays AltGr). An Apple keyboard never swaps. The choice is saved in `~/.config/bxrig/keystyle.json`. Keys in the table are what Hyprland sees after the swap. See `docs/architecture/SHORTCUTS-DECISIONS.md` for every decision.

## Change a shortcut

```bash
bxrig keys show                         # the table, in the style that is on
bxrig keys set menu Super+Alt+M --yes
bxrig keys reset menu --yes
bxrig keys conflicts                    # the table, the remaps of the style that is on, and your own hl.bind lines
```

Your changes live in `~/.config/bxrig/shortcuts.json` and apply to both styles. Remaps (the Cmd keys) are xremap's and cannot be changed this way. `keys set` refuses a key another binding uses or xremap rewrites.

## From the runner

`Super+Space` opens the menu; its Shortcuts section lists every shortcut, searches them (`bxrig keys search TEXT`), rebinds one (it asks which one and for the new keys, then runs `keys set`), runs the command a shortcut stands for (`bxrig keys run ID`), writes the keys to Hyprland and Plasma, and switches the style. `Super+Escape`, `Super+Ctrl+C` and `Super+Ctrl+O` open the System, Capture and Toggle menus on their own (`bxrig menu open system`).

## The main ones

| Keys | Does |
|---|---|
| `Super+Space` | BxRig menu (the runner) |
| `Super+Alt+Space` | Launch apps |
| `Super+K` | Shortcut cheat sheet |
| `Print` (Mac style also `Super+Shift+3` / `4` / `5`) | Screenshot: region (Mac style: screen / region / menu) |
| `Super+Print` | Color picker |
| `Super+Shift+R` | Screen recording (`Super+Alt+Shift+R`: a region) |
| `Super+Ctrl+V` | Clipboard history |
| `Super+Ctrl+E` | Emoji |
| `Alt+Space` | Dictation on or off (the logical Alt key: with the Mac swap on a PC keyboard it is the Win key, where Option sits on a Mac) |
| `Super+Alt+D` | Show or hide the dock |
| `Super+Ctrl+Alt+F` | Hide or show the bar |
| `Super+Ctrl+A` `B` `N` `P` `D` | The control center panel |
| `Super+Ctrl+Alt+Comma` | Do Not Disturb |
| `Super+Ctrl+Alt+T` / `B` / `W` | Show the time / battery / weather |
| `Super+Ctrl+L` | Lock |
| `Super+Q` | Close window |
| `Super+H` / `Super+Shift+H` | Minimize / show minimized |
| `Super+Alt+C` | Noctalia control center panel |
| `Super+Ctrl+Comma` | Noctalia settings |
| `Super+Grave` | Pull-down AI shell |
