#!/usr/bin/env bash
# Ratchet: patterns that must not come back, each with the highest count allowed today. Lower a maximum whenever a refactor removes copies;
# Targets (new homes included in the counts): say 2 (Cli, Out), fail 2, tryExec 0, has 1 (Proc), merge 1 (Text), validName 1, home/env/self 1 each (Env), Usage 0, test fail() 0.
# never raise one. See docs/architecture/CODE-REVIEW.md section 8 and docs/guides/contributing.md. Usage: dry-test.sh [ignored]
root="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
count() { # pattern, path, max   (counts matching lines, fixed string)
  local n; n="$(grep -rF --include='*.bx' --include='*.sh' -- "$1" "$root/$2" 2>/dev/null | wc -l)"
  if (( n > $3 )); then echo "FAIL: '$1' in $2 is $n, allowed $3"; fails=$((fails+1)); elif (( n < $3 )); then echo "note: '$1' in $2 is $n, lower the maximum from $3"; fi
}
count 'function say('              src/bxrig 56
count 'function fail('             src/bxrig 16
count 'function tryExec('          src/bxrig 30
count 'function has('              src/bxrig 26
count 'function merge('            src/bxrig 12
count 'function validName('        src/bxrig 9
count 'function dataHome('         src/bxrig 6
count 'function home()'            src/bxrig 18
count 'function env('              src/bxrig 8
count 'function self()'            src/bxrig 10
count '"Usage: bxrig'              src/Main.bx 56
count 'fail() { echo "FAIL'        tests 67
count 'jsonDeserialize( fileRead(' src/bxrig 37
count 'getSystemSetting( "HOME"'   src/bxrig 39
(( fails == 0 )) || exit 1
echo "dry-test: ok"
