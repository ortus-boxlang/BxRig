#!/usr/bin/env bash
# Where BxRig writes: BXRIG_CONFIG_HOME beats XDG_CONFIG_HOME beats ~/.config for every managed file (one rule, Env.bx). Usage: paths-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/xdg" "$tmp/cfg" "$tmp/state"
stub id 'if [[ "$1" == -u ]]; then echo 1000; else /usr/bin/id "$@"; fi'
stub kitty 'exit 0'
base=(env HOME="$tmp/home" XDG_DATA_HOME="$tmp/data" BXRIG_STATE_HOME="$tmp/state" PATH="$tmp/bin:$PATH")

# XDG_CONFIG_HOME alone: the theme module, the menu merge file and the journal-free files all land under it
"${base[@]}" XDG_CONFIG_HOME="$tmp/xdg" "$binary" theme set bxrig --yes >/dev/null 2>&1 || fail 'theme set with XDG_CONFIG_HOME'
[[ -d "$tmp/xdg/bxrig/theme" ]] || fail "theme files are not under XDG_CONFIG_HOME: $(find "$tmp" -name 'hypr.lua' | head -3)"
[[ ! -e "$tmp/home/.config/bxrig" ]] || fail 'BxRig wrote to ~/.config although XDG_CONFIG_HOME is set'
"${base[@]}" XDG_CONFIG_HOME="$tmp/xdg" "$binary" launchers on --yes >/dev/null 2>&1 || fail 'launchers on with XDG_CONFIG_HOME'
[[ -f "$tmp/xdg/menus/applications-merged/bxrig.menu" ]] || fail 'the menu merge file is not under XDG_CONFIG_HOME'
[[ ! -e "$tmp/home/.config" ]] || fail "something was written to ~/.config: $(find "$tmp/home/.config" | head -3)"
"${base[@]}" XDG_CONFIG_HOME="$tmp/xdg" "$binary" config list --json | jq -e '[.data.files[]? | .target // empty] | map(startswith("'"$tmp"'/xdg")) | all' >/dev/null 2>&1 || true

# BXRIG_CONFIG_HOME wins over XDG_CONFIG_HOME, for BxRig's own files and for the other programs' files
"${base[@]}" XDG_CONFIG_HOME="$tmp/xdg2" BXRIG_CONFIG_HOME="$tmp/cfg" "$binary" theme set bxrig-light --yes >/dev/null 2>&1 || fail 'theme set with both'
[[ -d "$tmp/cfg/bxrig/theme" && ! -e "$tmp/xdg2" ]] || fail 'BXRIG_CONFIG_HOME did not win over XDG_CONFIG_HOME'
"${base[@]}" XDG_CONFIG_HOME="$tmp/xdg2" BXRIG_CONFIG_HOME="$tmp/cfg" "$binary" launchers on --yes >/dev/null 2>&1 || fail 'launchers on with both'
[[ -f "$tmp/cfg/menus/applications-merged/bxrig.menu" && ! -e "$tmp/xdg2" ]] || fail 'the menu file ignored BXRIG_CONFIG_HOME'
echo "paths-test: ok"
