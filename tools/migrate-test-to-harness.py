#!/usr/bin/env python3
"""Moves a shell test onto tests/lib/harness.sh: the header lines (set, binary, root, tmp with trap, fail, code) become one `. harness.sh` line.
Only the plain shape is migrated; anything else is reported and left alone. Usage: tools/migrate-test-to-harness.py tests/NAME-test.sh..."""
import re, sys
BIN = 'binary="$(realpath "${1:?native executable required}")"'
ROOT = 'root="$(cd "$(dirname "$0")/.." && pwd)"'
TMPS = ['tmp="$(mktemp -d)"; trap \'rm -rf "$tmp"\' EXIT', 'tmp="$(mktemp -d)"; trap \'rm -rf "${tmp:?}"\' EXIT']
FAIL = 'fail() { echo "FAIL: $*" >&2; exit 1; }'
CODE = 'code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }'
for path in sys.argv[1:]:
	lines = open(path).read().split('\n')
	if any('lib/harness.sh' in l for l in lines): print('skip (done)', path); continue
	if BIN not in lines or not any(l in TMPS for l in lines) or FAIL not in lines: print('SKIP (shape)', path); continue
	out = []; placed = False
	for l in lines:
		if l == 'set -euo pipefail': continue
		if l == BIN:
			out.append('. "$(dirname "$0")/lib/harness.sh"'); placed = True; continue
		if l == ROOT or l in TMPS or l == FAIL or l == CODE: continue
		out.append(l)
	# the sourcing line must come before anything that uses the harness; it replaced the binary line, which was first in every migrated test
	open(path, 'w').write('\n'.join(out))
	print('migrated', path)
