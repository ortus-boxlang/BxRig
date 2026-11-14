# BxRig runner menu vs Omarchy 4.5 menu

One-to-one comparison of `bxrig menu` (the control center, shown on your runner's menu provider) with the Omarchy 4.5 menu, plus the keyboard shortcuts of both.

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

Not read: `default/hypr/bindings/jis.lua` (JIS keyboards), the `omarchy-*` helper scripts the entries call (for example `omarchy-menu-share`, `omarchy-transcode`, `omarchy-toggle-crash-capture`), `workspace-modes.lua`, `qconsole.lua`. Where a verdict depends on one of them, the note says so.

### BxRig files read

`bxrig menu items` and `--json` (298 leaf entries), `src/bxrig/Menu.bx`, `MenuTree.bx` (via the tree output), `docs/guides/menu.md`, COMMAND-CONTRACT 13.4 and 13.16, `bxrig keys show`, `src/bxrig/Shortcuts.bx`, `templates/hyprland.lua`, `docs/guides/shortcuts.md`, and `catalog/apps.json` for catalog ids.

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
| Filterable nested palette (search over all rows) | Search entry first in the interactive menu, plus `bxrig menu search TEXT` | same | BxRig delegates filtering to the provider |
| Jump to any submenu: `omarchy menu summon ROUTE`, ids and aliases (35 aliases) | `bxrig menu` takes only `items` and `search` | Omarchy only | Add (P1): `bxrig menu ROUTE` so keys can open one section |
| Menu defined as JSONC data, user extension file, hot reload | Menu is code (`MenuTree.bx`) | Omarchy only | Add (P2): a user menu file merged over the tree |
| `checked` ticks the current value (theme, font, browser, DNS, layout, bar position...) | no current-value marks in `menu items` | Omarchy only | Add (P2) |
| `when` hides rows that do not apply (laptop only, x86 only, installed or not) | no condition field in the JSON read | Omarchy only | Add (P3): hide rows for missing hardware or already installed apps |
| `disabled` greys out installed items in Install | none | Omarchy only | Add (P3) |
| `omarchy-menu-select` and `omarchy-menu-input` (the menu as system dmenu) | `bxrig runner select JSON` (prints the index) | same | |
| Press the menu key again to close | Esc cancels | Omarchy only | N/A: depends on the provider; BxRig supports five |
| Provider rows: fonts, languages, kernels | fonts, themes, monitors, zones, backgrounds, packages (`pick` entries) | same | |

Order: Omarchy 4.5 goes Apps, Learn, Appearance, Trigger, Setup, Install, Remove, Update, About, System. BxRig goes Apps, Install, Remove, Appearance, Trigger, Setup, Update, Develop, Agent, Learn, About, System, Control Center.

Leaf entries per section (Omarchy, counted from the JSONC; a provider submenu counts once): Install 82, Setup 73, Remove 60, Appearance 56, Trigger 44, Update 23, Learn 9, System 7, Apps 1, About 1, total 356. BxRig (from `menu items --json`): Setup 94, Appearance 56, Install 31, Develop 31, Trigger 21, Control Center 18, Update 17, Agent 9, Learn 8, Remove 6, System 5, Apps 1, About 1, total 298.

## 2. Sections, entry by entry

### 2.1 Apps and Learn

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Launch an app | `omarchy-shell omarchy.dock apps` | `bxrig apps` | same | BxRig's key (Super+Alt+Space) was copied from 4.5 |
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
| Screenrecord: no audio | Screenrecord | Screen recording start or stop | same | |
| Screenrecord: with desktop audio | `--with-desktop-audio` | none (`Record.bx` has no audio option) | Omarchy only | Add (P1) |
| Screenrecord: desktop and microphone | `--with-microphone-audio` | none | Omarchy only | Add (P1) |
| Screenrecord: with webcam | shown when a webcam exists | none | Omarchy only | Add (P3) |
| Stop screenrecording | row shown only while recording | the same toggle entry | same | |
| Text (OCR) | Text | Text (OCR) | same | |
| QR code | QR Code | QR code | same | |
| Color picker | `hyprpicker -a` | none (`hyprpicker` is in the catalog) | Omarchy only | Add (P1) |
| Transcode | `omarchy-transcode` (not read) | none | Omarchy only | Add (P3): `ffmpeg` is in the catalog |
| Share: clipboard, file, folder, receive (4) | `omarchy-menu-share`, LocalSend for receive | none (`localsend` is a default catalog app) | Omarchy only | Add (P3) |
| Hardware: laptop display, mirror (4 rows, on and off) | present on laptops | Setup > Display > Laptop panel, Mirror (4) | same | Different section |
| Hardware: hybrid GPU, integrated GPU | terminal presentation toggle | Setup > Hardware > GPU check (read only) | Omarchy only | Add (P3) |
| Hardware: touchpad on, off | present when a touchpad exists | Setup > Hardware > Input devices and gestures (read only) | Omarchy only | Add (P3) |
| Hardware: touchscreen on, off | present when a touchscreen exists | none | Omarchy only | Add (P3) |
| Hardware: touchpad haptics | Dell XPS tool | none | Omarchy only | N/A: Dell XPS only |
| Speed test: network, disk | shell panels | none (`speedtest` is in the catalog) | Omarchy only | Add (P3) |
| Window layout: tile or float | in Appearance (default layout) and key Super+L | Window layout: tile or float | different on purpose | BxRig toggles the current workspace from the menu |
| Force quit, Minimize window, Restore window, Overview (4) | none in the menu | present | ours only | |

### 2.4 Setup

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Monitors | opens `monitors.lua` | Display: list, scale, laptop panel, mirror, brightness, apply, forget (12 leaves) | different on purpose | BxRig has real controls |
| Keybindings | opens `bindings.lua` | Keyboard: shortcuts, cheat sheet, conflicts, Mac keys; Control Center > Shortcuts | different on purpose | |
| Input | opens `input.lua` | Hardware > Input devices and gestures (read only) | Omarchy only | Add (P2): natural scroll, repeat rate |
| Typing: keyboard layouts, input methods | `omarchy-setup-keyboard`, `omarchy-setup-input` | none | Omarchy only | Add (P2): layouts for a multi-language keyboard |
| Language (50-odd UI languages) | provider `languages`; `default/i18n` has 54 entries | none | Omarchy only | N/A: the BxRig menu has no translations; revisit only if it gets any |
| Network: DNS | DHCP, Cloudflare, Google, Custom | DNS: show, Cloudflare, Google, Quad9, custom, DHCP | same | |
| Network: Wi-Fi QR code | shown when connected | none | Omarchy only | Add (P3) |
| Audio, Wifi, Bluetooth, Power profile, sleep | none in the 4.5 menu (moved to shell panels, keys Super+Ctrl+A, N, B, P) | Power > Profile and Closing the lid | different on purpose | See keys in 3.1: BxRig has no panel keys, Add (P2) there |
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
| Hardware: AirPlay receiver, GPU check; setup status, dotfiles status, launcher check, export settings | none | present | ours only | |

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

## 3. Keyboard shortcuts

Omarchy 4.5: `o.bind` lines in `default/hypr/bindings/*.lua` at v4.5.0 (211 `o.bind` lines plus loops over workspaces, groups and bar panels, each counted as one row below). BxRig: `bxrig keys show` (38 rows with keys, 17 more unbound rows, one per Control Center page), plus the binds in `bxrig.lua` outside the table (Super+Space, Super+S, Super+Comma, Alt+Tab) and the starter `hyprland.lua`.

Moved or new in 4.5 that matter here: panels have their own keys (Super+Ctrl+A audio, B Bluetooth, N network, P power, D display, Alt+D calendar, Alt+E world clock, Super+Ctrl+1..9 bar panels); Super+Alt+Space is now Apps and Super+Space the menu root; Super+Q and Super+W both close; Super+M minimizes to the dock; Super+grave opens a Quake console; Super+Shift+Q is Calculator; Tab keys cycle workspaces per monitor; the notification keys moved to Super+comma with Shift, Ctrl, Alt variants; Super+Ctrl+N is Network (it was night light); Super+Ctrl+T is the theme menu and Super+Shift+T the activity monitor; dictation moved to Alt+Space.

### 3.1 Side by side

| Action | Omarchy 4.5 keys | BxRig keys | Status | Note |
|---|---|---|---|---|
| Open the menu | Super+Space (root), Super+Shift+code:201 | Super+Alt+M | different on purpose | BxRig keeps Super+Space for the launcher |
| Launch apps | Super+Alt+Space (dock apps) | Super+Space (launcher), Super+Alt+Space (all apps) | same | BxRig has both |
| System menu | Super+Escape, XF86PowerOff | none | Omarchy only | Add (P1): needs `menu ROUTE` first |
| Capture, Toggle, Hardware menus | Super+Ctrl+C, O, H | Super+Shift+5 (screenshot menu only) | Omarchy only | Add (P1): same dependency |
| Show key bindings | Super+K | Super+K | same | |
| Tmux, Herdr key lists | Super+Alt+K, Super+Ctrl+K | none | Omarchy only | Add (P3) |
| Emoji picker | Super+Ctrl+E | Super+Ctrl+E | same | |
| Clipboard manager | Super+Ctrl+V | Super+Shift+V | different on purpose | Mac-style |
| Copy, paste, cut, select all | Super+C, V, X, A (Hyprland key injection, terminal aware) | Super+C, V, X, A (xremap, terminal aware) | same | BxRig adds 14 more Cmd keys |
| Screenshot | Print, Super+Ctrl+Alt+C | Super+Shift+3, 4 | different on purpose | Add (P3): also bind Print |
| Screen recording | Alt+Print (menu or stop) | Super+Shift+R; region Super+Alt+Shift+R | different on purpose | |
| Webcam overlay size | Super+Alt+code:34, 35 | none | Omarchy only | Add (P3) with webcam recording |
| Color picker | Super+Print | none | Omarchy only | Add (P1) with the menu entry |
| OCR | Super+Ctrl+Print | none (menu, or Super+Shift+5) | Omarchy only | Add (P3) |
| Share, transcode | Super+Ctrl+S, Super+Ctrl+Period | none | Omarchy only | Add (P3) |
| Reminders: set, show, clear | Super+Ctrl+R, Super+Ctrl+Alt+R, Super+Shift+Ctrl+R | none | Omarchy only | Add (P3) with Reminder |
| Time, battery, weather notices | Super+Ctrl+Alt+T, B, W | none | Omarchy only | N/A: the Noctalia bar shows them |
| Audio, Bluetooth, Network, Power, Display panels | Super+Ctrl+A, B, N, P, D | Super+S (Noctalia control center only) | Omarchy only | Add (P1): one key per panel; Super+S clashes with the Save remap when Mac keys are on |
| Bar panel by number | Super+Ctrl+1..9 | none | Omarchy only | Add (P3) |
| Calendar, world clock | Super+Ctrl+Alt+D, E | none | Omarchy only | Add (P3) |
| Activity monitor | Super+Shift+T (btop) | none | Omarchy only | Add (P3) |
| Agent picker | Super+Shift+Ctrl+A | Super+` (pull-down AI shell) | different on purpose | |
| Dictation toggle | Alt+Space | Super+Ctrl+X | different on purpose | Both drive Voxtype or the chosen backend |
| Dictation push to talk | hold Right Alt | none | Omarchy only | Add (P3) |
| Input language switch | Super+I, Super+Shift+I | none (Super+I is Italic with Mac keys) | Omarchy only | Add (P3) with Typing |
| Zoom in, reset | Super+Ctrl+Z, Super+Ctrl+Alt+Z | none | Omarchy only | Add (P3) |
| Lock | Super+Ctrl+L | Super+Ctrl+Q (starter file) | different on purpose | Mac-style |
| Toggle top bar | Super+Shift+Space | none | Omarchy only | Add (P2): bind `appearance bar toggle` |
| Background menu, theme menu | Super+Ctrl+Space or W; Super+Shift+Ctrl+Space or Super+Ctrl+T | none | Omarchy only | Add (P3) |
| Window transparency, gaps, square ratio | Super+Backspace, with Shift, with Ctrl | none | Omarchy only | Add (P3) |
| Full screen desktop | Super+Ctrl+Alt+F | none | Omarchy only | Add (P3) |
| Dismiss all notifications | Super+Shift+comma | none (menu: Clear notifications) | Omarchy only | Add (P2): bind `notify clear` |
| Act on, dismiss one, history, keyboard control of notifications | Super+comma, Alt+comma, Shift+Alt+comma, Ctrl+comma | none (Super+Comma is Noctalia settings or Preferences) | Omarchy only | N/A: no Noctalia equivalent was read; revisit with Noctalia's IPC |
| Silence notifications | Super+Ctrl+Alt+comma | Super+Alt+N | different on purpose | |
| Stay awake toggle | Super+Ctrl+I | none (menu entry exists) | Omarchy only | Add (P3) |
| Night light | none (menu only) | Super+Alt+Shift+N | ours only | |
| Laptop display toggle, mirror | Super+Ctrl+Delete, with Alt | none (menu entries exist) | Omarchy only | Add (P3) |
| Lid close and open (incl. Apple SMC lid) | `switch:on:Lid Switch` and the Apple name | Power > Closing the lid (logind setting) | different on purpose | Apple Silicon: BxRig targets x86 Arch |
| Close window | Super+W, Super+Q | Super+Q (starter file) | same | Super+W is Close tab in BxRig |
| Close all windows | Ctrl+Alt+Delete | none | Omarchy only | Add (P3) |
| Toggle split | Super+J | Super+J (starter file) | same | |
| Pseudo window | Super+P | none | Omarchy only | N/A: Super+P is Print with Mac keys, pseudo-tiling is rare |
| Float or tile | Super+T | Super+V (starter file) | different on purpose | Clashes with the Paste remap when Mac keys are on |
| Full screen | Super+F | Super+F (starter file) | same | Clashes with the Find remap when Mac keys are on |
| Tiled fullscreen, full width | Super+Ctrl+F, Super+Alt+F | none | Omarchy only | Add (P3) |
| Pop window out | Super+O | none | Omarchy only | Add (P3) |
| Save, restore window width | Super+Alt+Home, Super+Home | none | Omarchy only | Add (P3) |
| Cycle workspace layout | Super+L, Super+Alt+L | none (menu: Window layout) | Omarchy only | Add (P3) |
| Focus with arrows | Super+Arrows | Super+Arrows (starter file) | same | |
| Workspace 1 to 10: switch, move, move silently | Super+1..0, with Shift, with Shift+Alt | Super+1..0, with Shift | same | BxRig lacks the silent move (Add P3) |
| Scratchpad | Super+S, Super+Alt+S | none (Super+S is the Noctalia panel) | Omarchy only | Add (P3) |
| Quake console | Super+grave, Super+Shift+grave (`qconsole.lua`, not read) | Super+` (pull-down AI shell) | different on purpose | Same key, similar idea, different program |
| Minimize to the dock | Super+M | Super+M (and Super+Shift+M to restore) | same | Super+Shift+M is Music in Omarchy |
| Next, previous, former workspace | Super+Tab, with Shift, with Ctrl (per monitor) | none (swipe, Super+scroll); Super+Tab is the Cmd+Tab switcher | different on purpose | |
| Move workspace, move window to another monitor | Super+Shift+Alt+Arrows, Super+Shift+Ctrl+Arrows | none | Omarchy only | Add (P3) |
| Swap window with neighbour | Super+Shift+Arrows | Super+Shift+Arrows (`window.move`, starter file) | same | Dispatcher differs, behaviour not tested |
| Cycle windows | Alt+Tab, Alt+Shift+Tab | Alt+Tab (Noctalia switcher; Super+Tab remaps to it) | same | |
| Focus other monitor | Ctrl+Alt+Tab | none | Omarchy only | Add (P3) |
| Resize with keys (3 step sizes) | Super+Minus, Super+Equal; with Alt (small), Ctrl (large), Shift (other axis) | none (mouse drag only) | Omarchy only | Add (P2) |
| Scroll workspaces; move, resize with mouse | Super+scroll, Super+LMB, RMB | same (starter file) | same | |
| Window groups (13 binds) | Super+G and relatives | none | Omarchy only | Add (P3) |
| Monitor scaling up, down | Super+Slash, Super+Alt+Slash | none (menu: Display > Scale) | Omarchy only | Add (P3) |
| Volume, mute, mic mute | XF86Audio keys | XF86Audio keys (`wpctl`, starter file) | same | |
| Brightness; precise, max, min | XF86MonBrightness keys; with Alt, Shift | XF86MonBrightness keys only | Omarchy only | Add (P3) for precise, max, min |
| Keyboard backlight (also Ctrl+brightness on Macs) | XF86Kbd keys | none | Omarchy only | Add (P3) |
| Touchpad on, off, toggle | XF86Touchpad keys | none | Omarchy only | Add (P3) |
| Media: play, pause, next, previous, eject | XF86 keys through the shell | none (`playerctl` is in the catalog) | Omarchy only | Add (P2) |
| Switch audio output, media source | Shift+XF86AudioMute, Shift+XF86AudioPlay | none | Omarchy only | Add (P3) |
| Terminal | Super+Return | Super+Return (starter file) | same | |
| Tmux, Herdr in a terminal | Super+Alt+Return, Super+Ctrl+Return | none | Omarchy only | Add (P3) |
| Browser; private | Super+Shift+Return or B; Super+Shift+Alt+B | Super+B (starter file) | different on purpose | Super+B is Bold with Mac keys |
| File manager; in cwd | Super+Shift+F; Super+Alt+Shift+F | Super+E (starter file) | different on purpose | |
| Editor | Super+Shift+N | none | Omarchy only | Add (P3) |
| Calculator | Super+Shift+Q, XF86Calculator | none | Omarchy only | N/A: Super+Shift+Q is Log out in BxRig; XF86Calculator is trivial |
| Preinstalled apps and web apps (Music, Docker, Signal, Obsidian, Omawrite, Passwords, ChatGPT, Grok, Calendar, Email, New email, YouTube, WhatsApp, Messages, Photos, Maps, X, X Post; about 20 binds, switched off by `omarchy_preinstalled_bindings`) | Super+Shift+letter | none | Omarchy only | N/A: personal app choices; Add (P3) a way to bind your own commands (not checked whether `keys` supports it) |
| Log out to the login screen | none | Super+Shift+Q | ours only | |
| Force quit | none | Super+Alt+Escape | ours only | |
| Overview | none | Super+Ctrl+Up | ours only | |
| Cmd-style remaps beyond copy, paste, cut, select all (Z, S, F, T, N, O, P, R, W, L, B, I, U, Comma, Tab; 15) | none | xremap | ours only | Opt-in with `keys mac on` |
| Control Center pages (17 unbound rows) | none | unbound by default | ours only | Bind in the keys editor |
| Noctalia settings window | none | Super+Comma | ours only | Clashes with the Preferences remap |

### 3.2 Is each BxRig shortcut reachable from the runner menu

Every row of `bxrig keys show`, plus the extra binds in `bxrig.lua` and the starter file.

| BxRig shortcut | Action | In the menu | Where | Note |
|---|---|---|---|---|
| Super+Space | Launch apps | no | none (Apps opens `bxrig apps`, not the runner) | Add (P3): `runner launch` entry |
| Super+Alt+M | Control center | n/a | the menu itself | |
| Super+Alt+Space | All apps | yes | Apps | |
| Super+K | Shortcut cheat sheet | yes | Learn, Setup > Keyboard | |
| Super+Shift+3 | Screenshot screen | yes | Trigger > Capture > Screen | |
| Super+Shift+4 | Screenshot region | yes | Trigger > Capture > Region | |
| Super+Shift+5 | Screenshot menu | yes | Trigger > Capture > Screenshot menu | |
| Super+Shift+R | Recording toggle | yes | Trigger > Capture > Screen recording | |
| Super+Alt+Shift+R | Recording of a region | no | none | Add (P2): `record toggle --region` entry |
| Super+Shift+V | Clipboard history | yes | Trigger > Clipboard history | |
| Super+Ctrl+E | Emoji | yes | Trigger > Emoji | |
| Super+Ctrl+X | Dictation toggle | no | only the Dictation setup under Install | Add (P2): a toggle entry |
| Super+Alt+N | Do Not Disturb | yes | Trigger > Toggle | |
| Super+Alt+Shift+N | Night shift | yes | Trigger > Toggle > Night light | |
| Super+Alt+Escape | Force quit | yes | Trigger > Force quit an app | |
| Super+M | Minimize | yes | Trigger > Minimize window | |
| Super+Shift+M | Show minimized | yes | Trigger > Restore window | |
| Super+Ctrl+Up | Overview | yes | Trigger > Overview | |
| Super+` | AI shell | yes | Agent > Pull-down AI shell | |
| Super+Shift+Q | Log out | yes | System > Logout | |
| Super+Ctrl+Q | Lock (starter file) | yes | System > Lock | |
| 17 Control Center page rows | Open one TUI page | yes | Control Center, one entry each | |
| Cmd-style remaps (19 keys incl. Super+Tab) | Key remaps | no | Setup > Keyboard > Mac-style keys on, off only | Remaps are not actions; nothing to run |
| Super+S | Noctalia control center panel | no | none | Add (P2) with the panel entries |
| Super+Comma | Noctalia settings | no | none | Add (P2) |
| Alt+Tab | Noctalia window switcher | no | none | N/A: interactive switcher |
| Super+Q, Return, B, E, F, V, J, arrows, workspaces, mouse | Window and app basics (starter file) | no | none | N/A: window manager actions, not commands |
| XF86 volume and brightness keys | Hardware keys | partly | Setup > Display > Brightness (up, down, 50%, 100%) | No volume entry |

## 4. Summary and gaps

### Counts (rows of the tables above; a row can stand for several leaf entries)

| Status | Menu (sections 1 and 2) | Shortcuts (3.1) |
|---|---|---|
| same | 80 | 15 |
| different on purpose | 6 | 14 |
| ours only | 20 | 7 |
| Omarchy only | 60 | 45 |
| of which: Add (P1) | 4 | 4 |
| of which: Add (P2) | 10 | 4 |
| of which: Add (P3) | 25 | 33 |
| of which: N/A | 21 | 4 |

Size: Omarchy 4.5 has 10 top-level sections and 356 leaf entries; BxRig has 13 sections and 298 leaf entries. BxRig already matches Omarchy 4.5 on the section names (Appearance), the dock, floating and scrolling layouts, stay awake, QR code, emoji, clipboard history and the all-apps key.

Reading the numbers: Omarchy 4.5 moved Audio, Wi-Fi, Bluetooth and power out of the Setup menu into shell panels with their own keys, so the old "add Audio, Wifi, Bluetooth entries" gap is now a gap in panel keys (P2), not in the menu. What remains are a few real menu gaps (route jump, color picker, recording audio) and the menu mechanics BxRig does not have (user extension file, current-value ticks, hide-when-not-applicable). Many Omarchy-only rows are Omarchy branding, Plymouth, Quickshell plugins or app picks (21 menu and 4 key rows marked N/A).

### Prioritized gaps

P1, small to build, clear value:

1. `bxrig menu ROUTE` (open any section directly, as `omarchy menu summon`), then keys for System, Capture, Toggle and Hardware menus (Omarchy Super+Escape, Super+Ctrl+C, O, H, XF86PowerOff).
2. Trigger > Capture > Color picker (`hyprpicker`, optional in the catalog) and a key (Omarchy Super+Print).
3. Screen recording with desktop audio and with microphone (`Record.bx` has no audio option).
4. Keys for the Noctalia panels: audio, Bluetooth, network, power, display (Omarchy Super+Ctrl+A, B, N, P, D). The key is P1 here, the matching menu entries are P2. Super+S already opens the control center but clashes with the Save remap when Mac keys are on.

P2, useful:

5. Menu mechanics: a user menu extension file merged over the tree, and a tick on the current value (theme, font, browser, DNS, layout, bar position).
6. Update > Process and Hardware: restart Noctalia, audio (pipewire and wireplumber), Wi-Fi, Bluetooth, trackpad; Update > Firmware (fwupd).
7. Setup: open `hyprland.lua` in the editor, Input (natural scroll, repeat rate), Typing (keyboard layouts), Defaults > Editor.
8. System > Hibernate when resume is configured.
9. Keys: dismiss all notifications (`notify clear`), toggle top bar (`appearance bar toggle`), keyboard window resize (three step sizes), media transport (`playerctl` is in the catalog).
10. Menu entries for what only has a key today: record a region, dictation toggle, Noctalia settings.

P3, nice to have: reminders, transcode, share and receive, speed tests, recording with webcam, hybrid GPU, touchpad and touchscreen toggles, Wi-Fi QR, Git setup, default agent and dictation pickers, Vim, Emacs, Amp, Xbox controllers and Battle.net installs, Learn links (Bash, Tmux, Herdr), window groups, scratchpad, silent workspace move, move to monitor, zoom, keyboard backlight, Print key, hide-when-not-applicable rows, binding your own commands to keys.

### Findings outside the comparison

- With Mac keys on, the starter `hyprland.lua` binds Super+V (float), Super+F (fullscreen), Super+B (browser) and `bxrig.lua` binds Super+S and Super+Comma, while xremap sends Ctrl+V, Ctrl+F, Ctrl+B, Ctrl+S, Ctrl+Comma for the same keys. `bxrig keys conflicts` printed "No conflicts" on this machine; its docs say it compares against your own `hyprland.lua`, so whether it sees the starter file's binds was not verified.
- Some keys mean different things in the two systems and may confuse users who know both: Super+Shift+Q (Omarchy Calculator, BxRig Log out), Super+Shift+M (Omarchy Music, BxRig Show minimized), Super+Ctrl+N (Omarchy Network panel, BxRig none), Super+grave (Omarchy Quake console, BxRig AI shell).
- The menu has no volume entries; brightness has four.
