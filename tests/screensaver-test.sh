#!/usr/bin/env bash
# `bxrig screensaver`: the settings and their checks, Noctalia being told (a stub), start and stop on Hyprland (stubs for hyprctl and kitty),
# and the screensaver itself in a pty closing on a key and on a mouse move. Usage: screensaver-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
export LOG="$tmp/log"
run() { env HOME="$tmp" BXRIG_SELF="$binary" PATH="$tmp/bin:/usr/bin:/bin" "$@"; }
mkdir -p "$tmp/bin"; : > "$LOG"
cfg="$tmp/.config/bxrig/screensaver.json"

# defaults, the effects, and usage errors
run "$binary" screensaver --json | jq -e '.ok and .data.enabled and .data.screensaver == 150 and .data.lock == 300 and (.data.effects | length == 6) and .data.logo.text == "BXRIG" and .data.running == 0' >/dev/null || fail 'defaults'
run "$binary" screensaver effects --json | jq -e '[.data.effects[].name] == ["sweep","laptop","rain","clock","stars","logo"] and all(.data.effects[]; .on)' >/dev/null || fail 'effects'
[[ "$(code "$binary" screensaver bogus)" == 2 ]] || fail 'unknown verb exits 2'
[[ "$(code "$binary" screensaver set lock=30)" == 2 ]] || fail 'a lock before the screensaver exits 2'
[[ "$(code "$binary" screensaver set screensaver=1.5 --yes)" == 2 ]] || fail 'seconds are whole'
[[ "$(code "$binary" screensaver set effects=nope --yes)" == 2 ]] || fail 'unknown effect exits 2'
[[ "$(code "$binary" screensaver set colour=red --yes)" == 2 ]] || fail 'unknown setting exits 2'
[[ "$(code "$binary" screensaver logo text "much too long here" --yes)" == 2 ]] || fail 'long logo text exits 2'
[[ "$(code "$binary" screensaver logo image notes.txt --yes)" == 2 ]] || fail 'a logo that is not a picture exits 2'
[[ "$(code "$binary" screensaver logo image /no/such.png --yes)" == 4 ]] || fail 'a missing picture exits 4'
[[ "$(code "$binary" screensaver start --effect=nope)" == 2 ]] || fail 'start with an unknown effect exits 2'

# a change without --yes is a plan and writes nothing
out="$(run "$binary" screensaver set screensaver=300 lock=600 2>&1 || true)"
grep -q 'Add --yes' <<<"$out" || fail "plan without --yes: $out"
[[ ! -f "$cfg" ]] || fail 'the plan wrote the settings'

# with --yes it is saved and a running Noctalia is told
stub noctalia 'echo "noctalia $*" >> "$LOG"'
run "$binary" screensaver set screensaver=300 lock=600 effects=clock,stars --yes --json | jq -e '.ok and .data.noctalia == "applied"' >/dev/null || fail 'set --yes'
jq -e '.screensaver == 300 and .lock == 600 and .effects == ["clock","stars"]' "$cfg" >/dev/null || fail 'the settings file'
grep -q "noctalia msg config-set idle.behavior.bxrig_screensaver.timeout 300" "$LOG" || fail 'Noctalia gets the screensaver timeout'
grep -q "noctalia msg config-set idle.behavior.bxrig_lock.timeout 600" "$LOG" || fail 'Noctalia gets the lock timeout'
grep -q "idle.behavior.bxrig_screensaver.resume_command \"'$binary' screensaver stop\"" "$LOG" || fail 'the resume command stops the screensaver'
run "$binary" screensaver off --yes >/dev/null || fail 'off'
grep -q "idle.behavior.bxrig_screensaver.enabled false" "$LOG" || fail 'off turns the behavior off'
grep -q "idle.behavior.bxrig_lock.enabled true" "$LOG" || fail 'off keeps the lock'
run "$binary" screensaver on --yes >/dev/null && jq -e '.enabled' "$cfg" >/dev/null || fail 'on'
echo x > "$tmp/logo.png"
run "$binary" screensaver logo image "$tmp/logo.png" --yes >/dev/null && jq -e --arg p "$tmp/logo.png" '.logo.type == "image" and .logo.path == $p' "$cfg" >/dev/null || fail 'logo image'
run "$binary" screensaver logo text ACME --yes >/dev/null && jq -e '.logo == {type:"text",text:"ACME",path:""}' "$cfg" >/dev/null || fail 'logo text'
run "$binary" screensaver logo reset --yes >/dev/null && jq -e '.logo.text == "BXRIG"' "$cfg" >/dev/null || fail 'logo reset'
stub noctalia 'exit 1'
run "$binary" screensaver on --yes --json | jq -e '.data.noctalia == "not running"' >/dev/null || fail 'Noctalia not running is reported'

