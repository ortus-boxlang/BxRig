#!/usr/bin/env bash
# The look pages in a real pseudo-terminal: the wizard's Top bar layout, App grid style and Theme pages (keys in, answers out, colours on the
# wire), and the Control Center's Look and Themes pages. Needs the native bxrig built with MatchBox's TUI. Usage: look-pages-test.sh BXRIG_BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/home" "$tmp/cfg/bxrig"
# play OUT_CAPTURE CMD... : runs CMD in a pty (120 x 40), waits until WAIT is on screen, sends the keys in $KEYS ('|' between keys, python escapes), keeps everything drawn
play() {   # WAIT=text of the first screen, KEYS=keys
	local cap="$1"; shift
	python3 - "$cap" "$@" <<'PY'
import os, pty, select, sys, time, struct, fcntl, termios
sys.path.insert(0, os.environ['BXRIG_TEST_LIB'])
cap, argv = sys.argv[1], sys.argv[2:]
keys = os.environ.get('KEYS', '').encode().decode('unicode_escape').encode('latin-1')
env = dict(os.environ, HOME=os.environ['TMPHOME'], BXRIG_CONFIG_HOME=os.environ['TMPCFG'], BXRIG_STATE_HOME=os.environ['TMPHOME'] + '/state', BXRIG_ICONS='off', BXRIG_IMAGES='off', TERM='xterm-256color', COLORTERM='truecolor')
pid, fd = pty.fork()
if pid == 0:
    os.execve(argv[0], argv, env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 120, 0, 0))
buf = bytearray()
def pump(t):
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try:
                d = os.read(fd, 65536)
            except OSError: return
            if not d: return
            buf.extend(d)
# wait for the first screen: the program has drawn the text in WAIT (the screens animate, so there is no quiet moment to wait for), at most 20 s
want = os.environ.get('WAIT', 'x').encode()
start = time.time()
while time.time() - start < 20 and want not in buf:
    pump(0.1)
pump(0.4)
for k in keys.split(b'|'):
    if k: os.write(fd, k); pump(0.3)
pump(0.6)
try:
    pid2, status = os.waitpid(pid, os.WNOHANG)
    if pid2 == 0:
        os.kill(pid, 15); _, status = os.waitpid(pid, 0)
