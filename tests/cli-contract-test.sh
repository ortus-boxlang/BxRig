#!/usr/bin/env bash
# Shared CLI contract: unknown flags exit 2, --json prints one JSON object. Usage: cli-contract-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
code() { set +e; "$@" >/dev/null 2>&1; local rc=$?; set -e; echo "$rc"; }
[[ "$(code "$binary" version --bogus)" == 2 ]] || fail 'unknown flag on version'
[[ "$(code "$binary" desktop-list --bogus)" == 2 ]] || fail 'unknown flag on list'
[[ "$(code "$binary" config list --bogus)" == 2 ]] || fail 'unknown flag on config'
declare -A DATA_TYPE=( [version]=object [desktop-list]=array [tui-list]=array [web-list]=array [optional-list]=array [profile-list]=array )
for c in version desktop-list tui-list web-list optional-list profile-list; do
	out="$("$binary" $c --json)"
	[[ "$(printf '%s' "$out" | jq -r .schema)" == 1 ]] || fail "$c: schema"
	[[ "$(printf '%s' "$out" | jq -r .command)" == "$c" ]] || fail "$c: command"
	[[ "$(printf '%s' "$out" | jq -r .ok)" == true ]] || fail "$c: ok"
	[[ "$(printf '%s' "$out" | jq -r '.data|type')" == "${DATA_TYPE[$c]}" ]] || fail "$c: data"
	[[ "$(printf '%s\n' "$out" | wc -l)" == 1 ]] || fail "$c: more than one line on stdout"
done
[[ "$("$binary" version --json | jq -r .data.version)" == "$(jq -r .version "$(dirname "$0")/../box.json")" ]] || fail 'json version differs from box.json'
"$binary" desktop-list | grep -Fq 'Visual Studio Code' || fail 'plain list rows'
set +e; "$binary" nosuchcommand >/dev/null 2>&1; c=$?; set -e; [[ $c == 2 ]] || fail "an unknown command exits 2 (got $c)"
set +e; "$binary" version --nosuchflag >/dev/null 2>&1; c=$?; set -e; [[ $c == 2 ]] || fail "an unknown flag exits 2 (got $c)"
# --help and -h are `bxrig help`: the same text, exit 0
"$binary" help > "$tmp/help.txt"; [[ -s "$tmp/help.txt" ]] || fail 'help prints nothing'
for h in --help -h; do
	"$binary" $h > "$tmp/h.txt" 2>&1 || fail "bxrig $h does not exit 0"
	cmp -s "$tmp/help.txt" "$tmp/h.txt" || fail "bxrig $h differs from bxrig help"
done
[[ "$("$binary" --help --json | jq -r .command)" == help ]] || fail '--help --json is the help envelope'
[[ "$(code "$binary" --nosuchflag)" == 2 ]] || fail 'an unknown flag without a command still exits 2'
echo 'cli contract tests passed'
