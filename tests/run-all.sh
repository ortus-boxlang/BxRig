#!/usr/bin/env bash
# Runs every test by discovery: tests/*-test.sh (with the binary) and tests/*_test.bxs (with matchbox, from src/).
# Usage: tests/run-all.sh [BINARY] [filter]     JOBS=3 sets the parallelism (default 3; wizard-test is timing-sensitive, run it alone with JOBS=1 if it fails).
# BINARY defaults to dist/bxrig; MATCHBOX to the one in .cache/dev.env (scripts/setup-local.sh) or `matchbox` on PATH. Skips native-package-integration.sh (needs a sandbox with strata).
# Prints one line per test and a summary; exit 1 on any failure.
root="$(cd "$(dirname "$0")/.." && pwd)"
binary="$(realpath "${1:-$root/dist/bxrig}")"
filter="${2:-}"
jobs="${JOBS:-3}"
mb="${MATCHBOX:-}"
[[ -z "$mb" && -f "$root/.cache/dev.env" ]] && mb="$(source "$root/.cache/dev.env"; echo "${MATCHBOX:-}")"
[[ -z "$mb" ]] && mb="$(command -v matchbox || true)"
export BXRIG_DISTRO="${BXRIG_DISTRO:-arch}"   # the tests describe Arch unless one says otherwise (see lib/harness.sh)
logdir="$(mktemp -d)"; trap 'rm -rf "${logdir:?}"' EXIT
run_one() { # name, command...   (runs in a subshell, writes $logdir/NAME.result)
	local name="$1"; shift
	if timeout 900 "$@" >"$logdir/$name.log" 2>&1; then echo ok > "$logdir/$name.result"; echo "ok    $name"
	else echo fail > "$logdir/$name.result"; echo "FAIL  $name"; tail -5 "$logdir/$name.log" | sed 's/^/      /'; fi
}
queue=()
for t in "$root"/tests/*-test.sh; do n="$(basename "$t")"; [[ -n "$filter" && "$n" != *"$filter"* ]] || queue+=("sh:$t"); done
if [[ -n "$mb" ]]; then
	for t in "$root"/tests/*_test.bxs "$root"/tests/catalog_check.bxs; do [[ -f "$t" ]] || continue; n="$(basename "$t")"; [[ -n "$filter" && "$n" != *"$filter"* ]] || queue+=("bxs:$t"); done
else echo "skip  .bxs tests (no matchbox)"; fi
for item in "${queue[@]}"; do
	while (( $(jobs -rp | wc -l) >= jobs )); do wait -n || true; done
	t="${item#*:}"; n="$(basename "$t")"
	if [[ "$item" == sh:* ]]; then
		case "$n" in package-manager-test.sh|bootstrap-test.sh|web-install-test.sh|config-test.sh|setup-local-test.sh) run_one "$n" bash "$t" & ;; *) run_one "$n" bash "$t" "$binary" & ;; esac
	else run_one "$n" bash -c "cd '$root/src' && '$mb' '$t'" & fi
done
wait
pass=$(grep -l '^ok$' "$logdir"/*.result 2>/dev/null | wc -l)
failed=$(grep -L '^ok$' "$logdir"/*.result 2>/dev/null | xargs -r -n1 basename | sed 's/\.result$//' | sort)
echo "passed $pass, failed $(echo -n "$failed" | grep -c . || true)"
[[ -z "$failed" ]] || { echo "failed:"; echo "$failed" | sed 's/^/  /'; exit 1; }
