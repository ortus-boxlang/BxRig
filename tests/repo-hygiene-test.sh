#!/usr/bin/env bash
# Build products must not be tracked: no Python bytecode in git, and .gitignore keeps it out. Usage: repo-hygiene-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
cd "$root"
git rev-parse --git-dir >/dev/null 2>&1 || { echo 'repo hygiene: not a git checkout, skipped'; exit 0; }
tracked="$(git ls-files | grep -E '(^|/)__pycache__/|\.py[co]$' || true)"
[[ -z "$tracked" ]] || fail "Python bytecode is tracked: $tracked"
git check-ignore -q tests/lib/__pycache__/x.cpython-313.pyc || fail '__pycache__ is not ignored'
git check-ignore -q tools/x.pyc || fail '*.pyc is not ignored'
echo 'repo hygiene tests passed'
