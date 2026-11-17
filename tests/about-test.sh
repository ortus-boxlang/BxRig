#!/usr/bin/env bash
# `bxrig about`: the files it writes, fastfetch's arguments (a stub), the fallback without fastfetch, --json, and `theme set` recolouring the
# logo. Usage: about-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
run() { env -u NO_COLOR HOME="$tmp" PATH="$tmp/bin:/usr/bin:/bin" "$@"; }
esc=$'\e'
cfg="$tmp/.config"

# without fastfetch: the logo, version and tagline, and the hint
mkdir -p "$tmp/bin"
out="$(run "$binary" about --plain)" || fail 'about without fastfetch'
grep -q 'BXRIG powered by BoxLang' <<<"$out" || fail 'the caption'
grep -q 'www.boxlang.io' <<<"$out" || fail 'the site'
grep -q '███████████  █████ █████' <<<"$out" || fail 'BX in DOS Rebel on the screen'
grep -q 'bxrig install fastfetch' <<<"$out" || fail 'the install hint'
[[ "$out" != *"$esc"* ]] || fail '--plain has no colour'
[[ -s "$cfg/bxrig/theme/fastfetch-logo.ans" ]] || fail 'the logo file is written'
[[ -s "$cfg/bxrig/fastfetch.jsonc" ]] || fail 'the managed config is written'
grep -q "\"source\": \"$cfg/bxrig/theme/fastfetch-logo.ans\"" "$cfg/bxrig/fastfetch.jsonc" || fail 'the config points at the logo'
grep -q "${esc}\[38;2;" "$cfg/bxrig/theme/fastfetch-logo.ans" || fail 'the logo file is in colour'
[[ "$(sed -n '17p' "$cfg/bxrig/theme/fastfetch-logo.ans" | cut -c1-8)" == "        " ]] || fail 'the logo keeps its spaces (not tabs)'

# --json
run "$binary" about --json | jq -e '.ok and .data.name == "BxRig" and .data.poweredBy == "BoxLang" and .data.site == "https://www.boxlang.io" and (.data.fastfetch | not) and (.data.config | endswith("/bxrig/fastfetch.jsonc"))' >/dev/null || fail '--json'

# with fastfetch: our config, colour off into a pipe (and no fastfetch logo: ours is printed plain)
stub fastfetch 'echo "ARGS $*"'
out="$(run "$binary" about)" || fail 'about with fastfetch'
grep -q "ARGS --config $cfg/bxrig/fastfetch.jsonc --pipe true --logo none" <<<"$out" || fail "fastfetch arguments: $out"
grep -q 'BXRIG powered by BoxLang' <<<"$out" || fail 'the plain logo after fastfetch'
run "$binary" about --json | jq -e '.data.fastfetch' >/dev/null || fail '--json sees fastfetch'

# --wait reads a line before returning
out="$(echo | run "$binary" about --plain --wait)" || fail '--wait'
grep -q 'Press Enter to close.' <<<"$out" || fail '--wait asks for Enter'

# an edited managed config is kept (written only when missing)
echo '{ "mine": true }' > "$cfg/bxrig/fastfetch.jsonc"
run "$binary" about --plain >/dev/null || fail 'about with an edited config'
grep -q '"mine"' "$cfg/bxrig/fastfetch.jsonc" || fail 'an existing config is not replaced'

# theme set recolours the logo
before="$(md5sum < "$cfg/bxrig/theme/fastfetch-logo.ans")"
run "$binary" theme set tokyo-night >/dev/null 2>&1 || fail 'theme set'
[[ "$(md5sum < "$cfg/bxrig/theme/fastfetch-logo.ans")" != "$before" ]] || fail 'theme set rewrites the logo'
grep -q "${esc}\[38;2;122;162;247m" "$cfg/bxrig/theme/fastfetch-logo.ans" || fail 'the logo uses the tokyo-night accent'

# the menu's About runs it
run "$binary" menu items --json 2>/dev/null | jq -e '[.. | objects | select(.label? == "About")] | any(.argv == ["about"])' >/dev/null || fail 'the menu About runs bxrig about'
echo "about-test: ok"