except ChildProcessError: status = 0
open(cap, 'wb').write(bytes(buf))
sys.exit(os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1)
PY
}
export TMPHOME="$tmp/home" TMPCFG="$tmp/cfg"
# the SGR background of a colour: 48;2;R;G;B
bg() { printf '48;2;%d;%d;%d' $((16#${1:0:2})) $((16#${1:2:2})) $((16#${1:4:2})); }
ENTER='\r'; TAB='\t'; DOWN='\x1b[B'; UP='\x1b[A'
tabs() { local s='' i; for ((i = 0; i < $1; i++)); do s+="|$TAB"; done; printf '%s' "$s"; }   # N Tab keys

# ---- the wizard: welcome, Desktop, Look, then the three pages ----
# Enter, Tab (Look), Tab (Top bar layout): Down picks Dense; Tab (App grid): Down picks Terminal-style; Tab (Theme): two Downs pick the third theme;
# then Tab through Input .. Import and the review, Enter
WAIT="to begin" KEYS="$ENTER|$TAB|$TAB|$DOWN|$TAB|$DOWN|$TAB|$DOWN|$DOWN$(tabs 12)|$ENTER" \
	play "$tmp/wizard.out" "$binary" wizard --demo --out="$tmp/answers.json" || fail "the wizard did not finish"
jq -e '.bar_layout == "dense" and .appgrid_style == "terminal" and .theme_name == "bxrig-cyan" and .theme == "dark" and (has("login_session") | not)' "$tmp/answers.json" >/dev/null || fail "wizard answers: $(cat "$tmp/answers.json")"
grep -q 'Top bar layout' "$tmp/wizard.out" && grep -q 'App grid style' "$tmp/wizard.out" && grep -q 'Launchpad grid' "$tmp/wizard.out" || fail 'the new pages were not drawn'
grep -q 'Preview: BxRig Cyan' "$tmp/wizard.out" || fail 'the theme pane did not preview the highlighted theme'
# the wizard is drawn in the highlighted theme: BxRig Cyan's background (#24273a) is on the wire, after the default's (#303446)
grep -q "$(bg 303446)" "$tmp/wizard.out" || fail 'the default BxRig background is missing'
grep -q "$(bg 24273a)" "$tmp/wizard.out" || fail 'the wizard did not take the highlighted theme colours'
# Enter on the first screen of a choice page keeps the default (the page opens on the answer, not on the first option)
WAIT="to begin" KEYS="$ENTER|$TAB|$TAB|$ENTER|$ENTER|$ENTER$(tabs 11)|$ENTER" play "$tmp/w2.out" "$binary" wizard --demo --out="$tmp/a2.json" || fail "second wizard run"
jq -e '.bar_layout == "standard" and .appgrid_style == "launchpad" and .theme_name == "bxrig"' "$tmp/a2.json" >/dev/null || fail "defaults kept: $(cat "$tmp/a2.json")"
# starting answers colour the wizard from the first frame
echo '{"theme_name":"nord"}' > "$tmp/nord.json"
WAIT="to begin" KEYS="$ENTER|\x03" play "$tmp/w3.out" "$binary" wizard --demo --answers="$tmp/nord.json" --out="$tmp/a3.json" || true
grep -q "$(bg 2e3440)" "$tmp/w3.out" || fail 'a saved theme answer (Nord) should colour the wizard'

# ---- the Control Center: Look page, and the Themes page by name ----
echo '{"name":"nord","mode":"theme"}' > "$tmp/cfg/bxrig/theme.json"
printf '#!/usr/bin/env bash\ncase "$*" in\n "appearance bar layout status --json") echo "{\\"ok\\":true,\\"data\\":{\\"layout\\":\\"dense\\",\\"dock\\":false}}";;\n "appearance appgrid status --json") echo "{\\"ok\\":true,\\"data\\":{\\"appgrid\\":\\"terminal\\"}}";;\n *) echo "{}";;\nesac\n' > "$tmp/self"; chmod +x "$tmp/self"
export BXRIG_SELF="$tmp/self"
WAIT="quit" KEYS="q" play "$tmp/cc.out" "$binary" tui look || fail "tui look did not exit on q"
grep -q 'Top bar layout' "$tmp/cc.out" && grep -q 'Dense' "$tmp/cc.out" && grep -q 'Terminal-style grid' "$tmp/cc.out" || fail 'the Look page did not show the status values'
grep -q 'dock off' "$tmp/cc.out" || fail 'a dock that is off is said in the preview'
grep -q "$(bg 2e3440)" "$tmp/cc.out" || fail 'the Control Center should be drawn in the active theme (Nord)'
! grep -q "$(bg 303446)" "$tmp/cc.out" || fail 'no BxRig background left once a theme is active'
# demo keeps the BxRig colours
WAIT="quit" KEYS="q" play "$tmp/ccd.out" "$binary" tui look --demo || fail "tui look --demo"
grep -q "$(bg 303446)" "$tmp/ccd.out" && ! grep -q "$(bg 2e3440)" "$tmp/ccd.out" || fail '--demo keeps the BxRig colours'
# a change shows its plan first: Right on the layout (dense -> minimal) asks, n drops it
WAIT="quit" KEYS="$DOWN|$UP|+|n|q" play "$tmp/cc2.out" "$binary" tui look || fail "tui look keys"
grep -q 'appearance bar layout' "$tmp/cc2.out" || fail 'the plan box for the layout change'
# the Themes page is reachable by name and from the sidebar (Tab from Look)
WAIT="quit" KEYS="q" play "$tmp/th.out" "$binary" tui themes --demo || fail "tui themes"
grep -q 'Tokyo Night' "$tmp/th.out" || fail 'tui themes shows the themes'
WAIT="quit" KEYS="\t|q" play "$tmp/th2.out" "$binary" tui look --demo || fail "tab to the next page"
grep -q 'Tokyo Night' "$tmp/th2.out" || fail 'Tab from Look reaches the Themes page'
echo "look pages tests passed"
