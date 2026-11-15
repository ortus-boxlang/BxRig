#!/usr/bin/env bash
# Formats the repository: tabs for indentation (shown 4 wide, see .editorconfig), LF, one final newline, no trailing spaces.
#   scripts/format.sh            rewrite the files that are not formatted
#   scripts/format.sh --check    list them and exit 1 (CI)
#   scripts/format.sh FILE...    only these files
# Only leading whitespace outside strings and heredocs changes; JSON gets the standard layout with tabs. See tools/format.py.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$root/tools/format.py" "$@"
