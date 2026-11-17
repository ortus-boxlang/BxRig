#!/usr/bin/env bash
# `bxrig time ...` with fake timedatectl, systemctl, sudo, pacman, yay, tzupdate. Usage: time-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/sd" "$tmp/gc" "$tmp/fake"; export LOG="$tmp/log"; : > "$LOG"
echo UTC > "$tmp/fake/zone"
cat > "$tmp/bin/timedatectl" <<'F'
#!/usr/bin/env bash
echo "timedatectl $*" >> "$LOG"
case "$1" in
  show) printf 'Timezone=%s\nNTP=yes\nNTPSynchronized=yes\nLocalRTC=no\n' "$(cat "$FAKE/zone")" ;;
  list-timezones) printf 'UTC\nEurope/Madrid\nAmerica/New_York\n' ;;
  set-timezone) echo "$2" > "$FAKE/zone" ;;
esac
exit 0
F
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$LOG"\n[[ "$1" == is-active ]] && exit "${ACTIVE:-3}"\nexit 0\n' > "$tmp/bin/systemctl"
stub_sudo_log
cat > "$tmp/bin/pacman" <<'F'
#!/usr/bin/env bash
echo "pacman $*" >> "$LOG"
case "$1" in -Q) exit 1 ;; -Qq) true ;; esac
exit 0
F
printf '#!/usr/bin/env bash\necho "yay $*" >> "$LOG"\n' > "$tmp/bin/yay"
printf '#!/usr/bin/env bash\necho "tzupdate $*" >> "$LOG"\necho Europe/Madrid > "$FAKE/zone"\n' > "$tmp/tzupdate.real"
stub_id
printf '#!/usr/bin/env bash\necho x86_64\n' > "$tmp/bin/uname"; printf 'ID=cachyos\n' > "$tmp/os"
chmod +x "$tmp/bin"/* "$tmp/tzupdate.real"
run() { env HOME="$tmp/home" USER=dev BXRIG_OS_RELEASE="$tmp/os" BXRIG_STATE_HOME="$tmp/state" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_SYSTEMD_DIR="$tmp/sd" BXRIG_GEOCLUE_DIR="$tmp/gc" PATH="$tmp/bin:$PATH" LOG="$LOG" FAKE="$tmp/fake" ACTIVE="${ACTIVE:-3}" "$@"; }
has() { grep -qF -- "$1" "$LOG"; }

run "$binary" time status --json | jq -e '.data.timezone == "UTC" and .data.ntp and (.data.automatic_zone | not)' >/dev/null || fail 'status'
[[ "$(code "$binary" time nonsense)" == 2 ]] || fail 'usage exits 2'
run "$binary" time zone | grep -qx UTC || fail 'zone shows the current one'
run "$binary" time zone --list | grep -qx 'Europe/Madrid' || fail 'zone --list'

# ---- zone: a plan without --yes, validated against the list ----
[[ "$(code "$binary" time zone Europe/Madrid)" == 2 ]] || fail 'zone without --yes is a plan'
[[ "$(cat "$tmp/fake/zone")" == UTC ]] || fail 'the plan changed the zone'
[[ "$(code "$binary" time zone Mars/Olympus --yes)" == 4 ]] || fail 'an unknown zone exits 4'
run "$binary" time zone Europe/Madrid --dry-run --json | jq -e '.dry_run and (.data.commands[0] == "sudo timedatectl set-timezone Europe/Madrid")' >/dev/null || fail 'dry run'
run "$binary" time zone America/New_York --yes >/dev/null; [[ "$(cat "$tmp/fake/zone")" == America/New_York ]] && has 'sudo timedatectl set-timezone America/New_York' || fail 'zone set'

# ---- ntp ----
run "$binary" time ntp off --yes >/dev/null; has 'timedatectl set-ntp false' || fail 'ntp off'
[[ "$(code "$binary" time ntp maybe)" == 2 ]] || fail 'bad ntp'

# ---- sync: tzupdate (installed from the AUR when missing) ----
echo UTC > "$tmp/fake/zone"; : > "$LOG"
run "$binary" time sync --dry-run | grep -q 'install tzupdate' || fail 'sync plan mentions the install'
cp "$tmp/tzupdate.real" "$tmp/bin/tzupdate"
run "$binary" time sync --yes | grep -q 'UTC -> Europe/Madrid' || fail "sync changes the zone: $(cat "$LOG")"
has 'sudo tzupdate' || fail 'sync runs tzupdate with sudo'

# ---- auto on: geoclue + automatic-timezoned, a unit and a geoclue drop-in ----
: > "$LOG"
[[ "$(code "$binary" time auto on)" == 2 ]] || fail 'auto on without --yes is a plan'
[[ ! -e "$tmp/sd/automatic-timezoned.service" ]] || fail 'the plan wrote the unit'
run "$binary" time auto on --dry-run | grep -q '^Privacy:' || fail 'the plan states the privacy tradeoff'
run "$binary" time auto on --yes >/dev/null
grep -q '^ExecStart=/usr/bin/automatic-timezoned$' "$tmp/sd/automatic-timezoned.service" && grep -q '^Requires=geoclue.service$' "$tmp/sd/automatic-timezoned.service" || fail 'unit file'
grep -q '^whitelist=$' "$tmp/gc/90-bxrig-timezone.conf" && grep -q '^\[automatic-timezoned\]$' "$tmp/gc/90-bxrig-timezone.conf" && grep -q '^allowed=true$' "$tmp/gc/90-bxrig-timezone.conf" || fail 'geoclue drop-in'
has 'pacman -S --needed --noconfirm geoclue' && has 'yay' && has 'automatic-timezoned' || fail "install steps: $(cat "$LOG")"
has 'sudo systemctl enable --now automatic-timezoned.service' || fail 'the service is enabled'
ACTIVE=0 run "$binary" time status --json | jq -e '.data.automatic_zone' >/dev/null || fail 'status sees the daemon'

# ---- auto off ----
: > "$LOG"; run "$binary" time auto off --yes >/dev/null
has 'systemctl disable --now automatic-timezoned.service' && [[ ! -e "$tmp/sd/automatic-timezoned.service" && ! -e "$tmp/gc/90-bxrig-timezone.conf" ]] || fail 'auto off removes the files'
# ---- time format: the bar clock's text (a setting: acts at once, rewrites the Noctalia config) ----
run "$binary" time format --json | jq -e '.data.format == "%b %-d - %H:%M" and .data.default_format == "%b %-d - %H:%M" and (.data.sample | length) > 0' >/dev/null || fail 'time format shows the default'
[[ ! -e "$tmp/cfg/noctalia/config.toml" ]] || fail 'reading the format wrote a file'
run "$binary" time format "%a %-I:%M %p" --dry-run --json | jq -e '.dry_run and .data.format == "%a %-I:%M %p"' >/dev/null || fail 'time format dry run'
[[ ! -e "$tmp/cfg/bxrig/appearance.json" ]] || fail 'a dry run saved the format'
run "$binary" time format "%a %-I:%M %p" --json | jq -e '.ok and .data.config.state == "written"' >/dev/null || fail 'time format set'
grep -qF 'format = "%a %-I:%M %p"' "$tmp/cfg/noctalia/config.toml" || fail "the format is in the clock plugin setting: $(grep -n format "$tmp/cfg/noctalia/config.toml")"
jq -e '.bar.time_format == "%a %-I:%M %p"' "$tmp/cfg/bxrig/appearance.json" >/dev/null || fail 'the format is remembered'
run "$binary" time format "MMM d - HH:mm" --json | jq -e '.data.format == "%b %-d - %H:%M"' >/dev/null || fail 'MMM d - HH:mm is read as a pattern'
run "$binary" time format default >/dev/null; grep -qF 'format = "%b %-d - %H:%M"' "$tmp/cfg/noctalia/config.toml" || fail 'default resets the format'
[[ "$(code "$binary" time format a b)" == 2 ]] || fail 'two words exit 2'
echo "time-test: ok"
