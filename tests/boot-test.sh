#!/usr/bin/env bash
# `bxrig setup boot`: the plan (package, theme, hook, default), hook and splash detection, the hook edit itself. Usage: boot-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home"; export LOG="$tmp/log"; : > "$LOG"
for t in sudo pacman plymouth-set-default-theme; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n' "$t" > "$tmp/bin/$t"; done
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/bin/pacman"   # plymouth not installed (pacman -Q fails)
stub_id
chmod +x "$tmp/bin"/*
echo 'HOOKS=(base udev autodetect block filesystems fsck)' > "$tmp/mk.conf"
echo 'BOOT_IMAGE=/vmlinuz root=UUID=x rw' > "$tmp/cmdline"
run() { env HOME="$tmp/home" PATH="$tmp/bin:$PATH" BXRIG_MKINITCPIO="$tmp/mk.conf" BXRIG_CMDLINE="$tmp/cmdline" BXRIG_PLYMOUTH_DIR="$tmp/themes" BXRIG_BOOT_DIR="$tmp/boot" "$@"; }
out="$(run "$binary" setup boot --dry-run --json)" || fail "dry run: $out"
echo "$out" | jq -e '(.data.steps | map(.id) == ["package","theme","hook","default"]) and (.data.notes | map(select(test("splash"))) | length == 1)' >/dev/null || fail "plan: $out"
# with the hook and splash already there: no hook step, no splash note
echo 'HOOKS=(base systemd plymouth autodetect)' > "$tmp/mk.conf"; echo 'root=x quiet splash' > "$tmp/cmdline"
run "$binary" setup boot --dry-run --json | jq -e '(.data.steps | map(.id) | index("hook") == null) and (.data.notes | length == 0)' >/dev/null || fail 'hook and splash detected'
# the sed BxRig runs puts plymouth after systemd, else after udev, and never twice
echo 'HOOKS=(base udev autodetect block filesystems fsck)' > "$tmp/mk.conf"
sedexpr="$(run "$binary" setup boot --dry-run --json | jq -r '.data.steps[] | select(.id=="hook") | .commands[1][4]')"
for pair in 'HOOKS=(base udev autodetect)|HOOKS=(base udev plymouth autodetect)' 'HOOKS=(base systemd autodetect sd-encrypt)|HOOKS=(base systemd plymouth autodetect sd-encrypt)' 'HOOKS=(base udev plymouth)|HOOKS=(base udev plymouth)'; do
  echo "${pair%%|*}" > "$tmp/t.conf"; sed -i -E "$sedexpr" "$tmp/t.conf"
  [[ "$(cat "$tmp/t.conf")" == "${pair##*|}" ]] || fail "hook edit: ${pair%%|*} -> $(cat "$tmp/t.conf")"
done
echo "boot-test: ok"
