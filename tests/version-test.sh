#!/usr/bin/env bash
# One version source: box.json. The generated Version.bx, `bxrig version` (plain and --json) and the docs must all agree with it,
# and no page file or constant may carry a version of its own. Usage: version-test.sh [binary]
. "$(dirname "$0")/lib/harness.sh"
want="$(jq -r .version "$root/box.json")"
[[ -n "$want" && "$want" != null ]] || fail 'box.json has no version'
"$root/bootstrap/gen-version.sh" --check || fail 'Version.bx is not generated from box.json'
grep -Fq "\"$want\"" "$root/src/bxrig/util/Version.bx" || fail 'Version.bx does not hold the box.json version'
[[ "$("$binary" version --json | jq -r .data.version)" == "$want" ]] || fail 'bxrig version --json differs from box.json'
"$binary" version | grep -Fq "$want" || fail 'bxrig version differs from box.json'
[[ "$(jq 'has("version")' "$root/assets/wizard/pages-demo.json")" == false ]] || fail 'pages-demo.json carries its own version'
# no other source file hard-codes the current version string
hits="$(grep -rnF "\"$want\"" "$root/src" --include='*.bx' | grep -v 'util/Version.bx' || true)"
[[ -z "$hits" ]] || fail "the version is hard-coded outside Version.bx: $hits"
grep -rnE 'v?0\.1[0-9]\.[0-9]+(-dev)?' "$root/README.md" | grep -i 'version 0\.' && fail 'README.md states a version number' || true
echo 'version tests passed'
