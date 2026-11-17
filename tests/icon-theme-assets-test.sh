#!/usr/bin/env bash
# The BxRig icon theme files (assets/icons/theme/BxRig, made by tools/gen-icon-theme.py): index.theme, every icon at every size, the licence.
# Needs no binary. Usage: icon-theme-assets-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
t="$root/assets/icons/theme"
[[ -f "$t/BxRig/index.theme" ]] || fail 'index.theme missing'
grep -q '^Name=BxRig$' "$t/BxRig/index.theme" || fail 'theme name'
grep -q '^Inherits=Papirus-Dark,hicolor$' "$t/BxRig/index.theme" || fail 'Inherits must be Papirus-Dark,hicolor'
grep -q 'MIT License' "$t/BxRig/LICENSE-Phosphor.txt" || fail 'the Phosphor licence is not shipped'
[[ -f "$root/assets/icons/phosphor/LICENSE" ]] || fail 'vendored Phosphor LICENSE missing'
n=0
while IFS= read -r name; do
	n=$((n+1))
	[[ "$name" == bxrig || "$name" == bxrig-* ]] || fail "icon name $name is not a bxrig-* name"
	ctx="$(jq -r --arg n "$name" '.icons[] | select(.name == $n) | .context' "$t/manifest.json")"
	[[ -s "$t/BxRig/scalable/$ctx/$name.svg" ]] || fail "$name: scalable SVG missing"
	for z in 16 22 24 32 48 64 128 256; do
		f="$t/BxRig/${z}x${z}/$ctx/$name.png"
		[[ -s "$f" ]] || fail "$name: ${z}px PNG missing"
		[[ "$(file -b "$f")" == *"${z} x ${z}"* ]] || fail "$name: $f is not ${z}x${z}"
	done
done < <(jq -r '.icons[].name' "$t/manifest.json")
(( n >= 31 )) || fail "only $n icons"
for need in bxrig bxrig-grid bxrig-develop bxrig-system bxrig-look bxrig-control-center bxrig-wizard bxrig-runner bxrig-apps bxrig-dashboard bxrig-ports bxrig-backups bxrig-updates bxrig-agents bxrig-vpn bxrig-dev-services; do
	jq -e --arg n "$need" '.icons[] | select(.name == $n)' "$t/manifest.json" >/dev/null || fail "$need missing from the manifest"
done
# every page of `bxrig tui list` has its own icon (the dashboard, apps, ports and look pages are named like their page)
for page in $(grep -o 'id: "[a-z]*"' "$root/src/bxrig/ControlCenterPages.bx" | cut -d'"' -f2); do
	jq -e --arg n "bxrig-$page" '.icons[] | select(.name == $n)' "$t/manifest.json" >/dev/null || fail "no icon bxrig-$page for the $page page"
done
! grep -rl '—' "$t/BxRig/index.theme" "$t/manifest.json" "$root/tools/gen-icon-theme.py" "$root/tools/render-icon-theme.js" || fail 'em dash'
python3 "$root/tools/gen-icon-theme.py" --check >/dev/null || fail 'generator --check'
echo "icon theme asset tests passed"
