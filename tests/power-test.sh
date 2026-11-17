#!/usr/bin/env bash
# `bxrig power ...` with fake powerprofilesctl, systemctl, sudo and a fake /sys and /proc. Usage: power-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/sys/BAT0" "$tmp/sys/AC" "$tmp/logind"; export LOG="$tmp/log"; : > "$LOG"
echo 82 > "$tmp/sys/BAT0/capacity"; echo Discharging > "$tmp/sys/BAT0/status"
# energy based battery: 40 Wh now, 50 Wh full, 53.2 Wh when new, 10 W draw -> 4 h left; health 94 %; no charge limit file yet
echo 40000000 > "$tmp/sys/BAT0/energy_now"; echo 50000000 > "$tmp/sys/BAT0/energy_full"; echo 53200000 > "$tmp/sys/BAT0/energy_full_design"
echo 10000000 > "$tmp/sys/BAT0/power_now"; echo 212 > "$tmp/sys/BAT0/cycle_count"
echo Mains > "$tmp/sys/AC/type"; echo 0 > "$tmp/sys/AC/online"
printf 'MemTotal:       16000000 kB\nSwapTotal:       8000000 kB\n' > "$tmp/meminfo"
# /proc/swaps: a zram device (does not count) and an 8 GB partition; the kernel command line, /sys/power and the lockdown file
printf 'Filename\t\t\t\tType\t\tSize\t\tUsed\t\tPriority\n/dev/zram0\t\t\t\tpartition\t16000000\t0\t\t100\n/dev/nvme0n1p3\t\t\t\tpartition\t8000000\t0\t\t-2\n' > "$tmp/swaps"
echo 'BOOT_IMAGE=/vmlinuz root=UUID=abc rw quiet resume=UUID=def' > "$tmp/cmdline"
mkdir -p "$tmp/syspower"; echo 'freeze mem disk' > "$tmp/syspower/state"
echo '[none] integrity confidentiality' > "$tmp/lockdown"
cat > "$tmp/bin/powerprofilesctl" <<'F'
#!/usr/bin/env bash
echo "powerprofilesctl $*" >> "$LOG"
[[ "$1" == get ]] && echo balanced
exit 0
F
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$LOG"\n[[ "$1" == is-active ]] && exit "${ACTIVE:-0}"\nexit 0\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\necho "sudo $*" >> "$LOG"\nexec "$@"\n' > "$tmp/bin/sudo"
printf '#!/usr/bin/env bash\necho "pacman $*" >> "$LOG"\n' > "$tmp/bin/pacman"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" BXRIG_POWER_DIR="${POWER_DIR:-$tmp/sys}" BXRIG_LOGIND_DIR="$tmp/logind" BXRIG_MEMINFO="$tmp/meminfo" BXRIG_SWAPS="$tmp/swaps" BXRIG_CMDLINE="$tmp/cmdline" \
	BXRIG_SYS_POWER="$tmp/syspower" BXRIG_LOCKDOWN="$tmp/lockdown" BXRIG_SYSTEMD_DIR="$tmp/systemd" PATH="$tmp/bin:$PATH" LOG="$LOG" ACTIVE="${ACTIVE:-0}" "$@"; }
has() { grep -qF -- "$1" "$LOG"; }

