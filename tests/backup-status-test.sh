#!/usr/bin/env bash
# `bxrig backup status` with fake snapper, systemctl, restic, pacman and findmnt: one row per kind, last and next run, size, health. Usage: backup-status-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
H="$tmp/home"; mkdir -p "$tmp/bin" "$H" "$tmp/disk" "$tmp/fake"; export LOG="$tmp/log"; : > "$LOG"; export FAKEDIR="$tmp/fake"
mkdir -p "$H/Documents"; NOW="$(date +%s)"
utc() { date -u -d "@$1" '+%Y-%m-%d %H:%M:%S'; }   # snapper prints dates like this
cat > "$tmp/snapper.real" <<'F'
#!/usr/bin/env bash
echo "snapper $*" >> "$LOG"
case "$*" in
  *list-configs*) [[ -e "$FAKEDIR/configured" ]] && echo root ;;
  *"-c root list"*) if [[ -s "$FAKEDIR/snaps" ]]; then cat "$FAKEDIR/snaps"; else echo '{"root":[{"number":0,"type":"single","date":"","description":"current"}]}'; fi ;;
esac
F
cat > "$tmp/bin/systemctl" <<'F'
#!/usr/bin/env bash
echo "systemctl $*" >> "$LOG"
case " $* " in
  *" show "*) echo "@${NEXT:-0}"; exit 0 ;;
  *" is-active "*) unit="${@: -1}"
     if [[ -f "$FAKEDIR/failed-$unit" ]]; then echo failed; exit 3; fi
     if [[ -f "$FAKEDIR/active-$unit" ]]; then echo active; exit 0; fi
     echo inactive; exit 3 ;;
