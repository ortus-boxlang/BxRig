# Shortcut decisions (owner, 2026-11-14)

Source: the "Shortcut styles" comparison page (Omarchy 4.5 vs BxRig Traditional vs BxRig Mac). Rows not listed here follow the proposal on that page.
Two styles: **Traditional** (Omarchy-like keys) and **Mac** (Cmd-style keys for apps; on a PC keyboard the Alt key acts as Cmd and the Win key as Option, with an Apple keyboard exempt). Same key assignments in both styles unless a row says otherwise.

## Decided

| Action | Traditional | Mac | Note |
|---|---|---|---|
| Open the BxRig menu (runner) | `Super+Space` | `Super+Space` | Moves from `Super+Alt+M` |
| Launch apps | `Super+Alt+Space` | `Super+Alt+Space` | Moves from `Super+Space`; replaces the separate all-apps key |
| Clipboard manager | `Super+Ctrl+V` | `Super+Ctrl+V` | `Super+Shift+V` is dropped |
| Copy, paste, cut, select all | `Super+C/V/X/A` | `Super+C/V/X/A` | Terminal aware |
| Screenshot | `Super+Shift+3/4/5` and `Print` | same | "Keep Mac plus Print", assumed for both styles |
| Color picker | `Super+Print` | `Super+Print` | New: hyprpicker |
| Time, battery, weather notices | `Super+Ctrl+Alt+T/B/W` | same | New commands needed (earlier marked N/A) |
| Agent picker | `Super+Shift+Ctrl+A` | same | |
| Dictation toggle | `Alt+Space` | same | Replaces `Super+Ctrl+X` |
| Input language switch | `Super+I`, `Super+Shift+I` | `Super+Alt+I`, `Super+Alt+Shift+I` | `Super+I` is Italic in Mac mode |
| Lock | `Super+Ctrl+L` | `Super+Ctrl+L` | Replaces `Super+Ctrl+Q` |
| Full screen desktop | `Super+Ctrl+Alt+F` | same | |
| Notification act, dismiss one, history | dropped | dropped | |
| Silence notifications (DND) | `Super+Ctrl+Alt+Comma` | same | Replaces `Super+Alt+N` |
| Night light | no key (menu only) | no key (menu only) | Assumed from "use Omarchy's"; Omarchy has none |
| Close window | `Super+W`, `Super+Q` | `Super+Q` | `Super+W` is Close tab in Mac mode |
| Float or tile | `Super+T` | `Super+Alt+T` | `Super+T` is New tab in Mac mode |
| Quake console | `Super+Shift+Grave` | `Super+Shift+Grave` | `Super+Grave` stays the pull-down AI shell |
| Minimize | `Super+H` | `Super+H` | Replaces `Super+M`; restore assumed `Super+Shift+H` |

## Consequences

- The five Mac collisions (`Super+B/F/V/S/Comma`) are resolved by the proposal on the page: browser `Super+Shift+Return` (Mac), fullscreen `Super+Ctrl+F` (Mac), float as above, control center panel `Super+Alt+C`, settings panel `Super+Ctrl+Comma`.
- Every hand-written bind (starter file and `bxrig.lua`) moves into the one shortcut table, which has a key set per style.
- Mac mode also swaps Alt and Win for PC keyboards (asked in the wizard; Apple keyboard: no swap).
- New runner entries: region record, dictation toggle, color picker, Shortcuts section (list, search, rebind, run).
