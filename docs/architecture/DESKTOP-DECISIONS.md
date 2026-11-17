---
title: Desktop decisions
order: 93
hidden: true
summary: Owner decisions on the desktop shell (top bar, dock, icons, themes, helpers). Status is decided or planned.
---

# Desktop decisions (owner, 2026-11-17)

Status: **decided** means the owner chose it; **planned** means it is agreed and scheduled but not built yet.

## Top bar and dock

| Decision | Choice | Status |
|---|---|---|
| Top bar layout (wizard) | Asks Minimal, Standard (default, recommended) or Dense, with a preview in the TUI | decided |
| Minimal layout | Keeps workspaces, active window and quick settings | decided |
| Dock | ON by default; the Launchpad grid is its first button; the grid leaves the bar when the dock is on | decided |
| Clock | One widget showing `Nov 5 - 04:00` (format is user-configurable); its popover shows other zones and a route to the calendar; clock and world clock are merged | decided |
| Battery | Shows the percentage, and only on laptops | decided |
| Clipboard history | Top right of the bar | decided |
| Last two icons | Quick settings, then control center (control center is last) | decided |
| Caffeine | A switch inside quick settings | decided |
| Brightness, weather | Noctalia built-ins, not on the bar | decided |
| VPN | Its own bar icon; NordVPN, NordLayer, Tailscale and NetworkManager profiles in one pick-one list with adapters; an allow-several toggle | planned |
| System popover | Updates and Backups | planned |
| Developer panel | Separate from System: databases, containers, VMs | planned |
| Capture icon | On Standard and Dense | decided |
| Noctalia control center | Reused, not extended (tabs cannot be added); only the screen-time tab is hidden | decided |
| Panel keys | `Super+Ctrl+A/B/N/P/D` fixed (they open the control center) | decided |
| Hardware menu (`Super+Ctrl+H`) | Kept | decided |

## Icons, apps and themes

| Decision | Choice | Status |
|---|---|---|
| Icon style on the bar | Hybrid: bare Tabler outline glyphs colored by one palette role; plates only on the logo button and on the Launchpad grid in the dock (plates need an outline or glow on dark and Retro) | decided |
| Icon theme | `BxRig`, style A (superellipse tile, vertical glow, Phosphor duotone, MIT notice), new `bxrig-*` names, `Inherits=Papirus-Dark`; our icon where we have one, else Papirus; the icon set is not asked in the wizard | planned |
| App grid | Default Launchpad; a second style, Terminal-style grid, is selectable in quick settings via `appearance appgrid` | planned |
| Theme selection | A separate, bigger TUI selector plus a wizard Theme page (default BxRig); the Look page has no theme list | planned |
| Retro theme | Later, with Share Tech Mono Nerd | planned |
| Wizard colors | The wizard follows the chosen theme (TuiKit must stop hard-coding the Frappe palette) | planned |
| Noctalia plugin store | The official store is not used; pinned own plugins only | decided |

## Helpers, defaults and roadmap

| Decision | Choice | Status |
|---|---|---|
| Logitech | Solaar is the helper; logiops is dropped; libratbag and Piper for gaming mice | decided |
| Password managers | Added to the catalog | decided |
| Default apps | Gwenview, Okular, Satty, Signed | decided |
| AI launcher (`bxrig ask`, Tab mode) | Deferred to later | planned |
| BxRig modules planning (MX1) | After the bar foundation | planned |