run "$binary" power status --json | jq -e '(.data.battery[0].percent == 82) and .data.profile == "balanced" and .data.lid == "default"' >/dev/null || fail 'status'
# the details: charge, state, time left, watts, health, cycles; no charge limit file yet; on battery
run "$binary" power status --json | jq -e '.data.battery[0] | (.name == "BAT0" and .state == "discharging" and .watts == 10 and .time_remaining_minutes == 240 and .health_percent == 94 and .cycles == 212 and .charge_limit == -1 and (.charge_limit_supported | not))' >/dev/null || fail "battery details: $(run "$binary" power status --json)"
run "$binary" power status --json | jq -e '(.data.on_ac | not) and (.data.charge_limit_supported | not) and .data.lid_battery == "default" and .data.lid_ac == "default"' >/dev/null || fail 'status: on_ac, lid on battery and AC'
run "$binary" power status | grep -q 'battery BAT0: 82% discharging, 4 h 0 min left, 10 W' || fail "status text: $(run "$binary" power status)"
# charging and on AC: time to full from the energy still missing (10 Wh at 10 W = 1 h)
echo Charging > "$tmp/sys/BAT0/status"; echo 1 > "$tmp/sys/AC/online"
run "$binary" power status --json | jq -e '.data.on_ac and .data.battery[0].state == "charging" and .data.battery[0].time_remaining_minutes == 60' >/dev/null || fail 'charging: time to full'
echo Discharging > "$tmp/sys/BAT0/status"; echo 0 > "$tmp/sys/AC/online"
# a battery that reports charge and current instead of energy and power (micro-Ah, micro-A, micro-V), first with nothing known
mkdir -p "$tmp/sys2/BAT1"; echo 50 > "$tmp/sys2/BAT1/capacity"; echo "Not charging" > "$tmp/sys2/BAT1/status"
POWER_DIR="$tmp/sys2" run "$binary" power status --json | jq -e '.data.battery[0] | (.state == "not_charging" and .watts == -1 and .time_remaining_minutes == -1 and .health_percent == -1 and .cycles == -1)' >/dev/null || fail 'unknown values are -1'
echo 2000000 > "$tmp/sys2/BAT1/charge_now"; echo 4000000 > "$tmp/sys2/BAT1/charge_full"; echo 5000000 > "$tmp/sys2/BAT1/charge_full_design"; echo 1000000 > "$tmp/sys2/BAT1/current_now"; echo 12000000 > "$tmp/sys2/BAT1/voltage_now"; echo Discharging > "$tmp/sys2/BAT1/status"
POWER_DIR="$tmp/sys2" run "$binary" power status --json | jq -e '.data.battery[0] | (.watts == 12 and .time_remaining_minutes == 120 and .health_percent == 80)' >/dev/null || fail "charge based battery: $(POWER_DIR="$tmp/sys2" run "$binary" power status --json)"
[[ "$(code "$binary" power nonsense)" == 2 ]] || fail 'usage exits 2'

# ---- profile ----
run "$binary" power profile saver >/dev/null; has 'powerprofilesctl set power-saver' || fail 'saver is power-saver'
run "$binary" power profile performance >/dev/null; has 'powerprofilesctl set performance' || fail 'performance'
run "$binary" power profile --json | jq -e '.data.profile == "balanced"' >/dev/null || fail 'profile shows the current one'
[[ "$(code "$binary" power profile turbo)" == 2 ]] || fail 'bad profile exits 2'
run "$binary" power profile saver --dry-run --json | jq -e '.dry_run and (.data.command == "powerprofilesctl set power-saver")' >/dev/null || fail 'profile dry run'

# ---- lid: a logind drop-in, only with --yes ----
[[ "$(code "$binary" power lid lock)" == 2 ]] || fail 'lid without --yes exits 2'
[[ ! -e "$tmp/logind/50-bxrig-lid.conf" ]] || fail 'lid wrote without --yes'
run "$binary" power lid lock --dry-run >/dev/null; [[ ! -e "$tmp/logind/50-bxrig-lid.conf" ]] || fail 'dry run wrote'
run "$binary" power lid lock --yes >/dev/null
grep -q '^HandleLidSwitch=lock$' "$tmp/logind/50-bxrig-lid.conf" && grep -q '^HandleLidSwitchExternalPower=lock$' "$tmp/logind/50-bxrig-lid.conf" && grep -q '^HandleLidSwitchDocked=ignore$' "$tmp/logind/50-bxrig-lid.conf" || fail "lid file: $(cat "$tmp/logind/50-bxrig-lid.conf")"
has 'sudo install -Dm644' || fail 'the file is written with sudo install'
run "$binary" power status --json | jq -e '.data.lid == "lock"' >/dev/null || fail 'status reads the lid action back'
[[ "$(code "$binary" power lid sideways --yes)" == 2 ]] || fail 'bad lid action'

