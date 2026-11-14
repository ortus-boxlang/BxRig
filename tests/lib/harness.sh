# Shared header for the shell tests: `. "$(dirname "$0")/lib/harness.sh"` as the first line after the shebang and comment.
# Provides: binary (realpath of $1), root (repo root), tmp (scratch dir, removed on exit), fail MSG, stub NAME BODY, code CMD... (exit code of
# `run CMD...`; the test defines run() to set its environment). Do not define fail, code or the tmp trap again in a test.
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
root="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
# stub NAME 'bash body': an executable $tmp/bin/NAME (put $tmp/bin first on PATH in run()).
stub() { mkdir -p "$tmp/bin"; printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