esac
exit 0
F
cat > "$tmp/bin/restic" <<'F'
#!/usr/bin/env bash
echo "restic $*" >> "$LOG"
case "$1" in backup) [[ -e "$FAKEDIR/resticfail" ]] && { echo "Fatal: repository is locked" >&2; exit 1; } ;; esac
exit 0
F
printf '#!/usr/bin/env bash\ncase "$1" in -Qqe|-Qqm) echo git ;; esac\n' > "$tmp/bin/pacman"
printf '#!/usr/bin/env bash\necho "findmnt $*" >> "$LOG"\n' > "$tmp/bin/findmnt"
stub_id
chmod +x "$tmp/bin"/*
run() { env HOME="$H" USER=dev BXRIG_CONFIG_HOME="$H/.config" BXRIG_DATA_HOME="$tmp/data" BXRIG_SELF=/usr/bin/bxrig BXRIG_NOW_EPOCH="${NOWE:-$NOW}" BXRIG_ROOT_FS=btrfs PATH="$tmp/bin:$PATH" LOG="$LOG" FAKEDIR="$FAKEDIR" NEXT="${NEXT:-0}" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1 < /dev/null; local c=$?; set -e; echo "$c"; }
row() { jq -c --arg id "$1" '.data.rows[] | select(.id == $id)'; }   # one row of the JSON on stdin

# ---- nothing is set up: three rows, nothing to judge ----
[[ "$(code "$binary" backup status)" == 0 ]] || fail 'status exits 0'
[[ "$(code "$binary" backup status extra)" == 2 ]] || fail 'status takes no words'
run "$binary" backup status --json | jq -e '(.data.rows | map(.id)) == ["config","system","data"] and .data.health == "none" and .data.warn_count == 0' >/dev/null || fail "empty: $(run "$binary" backup status --json)"
run "$binary" backup status --json | row system | jq -e '.health == "none" and .configured == false and .action == [] and (.note | test("snapshot tool"))' >/dev/null || fail 'system without a tool'
run "$binary" backup status --json | row data | jq -e '.health == "none" and .configured == false and .action == [] and (.note | test("backup place"))' >/dev/null || fail 'data without a target'
run "$binary" backup status --json | row config | jq -e '.health == "none" and .count == 0 and .action == ["backup","config","now"] and .next == "before the next update"' >/dev/null || fail 'config without a snapshot'
run "$binary" backup status | grep -q '^Config snapshots: none, last never, next before the next update' || fail 'text line'

# ---- config: a snapshot makes it ok; old makes it warn; automatic off makes next manual ----
run "$binary" backup config now --reason=first >/dev/null
run "$binary" backup status --json | row config | jq -e '.health == "ok" and .count == 1 and .last_epoch > 0 and .last_ago == "just now" and .size > 0 and (.size_text | length > 0) and (.last | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T"))' >/dev/null || fail "config ok: $(run "$binary" backup status --json | row config)"
NOWE=$(( NOW + 40 * 86400 )) run "$binary" backup status --json | row config | jq -e '.health == "warn" and (.note | test("older than 30d"))' >/dev/null || fail 'config older than 30 days warns'
run "$binary" backup config auto off >/dev/null
run "$binary" backup status --json | row config | jq -e '.next == "manual"' >/dev/null || fail 'auto off: next is manual'
run "$binary" backup config auto on >/dev/null

# ---- system: snapper with a timeline timer ----
cp "$tmp/snapper.real" "$tmp/bin/snapper"; chmod +x "$tmp/bin/snapper"
run "$binary" backup status --json | row system | jq -e '.tool == "snapper" and .configured == false and .health == "none" and (.note | test("no configuration"))' >/dev/null || fail 'snapper without a config'
touch "$FAKEDIR/configured"
run "$binary" backup status --json | row system | jq -e '.configured == true and .count == 0 and .health == "none" and .note == "no snapshot yet" and .action == ["backup","snapshots","create","--yes"]' >/dev/null || fail "snapper without snapshots: $(run "$binary" backup status --json | row system)"
printf '{"root":[{"number":0,"type":"single","date":"","description":"current"},{"number":7,"type":"single","date":"%s","description":"timeline"},{"number":6,"type":"single","date":"%s","description":"timeline"}]}\n' "$(utc $(( NOW - 3 * 3600 )))" "$(utc $(( NOW - 30 * 3600 )))" > "$FAKEDIR/snaps"
touch "$FAKEDIR/active-snapper-timeline.timer"
NEXT=$(( NOW + 1500 )) run "$binary" backup status --json | row system | jq -e '.health == "ok" and .count == 2 and .last_ago == "3 hours ago" and .next == "in 25m" and .next_epoch > 0' >/dev/null || fail "system ok: $(NEXT=$(( NOW + 1500 )) run "$binary" backup status --json | row system)"
NOWE=$(( NOW + 3 * 86400 )) run "$binary" backup status --json | row system | jq -e '.health == "warn"' >/dev/null || fail 'system older than 2 days warns when the timeline runs'
rm "$FAKEDIR/active-snapper-timeline.timer"
NOWE=$(( NOW + 3 * 86400 )) run "$binary" backup status --json | row system | jq -e '.health == "ok" and .next == "none"' >/dev/null || fail 'without the timer the limit is 14 days'
touch "$FAKEDIR/active-snapper-timeline.timer"

# ---- data: a target, the schedule, recorded runs ----
run "$binary" backup data target add usb --type=local --path="$tmp/disk/repo" >/dev/null
run "$binary" backup status --json | row data | jq -e '.configured == true and .health == "none" and .targets == ["usb"] and (.note | test("no backup has run yet")) and .next == "manual"' >/dev/null || fail "data before a run: $(run "$binary" backup status --json | row data)"
run "$binary" backup data init usb --yes >/dev/null
run "$binary" backup data run --yes >"$tmp/o.txt" 2>&1 || fail "backup data run: $(cat "$tmp/o.txt")"
run "$binary" backup status --json | row data | jq -e '.health == "ok" and .last_ago == "just now" and .action == ["backup","data","run","--all","--yes"] and .count == 1' >/dev/null || fail "data ok: $(run "$binary" backup status --json | row data)"
jq -e '.data.runs.usb.ok > 0' "$H/.config/bxrig/backup.json" >/dev/null || fail 'the run is recorded in backup.json'
# the schedule decides the limit and the next run
jq '.data.schedule = "hourly"' "$H/.config/bxrig/backup.json" > "$tmp/b.json" && mv "$tmp/b.json" "$H/.config/bxrig/backup.json"
NEXT=$(( NOW + 3600 )) run "$binary" backup status --json | row data | jq -e '.next == "in 1h" or .next == "in 60m"' >/dev/null || fail "hourly next: $(NEXT=$(( NOW + 3600 )) run "$binary" backup status --json | row data)"
NOWE=$(( NOW + 7 * 3600 )) run "$binary" backup status --json | row data | jq -e '.health == "warn" and (.note | test("older than"))' >/dev/null || fail 'hourly: 7 hours old warns'
jq '.data.schedule = "daily"' "$H/.config/bxrig/backup.json" > "$tmp/b.json" && mv "$tmp/b.json" "$H/.config/bxrig/backup.json"
NOWE=$(( NOW + 7 * 3600 )) run "$binary" backup status --json | row data | jq -e '.health == "ok"' >/dev/null || fail 'daily: 7 hours old is fine'
# a failed run warns, a later success clears it; a failed scheduled unit warns
touch "$FAKEDIR/resticfail"
NOWE=$(( NOW + 60 )) run "$binary" backup data run --yes >/dev/null 2>&1 || true
NOWE=$(( NOW + 61 )) run "$binary" backup status --json | row data | jq -e '.health == "warn" and (.note | test("failed"))' >/dev/null || fail "failed run: $(NOWE=$(( NOW + 61 )) run "$binary" backup status --json | row data)"
rm "$FAKEDIR/resticfail"
NOWE=$(( NOW + 120 )) run "$binary" backup data run --yes >/dev/null
NOWE=$(( NOW + 121 )) run "$binary" backup status --json | row data | jq -e '.health == "ok"' >/dev/null || fail 'a later success clears the warning'
touch "$FAKEDIR/failed-bxrig-backup.service"
run "$binary" backup status --json | row data | jq -e '.health == "warn" and (.note | test("scheduled backup failed"))' >/dev/null || fail 'a failed timer service warns'
rm "$FAKEDIR/failed-bxrig-backup.service"
# without restic
mv "$tmp/bin/restic" "$tmp/restic.off"
run env PATH="$tmp/bin:/usr/bin:/bin" "$binary" backup status --json | row data | jq -e '.health == "warn" and (.note | test("restic"))' >/dev/null || fail 'no restic warns'
mv "$tmp/restic.off" "$tmp/bin/restic"
# the worst row is the overall health
NOWE=$(( NOW + 40 * 86400 )) run "$binary" backup status --json | jq -e '.data.health == "warn" and .data.warn_count >= 2' >/dev/null || fail 'overall health is the worst row'
# a timer-less, tool-less machine still answers
run "$binary" backup status | grep -q '^Files: ok' || fail 'text line for files'
echo "backup-status-test: ok"
