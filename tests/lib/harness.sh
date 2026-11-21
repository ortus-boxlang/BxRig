# Shared header for the shell tests: `. "$(dirname "$0")/lib/harness.sh"` as the first line after the shebang and comment.
# Provides: binary (realpath of $1), root (repo root), tmp (scratch dir, removed on exit), fail MSG, stub NAME BODY, code CMD... (exit code of
# `run CMD...`; the test defines run() to set its environment). Do not define fail, code or the tmp trap again in a test.
set -euo pipefail
binary="$(realpath "${1:?native executable required}")"
root="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
export BXRIG_TEST_LIB="$root/tests/lib"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
# Tests point HOME (or BXRIG_*_HOME) at $tmp; the XDG overrides a CI runner or desktop sets would win over HOME (Env), so drop them.
unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME XDG_CACHE_HOME
# The catalog and the package manager follow BXRIG_DISTRO, not the runner's own system (an Ubuntu CI runner is not the Arch the tests
# describe); a test that is about another distribution sets it itself.
export BXRIG_DISTRO="${BXRIG_DISTRO:-arch}"
fail() { echo "FAIL: $*" >&2; exit 1; }
# stub NAME 'bash body': an executable $tmp/bin/NAME (put $tmp/bin first on PATH in run()).
stub() { mkdir -p "$tmp/bin"; printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
# The fakes that many tests need. stub_id: `id -u` answers 1000 (MOCK_UID overrides it), everything else goes to the real id.
# stub_sudo: `sudo --version` answers, then it runs the command; stub_sudo_log also appends "sudo ARGS" to $LOG first.
stub_id() { stub id 'if [[ "$1" == -u ]]; then echo "${MOCK_UID:-1000}"; else /usr/bin/id "$@"; fi'; }
stub_sudo() { stub sudo '[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }
"$@"'; }
stub_sudo_log() { stub sudo '[[ "$1" == --version ]] && { echo "Sudo version 1.9"; exit 0; }
echo "sudo $*" >> "$LOG"
exec "$@"'; }
