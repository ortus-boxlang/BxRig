# BxRig runner menu vs Omarchy 4.5 menu

One-to-one comparison of `bxrig menu` (the control center, shown on your runner's menu provider) with the Omarchy 4.5 menu, plus the keyboard shortcuts of both. State of the code on 2026-11-15 (after the second shortcut round, `docs/architecture/SHORTCUTS-DECISIONS.md`).

## Which Omarchy was read

| Item | Value |
|---|---|
| Repository | `omacom/omarchy` (the live project; `basecamp/omarchy` master is stale at 3.8.5) |
| Ref read | tag `v4.5.0` (annotated tag object `97e664b`), commit `ac2690cd7be4f47e4a255f5e2e78d904d436b068`, 2026-11-04, "Invite agent and fingerprint setup once online, not after the first update (4.5) (#17631)" |
| How | `git clone --depth 1 --branch v4.5.0` of the repository (git over the proxy worked; the API did not) |
| `version` file | prints `4.0.0.alpha` at v4.5.0 and at v4.5.0-rc3, so it is not a usable 4.5 marker; the tag is |
| Other refs checked | `dev` and `master` print 3.8.5 (stale). Branch `v4-5-1` (`dac93b4`): menu file and the `utilities`, `tiling`, `applications` binding files are byte-identical to v4.5.0. Branch `quattro` (default branch HEAD, `663aff7`): newer, its menu file already differs (it adds an Agent section), so it is not 4.5 and was not used |

### Omarchy files read

| Purpose | File at v4.5.0 |
|---|---|
| Menu definition (425 JSONC ids, 356 leaf entries) | `default/omarchy/omarchy-menu.jsonc` |
| User extension file template | `config/omarchy/extensions/omarchy-menu.jsonc` |
| Menu behaviour | `docs/menu.md`; `shell/plugins/menu/Menu.qml` (the `providers` map only) |
| Default key bindings | `default/hypr/bindings/applications.lua`, `tiling.lua`, `utilities.lua`, `clipboard.lua`, `dictation.lua`, `media.lua`, `input-method.lua` |
| Personal bindings template | `config/hypr/bindings.lua` |

Re-read on 2026-11-15 with `curl` from `raw.githubusercontent.com/omacom/omarchy/v4.5.0/default/hypr/bindings/`: `tiling`, `utilities`, `media`, `clipboard`, `applications`, `dictation`, `input-method`, `jis` (211 `o.bind` lines in total). `qconsole.lua` and `workspace-modes.lua` are 404 at that tag: the Quake console binds are in `tiling.lua` (the special workspace `qconsole`). Not read: the `omarchy-*` helper scripts the entries call (for example `omarchy-menu-share`, `omarchy-transcode`, `omarchy-toggle-crash-capture`). Where a verdict depends on one of them, the note says so.

### BxRig files read

`bxrig menu items` and `--json` (332 leaf entries without the wizard entry), `src/bxrig/Menu.bx`, `MenuTree.bx` (via the tree output), `docs/guides/menu.md`, COMMAND-CONTRACT 13.4 and 13.16, `bxrig keys show` (131 rows), `src/bxrig/Shortcuts.bx`, `templates/hyprland.lua`, `docs/guides/shortcuts.md`, and `catalog/apps.json` for catalog ids.

### How the 4.x menu works (read from docs/menu.md and the JSONC)

- It is the `omarchy.menu` plugin of the Quickshell desktop. Content is data: ids are dotted keys (`trigger.share.file` sits under `trigger.share`), fields are `icon`, `label`, `title`, `action`, `target`, `provider`, `aliases`, `description`, `when` (hide unless a shell test passes), `checked` (shows a tick on the current value) and `disabled`.
- Search matches labels, the last id segment and descriptions; this is the filterable nested palette. Providers build live rows (`fonts`, `languages`, `kernels`, `apps`; `power-profiles` is declared but not used by the shipped menu).
- Users add or override entries in `~/.config/omarchy/extensions/omarchy-menu.jsonc`; both files are watched.
- `omarchy menu [toggle|summon] ROUTE` opens any submenu by id or alias; the default key bindings use it.
- The same plugin is the system dmenu (`omarchy-menu-select`, `omarchy-menu-input`).

Status words: **same** (same job, same or close place), **ours only**, **Omarchy only**, **different on purpose**. Omarchy-only rows carry a verdict: `Add (P1/P2/P3)` means missing and worth adding, `N/A` means not applicable, with the reason. Rows are grouped: one row can stand for several leaf entries, the note says how many.

## 1. Top-level sections and menu mechanics

| Omarchy 4.5 | BxRig | Status | Note |
|---|---|---|---|
| Apps (dock app grid, provider `apps`) | Apps (`bxrig apps`) | same | |
| Learn | Learn | same | |
| Appearance (alias `style`) | Appearance | same | Omarchy 4.x renamed Style to Appearance; BxRig already used the name |
| Trigger | Trigger | same | |
| Setup (alias `settings`) | Setup | same | |
| Install | Install | same | |
| Remove (alias `uninstall`) | Remove | same | |
| Update (aliases `restart`, `refresh`) | Update | same | |
| About (leaf) | About (leaf) | same | |
| System (alias `power-menu`) | System | same | |
| (none) | Develop | ours only | BoxLang, databases, mail catcher, VMs, containers, editor (31 leaves) |
| (none) | Agent | ours only | 9 leaves. Omarchy 4.5 has no Agent section; `quattro` (post 4.5) adds one |
| (none) | Control Center | ours only | The TUI, one entry per page (18 leaves) |
| (none) | Shortcuts | ours only | List, cheat sheet, search, rebind, run, write, conflicts, style (11 leaves) |
| Hardware (under Trigger; key Super+Ctrl+H) | Hardware (top level; key Super+Ctrl+H, `menu open hardware`) | same | Monitors, laptop panel, mirror, brightness, webcam preview, GPU check, input devices, AirPlay (14 leaves). No audio, Wi-Fi or Bluetooth entries: BxRig has no command for them (see 2.3) |
| Filterable nested palette (search over all rows) | Search entry first in the interactive menu, plus `bxrig menu search TEXT` | same | BxRig delegates filtering to the provider |
| Jump to any submenu: `omarchy menu summon ROUTE`, ids and aliases (35 aliases) | `bxrig menu open ROUTE` (a section label or a path such as `trigger > capture`; no ROUTE lists them) | same | Keys: System, Capture, Toggle, Hardware, Agent. BxRig has no aliases like `style` or `power-menu` (Add (P3)) |
| Menu defined as JSONC data, user extension file, hot reload | Menu is code (`MenuTree.bx`) | Omarchy only | Add (P2): a user menu file merged over the tree |
| `checked` ticks the current value (theme, font, browser, DNS, layout, bar position...) | no current-value marks in `menu items` | Omarchy only | Add (P2) |
| `when` hides rows that do not apply (laptop only, x86 only, installed or not) | no condition field in the JSON read | Omarchy only | Add (P3): hide rows for missing hardware or already installed apps |
| `disabled` greys out installed items in Install | none | Omarchy only | Add (P3) |
| `omarchy-menu-select` and `omarchy-menu-input` (the menu as system dmenu) | `bxrig runner select JSON` (prints the index) | same | |
| Press the menu key again to close | Esc cancels | Omarchy only | N/A: depends on the provider; BxRig supports five |
| Provider rows: fonts, languages, kernels | fonts, themes, monitors, zones, backgrounds, packages (`pick` entries) | same | |

Order: Omarchy 4.5 goes Apps, Learn, Appearance, Trigger, Setup, Install, Remove, Update, About, System. BxRig goes Apps, Setup wizard, Install, Remove, Appearance, Trigger, Shortcuts, Hardware, Setup, Update, Develop, Agent, Learn, About, System, Control Center.

Leaf entries per section (Omarchy, counted from the JSONC; a provider submenu counts once): Install 82, Setup 73, Remove 60, Appearance 56, Trigger 44, Update 23, Learn 9, System 7, Apps 1, About 1, total 356. BxRig (counted from the menu tree, `Menu.flatten`): Setup 90, Appearance 56, Trigger 34, Install 31, Develop 31, Control Center 18, Update 17, Hardware 14, Shortcuts 11, Agent 9, Learn 8, Remove 6, System 5, Apps 1, About 1, Setup wizard 1, total 333 (332 without the wizard entry, which Omarchy has no counterpart for).

## 2. Sections, entry by entry

### 2.1 Apps and Learn

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Launch an app | `omarchy-shell omarchy.dock apps` | `bxrig apps` (All apps window); the key Super+Alt+Space runs `runner launch`, the launcher you chose | same | The key was copied from 4.5; the runner has no entry for `runner launch` (Add (P3)) |
| Keybindings | Keybindings | Shortcut cheat sheet | same | |
| Product manual | omarchy.org/manual | BxRig docs | different on purpose | Own docs |
| Hyprland, Arch, Neovim | wiki, wiki, LazyVim keymaps | same three | same | |
| Bash | devhints.io/bash | none | Omarchy only | Add (P3): a shell cheat sheet link (zsh is the default) |
| Tmux keybindings | `omarchy-menu-tmux-keybindings` | none (`tmux` is in the catalog) | Omarchy only | Add (P3) |
| Herdr keybindings | `omarchy-menu-herdr-keybindings` | none (`herdr` is in the catalog) | Omarchy only | Add (P3) |
| Community | Discord | none | Omarchy only | N/A: Omarchy's community; BoxLang links already in Learn |
| BoxLang docs, Noctalia docs, CachyOS wiki | none | 3 entries | ours only | |

### 2.2 Appearance

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Theme | image picker over themes | Theme (pick) | same | |
| Background | background switcher | Background > Pick, Next, Random | same | |
| Font | provider `fonts` | Font (pick) | same | |
| Bar: hide, show | Menu Bar | Bar > Show, Hide, Toggle | same | |
| Bar position (4) | top, bottom, left, right | Bar > Position (4) | same | |
| Bar background | opaque, glassy, clear | Bar > Style opaque, glassy, clear | same | |
| Bar battery percentage | show, hide | Bar > Battery percentage | same | |
| Bar clock formats | 8 horizontal plus 4 stacked (left bar) | 5 formats | same | Omarchy has more formats and stacked ones for a left bar; Add (P3) is optional |
| Window gaps | on, off | Windows > Gaps | same | |
| Window corners | theme, sharp, rounded | Windows > Corners (same three) | same | |
| Window opacity | opaque, transparent, glassy | Windows > Opacity opaque, glassy | same | Omarchy has a third level |
| 1-window ratio | on, off | Windows > Single window aspect ratio | same | |
| Dock autohide, always on | 2 entries | Dock > Mode always, auto hide, off | same | |
| Dock position | top, bottom, left, right | bottom, left, right | same | BxRig has no top dock |
| Dock show, hide, toggle | none | Dock > Show, Hide, Toggle | ours only | |
| Default workspace layout | Tiling, Scrolling, Floating | Layout dwindle, scrolling, floating | same | Floating mode exists on both |
| Animations | on, off | Animations On, Off | same | |
| Branding: screensaver and about (6) | text, image, default | none | Omarchy only | N/A: Omarchy branding |
| Unlock | `omarchy-plymouth-switcher` (boot unlock screen) | none | Omarchy only | N/A: Plymouth theme switch for Omarchy's boot; BxRig is CachyOS |
| Next, random theme; mode (4); theme status; install a font; status; re-apply; install a theme from git (13) | none here | present | ours only | |

### 2.3 Trigger

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Stay awake / Allow sleep | `omarchy-toggle-idle` | Stay awake | same | |
| Notifications: silence | on, off | Do Not Disturb | same | |
| Notifications: snooze, clear (4) | none | present | ours only | |
| Nightlight | on, off | Night light | same | |
| Screensaver on, off | `omarchy-toggle-screensaver` | none | Omarchy only | N/A: Omarchy's own screensaver |
| Crash capture on, off | `omarchy-toggle-crash-capture` (script not read) | none | Omarchy only | N/A: looks like Omarchy support tooling, script not read |
| Emoji | Emoji | Emoji | same | |
| Clipboard history | Clipboard History | Clipboard history | same | |
| Reminder: set, show all, clear all (3) | `omarchy-reminder` | none | Omarchy only | Add (P3): small `bxrig remind` |
| Screenshot | Screenshot | Screenshot menu, Screen, Region, Window (4) | same | |
| Screenrecord: no audio | Screenrecord | Screen recording: start or stop; Record a region of the screen | same | |
| Screenrecord: with desktop audio | `--with-desktop-audio` | Screen recording with desktop audio (`record toggle --audio=desktop`, the monitor of the default sink) | same | Key Alt+Print |
| Screenrecord: microphone | `--with-microphone-audio` (desktop and microphone) | Screen recording with microphone audio (`--audio=mic`, the default input) | different on purpose | One source at a time: `wf-recorder` takes one audio device. Both at once is Add (P3) |
| Screenrecord: with webcam | shown when a webcam exists | Hardware > Webcam preview on or off (`webcam toggle`, an `mpv` window; it is only in the video if it is on screen) | different on purpose | Add (P3) to record the webcam as an overlay |
| Stop screenrecording | row shown only while recording | the same toggle entry | same | |
| Text (OCR) | Text | Text (OCR) | same | |
| QR code | QR Code | QR code | same | |
| Color picker | `hyprpicker -a` | `bxrig screenshot color` (Trigger > Capture > Color picker) | same | |
| Transcode | `omarchy-transcode` (not read) | none | Omarchy only | Add (P3): `ffmpeg` is in the catalog |
| Share: clipboard, file, folder, receive (4) | `omarchy-menu-share`, LocalSend for receive | none (`localsend` is a default catalog app) | Omarchy only | Add (P3) |
| Hardware: laptop display, mirror (4 rows, on and off) | present on laptops | Hardware > Laptop panel, Mirror (4; also under Setup > Display) | same | Omarchy shows them only on laptops; BxRig always |
| Hardware: hybrid GPU, integrated GPU | terminal presentation toggle | Hardware > GPU check (read only) | Omarchy only | Add (P3) |
| Hardware: touchpad on, off | present when a touchpad exists | Hardware > Input devices and gestures (read only) | Omarchy only | Add (P3) |
| Hardware: touchscreen on, off | present when a touchscreen exists | none | Omarchy only | Add (P3) |
| Hardware: touchpad haptics | Dell XPS tool | none | Omarchy only | N/A: Dell XPS only |
| Speed test: network, disk | shell panels | none (`speedtest` is in the catalog) | Omarchy only | Add (P3) |
| Window layout: tile or float | in Appearance (default layout) and key Super+L | Window layout: tile or float | different on purpose | BxRig toggles the current workspace from the menu |
| Force quit, Minimize window, Restore window, Overview (4) | none in the menu | present | ours only | |
| Quake console, send the window to it, private browser window, file manager in the current folder (4) | keys only (Super+grave, Super+Shift+grave, Super+Shift+Alt+B, Super+Alt+Shift+F) | present | ours only | |
| Hardware: webcam preview | none in the menu | Hardware > Webcam preview on or off | ours only | |

### 2.4 Setup

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Monitors | opens `monitors.lua` | Display: list, scale, laptop panel, mirror, brightness, apply, forget (12 leaves) | different on purpose | BxRig has real controls |
| Keybindings | opens `bindings.lua` | Shortcuts (list, cheat sheet, search, rebind, run, conflicts, style); Setup > Keyboard; Control Center > Shortcuts | different on purpose | BxRig has a table you rebind with `keys set`, not a file you edit |
| Input | opens `input.lua` | Hardware > Input devices and gestures (read only) | Omarchy only | Add (P2): natural scroll, repeat rate |
| Typing: keyboard layouts, input methods | `omarchy-setup-keyboard`, `omarchy-setup-input` | none | Omarchy only | Add (P2): layouts for a multi-language keyboard |
| Language (50-odd UI languages) | provider `languages`; `default/i18n` has 54 entries | none | Omarchy only | N/A: the BxRig menu has no translations; revisit only if it gets any |
| Network: DNS | DHCP, Cloudflare, Google, Custom | DNS: show, Cloudflare, Google, Quad9, custom, DHCP | same | |
| Network: Wi-Fi QR code | shown when connected | none | Omarchy only | Add (P3) |
| Audio, Wifi, Bluetooth, Power profile, sleep | none in the 4.5 menu (moved to shell panels, keys Super+Ctrl+A, N, B, P) | Power > Profile and Closing the lid; the keys Super+Ctrl+A, B, N, P, D open the Noctalia control center panel | different on purpose | No BxRig command exists for audio, Wi-Fi or Bluetooth, so the Hardware menu has no entry for them: Add (P2) |
| Defaults: Browser | 7 | Defaults > Browser | same | |
| Defaults: Terminal | 4 | Defaults > Terminal | same | |
| Defaults: Editor | 8 | none (`default` takes browser, terminal, filemanager) | Omarchy only | Add (P2) |
| Defaults: Agent | 24 agents | Agent > Open an agent (launch only) | Omarchy only | Add (P3): set the default agent from the menu |
| Defaults: Dictation | Superwhisper, Voxtype | Install > Dictation (Voxtype setup) | Omarchy only | Add (P3) |
| Defaults: File manager | none | Defaults > File manager | ours only | |
| Plugins: enable, disable, add, clone, remove (5) | Quickshell plugins | none | Omarchy only | N/A: Omarchy shell plugins |
| Security: Fingerprint | `omarchy-setup-security-fingerprint`, shown with a reader | Fingerprint for sudo (3) | same | |
| Security: Fido2 | setup | Security key for sudo (3) | same | |
| Security: SSHD | setup | SSH server on, off | same | |
| Security: SSH agent | setup | SSH key (shows) | Omarchy only | Add (P3) |
| Security: Sudoless Docker | setup | none | Omarchy only | N/A: BxRig uses rootless Podman |
| Security: Passwordless sudo | setup | Passwordless sudo on, off | same | |
| Config: Hyprland | opens `hyprland.lua` | none (Update > Refresh a config > Hyprland resets it) | Omarchy only | Add (P2): open `hyprland.lua` in the editor |
| Config: Git | `omarchy-setup-git` | none | Omarchy only | Add (P3): git name, email, signing |
| Config: Hyprsunset | opens file, restarts | none | Omarchy only | Add (P3): only if BxRig ships the file |
| Config: XCompose | opens `~/.XCompose` | none | Omarchy only | N/A: Omarchy text expansion |
| Direct boot | `omarchy-setup-direct-boot` | none | Omarchy only | N/A: Omarchy boot setup (script not read) |
| Reset computer | btrfs factory reset | none (snapshots under Backup) | Omarchy only | N/A: Omarchy install reset; BxRig has snapshot rollback instead (not compared in detail) |
| Time, Kernel, Cloud storage, Backup, NAS (36 leaves) | none here (Kernel and Time sit under Update) | present | ours only | |
| Power: status, lid action, laptop tools, doctor (6 leaves) | none | present | ours only | |
| Security: status, secrets, keyring, key checks (several leaves) | none | present | ours only | |
| Hardware: AirPlay receiver on, off; setup status, dotfiles status, launcher check, export settings | none | present | ours only | AirPlay is in the Hardware section |

### 2.5 Install

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Package | `omarchy-pkg-install` | Package (repos and AUR) | same | |
| AUR | `omarchy-pkg-aur-install` | AUR package | same | |
| Web app | `omarchy-webapp-install` | Web app > Create web app | same | BxRig adds install-all for Google, Microsoft, Apple, BoxLang |
| TUI | `omarchy-tui-install` (script not read) | none | Omarchy only | N/A: no equivalent concept in BxRig; Package covers installs |
| Style: Theme | theme install | Appearance > Install a theme from git | same | Different section |
| Style: Background | `omarchy-theme-bg-install` | none | Omarchy only | Add (P3): add a wallpaper from a file or URL |
| Style: Font (6 fonts) | fixed list | Font > Install a font (choose from uninstalled) | same | |
| Service: 1Password, Bitwarden, Dropbox, NordVPN, Notion, Signal, Slack, Spotify, Tailscale (9) | per-app installers | Catalog (all nine ids exist) | same | |
| Service: Microsoft | web apps | Web app > Install all Microsoft apps | same | |
| Service: ONCE, Chromium Account | installers | none | Omarchy only | N/A: Basecamp and Omarchy specific |
| Editor: VSCode, Cursor, Zed, Sublime Text, Helix (5) | 5 | catalog (all five ids exist) | same | |
| Editor: Vim, Emacs | `vim`, `omarchy-emacs` | none (`neovim` is there) | Omarchy only | Add (P3) |
| Terminal: Alacritty, Foot, Ghostty, Kitty | 4 | catalog (same four, plus Konsole, Tabby) | same | |
| Browser: Chrome, Edge, Brave, Firefox, Zen (5) | 5 | catalog (all five ids exist) | same | |
| Browser: Brave Origin | installer | none | Omarchy only | N/A: Omarchy-specific package |
| AI: ChatGPT Desktop, Claude Desktop, Grok Bot, Hermes Desktop, LM Studio, Ollama, OpenClaw, Perplexity, T3 Code (9) | 9 | catalog (`chatgpt-desktop`, `claude-desktop`, `grokbot`, `hermes-desktop`, `lm-studio`, `ollama`, `openclaw`, `perplexity`, `t3-code`) | same | BxRig also has Codex, Gemini CLI, OpenCode, Jan and more |
| AI: Amp Desktop | installer | none | Omarchy only | Add (P3) |
| Gaming: Steam, RetroArch, Minecraft, GeForce Now, Xbox Cloud, Lutris, Heroic (7) | 7 | catalog (all seven ids exist) | same | |
| Gaming: Xbox Controllers, Battle.net, RetroArch game launcher (3) | installers | none | Omarchy only | Add (P3): the controller driver first |
| Development: JavaScript (Node, Bun, Deno) | 3 | Node.js (nvm); Bun and Deno from the catalog | same | |
| Development: Go, PHP, Python, Java | 4 | catalog (`go`, `php`, `uv`, `python-pip`, `jdk21`, `maven`, `gradle`) | same | |
| Development: Docker DB | `omarchy-install-docker-dbs` | Develop > Databases | same | BxRig uses Podman and more engines |
| Development: Rails, Elixir, Phoenix, Zig, Rust, .NET, OCaml, Clojure, Scala, Laravel, Symfony (11) | mise or tool installers | none (use Package; `mise` is in the catalog) | Omarchy only | N/A: outside the BoxLang and Java focus |
| Windows VM | `omarchy-windows-vm install`, x86 only | Virtual machine > Windows | same | |
| Preinstalls | reinstall the shipped app set | none | Omarchy only | N/A: Omarchy's preinstalled set |
| Catalog by group (11), Linux desktops VMs, Neovim with LazyVim, Agent skills, Dictation | none | present | ours only | |

### 2.6 Remove

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Package | `omarchy-pkg-remove` | Package | same | |
| Web app | remove | Web app | same | |
| Theme | remove | Theme | same | |
| Windows | `windows-vm remove` | Virtual machine | same | |
| AI (10), Dictation (2), Services (5), Development (18), Gaming (9), Browser (6) | dedicated removers, shown only when installed | App from the catalog (pick from installed) | different on purpose | One generic remover |
| TUI | remove | none | Omarchy only | N/A: see Install |
| Preinstalls | remove | none | Omarchy only | N/A: Omarchy's preinstalled set |
| Security: Fingerprint, Fido2, SSHD, Sudoless Docker (4) | removers | Setup > Security > Turn off | same | Different section |
| Agent skill | none | Agent skill | ours only | |

### 2.7 Update, About, System

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Update the system | `omarchy-update` | System update (snapshot first) | same | |
| Update the tool itself | none separate | Check for, install a BxRig update | ours only | |
| Channel | Stable, RC, Edge, Dev | Stable, Beta | same | |
| Kernel | provider `kernels`, shown with 2 or more kernels | Setup > Kernel (3 leaves) | same | Different section |
| Config refresh to default | Hyprland, Hyprsunset, Plymouth, Tmux, Shell (5) | Hyprland, Noctalia, Terminals, Shell and prompt, Neovim layer, Theme, Everything (7) | same | |
| Extra themes | `omarchy-theme-update` | none | Omarchy only | Add (P3) |
| Process restart: Shell, Hyprsunset | 2 | none | Omarchy only | Add (P2): restart Noctalia |
| Hardware restart: Audio, Wi-Fi, Bluetooth, Trackpad | 4 | none | Omarchy only | Add (P2): pipewire and wireplumber, NetworkManager, bluetooth |
| Firmware | `omarchy-update-firmware` | none | Omarchy only | Add (P2): fwupd |
| Password: drive encryption, user | 2 | none | Omarchy only | Add (P3): `passwd`; the drive password only with LUKS |
| Timezone, Time | `omarchy-menu-timezone`, `omarchy-update-time` | Setup > Time (6 leaves) | same | Different section |
| Notifications, re-apply appearance and display, agent skills update (5) | none | present | ours only | |
| About | `omarchy-launch-about` | About (`bxrig status`) | same | |
| Lock | `omarchy-system-lock` | Lock | same | |
| Suspend | `systemctl suspend`, hidden when sleep is off | Suspend | same | |
| Hibernate | shown when available | none | Omarchy only | Add (P2) |
| Logout, Reboot, Shutdown | 3 | 3 (with `--yes`) | same | |
| Screensaver (force) | `omarchy-launch-screensaver force` | none | Omarchy only | N/A: no BxRig screensaver |

### 2.8 BxRig-only sections

| Section | Leaves | Status | Note |
|---|---|---|---|
| Develop: BoxLang (6), databases, mail catcher (10), virtual machines (8), containers (3), editor (3) | 31 | ours only | |
| Agent: default agent, any agent, pull-down shell, sessions, models, API keys, skills status | 9 | ours only | |
| Control Center: whole TUI plus 17 single pages | 18 | ours only | |
| Shortcuts: list, cheat sheet, search, rebind, run, write, conflicts, style (4) | 11 | ours only | `keys` as a menu |

## 3. Keyboard shortcuts

Omarchy 4.5: `o.bind` lines in `default/hypr/bindings/*.lua` at v4.5.0 (211 `o.bind` lines plus loops over workspaces, groups and bar panels, each counted as one row below). BxRig: `bxrig keys show`. State 2026-11-15: the one table holds every bind (131 rows: 19 xremap remaps, 17 unbound Control Center page rows, the rest bindings; 96 rows have a key in the Traditional style and 112 in the Mac style), each with a Traditional and a Mac key. The rows below show the Traditional keys unless a note names the Mac style. `bxrig keys conflicts` is clean in both styles. Decisions: `docs/architecture/SHORTCUTS-DECISIONS.md`.

Moved or new in 4.5 that matter here: panels have their own keys (Super+Ctrl+A audio, B Bluetooth, N network, P power, D display, Alt+D calendar, Alt+E world clock, Super+Ctrl+1..9 bar panels); Super+Alt+Space is now Apps and Super+Space the menu root; Super+Q and Super+W both close; Super+M minimizes to the dock; Super+grave opens a Quake console (BxRig: the AI shell, see the row); Super+Shift+Q is Calculator; Tab keys cycle workspaces per monitor; the notification keys moved to Super+comma with Shift, Ctrl, Alt variants; Super+Ctrl+N is Network (it was night light); Super+Ctrl+T is the theme menu and Super+Shift+T the activity monitor; dictation moved to Alt+Space.

### 3.1 Side by side

| Action | Omarchy 4.5 keys | BxRig keys | Status | Note |
|---|---|---|---|---|
| Open the menu | Super+Space (root), Super+Shift+code:201 | Super+Space (both styles) | same | Owner r1 |
| Launch apps | Super+Alt+Space (dock apps) | Super+Alt+Space (the launcher you chose) | same | The separate all-apps key is gone (r2) |
| System menu | Super+Escape, XF86PowerOff | Super+Escape, XF86PowerOff (`menu open system`) | same | |
| Capture, Toggle, Hardware menus | Super+Ctrl+C, O, H | Super+Ctrl+C (Capture), Super+Ctrl+O (Toggle), Super+Ctrl+H (Hardware) | same | `menu open capture\|toggle\|hardware` |
| Show key bindings | Super+K | Super+K | same | |
| Tmux, Herdr key lists | Super+Alt+K, Super+Ctrl+K | none | Omarchy only | Add (P3) |
| Emoji picker | Super+Ctrl+E | Super+Ctrl+E | same | |
| Clipboard manager | Super+Ctrl+V | Super+Ctrl+V | same | `Super+Shift+V` dropped (r8) |
| Copy, paste, cut, select all | Super+C, V, X, A (Hyprland key injection, terminal aware) | Super+C, V, X, A (xremap, terminal aware, both styles) | same | xremap is always set up; the other Cmd keys are Mac style only |
| Screenshot | Print, Super+Ctrl+Alt+C | Print; Mac style also Super+Shift+3, 4, 5 | different on purpose | Owner r10: Print is the region screenshot |
| Screen recording | Alt+Print (stops, or opens the menu with the audio and webcam choices) | Super+Shift+R; region Super+Alt+Shift+R; with desktop audio Alt+Print | different on purpose | Alt+Print starts or stops a recording with desktop audio at once; the microphone variant is in the Capture menu |
| Webcam overlay size | Super+Alt+code:34, 35 | none | Omarchy only | Add (P3) with webcam recording |
| Webcam preview on or off | none (4.5 has only the overlay resize keys) | Super+Ctrl+Alt+V (`webcam toggle`) | ours only | The key is our own choice |
| Color picker | Super+Print | Super+Print (`screenshot color`, hyprpicker) | same | Owner r13 |
| OCR | Super+Ctrl+Print | none (menu, or Super+Shift+5) | Omarchy only | Add (P3) |
| Share, transcode | Super+Ctrl+S, Super+Ctrl+Period | none | Omarchy only | Add (P3) |
| Reminders: set, show, clear | Super+Ctrl+R, Super+Ctrl+Alt+R, Super+Shift+Ctrl+R | none | Omarchy only | Add (P3) with Reminder |
| Time, battery, weather notices | Super+Ctrl+Alt+T, B, W | Super+Ctrl+Alt+T, B, W (`notify time\|battery\|weather`) | same | Owner r17 |
| Audio, Bluetooth, Network, Power, Display panels | Super+Ctrl+A, B, N, P, D | Super+Ctrl+A, B, N, P, D | same | Owner: all open the Noctalia control center panel, as Super+Alt+C does |
| Bar panel by number | Super+Ctrl+1..9 | none | Omarchy only | Add (P3) |
| Calendar, world clock | Super+Ctrl+Alt+D, E | none | Omarchy only | Add (P3) |
| Activity monitor | Super+Shift+T (btop) | none | Omarchy only | Add (P3) |
| Agent picker | Super+Shift+Ctrl+A | Super+Shift+Ctrl+A (`menu open agent`); the AI shell is Super+` | same | Owner r22 |
| Dictation toggle | Alt+Space | Alt+Space (`dictation toggle`) | same | Owner r23 |
| Dictation push to talk | hold Right Alt | none | Omarchy only | Add (P3) |
| Input language switch | Super+I, Super+Shift+I | Super+I, Super+Shift+I; Mac style Super+Alt+I, Super+Alt+Shift+I | same | Owner r25; Super+I is Italic in the Mac style |
| Zoom in, reset | Super+Ctrl+Z, Super+Ctrl+Alt+Z | none | Omarchy only | Add (P3) |
| Lock | Super+Ctrl+L | Super+Ctrl+L | same | Owner r27 |
| Toggle top bar | Super+Shift+Space | none (`appearance bar toggle` is on Super+Ctrl+Alt+F) | different on purpose | Omarchy's Super+Ctrl+Alt+F is its full screen desktop, which hides bar and dock; owner r31 gave that key to the bar |
| Background menu, theme menu | Super+Ctrl+Space or W; Super+Shift+Ctrl+Space or Super+Ctrl+T | none | Omarchy only | Add (P3) |
| Window transparency, gaps, square ratio | Super+Backspace, with Shift, with Ctrl | none | Omarchy only | Add (P3) |
| Full screen desktop | Super+Ctrl+Alt+F | Super+Ctrl+Alt+F (`appearance bar toggle`) | same | Owner r31: toggles the Noctalia bar |
| Dismiss all notifications | Super+Shift+comma | none (menu: Clear notifications) | Omarchy only | Add (P2): bind `notify clear` |
| Act on, dismiss one, history, keyboard control of notifications | Super+comma, Alt+comma, Shift+Alt+comma, Ctrl+comma | none (Super+Comma is Noctalia settings or Preferences) | Omarchy only | N/A: no Noctalia equivalent was read; revisit with Noctalia's IPC |
| Silence notifications | Super+Ctrl+Alt+comma | Super+Ctrl+Alt+Comma | same | Owner r34 |
| Stay awake toggle | Super+Ctrl+I | none (menu entry exists) | Omarchy only | Add (P3) |
| Night light | none (menu only) | none (menu only) | same | Owner r36: Omarchy has no key, so the key is gone |
| Laptop display toggle, mirror | Super+Ctrl+Delete, with Alt | none (menu entries exist) | Omarchy only | Add (P3) |
| Lid close and open (incl. Apple SMC lid) | `switch:on:Lid Switch` and the Apple name | Power > Closing the lid (logind setting) | different on purpose | Apple Silicon: BxRig targets x86 Arch |
| Close window | Super+W, Super+Q | Super+Q; Super+W in the Traditional style | same | Owner r39. In the Mac style Super+W is the Close tab remap |
| Close all windows | Ctrl+Alt+Delete | none | Omarchy only | Add (P3) |
| Toggle split | Super+J | Super+J | same |  |
| Pseudo window | Super+P | none | Omarchy only | N/A: Super+P is Print with Mac keys, pseudo-tiling is rare |
| Float or tile | Super+T | Super+T; Mac style Super+Alt+T | same | Owner r43 |
| Full screen | Super+F | Super+F; Mac style Super+Ctrl+F | same | Super+F is Find in the Mac style |
| Tiled fullscreen, full width | Super+Ctrl+F, Super+Alt+F | none | Omarchy only | Add (P3) |
| Pop window out | Super+O | none | Omarchy only | Add (P3) |
| Save, restore window width | Super+Alt+Home, Super+Home | none | Omarchy only | Add (P3) |
| Cycle workspace layout | Super+L, Super+Alt+L | none (menu: Window layout) | Omarchy only | Add (P3) |
| Focus with arrows | Super+Arrows | Super+Arrows | same | |
| Workspace 1 to 10: switch, move, move silently | Super+1..0, with Shift, with Shift+Alt | Super+1..0, with Shift (Mac style: Super+Alt+Shift+3/4/5 for 3 to 5) | same | BxRig lacks the silent move (Add (P3)) |
| Scratchpad | Super+S, Super+Alt+S | none (Super+S is Save in the Mac style) | Omarchy only | Add (P3) |
| Quake console | Super+grave (show, hide), Super+Shift+grave (send the window) | Super+Shift+Grave (`window quake`), Super+Ctrl+Grave (`window quake send`); the AI shell is Super+Grave | different on purpose | Owner r52 and the second round. `qconsole.lua` does not exist at v4.5.0 (404); the binds are in `tiling.lua`: the special workspace `qconsole` |
| Minimize to the dock | Super+M | Super+H (restore Super+Shift+H) | different on purpose | Owner r53 |
| Next, previous, former workspace | Super+Tab, with Shift, with Ctrl (per monitor) | none (swipe, Super+scroll); Super+Tab is the Cmd+Tab switcher | different on purpose | |
| Move workspace, move window to another monitor | Super+Shift+Alt+Arrows, Super+Shift+Ctrl+Arrows | none | Omarchy only | Add (P3) |
| Swap window with neighbour | Super+Shift+Arrows | Super+Shift+Arrows (`window.move`) | same | Dispatcher differs, behaviour not tested |
| Cycle windows | Alt+Tab, Alt+Shift+Tab | Alt+Tab (Noctalia switcher; Super+Tab remaps to it) | same | |
| Focus other monitor | Ctrl+Alt+Tab | none | Omarchy only | Add (P3) |
| Resize with keys (3 step sizes) | Super+Minus, Super+Equal; with Alt (small), Ctrl (large), Shift (other axis) | none (mouse drag only) | Omarchy only | Add (P2) |
| Scroll workspaces; move, resize with mouse | Super+scroll, Super+LMB, RMB | same | same | |
| Window groups (13 binds) | Super+G and relatives | none | Omarchy only | Add (P3) |
| Monitor scaling up, down | Super+Slash, Super+Alt+Slash | none (menu: Display > Scale) | Omarchy only | Add (P3) |
| Volume, mute, mic mute | XF86Audio keys | XF86Audio keys (`wpctl`) | same | |
| Brightness; precise, max, min | XF86MonBrightness keys; with Alt, Shift | XF86MonBrightness keys only | Omarchy only | Add (P3) for precise, max, min |
| Keyboard backlight (also Ctrl+brightness on Macs) | XF86Kbd keys | none | Omarchy only | Add (P3) |
| Touchpad on, off, toggle | XF86Touchpad keys | none | Omarchy only | Add (P3) |
| Media: play, pause, next, previous, eject | XF86 keys through the shell | none (`playerctl` is in the catalog) | Omarchy only | Add (P2) |
| Switch audio output, media source | Shift+XF86AudioMute, Shift+XF86AudioPlay | none | Omarchy only | Add (P3) |
| Terminal | Super+Return | Super+Return | same | |
| Tmux, Herdr in a terminal | Super+Alt+Return, Super+Ctrl+Return | none | Omarchy only | Add (P3) |
| Browser; private | Super+Shift+Return or B; Super+Shift+Alt+B | Super+B, Super+Shift+Return; private Super+Alt+Shift+B (`browser private`). Mac style: Super+Shift+Return; private Super+Shift+N | same | Super+B is Bold in the Mac style; Super+Shift+N is the Cmd+Shift+N private window of Safari and Chrome |
| File manager; in cwd | Super+Shift+F; Super+Alt+Shift+F | Super+Shift+F; in the current folder Super+Alt+Shift+F (`files here`). Mac style: Super+E; Super+Alt+Shift+F | same | The folder is the focused window's (a terminal's shell), else home |
| Editor | Super+Shift+N | none | Omarchy only | Add (P3) |
| Calculator | Super+Shift+Q, XF86Calculator | none | Omarchy only | N/A: Super+Shift+Q is Log out in BxRig; XF86Calculator is trivial |
| Preinstalled apps and web apps (Music, Docker, Signal, Obsidian, Omawrite, Passwords, ChatGPT, Grok, Calendar, Email, New email, YouTube, WhatsApp, Messages, Photos, Maps, X, X Post; about 20 binds, switched off by `omarchy_preinstalled_bindings`) | Super+Shift+letter | none | Omarchy only | N/A: personal app choices; Add (P3) a way to bind your own commands (not checked whether `keys` supports it) |
| Log out to the login screen | none | Super+Shift+Q | ours only | |
| Force quit | none | Super+Alt+Escape | ours only | |
| Overview | none | Super+Ctrl+Up | ours only | |
| Cmd-style remaps beyond copy, paste, cut, select all (Z, S, F, T, N, O, P, R, W, L, B, I, U, Comma, Tab; 15) | none | xremap | ours only | Mac style only: `keys style mac` (or `keys mac on`) |
| Control Center pages (17 unbound rows) | none | unbound by default | ours only | Bind with `keys set tui-PAGE KEYS` |
| Noctalia settings window | none | Super+Ctrl+Comma | ours only | Super+Comma is Preferences in the Mac style |

### 3.2 Is each BxRig shortcut reachable from the runner menu

Every binding of `bxrig keys show` that is not a remap, a Control Center page row or one of the arrow, workspace and mouse keys (those are window manager actions, not commands). "Runs" is the command `keys run ID` starts; a row with no command is a Lua dispatch of the Hyprland module.

| BxRig shortcut | Action | Runs | In the menu | Where |
|---|---|---|---|---|
| Super+Space | BxRig menu | `menu` | n/a | the menu itself |
| Super+Alt+Space | Launch apps | `runner launch` | no | none (Apps opens `bxrig apps`, the All apps window): Add (P3) |
| Super+K | Shortcut cheat sheet | `keys sheet` | yes | Shortcuts > Cheat sheet; Setup > Keyboard; Learn |
| Super+Escape, XF86PowerOff | System menu | `menu open system` | yes | System |
| Super+Ctrl+C, O, H | Capture, Toggle, Hardware menus | `menu open ...` | yes | Trigger > Capture, Trigger > Toggle, Hardware |
| Super+Shift+Ctrl+A | Agent picker | `menu open agent` | yes | Agent |
| Super+Return, Super+B or Super+Shift+Return, Super+Shift+F or Super+E | Terminal, browser, file manager | none (Lua: the programs of `hyprland.lua`) | no | N/A: starts a program |
| Super+Alt+Shift+B (Mac: Super+Shift+N) | Private browser window | `browser private` | yes | Trigger > Private browser window |
| Super+Alt+Shift+F | File manager in the current folder | `files here` | yes | Trigger > File manager in the current folder |
| Super+Grave | Pull-down AI shell | `ai shell` | yes | Agent > Pull-down AI shell |
| Super+Ctrl+E | Emoji | `emoji` | yes | Trigger > Emoji |
| Super+Ctrl+V | Clipboard history | `clipboard pick` | yes | Trigger > Clipboard history |
| Print (Mac also Super+Shift+4) | Screenshot of a region | `screenshot region` | yes | Trigger > Capture > Region |
| Super+Shift+3 (Mac) | Screenshot of the screen | `screenshot screen` | yes | Trigger > Capture > Screen |
| Super+Shift+5 (Mac) | Screenshot menu | `screenshot menu` | yes | Trigger > Capture > Screenshot menu |
| Super+Print | Color picker | `screenshot color` | yes | Trigger > Capture > Color picker |
| Super+Shift+R | Recording | `record toggle` | yes | Trigger > Capture > Screen recording: start or stop |
| Super+Alt+Shift+R | Recording of a region | `record toggle --region` | yes | Trigger > Capture > Record a region of the screen |
| Alt+Print | Recording with desktop audio | `record toggle --audio=desktop` | yes | Trigger > Capture > Screen recording with desktop audio |
| Super+Ctrl+Alt+V | Webcam preview | `webcam toggle` | yes | Hardware > Webcam preview on or off |
| Alt+Space | Dictation toggle | `dictation toggle` | yes | Trigger > Toggle > Dictation on or off |
| Super+Ctrl+Alt+Comma | Do Not Disturb | `notify dnd toggle` | yes | Trigger > Toggle > Do Not Disturb |
| Super+Ctrl+Alt+T, B, W | Time, battery, weather notices | `notify time\|battery\|weather` | yes | Trigger > Notices |
| Super+Alt+C, Super+Ctrl+A, B, N, P, D | Noctalia control center panel | none (Noctalia IPC `panel-toggle control-center`) | no | none: Add (P2) with the panel entries |
| Super+Ctrl+Comma | Noctalia settings window | none (Noctalia IPC `settings-toggle`) | no | none: Add (P2) |
| Super+Ctrl+Alt+F | Hide or show the bar | `appearance bar toggle` | yes | Appearance > Bar > Toggle |
| Super+Alt+D | Show or hide the dock | `appearance dock toggle` | yes | Appearance > Dock > Toggle; Trigger > Toggle > Dock: show or hide |
| Super+Q, Super+W | Close window | none (Lua) | no | N/A: window manager action |
| Super+F (Mac: Super+Ctrl+F), Super+T (Mac: Super+Alt+T), Super+J | Full screen, float, toggle split | none (Lua) | partly | Trigger > Toggle > Window layout: tile or float covers the layout, not the window |
| Super+H, Super+Shift+H | Minimize, show minimized | `window minimize`, `window restore` | yes | Trigger > Minimize window, Restore window |
| Super+Shift+Grave, Super+Ctrl+Grave | Quake console: show or hide, send the window | `window quake`, `window quake send` | yes | Trigger > Quake console, Send the window to the quake console |
| Super+Alt+Escape | Force quit | `forcequit` | yes | Trigger > Force quit an app |
| Super+Ctrl+Up | Overview | `overview` | yes | Trigger > Overview |
| Alt+Tab | Noctalia window switcher | none (Noctalia IPC) | no | N/A: interactive switcher |
| Super+Ctrl+L | Lock | `system lock` | yes | System > Lock |
| Super+Shift+Q | Log out | none (Lua: `uwsm stop`; Plasma through `ksmserver`) | partly | System > Logout runs `system logout` |
| Super+I, Super+Shift+I (Mac: Super+Alt+I, Super+Alt+Shift+I) | Next, previous input language | none (Lua: `hyprctl switchxkblayout`) | no | N/A |
| XF86 volume, mute, mic mute, brightness keys | Hardware keys | none (Lua: `wpctl`, `brightnessctl`) | partly | Setup > Display > Brightness (up, down, 50%, 100%); Hardware > Brightness. No volume entry |
| Super+arrows, Super+Shift+arrows, Super+1..0, Super+Shift+1..0, mouse | Focus, move, workspaces | none (Lua) | no | N/A: window manager actions |
| none (menu only) | Night light | `nightshift toggle` | yes | Trigger > Toggle > Night light |
| 17 Control Center page rows (unbound) | Open one TUI page | `tui PAGE` | yes | Control Center, one entry each |
| 19 Cmd-style remaps (copy, paste, cut, select all in both styles; the rest and Super+Tab in the Mac style) | Key remaps | none | style only | Setup > Keyboard > Mac-style keys on, off; Shortcuts > Style |

## 4. Summary and gaps

State of the code on 2026-11-15. Every number below was counted from the tables above (a row can stand for several leaf entries).

### Counts

| Status | Menu (sections 1 and 2) | Shortcuts (3.1) |
|---|---|---|
| same | 84 | 31 |
| different on purpose | 8 | 7 |
| ours only | 24 | 7 |
| Omarchy only | 55 | 37 |
| of which: Add (P1) | 0 | 0 |
| of which: Add (P2) | 10 | 3 |
| of which: Add (P3) | 24 | 31 |
| of which: N/A | 21 | 3 |

Size: Omarchy 4.5 has 10 top-level sections and 356 leaf entries; BxRig has 16 top-level entries (15 sections and the setup wizard) and 333 leaf entries. Omarchy 4.5 has 211 `o.bind` lines (the loops over workspaces, groups and bar panels count once each in 3.1); BxRig has 131 rows in one table, 112 of them with a key in the Mac style and 96 in the Traditional style.

BxRig matches Omarchy 4.5 on the section names (Appearance), the dock, floating and scrolling layouts, stay awake, QR code, emoji, clipboard history, the apps key, the menu root and the System, Capture, Toggle and Hardware menus on their own keys, the panel keys, the notices, the color picker, recording with audio, the private browser window, the file manager in the current folder, the Quake console, dictation, lock and the cheat sheet.

Reading the numbers: Omarchy 4.5 moved Audio, Wi-Fi, Bluetooth and power out of the Setup menu into shell panels with their own keys. BxRig has the keys (all five open the Noctalia control center panel) but no commands behind them, so the Hardware menu has no such entries. What remains are menu mechanics BxRig does not have (user extension file, current-value ticks, hide-when-not-applicable) and a long tail of P3 items. Many Omarchy-only rows are Omarchy branding, Plymouth, Quickshell plugins or app picks (21 menu and 3 key rows marked N/A).

### Prioritized gaps

P1: none open. The four P1 items of the first comparison are built: `bxrig menu open ROUTE` with the System, Capture, Toggle and Hardware keys, the color picker, recording with audio, and the panel keys.

P2, useful:

1. Menu mechanics: a user menu extension file merged over the tree, and a tick on the current value (theme, font, browser, DNS, layout, bar position).
2. Audio, Wi-Fi and Bluetooth: a command for each (`wpctl`, `nmcli`, `bluetoothctl`) so the Hardware menu and the panel keys have something to run, plus the restart entries (pipewire and wireplumber, NetworkManager, bluetooth, trackpad) and restart Noctalia.
3. Update > Firmware (fwupd).
4. Setup: open `hyprland.lua` in the editor, Input (natural scroll, repeat rate), Typing (keyboard layouts), Defaults > Editor.
5. System > Hibernate when resume is configured.
6. Keys: dismiss all notifications (`notify clear`), keyboard window resize (three step sizes), media transport (`playerctl` is in the catalog).
7. Menu entries for what only has a key today: the Noctalia control center panel and settings window.

P3, nice to have: reminders, transcode, share and receive, speed tests, recording the webcam as an overlay, desktop and microphone audio together, hybrid GPU, touchpad and touchscreen toggles, Wi-Fi QR, Git setup, default agent and dictation pickers, Vim, Emacs, Amp, Xbox controllers and Battle.net installs, Learn links (Bash, Tmux, Herdr), menu aliases, a `runner launch` entry, window groups, scratchpad, silent workspace move, move to monitor, zoom, keyboard backlight, hide-when-not-applicable rows.

### Findings outside the comparison

- `bxrig keys conflicts` compares the table, the remaps of the style that is on and the `hl.bind` lines of your own files (`hyprland.lua` and others under `~/.config/hypr`). It is clean in both styles for the table itself.
- Some keys mean different things in the two systems and may confuse users who know both: Super+Shift+Q (Omarchy Calculator, BxRig Log out), Super+Shift+M (Omarchy Music), Super+grave (Omarchy Quake console, BxRig AI shell; the console is on Super+Shift+Grave), Super+Shift+N (Omarchy Editor, BxRig private window in the Mac style), Super+Ctrl+Alt+F (Omarchy hides bar and dock, BxRig only the bar).
- The menu has no volume entries; brightness has four, in two places (Setup > Display and Hardware).
- The webcam preview needs `mpv`, recording with audio needs `pactl` (PipeWire's pulse support); the Hyprland-side behaviour of `window quake`, `files here` and the webcam window rule has not run on a real desktop yet.
