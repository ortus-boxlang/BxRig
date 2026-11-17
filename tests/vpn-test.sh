#!/usr/bin/env bash
# `bxrig vpn list|status|connect|disconnect|locations|set` with fake nordvpn, tailscale, mullvad and nmcli (no real VPN is touched).
# Usage: vpn-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/state"; export LOG="$tmp/log" STATE="$tmp/state"; : > "$LOG"
stub nordvpn 'echo "nordvpn $*" >> "$LOG"
case "$1" in
	status) if [[ -f "$STATE/nord" ]]; then printf "Status: Connected\nHostname: de1.nordvpn.com\nCountry: Germany\nCity: Berlin\n"; else echo "Status: Disconnected"; fi ;;
	connect) touch "$STATE/nord" ;;
	disconnect) rm -f "$STATE/nord" ;;
	countries) printf "Albania Germany\nUnited_States\n" ;;
esac'
stub tailscale 'echo "tailscale $*" >> "$LOG"
case "$1" in
	status) if [[ -f "$STATE/ts" ]]; then echo "{\"BackendState\":\"Running\",\"Peer\":{\"k:a\":{\"HostName\":\"home\",\"ExitNodeOption\":true,\"Online\":true}}}"; else echo "{\"BackendState\":\"Stopped\",\"Peer\":{\"k:a\":{\"HostName\":\"home\",\"ExitNodeOption\":true,\"Online\":true}}}"; fi ;;
	up) touch "$STATE/ts" ;;
	down) rm -f "$STATE/ts" ;;
esac'
stub nmcli 'echo "nmcli $*" >> "$LOG"
if [[ "$*" == *"connection show"* ]]; then
	if [[ -f "$STATE/nm" ]]; then yn=yes; else yn=no; fi
	printf "Wired connection 1:u-1:802-3-ethernet:yes\nHome WireGuard:u-2:wireguard:%s\n" "$yn"
