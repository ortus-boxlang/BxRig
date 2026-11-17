# BxRig Noctalia plugins

Noctalia v5 plugins (author id `bxrig`). Each folder is one plugin.

| Folder | Plugin id | Entries | Data source |
|---|---|---|---|
| `clock/` | `bxrig/clock` | bar widget `bar` (the time as text), panel `panel` | text: `noctalia.formatTime` with the `format` setting; panel: `bxrig time world --json`, every 30 s while open |
| `agents/` | `bxrig/agents` | bar widget `bar`, panel `panel` | `bxrig ai panel --json`, every 60 s while open; launch runs `bxrig ai launch <id>` |
| `quick/` | `bxrig/quick` | bar widget `bar`, panel `panel` (switches and pickers), panel `themes` (theme switcher) | the `status` of each setting on open; each control runs its bxrig command with `--yes`; themes: `bxrig theme list --json` on open, Enter runs `bxrig theme set <name> --yes` |

The plugins use `plugin_api = 43`. They only draw with palette roles, so they follow the active Noctalia theme. Every file in a folder ships together. `bxrig.luau` is the same helper in every plugin: it runs bxrig and unwraps the `{"ok":…,"data":…}` envelope.

## Install

Noctalia finds hand-placed plugins in `~/.local/share/noctalia/plugins/<folder>/` (the built-in `local` source). Being installed does not make a plugin active: each one must also be enabled.

```sh
mkdir -p ~/.local/share/noctalia/plugins
for p in clock agents quick; do
  rm -rf ~/.local/share/noctalia/plugins/$p
  cp -r templates/noctalia-plugins/$p ~/.local/share/noctalia/plugins/$p
done
noctalia msg plugins enable bxrig/clock
noctalia msg plugins enable bxrig/agents
noctalia msg plugins enable bxrig/quick
noctalia msg plugins list | grep bxrig     # each shows "enabled"
```

Enabling adds the id to `enabled = [...]` under `[plugins]` in Noctalia's state-dir `settings.toml` (`~/.local/state/noctalia/settings.toml`). As an alternative, BxRig can write the ids into its own `config.toml`:

```toml
[plugins]
enabled = ["bxrig/clock", "bxrig/agents", "bxrig/quick"]
```

To disable a plugin and keep its files: `noctalia msg plugins disable bxrig/<name>`.

Noctalia hot-reloads edited `.luau` files. If you replace a whole plugin folder (`rm -rf` + `cp`), the reload is not reliable. Disable and re-enable the plugin after an upgrade.

## Open the panels (for keybinds)

```sh
noctalia msg panel-toggle bxrig/clock:panel
noctalia msg panel-toggle bxrig/agents:panel
noctalia msg panel-toggle bxrig/quick:panel
noctalia msg panel-toggle bxrig/quick:themes
```

Example Hyprland binds:

```
bind = SUPER, W, exec, noctalia msg panel-toggle bxrig/clock:panel
bind = SUPER, A, exec, noctalia msg panel-toggle bxrig/agents:panel
bind = SUPER CTRL, T, exec, noctalia msg panel-toggle bxrig/quick:panel
noctalia msg panel-toggle bxrig/quick:themes
```

Opened from a key, the clock, agents and quick settings panels are attached panels and appear near the bar. The theme switcher (`bxrig/quick:themes`, the second page of quick settings, opened by its Themes row) floats in the center of the screen and takes the keyboard:

- Typing filters the list.
- Up, Down, Page Up and Page Down move the selection.
- Enter applies the selected theme.
- Esc closes the panel.

## Bar widgets

A plugin widget is referenced as `<author>/<plugin>:<entry>`. Define a widget instance, then list it in a bar section:

```toml
[widget.bxrig-clock]
type = "bxrig/clock:bar"     # the time as text: click opens the panel, right click the calendar

[widget.bxrig-agents]
type = "bxrig/agents:bar"          # robot -> agents panel

[widget.bxrig-quick]
type = "bxrig/quick:bar"           # sliders -> quick settings (the theme switcher is its second page)

[bar.main]
center = ["bxrig-clock", "media"]
end = ["bxrig-agents", "tray", "network", "bluetooth", "volume", "battery", "notifications", "bxrig-quick", "control-center"]
```

