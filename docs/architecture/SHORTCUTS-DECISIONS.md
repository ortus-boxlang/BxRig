# Shortcut decisions (owner, merged 2026-11-15)

Source: the owner's "Shortcut styles" page (Omarchy 4.5 vs BxRig Traditional vs BxRig Mac), `decisions` collection, 19 rows set by the owner (r1 to r53). Rows the owner did not touch follow the proposal on that page. Ids below (r1, x1, ...) are the page's row ids.
Two styles: **Traditional** (Omarchy-like keys) and **Mac** (Cmd-style keys for apps; on a PC keyboard the Alt key acts as Cmd and the Win key as Option, an Apple keyboard is exempt). Same key assignments in both styles unless a row says otherwise. Keys in this file are what Hyprland sees after the optional Alt/Win swap.

## Set by the owner

| Row | Action | Traditional | Mac | Note |
|---|---|---|---|---|
| r1 | Open the BxRig menu (runner) | `Super+Space` | `Super+Space` | Moves from `Super+Alt+M` |
| r2 | Launch apps | `Super+Alt+Space` | `Super+Alt+Space` | Moves from `Super+Space`; the separate all-apps key goes away |
| r8 | Clipboard manager | `Super+Ctrl+V` | `Super+Ctrl+V` | `Super+Shift+V` is dropped |
| r9 | Copy, paste, cut, select all | `Super+C/V/X/A` | `Super+C/V/X/A` | Terminal aware |
| r10 | Screenshot | `Print` | `Print` and `Super+Shift+3/4/5` | Custom text "keep Mac plus Print"; owner answer 2026-11-15 |
| r13 | Color picker | `Super+Print` | `Super+Print` | Custom with empty text: read as the page proposal. New: hyprpicker |
| r17 | Time, battery, weather notices | `Super+Ctrl+Alt+T/B/W` | same | New `bxrig notify time\|battery\|weather` |
| r22 | Agent picker | `Super+Shift+Ctrl+A` | same | The pull-down AI shell stays on `Super+Grave` |
| r23 | Dictation toggle | `Alt+Space` | same | Replaces `Super+Ctrl+X` |
| r25 | Input language switch | `Super+I`, `Super+Shift+I` | `Super+Alt+I`, `Super+Alt+Shift+I` | `Super+I` is Italic in Mac mode |
| r27 | Lock | `Super+Ctrl+L` | `Super+Ctrl+L` | Replaces `Super+Ctrl+Q` |
| r31 | Full screen desktop | `Super+Ctrl+Alt+F` | same | Toggles the Noctalia bar |
| r33 | Notification act, dismiss one, history, keyboard control | dropped | dropped | |
| r34 | Silence notifications (DND) | `Super+Ctrl+Alt+Comma` | same | Replaces `Super+Alt+N` |
| r36 | Night light | no key (menu only) | no key (menu only) | Omarchy has none; `Super+Alt+Shift+N` goes |
| r39 | Close window | `Super+W`, `Super+Q` | `Super+Q` | `Super+W` is the Close tab remap in Mac mode |
| r43 | Float or tile | `Super+T` | `Super+Alt+T` | `Super+T` is New tab in Mac mode |
| r52 | Quake console | `Super+Shift+Grave` | `Super+Shift+Grave` | Not built here yet; the key is reserved |
| r53 | Minimize | `Super+H` | `Super+H` | Replaces `Super+M`; restore is `Super+Shift+H` (assumed) |

## Not touched by the owner: the page proposal applies

| Row | Action | Traditional | Mac | Note |
|---|---|---|---|---|
| r3 | System menu | `Super+Escape`, `XF86PowerOff` | same | P1, needs `menu ROUTE` |
| r4 | Capture, Toggle menus | `Super+Ctrl+C`, `Super+Ctrl+O` | same | P1, same dependency. No Hardware section exists in the BxRig menu, so no `Super+Ctrl+H` |
| r5, x3 | Shortcut cheat sheet | `Super+K` | `Super+K` | |
| r11, x2 | Screen recording | `Super+Shift+R`; region `Super+Alt+Shift+R` | same | Omarchy's `Alt+Print` is not added |
| r44 | Full screen | `Super+F` | `Super+Ctrl+F` | `Super+F` is Find in Mac mode |
| r71 | Browser; private | `Super+B`, `Super+Shift+Return`; private `Super+Shift+Alt+B` | `Super+Shift+Return`; private `Super+Shift+Alt+B` | `Super+B` is Bold in Mac mode |
| r72 | File manager | `Super+Shift+F`; in cwd `Super+Alt+Shift+F` | `Super+E`; in cwd `Super+Alt+Shift+F` | in cwd is not built, so not bound |
| r76 | Log out | System menu | `Super+Shift+Q` | Omarchy uses it for the calculator. Kept on both styles (Plasma needs it) |
| r77, r78 | Force quit, Overview | `Super+Alt+Escape`, `Super+Ctrl+Up` | same | |
| r81 | Noctalia settings window | `Super+Ctrl+Comma` | `Super+Ctrl+Comma` | `Super+Comma` is Preferences in Mac mode |
| x1, r18 | Noctalia control center panel | `Super+Alt+C`, `Super+Ctrl+A/B/N/P/D` | same | Was `Super+S` (Save in Mac mode); the five panel keys open the same panel |
| r41, r49, r50, r56, r57, r63 | Split, arrows, workspaces, swap, Alt+Tab, volume and brightness keys | as today | as today | Move from the starter file into the table |

