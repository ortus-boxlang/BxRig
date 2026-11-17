#!/usr/bin/env bash
# `bxrig system updates` and `bxrig system update --repo|--aur|--all` with fake checkupdates, yay, paru, snapper, pacman and uname. Usage: system-updates-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
H="$tmp/home"; mkdir -p "$tmp/bin" "$H" "$tmp/modules/6.17.8-1-cachyos"; export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/pacman.log" <<'F'
[2026-11-14T10:00:00+0000] [PACMAN] starting full system upgrade
[2026-11-15T21:42:10+0100] [PACMAN] starting full system upgrade
[2026-11-15T22:00:00+0100] [ALPM] transaction completed
F
stub checkupdates 'if [[ -f "$FAKE/noupdates" ]]; then exit 2; fi; if [[ -f "$FAKE/checkfail" ]]; then echo "error: failed to synchronize all databases" >&2; exit 1; fi; cat "$FAKE/repo"'
stub yay 'echo "yay $*" >> "$LOG"; if [[ "$1" == -Qua ]]; then if [[ -s "$FAKE/aur" ]]; then cat "$FAKE/aur"; else exit 1; fi; fi'
stub paru 'echo "paru $*" >> "$LOG"; if [[ "$1" == -Qua ]]; then if [[ -s "$FAKE/aur" ]]; then cat "$FAKE/aur"; else exit 1; fi; fi'
stub snapper 'echo "snapper $*" >> "$LOG"'
stub pacman 'echo "pacman $*" >> "$LOG"'
stub uname 'echo "${FAKE_KERNEL:-6.17.8-1-cachyos}"'
stub_sudo_log
mkdir -p "$tmp/fake"; export FAKE="$tmp/fake"
printf 'linux-cachyos 6.17.8-1 -> 6.17.9-1\nmesa 25.2.5-1 -> 25.2.6-1\nfirefox 143.0.1-1 -> 143.0.3-1\n' > "$FAKE/repo"
printf 'nordvpn-bin 4.1.1-1 -> 4.2.0-1\n' > "$FAKE/aur"
# a PATH with the fakes first and only the basic tools after them (no real yay, paru, snapper, timeshift or checkupdates of the machine)
basic="$tmp/basic"; mkdir -p "$basic"; for t in sh bash env cat grep sed tr head tail sort id dirname readlink sha256sum rm mkdir cp mv chmod date; do p="$(command -v "$t" || true)"; [[ -n "$p" ]] && ln -sf "$p" "$basic/$t"; done
mkdir -p "$tmp/only"; for t in sh bash env cat grep id; do ln -sf "$(command -v $t)" "$tmp/only/$t"; done
run() { env HOME="$H" USER=dev BXRIG_CONFIG_HOME="$H/.config" BXRIG_DATA_HOME="$tmp/data" BXRIG_MODULES_DIR="$tmp/modules" BXRIG_PACMAN_LOG="$tmp/pacman.log" BXRIG_NOW_EPOCH=1794861730 PATH="$tmp/bin:$basic" LOG="$LOG" FAKE="$FAKE" FAKE_KERNEL="${FAKE_KERNEL:-}" "$@"; }

# ---- system updates ----
run "$binary" system updates --json | jq -e '
  .data.total == 4 and .data.repo_count == 3 and .data.aur_count == 1 and
  (.data.packages | length == 4) and .data.packages[0] == {"name":"linux-cachyos","old":"6.17.8-1","new":"6.17.9-1","repo":"repo"} and
  .data.packages[3].repo == "aur" and .data.packages[3].name == "nordvpn-bin" and
  .data.needs_reboot == true and .data.reboot_pending == true and .data.reboot_stale == false and
  .data.reboot_reasons == ["linux-cachyos (kernel) is updated"] and
  .data.last_update == "2026-11-15T21:42:10+0100" and .data.last_update_epoch == 1794775330 and .data.last_update_ago == "24 hours ago" and
  .data.aur_helper == "yay" and .data.snapshot_tool == "snapper"' >/dev/null || fail "updates json: $(run "$binary" system updates --json)"
[[ "$(code "$binary" system updates)" == 0 ]] || fail 'updates exits 0 with updates waiting'
run "$binary" system updates | grep -q '4 updates waiting: 3 repository, 1 AUR' || fail 'text summary'
run "$binary" system updates | grep -q 'A restart is needed: linux-cachyos (kernel) is updated' || fail 'text restart line'
# no kernel in the list: no restart; ordinary packages never ask for one
printf 'mesa 25.2.5-1 -> 25.2.6-1\n' > "$FAKE/repo"; : > "$FAKE/aur"
run "$binary" system updates --json | jq -e '.data.total == 1 and .data.aur_count == 0 and .data.needs_reboot == false and .data.reboot_reasons == []' >/dev/null || fail 'no restart for mesa'
# systemd and glibc do
printf 'systemd 258.1-2 -> 258.2-1\nglibc 2.42-1 -> 2.43-1\n' > "$FAKE/repo"
run "$binary" system updates --json | jq -e '.data.reboot_reasons == ["systemd is updated","glibc is updated"]' >/dev/null || fail 'systemd and glibc'
# the running kernel is gone from /usr/lib/modules: a restart is overdue even when nothing is pending
: > "$FAKE/repo"; touch "$FAKE/noupdates"
FAKE_KERNEL=6.17.7-1-cachyos run "$binary" system updates --json | jq -e '.data.total == 0 and .data.needs_reboot == true and .data.reboot_stale == true and .data.reboot_pending == false' >/dev/null || fail 'stale kernel'
run "$binary" system updates | grep -q 'The system is up to date' || fail 'up to date text'
run "$binary" system updates --json | jq -e '.data.needs_reboot == false and .data.total == 0' >/dev/null || fail 'nothing waiting, kernel current'
rm "$FAKE/noupdates"
# paru is used when there is no yay
rm "$tmp/bin/yay"; printf 'x 1-1 -> 2-1\n' > "$FAKE/aur"; printf 'mesa 1-1 -> 2-1\n' > "$FAKE/repo"
run "$binary" system updates --json | jq -e '.data.aur_helper == "paru" and .data.aur_count == 1' >/dev/null || fail 'paru'
# without any helper: no AUR packages, not an error
rm "$tmp/bin/paru"
run "$binary" system updates --json | jq -e '.data.aur_helper == "" and .data.aur_count == 0 and .data.repo_count == 1' >/dev/null || fail 'no helper'
# checkupdates fails (no network): exit 4 with the text
touch "$FAKE/checkfail"
[[ "$(code "$binary" system updates)" == 4 ]] || fail 'checkupdates failing exits 4'
{ run "$binary" system updates --json || true; } | jq -e ".exit == 4 and (.data.error | test(\"synchronize\"))" >/dev/null || fail "the error text is in the envelope: $(run "$binary" system updates --json)"
rm "$FAKE/checkfail"
# checkupdates missing (pacman-contrib): exit 4
rm "$tmp/bin/checkupdates"
[[ "$(code "$binary" system updates)" == 4 ]] || fail 'no checkupdates exits 4'
{ run "$binary" system updates || true; } | grep -q 'pacman-contrib' || fail 'the message names pacman-contrib'
# never writes: nothing ran but the checkers
! grep -q 'sudo\|pacman -S\|snapper' "$LOG" || fail "updates changed something: $(cat "$LOG")"
echo "system-updates-test: ok"
