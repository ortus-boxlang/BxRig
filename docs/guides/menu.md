---
title: The control center
order: 2
summary: One menu for everything BxRig does, on your launcher, with search.
---

# The control center

`bxrig menu` (bound to `Super+Space`) opens a menu on your launcher (Rofi, Walker, Wofi, Fuzzel or Vicinae: `bxrig runner set NAME`). It follows Omarchy's layout and adds a Develop section for what is ours.

| Section | What is in it |
|---|---|
| Search | Every entry of the menu as one flat list; type to filter, press Enter to run it. |
| Apps | Your installed apps. |
| Install | Any package from the repositories or the AUR, the catalog by group (AI, Development, Terminal, Gaming), web apps, virtual machines, fonts. |
| Remove | Packages, catalog apps, web apps, themes, virtual machines, agent skills. It asks first. |
| Appearance | Theme, mode, font, background, bar, dock, windows, animations. See [Appearance](appearance.md). |
| Trigger | Screenshots, recording (screen, a region, with desktop or microphone audio), the color picker, notices (time, battery, weather), toggles (do not disturb, dictation, dock, stay awake, night light), emoji, clipboard history, force quit, minimize and restore, overview, the quake console, a private browser window, the file manager in the current folder. |
| Shortcuts | List, search, rebind and run a shortcut, check conflicts, write them to Hyprland and Plasma, pick the Traditional or Mac style. See [Shortcuts](shortcuts.md). |
| Hardware | Monitors, laptop panel, mirror, brightness, webcam preview, GPU check, input devices and gestures, AirPlay. |
| Setup | Power, Display, Defaults, Keyboard, Security, Time, DNS, Kernel, Cloud storage, Backup, NAS. |
| Update | BxRig updates, the system update (a snapshot first), skills, re-apply appearance and display. |
| Develop | BoxLang, databases, virtual machines, containers, the editor. |
| Agent | Open an agent, the pull-down AI shell, sessions, local models, API keys. |
| Learn, About, System | Docs and cheat sheets, the status of this machine, lock, suspend, log out, reboot, shut down. |

Every entry is a command you can type: `bxrig menu items` lists them with the command each one runs, and `bxrig menu search TEXT` finds one. `bxrig menu open capture` opens one submenu on its own (`bxrig menu open` lists the routes; System, Capture, Toggle, Hardware and Agent have keys). Entries that print something open in a terminal and wait for Enter; entries that need a choice (a theme, a font, a time zone, a monitor) ask you in the same menu.
