#!/usr/bin/env bash
# Build bxrig with the MatchBox chosen by scripts/setup-local.sh (saved in .cache/dev.env).
# Output: ./dist/bxrig
#   MATCHBOX=/path/to/matchbox  override the compiler
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
[[ -z "${MATCHBOX:-}" && -f "$root/.cache/dev.env" ]] && source "$root/.cache/dev.env"
mb="${MATCHBOX:-}"
[[ -n "$mb" && -x "$mb" ]] || { echo "No MatchBox set up (run scripts/setup-local.sh, or set MATCHBOX)" >&2; exit 4; }
mkdir -p "$root/dist"
"$root/bootstrap/gen-assets.sh" >/dev/null
"$root/bootstrap/gen-version.sh" >/dev/null
(cd "$root" && "$mb" --target native --output "$root/dist/bxrig" src/Main.bx)
echo "built $root/dist/bxrig with $("$mb" --version 2>&1 | head -1)"
