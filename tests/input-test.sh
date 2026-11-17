#!/usr/bin/env bash
# `bxrig input status|offer|apple|logitech|undo` with a fake sysfs (BXRIG_SYS_HID, BXRIG_SYS_INPUT, BXRIG_SYS_MODULE, BXRIG_HID_DRIVERS) and fake tools. Usage: input-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/st" "$tmp/mp" "$tmp/udev"; export LOG="$tmp/log" PKGS="$tmp/pkgs"; : > "$LOG"; : > "$PKGS"
stub_id; stub_sudo_log
stub pacman 'case "$1" in -Qq) cat "$PKGS" ;; *) echo "pacman $*" >> "$LOG" ;; esac'
stub yay 'echo "yay $*" >> "$LOG"'
stub systemctl 'echo "systemctl $*" >> "$LOG"; [[ "$*" == "is-active bluetooth" ]] && echo "${BT:-active}"; exit 0'
stub modinfo 'exit 1'
chmod +x "$tmp/bin"/*
# a fake sysfs: mk DIR NAME DRIVER HID_ID HID_NAME
mk() { mkdir -p "$1/hid/$2"; printf 'DRIVER=%s\nHID_ID=%s\nHID_NAME=%s\n' "$3" "$4" "$5" > "$1/hid/$2/uevent"; }
bat() { mkdir -p "$1/hid/$2/power_supply/b"; echo "$3" > "$1/hid/$2/power_supply/b/capacity"; echo "${4:-Discharging}" > "$1/hid/$2/power_supply/b/status"; }
sys() { local d="$tmp/sys-$1"; mkdir -p "$d/hid" "$d/in" "$d/mod" "$d/drv"; echo "$d"; }
none="$(sys none)"
apple="$(sys apple)"
mk "$apple" 0005:05AC:0265.0001 magicmouse 0005:000005AC:00000265 'Magic Mouse 2'; bat "$apple" 0005:05AC:0265.0001 83
mk "$apple" 0005:05AC:0314.0002 magicmouse 0005:000005AC:00000314 'Magic Trackpad 2'
mk "$apple" 0003:05AC:0250.0003 apple 0003:000005AC:00000250 'Apple Internal Keyboard / Trackpad'
logi="$(sys logi)"
mk "$logi" 0003:046D:C52B.0001 hid-generic 0003:0000046D:0000C52B 'Logitech USB Receiver'
mk "$logi" 0003:046D:C52B.0002 hid-generic 0003:0000046D:0000C52B 'Logitech USB Receiver Mouse'
mk "$logi" 0003:046D:C52B.0003 hid-generic 0003:0000046D:0000C52B 'Logitech USB Receiver Keyboard'
mk "$logi" 0005:046D:B034.0004 hid-generic 0005:0000046D:0000B034 'MX Master 3S'; bat "$logi" 0005:046D:B034.0004 64
nogame="$(sys nogame)"; cp -r "$logi"/hid/. "$nogame/hid/"
mk "$logi" 0003:046D:C08B.0005 hid-generic 0003:0000046D:0000C08B 'Logitech G502 HERO Gaming Mouse'
both="$(sys both)"; cp -r "$apple"/hid/. "$both/hid/"; cp -r "$logi"/hid/. "$both/hid/"
SYS="$none"
run() { env HOME="$tmp/home" BXRIG_STATE_HOME="$tmp/st" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_SYS_HID="$SYS/hid" BXRIG_SYS_INPUT="$SYS/in" BXRIG_SYS_MODULE="$SYS/mod" BXRIG_HID_DRIVERS="$SYS/drv" \
	BXRIG_MODPROBE_DIR="$tmp/mp" BXRIG_UDEV_DIR="$tmp/udev" BXRIG_DESKTOP="${DESK:-}" PATH="$tmp/bin:$PATH" LOG="$LOG" PKGS="$PKGS" "$@"; }
rj() { run "$@" || true; }
logged() { grep -qF -- "$1" "$LOG"; }

# ---- nothing plugged in ----
rj "$binary" input status --json | jq -e '.ok and (.data.devices | length) == 0 and .data.drivers.hid_magicmouse.state == "absent" and .data.helpers.solaar == false and (.data.missing | length) == 0' >/dev/null || fail "status with nothing: $(rj "$binary" input status --json)"
rj "$binary" input status | grep -q 'none found' || fail 'status text with nothing'
[[ "$(code "$binary" input offer)" == 0 ]] || fail 'offer with no device exits 0'
rj "$binary" input offer | grep -q 'nothing to offer' || fail 'offer with no device says so'
[[ "$(code "$binary" input offer --for=none)" == 0 ]] || fail 'offer --for=none exits 0'
# a choice made by hand works without a device
[[ "$(code "$binary" input offer --for=logitech)" == 2 ]] || fail 'offer --for=logitech is a plan (exit 2)'
rj "$binary" input offer --for=logitech --json | jq -e '.exit == 2 and (.data.install == ["solaar","upower"]) and .data.requested == "logitech"' >/dev/null || fail "forced logitech: $(rj "$binary" input offer --for=logitech --json)"
rj "$binary" input offer --for=apple --json | jq -e '(.data.install | index("libinput-gestures")) != null and (.data.install | index("solaar")) == null' >/dev/null || fail 'forced apple'
[[ "$(code "$binary" input offer --for=nope)" == 2 ]] || fail 'a bad --for exits 2'
[[ "$(code "$binary" input)" == 2 ]] || fail 'input alone is usage'
[[ "$(code "$binary" input bogus)" == 2 ]] || fail 'an unknown input word is usage'
[[ "$(code "$binary" input status --nope)" == 2 ]] || fail 'an unknown flag is usage'

# ---- Apple ----
SYS="$apple"
rj "$binary" input status --json | jq -e '(.data.devices | map(.kind)) == ["apple-mouse","apple-trackpad"] and .data.devices[0].battery == 83 and .data.devices[0].battery_source == "kernel" and .data.devices[0].transport == "bluetooth" and .data.devices[1].battery == -1 and .data.detected.trackpad == true' >/dev/null || fail "apple status: $(rj "$binary" input status --json)"
rj "$binary" input status | grep -q 'apple-mouse .*Magic Mouse 2 (Bluetooth)  battery 83% (discharging)' || fail 'apple status text'
rj "$binary" input status --json | jq -e '(.data.devices | map(.name) | index("Apple Internal Keyboard / Trackpad")) == null' >/dev/null || fail 'an Apple device without Magic in the name is not listed'
rj "$binary" input offer --json | jq -e '.exit == 2 and .data.install == ["libinput-gestures","upower"] and (.data.guesses | length) == 0' >/dev/null || fail "apple offer: $(rj "$binary" input offer --json)"
DESK=KDE rj "$binary" input offer --json | jq -e '.data.install == ["upower"]' >/dev/null || fail 'on Plasma the offer has no libinput-gestures'
# --dry-run and a plan change nothing
: > "$LOG"; [[ "$(code "$binary" input offer)" == 2 ]] || fail 'the offer is a plan (exit 2)'
[[ "$(code "$binary" input offer --dry-run)" == 0 ]] || fail '--dry-run exits 0'
[[ ! -s "$LOG" ]] || fail "a plan ran something: $(cat "$LOG")"
rj "$binary" input offer | grep -q 'sudo pacman -S --needed --noconfirm upower' || fail 'the plan shows the pacman command'
rj "$binary" input offer | grep -q 'yay -S --needed --noconfirm libinput-gestures' || fail 'the plan shows the AUR command'
rj "$binary" input offer | grep -q 'Magic devices already work through the kernel driver' || fail 'the plan says Apple works natively'
# an installed helper is not offered again
echo upower > "$PKGS"
rj "$binary" input offer --json | jq -e '.data.install == ["libinput-gestures"] and .data.already_installed == ["upower"]' >/dev/null || fail 'an installed helper is skipped'
: > "$PKGS"
# a helper on the PATH counts as installed
stub libinput-gestures 'exit 0'; stub upower 'exit 1'
rj "$binary" input offer --json | jq -e '.data.install == [] ' >/dev/null || fail 'helpers on the PATH are installed'
[[ "$(code "$binary" input offer)" == 0 ]] || fail 'nothing missing exits 0'
rm "$tmp/bin/libinput-gestures" "$tmp/bin/upower"

# ---- Logitech ----
SYS="$logi"
rj "$binary" input status --json | jq -e '(.data.devices | map(.kind)) == ["logitech-mouse","logitech-mouse","logitech-receiver"] and ([.data.devices[] | select(.kind == "logitech-receiver")] | length) == 1 and ([.data.devices[] | select(.name == "MX Master 3S")][0].battery) == 64 and .data.detected.gaming == true' >/dev/null || fail "logitech status: $(rj "$binary" input status --json)"
rj "$binary" input offer --json | jq -e '.data.install == ["solaar","libratbag","piper","upower"] and (.data.guesses[0] | test("G502.*a guess"))' >/dev/null || fail "logitech offer: $(rj "$binary" input offer --json)"
rj "$binary" input offer | grep -q 'Logi Options+ on a Mac .* On Linux that is Solaar' || fail 'the offer names Logi Options+'
SYS="$nogame"
rj "$binary" input offer --json | jq -e '.data.install == ["solaar","upower"] and (.data.guesses | length) == 0' >/dev/null || fail 'no gaming mouse, no libratbag or Piper'
SYS="$both"
rj "$binary" input offer --json | jq -e '.data.install == ["solaar","libratbag","piper","libinput-gestures","upower"]' >/dev/null || fail 'both brands'
# --yes installs: pacman once for the official packages, yay for the AUR one; undo is remembered
SYS="$logi"; : > "$LOG"
run "$binary" input offer --yes >/dev/null || fail "offer --yes: exit $?"
logged 'sudo pacman -S --needed --noconfirm solaar libratbag piper upower' || fail "the install command: $(cat "$LOG")"
jq -e '(.packages | sort) == ["libratbag","piper","solaar","upower"]' "$tmp/st/bxrig/input-helpers.json" >/dev/null || fail "the state file: $(cat "$tmp/st/bxrig/input-helpers.json" 2>/dev/null)"
[[ "$(code "$binary" input undo)" == 2 ]] || fail 'undo is a plan until --yes'
: > "$LOG"; [[ "$(code "$binary" input undo --dry-run)" == 0 && ! -s "$LOG" ]] || fail 'undo --dry-run changes nothing'
run "$binary" input undo --yes >/dev/null || fail 'undo --yes'
logged 'sudo pacman -Rns --noconfirm' && logged 'solaar' || fail "undo removes the packages: $(cat "$LOG")"
[[ ! -e "$tmp/st/bxrig/input-helpers.json" ]] || fail 'undo forgets the state'
[[ "$(code "$binary" input undo)" == 4 ]] || fail 'nothing to undo exits 4'
# a failing pacman is exit 5
stub pacman 'case "$1" in -Qq) cat "$PKGS" ;; *) exit 1 ;; esac'
[[ "$(code "$binary" input offer --yes)" == 5 ]] || fail 'a failed pacman exits 5'
[[ ! -e "$tmp/st/bxrig/input-helpers.json" ]] || fail 'nothing was installed, nothing is remembered'
stub pacman 'case "$1" in -Qq) cat "$PKGS" ;; *) echo "pacman $*" >> "$LOG" ;; esac'

# ---- paired but not connected (bluetoothctl) and the upower battery ----
SYS="$none"
stub bluetoothctl 'printf "Device AA:BB:CC:DD:EE:01 Magic Keyboard\nDevice AA:BB:CC:DD:EE:02 Some Speaker\nDevice AA:BB:CC:DD:EE:03 MX Anywhere 3\n"'
rj "$binary" input status --json | jq -e '(.data.devices | map(.name)) == ["Magic Keyboard","MX Anywhere 3"] and .data.devices[0].connected == false and .data.devices[0].kind == "apple-keyboard" and .data.devices[1].kind == "logitech-mouse" and .data.devices[0].source == "bluetooth"' >/dev/null || fail "bluetoothctl devices: $(rj "$binary" input status --json)"
rj "$binary" input status | grep -q 'Magic Keyboard (Bluetooth, paired, not connected)' || fail 'a paired device is said to be not connected'
rm "$tmp/bin/bluetoothctl"
SYS="$apple"
stub upower 'case "$1" in -e) echo /org/freedesktop/UPower/devices/DisplayDevice; echo /org/freedesktop/UPower/devices/mouse_hidpp_battery_0 ;; -i) printf "  native-path:  x\n  model:        Magic Trackpad 2\n  state:        charging\n  percentage:   71%%\n" ;; esac'
rj "$binary" input status --json | jq -e '.data.devices[1].battery == 71 and .data.devices[1].battery_source == "upower" and .data.devices[0].battery_source == "kernel"' >/dev/null || fail "upower battery: $(rj "$binary" input status --json)"
rm "$tmp/bin/upower"

# ---- input apple ----
SYS="$apple"
[[ "$(code "$binary" input apple)" == 4 ]] || fail 'no hid_magicmouse driver exits 4'
rj "$binary" input apple --json | jq -e '.exit == 4 and .data.driver.state == "absent" and (.data.devices | length) == 2' >/dev/null || fail 'apple json without a driver'
[[ "$(code "$binary" input apple --scroll-speed=40 --yes)" == 4 ]] || fail 'the setter without a driver exits 4'
mkdir -p "$apple/mod/hid_magicmouse/parameters"; echo live > "$apple/mod/hid_magicmouse/initstate"
for kv in scroll_speed=32 scroll_acceleration=N emulate_scroll_wheel=Y emulate_3button=Y; do echo "${kv#*=}" > "$apple/mod/hid_magicmouse/parameters/${kv%%=*}"; done
rj "$binary" input apple --json | jq -e '.exit == 0 and .data.driver.state == "loaded" and .data.parameters.scroll_speed == "32" and .data.parameters.scroll_acceleration == "N" and .data.scroll_speed_range.max == 63 and .data.bluetooth == true' >/dev/null || fail "apple json: $(rj "$binary" input apple --json)"
rj "$binary" input apple | grep -q 'info  scroll_speed  *32' || fail 'apple text shows the options'
BT=inactive rj "$binary" input apple | grep -q 'FIX   bluetooth service' || fail 'a stopped bluetooth service is a FIX'
for bad in 64 -1 abc 3.5 ""; do [[ "$(code "$binary" input apple --scroll-speed="$bad" --yes)" == 2 ]] || fail "--scroll-speed=$bad exits 2"; done
[[ "$(code "$binary" input apple --scroll-speed)" == 2 ]] || fail 'a bare --scroll-speed exits 2'
: > "$LOG"; [[ "$(code "$binary" input apple --scroll-speed=48)" == 2 ]] || fail 'the setter is a plan until --yes'
[[ ! -e "$tmp/mp/bxrig-magicmouse.conf" ]] || fail 'a plan wrote the file'
rj "$binary" input apple --scroll-speed=48 --dry-run | grep -q 'options hid_magicmouse scroll_speed=48' || fail 'the plan shows the option line'
rj "$binary" input apple --scroll-speed=48 --yes | grep -q 'applies the next time the module loads' || fail 'apple --yes says when it applies'
grep -qx 'options hid_magicmouse scroll_speed=48' "$tmp/mp/bxrig-magicmouse.conf" || fail "the modprobe.d file: $(cat "$tmp/mp/bxrig-magicmouse.conf" 2>/dev/null)"
logged 'sudo install -Dm644' || fail 'the file is written with sudo install'
run "$binary" input apple --scroll-speed=0 --yes >/dev/null; grep -qx 'options hid_magicmouse scroll_speed=0' "$tmp/mp/bxrig-magicmouse.conf" || fail 'scroll-speed 0 is allowed and rewrites the file'
run "$binary" input apple --scroll-speed=63 --yes >/dev/null; grep -q 'scroll_speed=63' "$tmp/mp/bxrig-magicmouse.conf" || fail 'scroll-speed 63 is allowed'
jq -e '.files == ["'"$tmp"'/mp/bxrig-magicmouse.conf"]' "$tmp/st/bxrig/input-helpers.json" >/dev/null || fail 'the file is remembered for undo'
# a built-in driver: modprobe.d is not read, the plan says so
rm "$apple/mod/hid_magicmouse/initstate"
rj "$binary" input apple --scroll-speed=10 --dry-run | grep -q 'built into this kernel.*kernel command line' || fail 'built-in warning'
rj "$binary" input apple | grep -q 'ok    kernel driver hid_magicmouse: built-in' || fail 'built-in is ok'
# undo removes the file with sudo rm
: > "$LOG"; run "$binary" input undo --yes >/dev/null || fail 'undo with a file'
logged "sudo rm -f $tmp/mp/bxrig-magicmouse.conf" || fail "undo removes the file: $(cat "$LOG")"
# a file that is not BxRig's is not overwritten
echo 'options hid_magicmouse scroll_speed=5' > "$tmp/mp/bxrig-magicmouse.conf"
[[ "$(code "$binary" input apple --scroll-speed=20 --yes)" == 8 ]] || fail 'a foreign modprobe file exits 8'
grep -q 'scroll_speed=5' "$tmp/mp/bxrig-magicmouse.conf" || fail 'a foreign file is kept'
rm "$tmp/mp/bxrig-magicmouse.conf"
# the driver registered with the HID bus counts as built in
rm -r "$apple/mod/hid_magicmouse"; mkdir -p "$apple/drv/magicmouse"
rj "$binary" input apple --json | jq -e '.data.driver.state == "built-in"' >/dev/null || fail 'a registered HID driver is built in'

# ---- input logitech ----
SYS="$logi"
rj "$binary" input logitech --json | jq -e '.exit == 0 and (.data.receivers | length) == 1 and (.data.devices | length) == 2 and .data.solaar.installed == false and .data.udev_rule == false' >/dev/null || fail "logitech json: $(rj "$binary" input logitech --json)"
rj "$binary" input logitech | grep -q 'FIX   solaar' || fail 'logitech text without solaar'
touch "$tmp/udev/42-logitech-unify-permissions.rules"
stub solaar 'printf "Unifying Receiver\n  Paired devices:\n    1: MX Master 3S\n       Codename     : MX Master 3S\n    2: K400 Plus\n"'
rj "$binary" input logitech --json | jq -e '.data.solaar.installed == true and .data.udev_rule == true and .data.solaar.show.exit == 0 and (.data.solaar.show.devices | length) == 2' >/dev/null || fail "logitech with solaar: $(rj "$binary" input logitech --json)"
rj "$binary" input logitech | grep -q 'solaar show: 2 paired devices listed' || fail 'solaar show summary'
SYS="$none"; rj "$binary" input logitech | grep -q 'No Logitech device or receiver was found' || fail 'logitech with nothing'
[[ "$(code "$binary" input logitech)" == 0 ]] || fail 'logitech with nothing exits 0'
echo "input-test: ok"
