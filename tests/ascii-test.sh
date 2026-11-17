#!/usr/bin/env bash
# `bxrig ascii`: text in large letters, fonts, colours and gradients, stdin, and the usage errors. Usage: ascii-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
run() { env -u NO_COLOR HOME="$tmp" "$@"; }
esc=$'\e'

out="$(run "$binary" ascii BXRIG)" || fail 'ascii BXRIG'
[[ "$(wc -l <<<"$out")" == 8 ]] || fail "DOS Rebel is 8 rows: $out"
[[ "$out" != *"$esc"* ]] || fail 'no colour into a pipe without --color or --gradient'
grep -q '███████████  █████ █████ █████   █████ █████ ░░█████████' <<<"$out" || fail 'the DOS Rebel BXRIG'
[[ "$(run "$binary" ascii BXRIG --font=calvin-s | head -1)" == "╔╗ ═╗ ╦╦═╗╦╔═╗" ]] || fail 'Calvin S'
[[ "$(run "$binary" ascii BXRIG --font=ansi-shadow | wc -l)" == 6 ]] || fail 'ANSI Shadow is 6 rows'
[[ "$(run "$binary" ascii BX RIG --font=calvin-s)" == "$(run "$binary" ascii "BX RIG" --font=calvin-s)" ]] || fail 'several words are joined with a space'
run "$binary" ascii OK --json | jq -e '.ok and .data.font == "dos-rebel" and .data.height == (.data.lines | length) and .data.width > 0' >/dev/null || fail '--json'
[[ "$(echo deploy | run "$binary" ascii --font=calvin-s | wc -l)" == 3 ]] || fail 'the text from stdin'

# colour: --color and --gradient paint even into a pipe; --plain and NO_COLOR leave it out
grep -q "${esc}\[38;2;0;255;120m" <<<"$(run "$binary" ascii hi --color='#00ff78')" || fail '--color'
grep -q "${esc}\[38;2;0;255;120m" <<<"$(run "$binary" ascii hi --color=boxlang)" || fail '--color with a name'
grep -q "${esc}\[38;2;255;0;0m" <<<"$(run "$binary" ascii hi --gradient=rainbow)" || fail '--gradient preset'
grep -q "${esc}\[38;2;0;0;255m" <<<"$(run "$binary" ascii hi --gradient='#ff0000,#0000ff' --direction=vertical)" || fail 'custom vertical gradient'
[[ "$(run "$binary" ascii hi --gradient=fire --plain)" != *"$esc"* ]] || fail '--plain'
[[ "$(env NO_COLOR=1 HOME="$tmp" "$binary" ascii hi --gradient=fire)" != *"$esc"* ]] || fail 'NO_COLOR'

# usage errors exit 2 and nothing is drawn
for bad in "--font=nope" "--color=nope" "--gradient=red" "--gradient=red,nope" "--direction=up"; do
	[[ "$(code "$binary" ascii x "$bad")" == 2 ]] || fail "$bad exits 2"
done
[[ "$(code "$binary" ascii x --color=red --gradient=fire)" == 2 ]] || fail '--color and --gradient together exit 2'
[[ "$(code "$binary" ascii x --bogus)" == 2 ]] || fail 'an unknown flag exits 2'
[[ "$(echo "" | run "$binary" ascii >/dev/null 2>&1; echo $?)" == 2 ]] || fail 'no text exits 2'
out="$(run "$binary" ascii x --font=nope || true)"; grep -q 'dos-rebel, ansi-shadow, calvin-s' <<<"$out" || fail 'an unknown font lists the fonts'

# fonts
out="$(run "$binary" ascii fonts)" || fail 'ascii fonts'
for f in dos-rebel ansi-shadow calvin-s; do grep -q "^$f" <<<"$out" || fail "fonts lists $f"; done
run "$binary" ascii fonts --json | jq -e '.data.fonts == ["dos-rebel","ansi-shadow","calvin-s"] and .data.default == "dos-rebel"' >/dev/null || fail 'fonts --json'
# image: a picture as text art, through the embedded bx-image module (SVG and PNG)
svg="$root/assets/brand/boxlang-icon-full.svg"; png="$root/assets/logo.png"
out="$(run "$binary" ascii image "$svg" --width=24)" || fail 'ascii image svg'
[[ "$out" != *"$esc"* ]] || fail 'no colour into a pipe'
(( $(wc -l <<<"$out") >= 8 )) || fail "the icon is several rows: $out"
grep -q '█' <<<"$out" || fail 'blocks style draws blocks'
widest="$(LC_ALL=C.UTF-8 bash -c 'w=0; while IFS= read -r l; do (( ${#l} > w )) && w=${#l}; done; echo "$w"' <<<"$out")"
(( widest <= 24 )) || fail "no wider than --width ($widest characters)"
run "$binary" ascii image "$svg" --width=30 --json | jq -e '.ok and .data.width == 30 and .data.style == "blocks" and .data.height == (.data.lines | length) and .data.height > 5' >/dev/null || fail 'image --json'
run "$binary" ascii image "$png" --width=40 --style=ascii --json | jq -e '.ok and .data.style == "ascii" and (.data.lines | length) > 0' >/dev/null || fail 'png, ascii style'
script -qc "env -u NO_COLOR HOME=$tmp $binary ascii image $svg --width=20" /dev/null | grep -q "${esc}\[38;2;" || fail 'colour in a terminal'
[[ "$(code "$binary" ascii image)" == 2 ]] || fail 'no path exits 2'
[[ "$(code "$binary" ascii image "$svg" --width=2)" == 2 ]] || fail 'a bad width exits 2'
[[ "$(code "$binary" ascii image "$svg" --style=nope)" == 2 ]] || fail 'a bad style exits 2'
[[ "$(code "$binary" ascii image "$tmp/missing.png")" == 4 ]] || fail 'a missing picture exits 4'
echo "not a picture" > "$tmp/bad.png"
[[ "$(code "$binary" ascii image "$tmp/bad.png")" == 4 ]] || fail 'an unreadable picture exits 4'
echo "ascii-test: ok"