## Consequences

- Every hand-written bind (starter `hyprland.lua` and `bxrig.lua`) moves into the one shortcut table, which has a key set per style.
- Mac mode also swaps Alt and Win on PC keyboards (asked in the wizard; Apple keyboard: no swap).
- New runner entries: region record, dictation toggle, color picker, time, battery and weather notices, a Shortcuts section (list, search, rebind, run).

## Owner answers to the open questions (2026-11-15)

- Panel keys `Super+Ctrl+A/B/N/P/D` (r18) all open the Noctalia control center panel, the same action as `Super+Alt+C`. No panel ids are needed.
- r25 Mac input language is `Super+Alt+I` and `Super+Alt+Shift+I` (confirmed).
- r39 close window: `Super+Q` closes the window in both styles. Traditional also has `Super+W` (Omarchy 4.5). In the Mac style `Super+W` stays the Ctrl+W remap (close tab, which closes the window in most apps).
- r10 `Print` is the region screenshot. Traditional has `Print` only; the Mac style also has `Super+Shift+3/4/5`.
- r31 `Super+Ctrl+Alt+F` ("full screen desktop", Omarchy's shell toggle that hides bar and dock) toggles the Noctalia bar in both styles (`appearance bar toggle`). The Mac full screen is `Super+Ctrl+F`, unchanged.
- Workspace moves: Traditional keeps `Super+Shift+1..0`. In the Mac style `Super+Shift+3/4/5` are screenshots, so moving a window to workspaces 3, 4 and 5 is `Super+Alt+Shift+3/4/5` (1, 2 and 6 to 0 stay `Super+Shift+N`). `keys conflicts` is clean in both styles.
- xremap is always installed (copy, paste, cut and select all are remaps in both styles); the wizard no longer ties it to the Mac keys question.
- `Alt+Space` (dictation) is the logical Alt key. With the Mac swap on a PC keyboard it is physically the Win key, the same place as Option on a Mac.
- This is the first version: there is no migration step and no migration code.

## Owner request: toggle the dock (2026-11-15)

`Super+Alt+D` shows or hides the dock in both styles (macOS Cmd+Option+D; with the Alt/Win swap on a PC keyboard it lands on the same physical keys). It runs `bxrig appearance dock toggle`, which is Noctalia's `dock-toggle` IPC command. No Omarchy 4.5 key uses `Super+Alt+D` (Omarchy has `Super+Ctrl+Alt+D` for the calendar), and `keys conflicts` is clean. It is also in the runner under Trigger > Toggle. macOS's "focus the dock" key (Ctrl+F3) is not possible: Noctalia has no IPC command to focus its dock.

## Still open

- Not built, so not bound: private browser window, file manager in the current directory, quake console, webcam, `Super+Ctrl+H` (no Hardware section), screen recording with audio (no decision row).

## Class API (written before the code)

One table, two styles, renderers that only read the table. Quirks respected: `compare()` for exact-case strings, `var me = this` before a closure, no closure calls a class method, no `extends`.

```
KeyStyle                        // ~/.config/bxrig/keystyle.json: { style: traditional|mac, keyboard: pc|apple, swap: bool }
  read() -> { style, keyboard, swap }     // no file: mac when the xremap unit exists, else traditional; swap defaults to true on a PC keyboard
  swapActive() -> bool                    // style mac AND keyboard pc AND swap on (an Apple keyboard never swaps)
  write( data ) -> exit code              // through JsonStore (config service: backup, journal)

LuaModule                       // the Lua text both the module and the starter need
  optional( file, var, apply ) -> [lines] // the "load ~/.config/bxrig/theme/FILE.lua if present" block, written once

Shortcuts( overrides = "", style = "" )   // style: "traditional" | "mac" | a KeyStyle struct; default KeyStyle.read()
  table() -> rows of { id, group, action, kind, keys, keysBy: { traditional, mac }, dispatch, words, opts }
             kind: remap (xremap) | bind (Hyprland and Plasma) | hypr-bind (Hyprland only); keys "" = no key in this style
  conflicts() -> { within, remapShadows, user }       // table + remaps active in this style + hl.bind lines of your own files
  render( "xremap" | "hyprland" | "plasma" )          // read only the table
  argvOf( id ) -> the bxrig argv a row runs (for `keys run ID`), [] for a pure Lua dispatch

CLI additions (cli.json): keys style [traditional|mac] [--keyboard=pc|apple] [--swap=on|off] [--yes] | keys search TEXT | keys run ID
                          notify time|battery|weather | screenshot color | dictation toggle | menu open ROUTE
```