`bxrig appearance bar layout minimal|standard|dense` writes the whole bar (these widgets, the built-in ones, the dock) into config.toml for you; the three layouts are in `docs/guides/appearance.md`. Planned BxRig widgets that are not built yet and therefore not on any bar: `bxrig-system` (updates, backups), `bxrig-dev` (databases, containers, VMs), `bxrig-vpn` and a power panel for the battery. Caffeine is not a bar widget: it is a switch in quick settings.

`noctalia config validate` checks the config without loading any plugins. It therefore warns `unrecognized widget type "bxrig/…:bar"` and `no loaded plugin with this id`, but it still reports the config as valid. The running shell resolves the widget types once the plugins are enabled.

## Settings

The clock has a second plugin-level setting, `format`: the text of the bar clock in Noctalia date format tokens (https://docs.noctalia.dev/noctalia/configuration/date-format-tokens/), default `%b %-d - %H:%M` ("Nov 5 - 04:00"). `bxrig time format FORMAT` writes it:

```toml
[plugin_settings."bxrig/clock"]
format = "%a %-I:%M %p"
```

The bar text is redrawn on the minute (every second when the format shows seconds). The id was `bxrig/world-clock` before the clock and the world clock became one widget; this is the first version, so there is nothing to migrate.

Each plugin has a plugin-level setting `command`, which defaults to `bxrig`. It is the bxrig executable: a name on Noctalia's PATH, an absolute path, or a `~/` path. The shell may be started without `~/.local/bin` on its PATH. In that case, BxRig should pin the path:

```toml
[plugin_settings."bxrig/clock"]
command = "~/.local/bin/bxrig"

[plugin_settings."bxrig/agents"]
command = "~/.local/bin/bxrig"

[plugin_settings."bxrig/quick"]
command = "~/.local/bin/bxrig"
```

## JSON contracts

The plugins read the envelope `{"ok": true, "data": {...}}`. When `ok` is false, the panel shows `data.error` (or a top-level `error`).

- `bxrig time world --json`:
  - `data.here`: `{city, time}`.
  - `data.zones[]`: `{label, tz, time, date, relative_day ("today"|"tomorrow"|"yesterday"), abbrev, offset ("+6h"; "+0h" is hidden), day_fraction (0..1 from local midnight), is_day}`.
- `bxrig ai panel --json`:
  - `data.tokens_today`: a number, or null to hide the count.
  - `data.agents[]`: `{id, name, installed, accounts[]}`.
  - `accounts[]`: `{name, plan, active, meters[]}`.
  - `meters[]`: `{label, used_fraction, resets_in}`.
  - An account with no meters, or an agent with no accounts, shows "no usage data".
- Quick settings page 1 reads `bxrig theme status --json` (`data.mode`, `data.name`), `bxrig notify dnd status --json` (`data.output`, `on` or `off`), `bxrig appearance dock|appgrid|bar layout|battery-percent status --json` (`data.dock`, `data.appgrid`, `data.layout`, `data.battery_percent` and `data.battery_found`) and `bxrig time format status --json` (`data.format`). It writes with `bxrig toggle stay-awake on|off`, `notify dnd on|off`, `theme mode theme|dark|light|auto`, `appearance dock on|off`, `appearance appgrid launchpad|terminal`, `appearance bar layout minimal|standard|dense`, `appearance battery-percent on|off` and `time format FORMAT`, always with `--yes`. A bar config.toml with changes of your own is replaced (a backup is kept) because of that `--yes`. Caffeine has Noctalia IPC to switch it (`noctalia msg caffeine-enable|disable|toggle`) but none to read it back, so its switch shows what the panel last set (kept until Noctalia restarts). Night light has no command here: a button opens the control center Home tab.
- `bxrig theme list --json`:
  - `data.current`: the active theme's name.
  - `data.themes[]`: `{name, label, light, preview?, wallpaper?}`.
  - The preview pane uses `preview`, falls back to `wallpaper`, and shows a placeholder otherwise. Paths must be local files (absolute or `~/`).
