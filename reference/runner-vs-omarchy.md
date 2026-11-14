# BxRig runner menu vs Omarchy quick-run menu

One-to-one comparison of `bxrig menu` (the control center, shown on your runner's menu provider) with `omarchy-menu`, plus the keyboard shortcuts of both.

## Sources read

| Side | Source | Read |
|---|---|---|
| Omarchy menu | `bin/omarchy-menu` of basecamp/omarchy, branch `master` (892 lines, fetched with curl) | all of it |
| Omarchy keys | `default/hypr/bindings/tiling-v2.conf`, `utilities.conf`, `media.conf`, `clipboard.conf` (current); `config/hypr/bindings.conf` (app launch keys). `tiling.conf` and `default/hypr/bindings.conf` are marked deprecated and only used to confirm that | all of them |
| BxRig menu | `dist/bxrig menu items` (298 entries) and `--json`; `src/bxrig/Menu.bx`, `MenuTree.bx`; `docs/guides/menu.md`; COMMAND-CONTRACT 13.16 | all of it |
| BxRig keys | `bxrig keys show`; `src/bxrig/Shortcuts.bx` (table plus the Lua module it renders); `templates/hyprland.lua` bindings; COMMAND-CONTRACT 13.4; `docs/guides/shortcuts.md` | all of it |

Not read: the helper scripts Omarchy's menu calls (`omarchy-capture-screenshot`, `omarchy-menu-share`, `omarchy-transcode`, `omarchy-launch-audio` and so on). Where a verdict depends on what such a script does, the note says so. The GitHub API listing of the repository was refused in this session, so the file list of `default/hypr/bindings/` comes from the `source` lines in the deprecated `bindings.conf` plus the files that were fetched (`system.conf`, 14 bytes, is empty of bindings).

Status words: **same** (same job, same or close place), **ours only**, **Omarchy only**, **different on purpose**. Omarchy-only rows carry a verdict: `Add (P1/P2/P3)` means missing and worth adding, `N/A` means not applicable, with the reason. Rows are grouped: one row can stand for several leaf entries, the note says how many. Section numbers below match the menu names.

## 1. Top-level sections

| Omarchy | BxRig | Status | Note |
|---|---|---|---|
| Apps (opens Walker) | Apps (`bxrig apps`) | same | BxRig lists every `.desktop` app in the menu provider |
| Learn | Learn | same | BxRig adds BoxLang, Noctalia, CachyOS links |
| Trigger | Trigger | same | Contents differ a lot, see 2.3 |
| Style | Appearance | different on purpose | Renamed; 56 leaf entries vs 7; absorbs the toggles for bar, gaps, ratio, layout |
| Setup | Setup | same | BxRig 94 leaf entries |
| Install | Install | same | Omarchy hard-codes apps; BxRig reads the 289-app catalog |
| Remove | Remove | same | |
| Update | Update | same | |
| About | About | same | Both are a single leaf that shows machine status |
| System | System | same | |
| (none) | Develop | ours only | BoxLang, databases, mail catcher, VMs, containers, editor (31 leaves) |
| (none) | Agent | ours only | AI agents, pull-down shell, local models (9 leaves) |
| (none) | Control Center | ours only | Opens the TUI, one entry per page (18 leaves) |
| (none) | Search (first entry of the interactive menu, not in `menu items`) | ours only | Flat filter over every entry; also `bxrig menu search TEXT` |
| `omarchy-menu NAME` jumps straight to a submenu (toggle, hardware, share, reminder, background, capture, theme, screenrecord, power, system, update, install, remove, style, setup, learn, trigger) | `bxrig menu` takes only `items` and `search` | Omarchy only | Add (P1): `bxrig menu SECTION` so shortcuts can open one section |
| User extension hook `~/.config/omarchy/extensions/menu.sh` | none | Omarchy only | Add (P3): custom entries file for the menu |
| Menu toggles closed when pressed again (`toggle_existing_menu`) | Esc cancels only | Omarchy only | N/A: depends on Walker; BxRig supports five providers |

Order differs: Omarchy goes Apps, Learn, Trigger, Style, Setup, Install, Remove, Update, About, System. BxRig goes Apps, Install, Remove, Appearance, Trigger, Setup, Update, Develop, Agent, Learn, About, System, Control Center.

## 2. Sections, entry by entry

### 2.1 Apps

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Launch an app | `walker -p "Launch..."` | `bxrig apps` | same | Also on Super+Space via `runner launch` |

### 2.2 Learn

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Keybindings | Keybindings (`omarchy-menu-keybindings`) | Shortcut cheat sheet (`keys sheet`) | same | |
| Product manual | Omarchy manual (learn.omacom.io) | BxRig docs (bxcachy.boxlang.io) | different on purpose | Own docs |
| Hyprland | Hyprland wiki | Hyprland wiki | same | |
| Arch | Arch wiki | Arch wiki | same | |
| Neovim | LazyVim keymaps | LazyVim keymaps | same | |
| Bash | devhints.io/bash | none | Omarchy only | Add (P3): a shell cheat sheet link (zsh is the BxRig default) |
| BoxLang, Noctalia, CachyOS | none | BoxLang docs and links, Noctalia docs, CachyOS wiki (3) | ours only | |

### 2.3 Trigger (Omarchy: Trigger; BxRig: Trigger)

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Reminder: set, show all, clear all (3) | `omarchy-reminder` | none | Omarchy only | Add (P3): small `bxrig remind` (notification after N minutes) |
| Screenshot | `omarchy-capture-screenshot` | Screenshot menu, Screen, Region, Window (4) | same | BxRig is finer grained |
| Screen recording start or stop | Screenrecord submenu | Screen recording: start or stop (`record toggle`) | same | |
| Recording with desktop audio | `--with-desktop-audio` | none (`Record.bx` has no audio option) | Omarchy only | Add (P1) |
| Recording with desktop + microphone audio | `--with-microphone-audio` | none | Omarchy only | Add (P1) |
| Recording with webcam overlay | `--with-webcam`, device picker | none | Omarchy only | Add (P3) |
| Recording of a region | none in the menu | `record toggle --region` (shortcut only) | ours only | Not in the menu, only on Super+Alt+Shift+R |
| Text extraction (OCR) | `omarchy-capture-text-extraction` | Text (OCR) | same | |
| Color picker | `hyprpicker -a` | none (`hyprpicker` is in the catalog, optional) | Omarchy only | Add (P1) |
| QR code | none | QR code | ours only | |
| Transcode | `omarchy-transcode` (not read) | none | Omarchy only | Add (P3): ffmpeg is in the catalog |
| Share: clipboard, file, folder (3) | `omarchy-menu-share` (not read) | none | Omarchy only | Add (P3): LocalSend is a default catalog app, wire it in |
| Toggle: Screensaver | `omarchy-toggle-screensaver` | none | Omarchy only | N/A: Omarchy's own screensaver; BxRig has none |
| Toggle: Nightlight | `omarchy-toggle-nightlight` | Night light | same | |
| Toggle: Idle Lock | `omarchy-toggle-idle` | none | Omarchy only | Add (P1): idle lock off while presenting or watching |
| Toggle: Notifications | silence on or off | Do Not Disturb, Snooze 30 minutes, Snooze 2 hours, Turn snooze off, Clear notifications (5) | same | BxRig is richer |
| Toggle: Top Bar | `omarchy-toggle-waybar` | Appearance > Bar > Show, Hide, Toggle | same | Different section |
| Toggle: Workspace Layout | layout toggle | Window layout: tile or float; Appearance > Layout (dwindle, scrolling, floating) | different on purpose | BxRig also offers scrolling and floating |
| Toggle: Window Gaps | gaps toggle | Appearance > Windows > Gaps | same | Different section |
| Toggle: 1-Window Ratio | square aspect toggle | Appearance > Windows > Single window aspect ratio | same | Different section |
| Toggle: Monitor Scaling | cycles scale | Setup > Display > Scale (pick monitor) | different on purpose | BxRig sets an explicit value |
| Toggle: Direct Boot | `omarchy-config-direct-boot` | none | Omarchy only | N/A: Omarchy's boot setup (script not read), not part of CachyOS installs |
| Toggle: Passwordless Sudo | `omarchy-sudo-passwordless` | Setup > Security > Passwordless sudo on, off | same | Different section |
| Hardware: Laptop Display | toggle | Setup > Display > Laptop panel on, off | same | |
| Hardware: Mirror Display | toggle | Setup > Display > Mirror the laptop panel on, off | same | |
| Hardware: Hybrid GPU | `omarchy-toggle-hybrid-gpu`, shown only on hybrid machines | Setup > Hardware > GPU check (read only) | Omarchy only | Add (P3): only the check exists, no switch |
| Hardware: Touchpad | toggle, shown when a touchpad exists | Setup > Hardware > Input devices and gestures (read only) | Omarchy only | Add (P3) |
| Hardware: Touchscreen | toggle | none | Omarchy only | Add (P3) |
| Hardware: Touchpad Haptics | Dell XPS tool | none | Omarchy only | N/A: Dell XPS only |
| Emoji | key only (Super+Ctrl+E) | Emoji | ours only | In BxRig's menu as well as on the key |
| Clipboard history | key only (Super+Ctrl+V) | Clipboard history | ours only | |
| Force quit, Minimize window, Restore window, Overview (4) | none | same names | ours only | Mac-like helpers |

### 2.4 Style (Omarchy) vs Appearance (BxRig)

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Theme | Walker theme menu | Theme (pick) | same | |
| Next, random theme; mode (follow, dark, light, auto); theme status (7) | none | present | ours only | |
| Unlock | Walker menu `omarchyunlocks` | none | Omarchy only | N/A: a Walker menu that is specific to Omarchy's lock screen |
| Font | pick from installed | Font (pick) | same | |
| Background | Walker background menu | Background > Pick, Next, Random | same | |
| Hyprland (edit `looknfeel.conf`) | opens editor | none | Omarchy only | Add (P2): see Setup > Config in 2.5 |
| Screensaver text or image | branding | none | Omarchy only | N/A: no BxRig screensaver |
| About text or image | `omarchy-branding-about` | none | Omarchy only | N/A: Omarchy branding |
| Bar: show, hide, position, style, clock, battery (17 leaves) | none | present | ours only | Noctalia bar |
| Dock: show, hide, toggle, mode, position (9 leaves) | none | present | ours only | |
| Windows: corners, opacity (the other 6 of the 12 Windows leaves are gaps, ratio, layout, counted above) | none | present | ours only | |
| Animations on, off | none | present | ours only | |
| Appearance status, re-apply, install theme from git | none here (Omarchy installs a theme from Install > Style) | present | ours only | |

### 2.5 Setup

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Audio | `omarchy-launch-audio` (not read) | none | Omarchy only | Add (P1): open the Noctalia control center (`panel-toggle control-center` is already used in `bxrig.lua`) or a mixer (`wiremix` is in the catalog) |
| Wifi | `omarchy-launch-wifi` | none | Omarchy only | Add (P1) |
| Bluetooth | `omarchy-launch-bluetooth` | none | Omarchy only | Add (P1) |
| Power Profile | pick from `powerprofilesctl` | Power > Profile: Performance, Balanced, Power saver | same | |
| Power: status, lid action, laptop tools, doctor (6 of the 9 Power leaves) | none | present | ours only | |
| System Sleep: enable or disable suspend, hibernate | toggles | Power > Closing the lid (suspend, lock, nothing) | different on purpose | BxRig sets the lid action, not the sleep modes |
| Monitors | opens `monitors.conf` | Display: list, scale, laptop panel, mirror, brightness, apply, forget (12 leaves) | different on purpose | BxRig has real controls, no file to edit |
| Keybindings | opens `bindings.conf` | Keyboard > Shortcuts, cheat sheet, conflicts; Control Center > Shortcuts | different on purpose | BxRig has a table and an editor |
| Input (opens `input.conf`) | opens the file | Hardware > Input devices and gestures (read only) | Omarchy only | Add (P2): natural scroll, repeat rate, layout |
| Defaults: Browser | pick | Defaults > Browser | same | |
| Defaults: Terminal | pick | Defaults > Terminal | same | |
| Defaults: Editor | pick (Neovim, VSCode, Cursor, Zed, Sublime, Helix, Vim, Emacs) | none (`default` takes browser, terminal, filemanager) | Omarchy only | Add (P2) |
| Defaults: File manager | none | Defaults > File manager | ours only | |
| DNS | `omarchy-setup-dns` | DNS: show, Cloudflare, Google, Quad9, custom, DHCP (6) | same | |
| Security: Fingerprint | setup | Security > Fingerprint for sudo (turn on, enroll, off) | same | |
| Security: Fido2 | setup | Security > Security key for sudo (register, on, off) | same | |
| Security: status, SSH key, secrets, keyring, SSH server (10 of the 14 Security leaves) | none | present | ours only | |
| Config: Hyprland | opens `hyprland.conf` | none (Update > Refresh a config > Hyprland resets it) | Omarchy only | Add (P2): open `hyprland.lua` in the editor |
| Config: Hypridle, Hyprlock, Hyprsunset | open the file, restart service | none | Omarchy only | Add (P3): only if BxRig ships those configs |
| Config: Swayosd, Walker, Waybar | open the file | none | Omarchy only | N/A: BxRig uses Noctalia for bar, OSD and notifications; Walker is one optional provider |
| Config: XCompose | open `~/.XCompose` | none | Omarchy only | N/A: Omarchy's text expansion feature |
| Time, Kernel, Cloud storage, Backup, NAS (36 leaves) | none | present | ours only | |
| Hardware: AirPlay receiver, GPU check | none | present | ours only | |
| Setup status, dotfiles status, launcher check, export settings (4) | none | present | ours only | |

### 2.6 Install

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Package | `omarchy-pkg-install` | Package (repos and AUR) | same | |
| AUR | `omarchy-pkg-aur-install` | AUR package | same | |
| Web App | create | Web app > Create web app | same | BxRig adds install-all for Google, Microsoft, Apple, BoxLang |
| TUI | `omarchy-tui-install` (script not read) | none | Omarchy only | N/A: script not read, BxRig has no equivalent concept; `Package` covers installs |
| Service: Dropbox, Tailscale, NordVPN, Bitwarden | install | Catalog (infra, network, everyday) | same | Catalog ids: `dropbox`, `tailscale`, `nordvpn`, `bitwarden` |
| Service: ONCE, Chromium Account | install | none | Omarchy only | N/A: Omarchy and Basecamp specific |
| Style: Theme | `omarchy-theme-install` | Appearance > Install a theme from git | same | Different section |
| Style: Background | `omarchy-theme-bg-install` | none (Pick covers installed backgrounds) | Omarchy only | Add (P3): add a wallpaper from a file or URL |
| Style: Font (Cascadia, Meslo, Fira, Victor, Bitstream, Iosevka) | 6 fixed fonts | Font > Install a font (choose from fonts-uninstalled) | same | |
| Development: Rails, Ruby | `install-dev-env ruby` | none (use Package) | Omarchy only | N/A: BxRig is Java and BoxLang first; `mise` is in the catalog for the rest |
| Development: JavaScript (Node, Bun, Deno) | 3 | Node.js (nvm); Bun and Deno from the catalog | same | |
| Development: Go, PHP, Python, Java | 4 | catalog (`go`, `php`, `uv`, `python-pip`, `jdk21`, `maven`, `gradle`) | same | |
| Development: Laravel, Symfony, Phoenix | 3 | none | Omarchy only | N/A: framework starters outside the BoxLang focus |
| Development: Elixir, Zig, Rust, .NET, OCaml, Clojure, Scala | 7 | none (use Package) | Omarchy only | N/A: outside the BoxLang focus |
| Development: Docker DB | `omarchy-install-docker-dbs` | Develop > Databases (`db menu`) | same | BxRig uses Podman and has more engines |
| Editor: Cursor, Zed, Sublime Text, Helix, VSCode | 5 | catalog (`cursor`, `zed`, `sublime-text`, `helix`, `vscode`) | same | |
| Editor: Vim, Emacs | 2 | none (`neovim` is there) | Omarchy only | Add (P3): `vim` and `emacs` are plain pacman packages |
| Terminal: Alacritty, Foot, Ghostty, Kitty | 4 | catalog (same four plus Konsole, Tabby) | same | |
| Browser: Chrome, Edge, Brave, Firefox, Zen | 5 | catalog (`google-chrome`, `edge`, `brave`, `firefox`, `zen`) | same | |
| Browser: Brave Origin | install | none | Omarchy only | N/A: Omarchy-specific package |
| AI: Dictation | `omarchy-voxtype-install` | Dictation (`dictation setup`) | same | |
| AI: LM Studio, Ollama | 2 | catalog (`lm-studio`, `ollama`, plus cuda and rocm builds) | same | |
| AI: Crush | install | none | Omarchy only | Add (P3): `crush-bin` AUR package |
| Gaming: Steam, RetroArch, Minecraft, GeForce Now, Xbox Cloud, Moonlight, Lutris, Heroic (8) | 8 | catalog (all eight ids exist) | same | |
| Gaming: Xbox Controller | driver install | none | Omarchy only | Add (P3) |
| Windows | `omarchy-windows-vm install` | Virtual machine > Windows | same | |
| Catalog by group (11), Virtual machine (Linux desktops, tags, check), Neovim with LazyVim, Agent skills (3 of the 31 leaves) | none | present | ours only | |

### 2.7 Remove

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Package | `omarchy-pkg-remove` | Package | same | |
| Web App | remove | Web app | same | |
| Theme | remove | Theme | same | |
| Windows | `windows-vm remove` | Virtual machine | same | |
| Dictation, Browser (6), Gaming (9), Development (13 groups) | dedicated removers | App from the catalog (pick from installed) | different on purpose | One generic remover instead of per-app scripts |
| TUI | remove | none | Omarchy only | N/A: see Install |
| Preinstalls | `omarchy-remove-preinstalls` | none | Omarchy only | N/A: Omarchy's preinstalled app set |
| Security: Fingerprint, Fido2 | remove | Setup > Security > Turn off | same | Different section |
| Agent skill | none | Agent skill | ours only | |

### 2.8 Update

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| Update the distro | Omarchy | System update (snapshot first) | same | |
| Update the tool itself | none separate | Check for a BxRig update, Install the BxRig update | ours only | |
| Omarchy to Quattro | upgrade | none | Omarchy only | N/A: Omarchy release migration |
| Channel | Stable, RC, Edge, Dev | Stable, Beta | same | |
| Config: refresh to default | Hyprland, Hypridle, Hyprlock, Hyprsunset, Plymouth, Swayosd, Tmux, Walker, Waybar (9) | Hyprland, Noctalia, Terminals, Shell and prompt, Neovim layer, Theme, Everything (7) | same | Targets follow each stack |
| Extra themes | `omarchy-theme-update` | none | Omarchy only | Add (P3): update themes installed from git |
| Process: restart Hypridle, Hyprsunset, Mako, Swayosd, Walker, Waybar | 6 | none | Omarchy only | Add (P1): restart Noctalia (and the other BxRig-managed processes) |
| Hardware: restart Audio, Wi-Fi, Bluetooth, Trackpad | 4 | none | Omarchy only | Add (P1): pipewire and wireplumber, NetworkManager, bluetooth service |
| Firmware | `omarchy-update-firmware` | none | Omarchy only | Add (P2): fwupd |
| Password: drive encryption, user | 2 | none | Omarchy only | Add (P3): `passwd`; drive password only if LUKS |
| Timezone, Time | tz select, update time | Setup > Time (6 leaves) | same | Different section |
| Notifications on, off; re-apply appearance and display; agent skills update (5) | none | present | ours only | |

### 2.9 About and System

| Entry | Omarchy | BxRig | Status | Note |
|---|---|---|---|---|
| About | `omarchy-launch-about` | About (`bxrig status`) | same | |
| Lock | `omarchy-system-lock` | Lock | same | |
| Suspend | `systemctl suspend`, hidden when disabled | Suspend | same | |
| Hibernate | shown when available | none | Omarchy only | Add (P2): show only when resume is configured |
| Logout | yes | Logout (`--yes`) | same | |
| Restart | yes | Reboot (`--yes`) | same | |
| Shutdown | yes | Shutdown (`--yes`) | same | |
| Screensaver (force) | `omarchy-launch-screensaver force` | none | Omarchy only | N/A: no screensaver in BxRig |

### 2.10 BxRig-only sections

| Section | Leaves | Status | Note |
|---|---|---|---|
| Develop: BoxLang (6), databases, mail catcher (10), virtual machines (8), containers (3), editor (3) | 31 | ours only | The BoxLang developer side |
| Agent: default agent, any agent, pull-down shell, sessions, models, API keys, skills status | 9 | ours only | |
| Control Center: whole TUI plus 17 single pages | 18 | ours only | |

## 3. Keyboard shortcuts

Omarchy: Hyprland `bindd` lines from `tiling-v2.conf`, `utilities.conf`, `media.conf`, `clipboard.conf`, and `config/hypr/bindings.conf`. BxRig: `bxrig keys show` (38 rows with keys, 17 more unbound rows, one per Control Center page), plus the binds in `bxrig.lua` that are outside the table (Super+Space, Super+S, Super+Comma, Alt+Tab) and the starter `hyprland.lua`.

### 3.1 Side by side

| Action | Omarchy keys | BxRig keys | Status | Note |
|---|---|---|---|---|
| Launch apps | Super+Space | Super+Space | same | `runner launch` |
| Main menu | Super+Alt+Space (also Super+Shift+code:201) | Super+Alt+M | different on purpose | BxRig gives Super+Alt+Space to the all-apps window |
| All apps window | none (Super+Space is Walker) | Super+Alt+Space | ours only | |
| System menu | Super+Escape, XF86PowerOff | none | Omarchy only | Add (P1): needs `menu SECTION` first |
| Toggle menu | Super+Ctrl+O | none | Omarchy only | Add (P2) |
| Hardware menu | Super+Ctrl+H | none | Omarchy only | Add (P2) |
| Capture menu | Super+Ctrl+C | Super+Shift+5 (screenshot menu) | different on purpose | Mac-style |
| Show key bindings | Super+K | Super+K | same | |
| Calculator key | XF86Calculator | none | Omarchy only | N/A: needs a calculator app; trivial |
| Emoji picker | Super+Ctrl+E | Super+Ctrl+E | same | |
| Clipboard manager | Super+Ctrl+V | Super+Shift+V | different on purpose | Mac-style |
| Universal copy, paste, cut | Super+C, V, X (Hyprland `sendshortcut`) | Super+C, V, X (xremap, terminal-aware) | different on purpose | BxRig also sends Ctrl+Shift in terminals |
| Screenshot | Print | Super+Shift+3, 4 | different on purpose | Add (P3): also bind the Print key |
| Screen recording | Alt+Print (menu) | Super+Shift+R; region Super+Alt+Shift+R | different on purpose | |
| Color picker | Super+Print | none | Omarchy only | Add (P1) with the menu entry |
| OCR from screen | Super+Ctrl+Print | none (menu entry, or Super+Shift+5) | Omarchy only | Add (P3) |
| Share | Super+Ctrl+S | none | Omarchy only | Add (P3) with Share |
| Transcode | Super+Ctrl+Period | none | Omarchy only | Add (P3) with Transcode |
| Reminders: set, show, clear | Super+Ctrl+R, Super+Ctrl+Alt+R, Super+Shift+Ctrl+R | none | Omarchy only | Add (P3) with Reminder |
| Time, battery, weather notices | Super+Ctrl+Alt+T, B, W | none | Omarchy only | N/A: Omarchy comment says these are for a bar-less setup; the Noctalia bar shows them |
| Audio, Bluetooth, Wifi controls | Super+Ctrl+A, B, W | Super+S opens the Noctalia control center | Omarchy only | Add (P1): one key per panel; Super+S clashes with the Save remap when Mac keys are on |
| Activity monitor | Super+Ctrl+T (btop) | none (Control Center pages are unbound) | Omarchy only | Add (P3) |
| Dictation toggle | Super+Ctrl+X | Super+Ctrl+X | same | Both use `voxtype record toggle` |
| Dictation push to talk | F9 (start on press, stop on release) | none | Omarchy only | Add (P3) |
| Zoom in, reset | Super+Ctrl+Z, Super+Ctrl+Alt+Z | none | Omarchy only | Add (P3): cursor zoom, an accessibility help |
| Lock | Super+Ctrl+L | Super+Ctrl+Q (starter file, `hyprlock`; not in the table) | different on purpose | Mac-style |
| Toggle top bar | Super+Shift+Space | none | Omarchy only | Add (P2): bind `appearance bar toggle` |
| Background menu, theme menu | Super+Ctrl+Space, Super+Shift+Ctrl+Space | none | Omarchy only | Add (P3) |
| Window transparency toggle | Super+Backspace | none | Omarchy only | Add (P3) |
| Window gaps toggle | Super+Shift+Backspace | none | Omarchy only | Add (P3) |
| Single-window square toggle | Super+Ctrl+Backspace | none | Omarchy only | Add (P3) |
| Dismiss last, all notifications | Super+Comma, Super+Shift+Comma | none (Super+Comma is Preferences or Noctalia settings) | Omarchy only | Add (P2): `notify clear` exists, bind it |
| Toggle silencing notifications | Super+Ctrl+Comma | Super+Alt+N (Do Not Disturb) | different on purpose | |
| Invoke, restore last notification | Super+Alt+Comma, Super+Shift+Alt+Comma | none | Omarchy only | N/A: `makoctl`; BxRig uses Noctalia and no Noctalia equivalent was read |
| Idle lock toggle | Super+Ctrl+I | none | Omarchy only | Add (P1) with the menu entry |
| Night light | Super+Ctrl+N | Super+Alt+Shift+N | different on purpose | |
| Laptop display toggle, mirror | Super+Ctrl+Delete, Super+Ctrl+Alt+Delete | none (menu entries exist) | Omarchy only | Add (P3) |
| Lid switch handling | `bindl switch:on:Lid Switch` | Power > Closing the lid (logind setting) | different on purpose | |
| Close window | Super+W | Super+Q (starter file) | different on purpose | Super+W is Close tab in BxRig |
| Close all windows | Ctrl+Alt+Delete | none | Omarchy only | Add (P3) |
| Toggle split | Super+J | Super+J (starter file) | same | |
| Pseudo window | Super+P | none | Omarchy only | N/A: Super+P is Print in BxRig and pseudo-tiling is rarely used |
| Float or tile | Super+T | Super+V (starter file) | different on purpose | Clashes with the Paste remap when Mac keys are on |
| Full screen | Super+F | Super+F (starter file) | same | Clashes with the Find remap when Mac keys are on |
| Tiled fullscreen, full width | Super+Ctrl+F, Super+Alt+F | none | Omarchy only | Add (P3) |
| Pop window out (float and pin) | Super+O | none | Omarchy only | Add (P3) |
| Toggle workspace layout | Super+L | none (menu entry only) | Omarchy only | Add (P3): Super+L is Address bar in BxRig |
| Focus with arrows | Super+Arrows | Super+Arrows (starter file) | same | |
| Switch to workspace 1 to 10 | Super+1..0 | Super+1..0 (starter file) | same | |
| Move window to workspace 1 to 10 | Super+Shift+1..0 | Super+Shift+1..0 (starter file) | same | |
| Move window silently to workspace | Super+Shift+Alt+1..0 | none | Omarchy only | Add (P3) |
| Scratchpad: toggle, send | Super+S, Super+Alt+S | none (the AI shell has its own special workspace on Super+`) | Omarchy only | Add (P3) |
| Next, previous, former workspace | Super+Tab, Super+Shift+Tab, Super+Ctrl+Tab | none (three-finger swipe and Super+scroll) | different on purpose | Super+Tab is the Cmd+Tab window switcher |
| Move workspace to other monitor | Super+Shift+Alt+Arrows | none | Omarchy only | Add (P3) |
| Swap window with neighbour | Super+Shift+Arrows (`swapwindow`) | Super+Shift+Arrows (`window.move`, starter file) | same | Dispatcher differs, behaviour not tested |
| Cycle windows | Alt+Tab, Alt+Shift+Tab | Alt+Tab (Noctalia switcher; Super+Tab remaps to it) | same | |
| Focus next, previous monitor | Ctrl+Alt+Tab, Ctrl+Alt+Shift+Tab | none | Omarchy only | Add (P3) |
| Resize with keys | Super+Minus, Super+Equal (+Shift) | none (mouse drag only) | Omarchy only | Add (P2) |
| Scroll workspaces | Super+scroll | Super+scroll (starter file) | same | |
| Move, resize with mouse | Super+LMB, Super+RMB | Super+LMB, Super+RMB (starter file) | same | |
| Window groups (toggle, join, navigate, by number; 13 binds) | Super+G, Super+Alt+... | none | Omarchy only | Add (P3) |
| Cycle monitor scaling | Super+Slash, Super+Alt+Slash | none (menu: Display > Scale) | Omarchy only | Add (P3) |
| Volume, mute, mic mute | XF86Audio keys (SwayOSD) | XF86Audio keys (`wpctl`, starter file) | same | |
| Brightness | XF86MonBrightness keys | XF86MonBrightness keys (`brightnessctl`, starter file) | same | |
| Precise 1%, max, min brightness and volume | Alt or Shift plus the keys | none | Omarchy only | Add (P3) |
| Keyboard backlight | XF86KbdBrightness, XF86KbdLightOnOff | none | Omarchy only | Add (P3) |
| Touchpad toggle | XF86Touchpad keys | none | Omarchy only | Add (P3) |
| Media transport | XF86AudioPlay, Pause, Next, Prev (`playerctl`) | none (`playerctl` is in the catalog) | Omarchy only | Add (P2) |
| Switch audio output | Super+XF86AudioMute | none | Omarchy only | Add (P3) |
| Terminal | Super+Return | Super+Return (starter file) | same | |
| Terminal with tmux | Super+Alt+Return | none | Omarchy only | Add (P3) |
| Browser | Super+Shift+Return, Super+Shift+B (private: +Alt) | Super+B (starter file) | different on purpose | Super+B is Bold when Mac keys are on |
| File manager | Super+Shift+F (cwd: +Alt) | Super+E (starter file) | different on purpose | |
| Editor | Super+Shift+N | none | Omarchy only | Add (P3) |
| Music, Docker TUI, Signal, Obsidian, Typora, passwords, ChatGPT, Grok, calendar, email, YouTube, WhatsApp, Messages, Photos, X (Super+Shift+letter, about 17 binds) | present | none; the keys editor binds only existing table rows | Omarchy only | N/A: personal app choices; Add (P3) a way to bind your own commands (not checked whether `keys` supports it) |
| Log out to the login screen | none | Super+Shift+Q | ours only | |
| Pull-down AI shell | none | Super+` | ours only | |
| Force quit | none | Super+Alt+Escape | ours only | |
| Minimize, show minimized | none | Super+M, Super+Shift+M | ours only | |
| Overview | none | Super+Ctrl+Up | ours only | |
| Mac-style Cmd keys (C, V, Z, X, A, S, F, T, N, O, P, R, W, L, B, I, U, Comma, Tab; 19 remaps) | none | xremap | ours only | Opt-in with `keys mac on` |
| Control Center pages (17 unbound rows) | none | unbound by default | ours only | Bind in the keys editor |
| Noctalia settings window | none | Super+Comma | ours only | Clashes with Preferences remap |

### 3.2 Is each BxRig shortcut reachable from the runner menu

Every row of `bxrig keys show`, plus the extra binds in `bxrig.lua` and the starter file.

| BxRig shortcut | Action | In the menu | Where | Note |
|---|---|---|---|---|
| Super+Space | Launch apps | no | none (Apps opens `bxrig apps`, not the runner) | Different command; Add (P3): `runner launch` entry |
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
| Super+Ctrl+X | Dictation toggle | no | only `Dictation` setup under Install | Add (P2): a toggle entry |
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
| Super+S | Noctalia control center panel | no | none | Add (P1) with the Audio, Wifi, Bluetooth entries |
| Super+Comma | Noctalia settings | no | none | Add (P2) |
| Alt+Tab | Noctalia window switcher | no | none | N/A: interactive switcher |
| Super+Q, Return, B, E, F, V, J, arrows, workspaces, mouse | Window and app basics (starter file) | no | none | N/A: window manager actions, not commands |
| XF86 volume and brightness keys | Hardware keys | partly | Setup > Display > Brightness (up, down, 50%, 100%) | No volume entry |

## 4. Summary and gaps

### Counts (rows of the tables above; a row can stand for several leaf entries)

| Status | Menu (sections 1 and 2) | Shortcuts (3.1) |
|---|---|---|
| same | 65 | 16 |
| different on purpose | 8 | 15 |
| ours only | 29 | 9 |
| Omarchy only | 51 | 43 |
| of which: Add (P1) | 10 | 4 |
| of which: Add (P2) | 6 | 6 |
| of which: Add (P3) | 16 | 29 |
| of which: N/A | 19 | 4 |

Size: Omarchy's menu has 10 top-level sections; BxRig's `menu items` has 13 sections and 298 leaf entries (plus the interactive Search entry). Omarchy leaves were counted as rows, not one by one, because most of its leaves are generated lists (fonts, languages, games).

Reading the numbers: most of what BxRig lacks is either Omarchy branding and Omarchy-only features (19 menu rows and 4 key rows marked N/A) or low-value extras (P3). The real gaps are few and cluster around daily-use controls: audio, network and Bluetooth panels, idle lock, color picker, recording audio, and restart helpers.

### Prioritized gaps

P1, daily use, small to build:

1. Setup: Audio, Wifi, Bluetooth entries, plus keys for each (Omarchy Super+Ctrl+A, B, W). Open the Noctalia control center (already used by `bxrig.lua`) or a mixer. Note: Super+S for the panel clashes with the Save remap when Mac keys are on.
2. `bxrig menu SECTION` (jump straight to a submenu, as `omarchy-menu NAME`), then bind System, Toggle and Hardware menus (Omarchy Super+Escape, Super+Ctrl+O, Super+Ctrl+H, XF86PowerOff).
3. Trigger > Capture > Color picker (`hyprpicker`, optional in the catalog) and a key (Omarchy Super+Print).
4. Trigger > Toggle > Idle lock, with a key (Omarchy Super+Ctrl+I).
5. Screen recording with desktop audio and with microphone (`Record.bx` has no audio option).
6. Update > Process and Hardware: restart Noctalia, pipewire and wireplumber, Wi-Fi, Bluetooth.

P2, useful:

7. Setup > Config: open `hyprland.lua` (and the Hyprlock, Hypridle files if BxRig ships them) in the editor; Setup > Defaults > Editor; Setup > Input (natural scroll, repeat rate, layout).
8. Update > Firmware (fwupd) and System > Hibernate when resume is configured.
9. Keys for dismiss notifications (`notify clear`), toggle top bar (`appearance bar toggle`), keyboard window resize, and media transport (`playerctl` is in the catalog).
10. Menu entries for what only has a key today: record a region, dictation toggle, `runner launch`, Noctalia settings.

P3, nice to have: reminders, transcode, share, recording with webcam, hybrid GPU, touchpad and touchscreen toggles, window groups, scratchpad, silent move to workspace, zoom, workspace to monitor, keyboard backlight, Print key, Vim, Emacs, Crush and Xbox controller installs, Bash cheat sheet link, a user extension file for the menu, binding your own commands to keys.

### Findings outside the comparison

- With Mac keys on, the starter `hyprland.lua` binds Super+V (float), Super+F (fullscreen), Super+B (browser) and `bxrig.lua` binds Super+S and Super+Comma, while xremap sends Ctrl+V, Ctrl+F, Ctrl+B, Ctrl+S, Ctrl+Comma for the same keys. `bxrig keys conflicts` printed "No conflicts" on this machine; its docs say it compares against your own `hyprland.lua`, so whether it sees the starter file's binds was not verified.
- The menu has no volume entries; brightness has four.
