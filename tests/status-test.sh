#!/usr/bin/env bash
# `bxrig status` and the system-aware wizard flags, with a fake pacman. Usage: status-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home"
printf '#!/usr/bin/env bash\nprintf "git\\ncurl\\nhyprland\\nghostty\\nollama\\nclaude-code\\n"\n' > "$tmp/bin/pacman"; chmod +x "$tmp/bin/pacman"
run() { env HOME="$tmp/home" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_ROOT_FS=ext4 SHELL=/usr/bin/zsh PATH="$tmp/bin:$PATH" "$@"; }

# status: detected answers and the missing default apps
run "$binary" status --json | jq -e '.data.detected | map(.id) | (index("terminal") != null)' >/dev/null || fail "status json: $(run "$binary" status --json)"
run "$binary" status --json | jq -e '.data.default_apps_missing | (index("timeshift") != null) and (index("btrfs-assistant") == null)' >/dev/null || fail 'status missing apps (timeshift yes, btrfs-assistant not on ext4)'
run "$binary" status | grep -q 'Default apps not installed:' || fail 'status text'

# init --from-system --print-answers: what the machine has, as wizard answers
run "$binary" init --from-system --print-answers --json | jq -e '.data.answers.terminal == "ghostty" and (.data.answers.ai_agents | index("claude-code") != null)' >/dev/null || fail "from-system: $(run "$binary" init --from-system --print-answers --json)"
# the Look pages start from what the desktop has now: theme.json and the appearance status commands (a fake bxrig answers them)
mkdir -p "$tmp/cfg/bxrig"; echo '{"name":"nord","mode":"theme"}' > "$tmp/cfg/bxrig/theme.json"
cat > "$tmp/self" <<'FAKE'
#!/usr/bin/env bash
case "$*" in
	"appearance bar layout status --json") echo '{"ok":true,"data":{"layout":"dense"}}' ;;
	"appearance appgrid status --json") echo '{"ok":true,"data":{"appgrid":"terminal"}}' ;;
	*) echo "usage"; exit 2 ;;
esac
FAKE
chmod +x "$tmp/self"
run env BXRIG_SELF="$tmp/self" "$binary" init --from-system --print-answers --json | jq -e '.data.answers.bar_layout == "dense" and .data.answers.appgrid_style == "terminal" and .data.answers.theme_name == "nord"' >/dev/null || fail "look prefill: $(run env BXRIG_SELF="$tmp/self" "$binary" init --from-system --print-answers --json)"
# a bxrig that does not know the appearance commands (or fails) leaves the defaults alone
run env BXRIG_SELF=/bin/false "$binary" init --from-system --print-answers --json | jq -e '(.data.answers | has("bar_layout") | not) and (.data.answers | has("appgrid_style") | not) and .data.answers.theme_name == "nord"' >/dev/null || fail 'look prefill without the status commands'
echo "status-test ok"
