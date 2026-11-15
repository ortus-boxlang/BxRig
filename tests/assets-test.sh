#!/usr/bin/env bash
# `bxrig assets list|install`: the embedded images land byte for byte. Usage: assets-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
export BXRIG_WALLPAPER_DIR="$root/assets/wallpapers" BXRIG_BASE_URL=http://127.0.0.1:9   # the theme wallpapers come from the checkout, never the network
mkdir -p "$tmp/bin" "$tmp/home"
stub_id
run() { env HOME="$tmp/home" PATH="$tmp/bin:$PATH" "$@"; }
run "$binary" assets list | grep -q 'logo.png -> ' || fail 'list shows the targets'
run "$binary" assets list --json | jq -e '(.data.assets | length) == 9' >/dev/null || fail 'list --json'
[[ "$(code "$binary" assets install)" == 2 ]] || fail 'install without --yes exits 2'
[[ "$(code "$binary" assets install --dry-run)" == 0 ]] || fail 'dry run exits 0'
[[ ! -e "$tmp/home/Pictures" ]] || fail 'plan or dry run wrote files'
[[ "$(MOCK_UID=0 code "$binary" assets install --yes)" == 4 ]] || fail 'root exits 4'
[[ "$(code "$binary" assets install --yes)" == 0 ]] || fail 'install --yes exits 0'
for f in "$root"/assets/wallpapers/*.jpg; do f="wallpapers/$(basename "$f")"
	cmp "$tmp/home/Pictures/BxRig/$(basename "$f")" "$root/assets/$f" || fail "$f differs from the source image"
done
for sz in 16 24 32 48 64 128 256; do
	cmp "$tmp/home/.local/share/icons/hicolor/${sz}x${sz}/apps/bxrig.png" "$root/assets/icons/$sz.png" || fail "icon $sz differs"
done
cmp "$tmp/home/.local/share/icons/hicolor/scalable/apps/bxrig.svg" "$root/assets/icons/bxrig.svg" || fail 'scalable icon differs'
# a file the user replaced is kept
echo mine > "$tmp/home/Pictures/BxRig/bxrig.jpg"
[[ "$(code "$binary" assets install --yes)" == 0 ]] || fail 're-run exits 0'
[[ "$(cat "$tmp/home/Pictures/BxRig/bxrig.jpg")" == mine ]] || fail 'a changed wallpaper was overwritten'
[[ -z "$(ls "$tmp/home/Pictures/BxRig" | grep '\.b64$' || true)" ]] || fail 'temp .b64 left behind'
echo "assets tests passed"