# start and stop on Hyprland: one kitty per monitor with our class, then killed by pid
[[ "$(code "$binary" screensaver start)" == 4 ]] || fail 'start without Hyprland exits 4'
stub hyprctl 'echo "hyprctl $*" >> "$LOG"
case "$1" in
	monitors) echo "[{\"name\":\"DP-1\"},{\"name\":\"eDP-1\"}]" ;;
	clients) if [[ -f "$LOG.open" ]]; then echo "[{\"class\":\"bxrig-screensaver\",\"pid\":424242,\"address\":\"0x1\",\"monitor\":0},{\"class\":\"kitty\",\"pid\":1,\"address\":\"0x2\"}]"; else echo "[]"; fi ;;
	dispatch) echo ok ;;
esac'
[[ "$(code "$binary" screensaver start)" == 4 ]] || fail 'start without a terminal exits 4'
stub kitty 'exit 0'
run "$binary" screensaver start --effect=clock --json | jq -e '.ok and .data.started == 2 and .data.terminal == "kitty"' >/dev/null || fail 'start on two monitors'
grep -q "hyprctl dispatch exec \[monitor DP-1\] 'kitty' '--class' 'bxrig-screensaver' '$binary' 'screensaver' 'run' '--effect=clock'" "$LOG" || fail 'the window command'
grep -q "hyprctl dispatch exec \[monitor eDP-1\]" "$LOG" || fail 'a window on the second monitor'
touch "$LOG.open"
run "$binary" screensaver start --json | jq -e '.data.started == 0 and .data.running == 1' >/dev/null || fail 'start twice does not open more'
stub kill 'echo "kill $*" >> "$LOG"'
run "$binary" screensaver stop --json | jq -e '.data.closed == 1' >/dev/null || fail 'stop'
grep -q '^kill 424242$' "$LOG" || fail 'stop kills the screensaver window only'
rm -f "$LOG.open"
run "$binary" screensaver stop --json | jq -e '.data.closed == 0' >/dev/null || fail 'stop with nothing open'

# hypridle is gone: Noctalia's idle behaviors replace it
! grep -q 'hypridle' "$root/templates/hyprland.lua" || fail 'hyprland.lua no longer starts hypridle'

# the screensaver in a pty: it draws, then a key closes it; then a mouse move does
[[ "$(code "$binary" screensaver run </dev/null)" == 4 ]] || fail 'run outside a terminal exits 4'
for input in key move; do
	python3 - "$binary" "$tmp" "$input" <<'PY' || fail "the screensaver closes on a $input"
import os, pty, sys, time, fcntl, termios, struct
sys.path.insert(0, os.environ["BXRIG_TEST_LIB"]); from pty_ready import ready
binary, home, kind = sys.argv[1:4]
pid, fd = pty.fork()
if pid == 0:
	os.environ.update({"HOME": home, "TERM": "xterm-256color", "COLORTERM": "truecolor"})
	os.execv(binary, [binary, "screensaver", "preview", "sweep"])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
ready(fd, quiet=0.2, limit=20); time.sleep(0.8)
os.write(fd, b"x" if kind == "key" else b"\x1b[<35;30;10M")
end = time.time() + 5
while time.time() < end:
	try: os.read(fd, 65536)
	except OSError: pass
	p, st = os.waitpid(pid, os.WNOHANG)
	if p: sys.exit(0 if os.WEXITSTATUS(st) == 0 else 1)
	time.sleep(0.05)
os.kill(pid, 9); sys.exit(1)
PY
done
echo "screensaver-test: ok"