# ---- setup: only with a battery ----
: > "$LOG"; POWER_DIR="$tmp/none" run "$binary" power setup --yes --json | jq -e '.data.skipped == "no battery"' >/dev/null || fail 'a desktop skips setup'
! has 'pacman' || fail 'a desktop installed packages'
[[ "$(code "$binary" power setup)" == 2 ]] || fail 'setup without --yes is a plan (2)'
run "$binary" power setup --dry-run | grep -q 'pacman -S --needed --noconfirm power-profiles-daemon upower' || fail 'plan lists the packages'
: > "$LOG"; run "$binary" power setup --yes >/dev/null
has 'sudo pacman -S --needed --noconfirm power-profiles-daemon upower' && has 'sudo systemctl enable --now power-profiles-daemon.service upower.service' || fail "setup: $(cat "$LOG")"
: > "$LOG"; POWER_DIR="$tmp/none" run "$binary" power setup --yes --force >/dev/null; has 'pacman -S' || fail '--force installs on a desktop'

# ---- doctor ----
run "$binary" power doctor --json | jq -e '(.data.checks | map(select(.id == "hibernation" and (.ok | not))) | length == 1) and (.data.checks | map(select(.id == "battery")) | length == 1)' >/dev/null || fail 'doctor flags swap smaller than RAM'
# zram does not count: SwapTotal says 24 GB (zram 16 + disk 8) but only the 8 GB partition is disk swap
printf 'MemTotal:       16000000 kB\nSwapTotal:      24000000 kB\n' > "$tmp/meminfo"
run "$binary" power doctor --json | jq -e '.data.checks | map(select(.id == "hibernation" and (.ok | not))) | length == 1' >/dev/null || fail 'zram is not disk swap'
printf 'Filename\tType\tSize\tUsed\tPriority\n/dev/zram0\tpartition\t16000000\t0\t100\n/dev/nvme0n1p3\tpartition\t16000000\t0\t-2\n' > "$tmp/swaps"
run "$binary" power doctor --json | jq -e '.data.checks | map(select(.id == "hibernation" and .ok)) | length == 1' >/dev/null || fail 'doctor accepts enough swap'
ACTIVE=3 run "$binary" power doctor --json | jq -e '.data.problems >= 2' >/dev/null || fail 'inactive daemons are problems'
POWER_DIR="$tmp/none" run "$binary" power doctor --json | jq -e '(.data.checks | map(.id) | index("hibernation")) == null' >/dev/null || fail 'a desktop skips the laptop checks'
# ---- lid on battery and on AC power ----
# (the earlier `lid lock` wrote both sides as lock)
run "$binary" power lid battery hibernate --yes >/dev/null
grep -q '^HandleLidSwitch=hibernate$' "$tmp/logind/50-bxrig-lid.conf" && grep -q '^HandleLidSwitchExternalPower=lock$' "$tmp/logind/50-bxrig-lid.conf" || fail "lid battery: $(cat "$tmp/logind/50-bxrig-lid.conf")"
run "$binary" power status --json | jq -e '.data.lid_battery == "hibernate" and .data.lid_ac == "lock" and .data.lid == "mixed"' >/dev/null || fail 'status reads both lid actions'
run "$binary" power lid ac ignore --yes >/dev/null
grep -q '^HandleLidSwitch=hibernate$' "$tmp/logind/50-bxrig-lid.conf" && grep -q '^HandleLidSwitchExternalPower=ignore$' "$tmp/logind/50-bxrig-lid.conf" || fail 'lid ac keeps the battery side'
[[ "$(code "$binary" power lid ac lock)" == 2 ]] || fail 'lid ac without --yes is a plan'
run "$binary" power lid ac lock --dry-run --json | jq -e '.dry_run and .data.scope == "ac" and .data.battery == "hibernate" and .data.ac == "lock"' >/dev/null || fail 'lid ac plan data'
[[ "$(code "$binary" power lid ac)" == 2 && "$(code "$binary" power lid ac sideways --yes)" == 2 && "$(code "$binary" power lid sideways ac --yes)" == 2 && "$(code "$binary" power lid battery lock extra --yes)" == 2 ]] || fail 'bad lid usage exits 2'
rm -f "$tmp/logind/50-bxrig-lid.conf"
run "$binary" power lid ac lock --yes >/dev/null
grep -q '^HandleLidSwitch=suspend$' "$tmp/logind/50-bxrig-lid.conf" && grep -q '^HandleLidSwitchExternalPower=lock$' "$tmp/logind/50-bxrig-lid.conf" || fail 'with no drop-in the other side is written as suspend (the systemd default)'
run "$binary" power lid suspend --yes >/dev/null
run "$binary" power status --json | jq -e '.data.lid == "suspend"' >/dev/null || fail 'lid ACTION sets both again'

