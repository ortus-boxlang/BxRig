# BxRig Noctalia plugins

Three Noctalia v5 plugins (author id `bxrig`). Each folder is one plugin.

| Folder | Plugin id | Entries | Data source |
|---|---|---|---|
| `world-clock/` | `bxrig/world-clock` | bar widget `bar`, panel `panel` | `bxrig time world --json`, every 30 s while open |
| `agents/` | `bxrig/agents` | bar widget `bar`, panel `panel` | `bxrig ai panel --json`, every 60 s while open; launch runs `bxrig ai launch <id>` |
| `themes/` | `bxrig/themes` | bar widget `bar`, panel `panel` | `bxrig theme list --json` on open; Enter runs `bxrig theme set <name> --yes` |

The plugins use `plugin_api = 43`. They only draw with palette roles, so they follow the active Noctalia theme. Every file in a folder ships together. `bxrig.luau` is the same helper in all three: it runs bxrig and unwraps the `{"ok":…,"data":…}` envelope.

## Install

Noctalia finds hand-placed plugins in `~/.local/share/noctalia/plugins/<folder>/` (the built-in `local` source). Being installed does not make a plugin active: each one must also be enabled.

```sh
mkdir -p ~/.local/share/noctalia/plugins
for p in world-clock agents themes; do
  rm -rf ~/.local/share/noctalia/plugins/$p
  cp -r templates/noctalia-plugins/$p ~/.local/share/noctalia/plugins/$p
done
noctalia msg plugins enable bxrig/world-clock
noctalia msg plugins enable bxrig/agents
noctalia msg plugins enable bxrig/themes
noctalia msg plugins list | grep bxrig     # each shows "enabled"
```

Enabling adds the id to `enabled = [...]` under `[plugins]` in Noctalia's state-dir `settings.toml` (`~/.local/state/noctalia/settings.toml`). As an alternative, BxRig can write the ids into its own `config.toml`:

```toml
[plugins]
enabled = ["bxrig/world-clock", "bxrig/agents", "bxrig/themes"]
```

To disable a plugin and keep its files: `noctalia msg plugins disable bxrig/<name>`.

Noctalia hot-reloads edited `.luau` files. If you replace a whole plugin folder (`rm -rf` + `cp`), the reload is not reliable. Disable and re-enable the plugin after an upgrade.

## Open the panels (for keybinds)

```sh
noctalia msg panel-toggle bxrig/world-clock:panel
noctalia msg panel-toggle bxrig/agents:panel
noctalia msg panel-toggle bxrig/themes:panel
```

Example Hyprland binds:

```
bind = SUPER, W, exec, noctalia msg panel-toggle bxrig/world-clock:panel
bind = SUPER, A, exec, noctalia msg panel-toggle bxrig/agents:panel
bind = SUPER CTRL, T, exec, noctalia msg panel-toggle bxrig/themes:panel
```

Opened from a key, the world-clock and agents panels are attached panels and appear near the bar. The themes panel floats in the center of the screen and takes the keyboard:

- Typing filters the list.
- Up, Down, Page Up and Page Down move the selection.
- Enter applies the selected theme.
- Esc closes the panel.

## Bar widgets

A plugin widget is referenced as `<author>/<plugin>:<entry>`. Define a widget instance, then list it in a bar section:

```toml
[widget.bxrig-world-clock]
type = "bxrig/world-clock:bar"     # globe -> world clock panel

[widget.bxrig-agents]
type = "bxrig/agents:bar"          # robot -> agents panel

[widget.bxrig-themes]
type = "bxrig/themes:bar"          # palette -> theme switcher

[bar.main]
end = ["bxrig-world-clock", "bxrig-agents", "bxrig-themes", "tray", "network", "bluetooth", "volume", "battery", "notifications", "control-center"]
```

`noctalia config validate` checks the config without loading any plugins. It therefore warns `unrecognized widget type "bxrig/…:bar"` and `no loaded plugin with this id`, but it still reports the config as valid. The running shell resolves the widget types once the plugins are enabled.

## Settings

Each plugin has one plugin-level setting, `command`, which defaults to `bxrig`. It is the bxrig executable: a name on Noctalia's PATH, an absolute path, or a `~/` path. The shell may be started without `~/.local/bin` on its PATH. In that case, BxRig should pin the path:

```toml
[plugin_settings."bxrig/world-clock"]
command = "~/.local/bin/bxrig"

[plugin_settings."bxrig/agents"]
command = "~/.local/bin/bxrig"

[plugin_settings."bxrig/themes"]
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
- `bxrig theme list --json`:
  - `data.current`: the active theme's name.
  - `data.themes[]`: `{name, label, light, preview?, wallpaper?}`.
  - The preview pane uses `preview`, falls back to `wallpaper`, and shows a placeholder otherwise. Paths must be local files (absolute or `~/`).