elif [[ "$*" == *"connection up"* ]]; then touch "$STATE/nm"
elif [[ "$*" == *"connection down"* ]]; then rm -f "$STATE/nm"; fi'
# a PATH of the stubs and the basic tools only, so a VPN of the machine running the test is never found
mkdir -p "$tmp/tools"; for t in bash sh env cat rm touch jq printf echo date id mkdir cp mv sleep dirname basename tr sed grep sort head tail wc uname readlink ln chmod stat; do p="$(command -v "$t" 2>/dev/null || true)"; [[ -x "$p" ]] && ln -sf "$p" "$tmp/tools/$t"; done
run() { env HOME="$tmp/home" USER=ada BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state/bx" LOG="$LOG" STATE="$STATE" PATH="$tmp/bin:$tmp/tools" "$@"; }
has_log() { grep -qx "$1" "$LOG"; }

# nothing is installed: list is empty (exit 0), the other verbs exit 4
mkdir -p "$tmp/empty"; ln -sf "$(command -v sh)" "$tmp/empty/sh"; ln -sf "$(command -v jq)" "$tmp/empty/jq"
erun() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state/bx" PATH="$tmp/empty" "$@"; }
erun "$binary" vpn list --json | jq -e '.ok == true and .data.providers == [] and (.data.install | length) >= 4' >/dev/null || fail 'an empty list when no VPN is installed'
erun "$binary" vpn list | grep -q 'No VPN is installed' || fail 'the empty list says how to install one'
for v in status 'connect tailscale' disconnect; do set +e; erun "$binary" vpn $v >/dev/null 2>&1; rc=$?; set -e; [[ "$rc" == 4 ]] || fail "vpn $v with nothing installed exits 4 (got $rc)"; done

# list, in the two groups
run "$binary" vpn list --json | jq -e '(.data.providers | map(.id) | sort) == ["nm:Home WireGuard","nordvpn","tailscale"] and (.data.providers | map(select(.group=="profiles")) | length) == 1 and .data.allow_several == false and .data.connected == []' >/dev/null || fail "list: $(run "$binary" vpn list --json)"
run "$binary" vpn list | grep -q '^Network profiles' && run "$binary" vpn list | grep -q '^VPN apps' || fail 'list: two groups'
[[ "$(code "$binary" vpn connect nonesuch)" == 2 ]] || fail 'an unknown name exits 2'
[[ "$(code "$binary" vpn connect mullvad)" == 4 ]] || fail 'a known provider that is not installed exits 4'
[[ "$(code "$binary" vpn frobnicate)" == 2 ]] || fail 'an unknown verb exits 2'
[[ "$(code "$binary" vpn connect)" == 2 ]] || fail 'connect needs a name'
[[ "$(code "$binary" vpn list --bogus)" == 2 ]] || fail 'an unknown flag exits 2'

# connect: acts at once, dry run changes nothing
: > "$LOG"; run "$binary" vpn connect nordvpn --dry-run | grep -q 'Dry run' || fail 'connect --dry-run'
! has_log 'nordvpn connect' || fail 'the dry run connected'
run "$binary" vpn connect nordvpn | grep -q 'done' || fail 'connect'
has_log 'nordvpn connect' || fail "connect ran: $(cat "$LOG")"
run "$binary" vpn status --json | jq -e '.data.connected == ["nordvpn"]' >/dev/null || fail 'status after connect'
run "$binary" vpn status | grep -q 'Connected: NordVPN (Berlin, Germany)' || fail "status text: $(run "$binary" vpn status)"
run "$binary" vpn connect nordvpn | grep -q 'already connected' || fail 'connecting twice is a no-op'

# choosing another disconnects the first one (default), a profile too
: > "$LOG"; run "$binary" vpn connect tailscale --location=home --json | jq -e '.data.disconnected == ["nordvpn"] and .ok == true' >/dev/null || fail 'connect tailscale disconnects nordvpn'
[[ "$(grep -n . "$LOG" | grep -E 'nordvpn disconnect|tailscale up|tailscale set --exit-node=home' | sed 's/^[0-9]*://' | tr '\n' '|')" == 'nordvpn disconnect|tailscale up|tailscale set --exit-node=home|' ]] || fail "order of commands: $(cat "$LOG")"
run "$binary" vpn status --json | jq -e '.data.connected == ["tailscale"]' >/dev/null || fail 'only tailscale is connected'
: > "$LOG"; run "$binary" vpn connect "nm:Home WireGuard" >/dev/null || fail 'connect a profile'
has_log 'tailscale down' && has_log 'nmcli connection up uuid u-2' || fail "the profile switch: $(cat "$LOG")"
run "$binary" vpn status --json | jq -e '.data.connected == ["nm:Home WireGuard"]' >/dev/null || fail 'only the profile is connected'

# allow several: saved through the config service, then nothing is disconnected
[[ "$(code "$binary" vpn set allow_several=true)" == 2 ]] || fail 'set without --yes is a plan (exit 2)'
[[ ! -e "$tmp/cfg/bxrig/vpn.json" ]] || fail 'the plan wrote the file'
[[ "$(code "$binary" vpn set allow_several=maybe --yes)" == 2 ]] || fail 'a bad value exits 2'
[[ "$(code "$binary" vpn set colour=red --yes)" == 2 ]] || fail 'an unknown key exits 2'
run "$binary" vpn set allow_several=true --yes --dry-run >/dev/null; [[ ! -e "$tmp/cfg/bxrig/vpn.json" ]] || fail 'the dry run wrote the file'
run "$binary" vpn set allow_several=true --yes --json | jq -e '.ok == true and .data.value == true' >/dev/null || fail 'set --yes'
jq -e '.allow_several == true' "$tmp/cfg/bxrig/vpn.json" >/dev/null || fail 'the setting is in vpn.json'
: > "$LOG"; run "$binary" vpn connect tailscale >/dev/null 2>&1
! has_log 'nmcli connection down uuid u-2' || fail 'allow_several still disconnected the other VPN'
run "$binary" vpn status --json | jq -e '(.data.connected | length) == 2 and .data.allow_several == true' >/dev/null || fail 'two connected with allow_several'
run "$binary" vpn set allow_several=false --yes >/dev/null; jq -e '.allow_several == false' "$tmp/cfg/bxrig/vpn.json" >/dev/null || fail 'turned off again'

# disconnect: one, or all
: > "$LOG"; run "$binary" vpn disconnect tailscale >/dev/null; has_log 'tailscale down' && ! has_log 'nmcli connection down uuid u-2' || fail "disconnect one: $(cat "$LOG")"
: > "$LOG"; run "$binary" vpn disconnect >/dev/null; has_log 'nmcli connection down uuid u-2' || fail "disconnect all: $(cat "$LOG")"
run "$binary" vpn disconnect | grep -q 'Nothing is connected' || fail 'disconnect with nothing connected'
[[ "$(code "$binary" vpn disconnect nonesuch)" == 2 ]] || fail 'disconnect of an unknown name exits 2'

# locations
run "$binary" vpn locations nordvpn --json | jq -e '(.data.locations | map(.value)) == ["default","Albania","Germany","United_States"] and .data.can_pick == true' >/dev/null || fail "nordvpn locations: $(run "$binary" vpn locations nordvpn --json)"
run "$binary" vpn locations tailscale --json | jq -e '(.data.locations | map(.value)) == ["default","none","home"]' >/dev/null || fail 'tailscale exit nodes'
run "$binary" vpn locations "nm:Home WireGuard" --json | jq -e '.data.can_pick == false and (.data.locations | length) == 0' >/dev/null || fail 'a profile has no places'
: > "$LOG"; run "$binary" vpn connect nordvpn --location=United_States >/dev/null; has_log 'nordvpn connect United_States' || fail 'connect with a place'
[[ "$(code "$binary" vpn connect nordvpn --location=--help)" == 2 ]] || fail 'a place that looks like an option exits 2'
[[ "$(code "$binary" vpn connect "nm:Home WireGuard" --location=x)" == 2 ]] || fail 'a profile has no place'

# a provider of your own (data only)
mkdir -p "$tmp/cfg/bxrig"; stub acmevpn 'echo "acmevpn $*" >> "$LOG"; if [[ "$1" == status ]]; then echo Disconnected; fi'
printf '{"providers":[{"id":"acme","name":"Acme VPN","binary":"acmevpn","verified":"no","note":"mine","status":{"argv":["acmevpn","status"],"parser":"mullvad"},"connect":["acmevpn","up"],"disconnect":["acmevpn","down"]}]}\n' > "$tmp/cfg/bxrig/vpn-providers.json"
run "$binary" vpn list --json | jq -e '.data.providers | map(.id) | index("acme") != null' >/dev/null || fail 'a provider from ~/.config/bxrig/vpn-providers.json is listed'
: > "$LOG"; run "$binary" vpn connect acme >/dev/null; has_log 'acmevpn up' || fail 'the added provider connects'
rm -f "$tmp/cfg/bxrig/vpn-providers.json"

# the old command keeps working
stub sudo '[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }
echo "sudo $*" >> "$LOG"'
[[ "$(code "$binary" vpn nordvpn setup)" == 2 ]] || fail 'vpn nordvpn setup without --yes still exits 2'
: > "$LOG"; run "$binary" vpn nordvpn setup --yes | grep -q 'nordvpn login' || fail 'vpn nordvpn setup --yes still works'
grep -q 'sudo systemctl enable --now nordvpnd' "$LOG" || fail "setup commands: $(cat "$LOG")"
echo "vpn-test: ok"