# ---- hibernate: ready (16 GB disk swap, resume= on the command line, the disk state, no lockdown) ----
: > "$LOG"
[[ "$(code "$binary" power hibernate)" == 2 ]] || fail 'hibernate without --yes is a plan (2)'
! has 'hibernate' || fail 'hibernate ran without --yes'
run "$binary" power hibernate --dry-run --json | jq -e '.dry_run and .data.ready and .data.command == "systemctl hibernate --no-block"' >/dev/null || fail 'hibernate dry run'
run "$binary" power hibernate --yes >/dev/null; has 'systemctl hibernate --no-block' || fail "hibernate --yes: $(cat "$LOG")"
# not ready: each check exits 4 and says why
echo 'BOOT_IMAGE=/vmlinuz root=UUID=abc rw quiet' > "$tmp/cmdline"
[[ "$(code "$binary" power hibernate --yes)" == 4 ]] || fail 'no resume= exits 4'
out="$(run "$binary" power hibernate --json || true)"   # exit 4 would fail the pipe
jq -e '(.ok | not) and (.data.ready | not) and (.data.error | test("resume=")) and (.data.checks | map(select(.id == "resume" and (.ok | not))) | length == 1)' <<<"$out" >/dev/null || fail 'hibernate says why'
echo 'BOOT_IMAGE=/vmlinuz root=UUID=abc rw resume=UUID=def' > "$tmp/cmdline"
printf 'Filename\tType\tSize\tUsed\tPriority\n/swapfile\tfile\t16000000\t0\t-2\n' > "$tmp/swaps"
[[ "$(code "$binary" power hibernate --yes)" == 4 ]] || fail 'a swap file needs resume_offset= (exit 4)'
echo 'BOOT_IMAGE=/vmlinuz root=UUID=abc rw resume=UUID=def resume_offset=123' > "$tmp/cmdline"
[[ "$(code "$binary" power hibernate --dry-run)" == 0 ]] || fail 'a swap file with resume_offset= is ready'
printf 'Filename\tType\tSize\tUsed\tPriority\n/dev/zram0\tpartition\t16000000\t0\t100\n' > "$tmp/swaps"
[[ "$(code "$binary" power hibernate --yes)" == 4 ]] || fail 'zram only exits 4'
printf 'Filename\tType\tSize\tUsed\tPriority\n/dev/nvme0n1p3\tpartition\t16000000\t0\t-2\n' > "$tmp/swaps"
echo 'freeze mem' > "$tmp/syspower/state"; [[ "$(code "$binary" power hibernate --yes)" == 4 ]] || fail 'no disk state exits 4'
echo 'freeze mem disk' > "$tmp/syspower/state"
echo 'none [integrity] confidentiality' > "$tmp/lockdown"; [[ "$(code "$binary" power hibernate --yes)" == 4 ]] || fail 'kernel lockdown exits 4'
run "$binary" power doctor --json | jq -e '.data.checks | map(select(.id == "hibernate-kernel" and (.ok | not))) | length == 1' >/dev/null || fail 'doctor reports the lockdown'
echo '[none] integrity confidentiality' > "$tmp/lockdown"
[[ "$(code "$binary" power hibernate --dry-run)" == 0 ]] || fail 'ready again'

