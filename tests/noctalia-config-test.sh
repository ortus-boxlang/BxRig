#!/usr/bin/env bash
# The Noctalia starter files through `config apply`: valid TOML and JSON, safe re-runs, drift. Usage: noctalia-config-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
export BXRIG_WALLPAPER_DIR="$root/assets/wallpapers" BXRIG_BASE_URL=http://127.0.0.1:9   # the theme wallpapers come from the checkout, never the network
mkdir -p "$tmp/home"
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" "$@"; }
run "$binary" config list | grep -q '^noctalia: missing' || fail 'config list shows noctalia as missing'
[[ "$(code "$binary" config apply noctalia)" == 2 ]] || fail 'apply without --yes exits 2'
[[ ! -e "$tmp/cfg/noctalia" ]] || fail 'apply without --yes wrote a file'
[[ "$(code "$binary" config apply noctalia --yes)" == 0 ]] || fail 'apply noctalia'
[[ "$(code "$binary" config apply noctalia-palette --yes)" == 0 ]] || fail 'apply noctalia-palette'
python3 - "$tmp/cfg/noctalia/config.toml" "$tmp/home" <<'PY' || fail 'config.toml is not valid TOML or lacks the expected keys'
import sys, tomllib
c = tomllib.load(open(sys.argv[1], 'rb'))
assert c['theme']['custom_palette'] == 'BxRig' and c['theme']['source'] == 'custom'
assert c['bar']['order'] == ['main'] and c['bar']['main']['position'] == 'top'
assert 'launcher' in c['bar']['main']['start'] and 'clock' in c['bar']['main']['center']
assert 'media' in c['bar']['main']['center'] and 'media' not in c['bar']['main']['end']
# the globe (world clock plugin) sits right before the clock, which reads "Nov 5 - 15:44"
center = c['bar']['main']['center']
assert center.index('bxrig-world-clock') + 1 == center.index('clock') and c['widget']['bxrig-world-clock']['type'] == 'bxrig/world-clock:bar'
assert c['widget']['clock']['format'] == '{:%b %-d - %H:%M}'
assert 'bxrig-agents' in c['bar']['main']['end'] and 'bxrig-themes' in c['bar']['main']['end']
assert c['plugins']['enabled'] == ['bxrig/world-clock', 'bxrig/agents', 'bxrig/themes']
assert c['notification']['group_by_app'] is True and c['notification']['border_color'] == 'primary'
assert c['wallpaper']['directory'] == sys.argv[2] + '/Pictures/BxRig'
assert c['wallpaper']['default']['path'].endswith('/bxrig.jpg')
PY
jq -e '.version == 2 and (.dark | has("primary","surface","hover")) and (.light | has("primary")) and (.dark.terminal.normal | length) == 8' "$tmp/cfg/noctalia/palettes/BxRig.json" >/dev/null || fail 'palette is not valid or lacks keys'
run "$binary" config list | grep -q '^noctalia: clean' || fail 'config list shows noctalia clean'
echo '# mine' >> "$tmp/cfg/noctalia/config.toml"
[[ "$(code "$binary" config apply noctalia --yes)" == 8 ]] || fail 'drift exits 8 without --force'
[[ "$(code "$binary" config apply noctalia --yes --force)" == 0 ]] || fail '--force overwrites'
echo "noctalia config tests passed"