# ---- charge limit (kernel attribute charge_control_end_threshold); this battery has none yet ----
[[ "$(code "$binary" power charge-limit 80 --yes)" == 4 ]] || fail 'no charge_control_end_threshold exits 4'
out="$(run "$binary" power charge-limit 80 --yes --json || true)"
jq -e '(.ok | not) and (.data.error | test("no charge limit"))' <<<"$out" >/dev/null || fail 'the unsupported message'
run "$binary" power charge-limit status --json | jq -e '.ok and (.data.supported | not) and .data.limit == -1' >/dev/null || fail 'status on an unsupported battery is information, not an error'
run "$binary" power doctor --json | jq -e '.data.checks | map(select(.id == "charge-limit")) | length == 1' >/dev/null || fail 'doctor mentions the charge limit'
echo 100 > "$tmp/sys/BAT0/charge_control_end_threshold"
run "$binary" power status --json | jq -e '.data.charge_limit_supported and .data.battery[0].charge_limit == 100 and .data.battery[0].charge_limit_supported' >/dev/null || fail 'status shows the charge limit'
run "$binary" power charge-limit status --json | jq -e '.data.supported and .data.limit == 100 and (.data.persisted | not)' >/dev/null || fail 'charge-limit status'
[[ "$(code "$binary" power charge-limit 80)" == 2 ]] || fail 'charge-limit without --yes is a plan (2)'
[[ ! -e "$tmp/systemd/bxrig-charge-limit.service" ]] || fail 'a plan wrote the unit'
run "$binary" power charge-limit 80 --dry-run | grep -q 'bxrig-charge-limit.service' || fail 'the plan names the unit'
for bad in 39 101 abc -5 80%; do [[ "$(code "$binary" power charge-limit $bad --yes)" == 2 ]] || fail "charge-limit '$bad' exits 2"; done
[[ "$(code "$binary" power charge-limit 80 90 --yes)" == 2 ]] || fail 'too many arguments exit 2'
: > "$LOG"; run "$binary" power charge-limit 80 --yes >/dev/null
u="$tmp/systemd/bxrig-charge-limit.service"
grep -q 'echo 80 >' "$u" && grep -q 'charge_control_end_threshold' "$u" && grep -q '^Type=oneshot$' "$u" && grep -q '^WantedBy=multi-user.target suspend.target hibernate.target' "$u" && grep -q '\$\$f' "$u" || fail "unit: $(cat "$u")"
has 'sudo install -Dm644' && has 'sudo systemctl daemon-reload' && has 'sudo systemctl enable --now bxrig-charge-limit.service' || fail "persisting: $(cat "$LOG")"
run "$binary" power charge-limit status --json | jq -e '.data.persisted and .data.persisted_percent == 80' >/dev/null || fail 'status reads the unit back'
echo 80 > "$tmp/sys/BAT0/charge_control_end_threshold"
: > "$LOG"; run "$binary" power charge-limit off --yes >/dev/null
[[ "$(cat "$tmp/sys/BAT0/charge_control_end_threshold")" == 100 ]] || fail 'off writes 100 to the attribute'
[[ ! -e "$u" ]] || fail 'off removes the unit'
has 'sudo systemctl disable --now bxrig-charge-limit.service' || fail "off disables the unit: $(cat "$LOG")"
: > "$LOG"; run "$binary" power charge-limit 100 --yes >/dev/null; ! has 'disable --now' || fail '100 with no unit does not call disable'
echo "power-test: ok"
