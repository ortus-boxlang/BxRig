#!/usr/bin/env bash
# Tests scripts/setup-local.sh, scripts/get-matchbox.sh and scripts/dev-build.sh (and scripts/lib/matchbox-ref.sh) with fake git, cargo and curl
# binaries first on PATH: no network, no real clone, no real build. Each case runs a copy of the scripts in its own scratch tree.
# Usage: bash tests/setup-local-test.sh   (needs no binary)
set -euo pipefail
src="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:?}"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
has() { grep -qF -- "$2" "$1" 2>/dev/null || fail "$3: '$2' not found in $1: $(cat "$1" 2>/dev/null | head -n 20)"; }
lacks() { if grep -qF -- "$2" "$1" 2>/dev/null; then fail "$3: '$2' must not be in $1"; fi; }
command -v jq >/dev/null || fail "jq is required"

manifest_repo=https://github.com/ortus-boxlang/matchbox
manifest_version="$(jq -r .toolchain.matchbox.version "$src/box.json")"
sha=0123456789abcdef0123456789abcdef01234567

# ---- the fakes: they log every call to $FAKE_LOG and create what the scripts expect ----
mkdir -p "$tmp/bin"
cat > "$tmp/bin/git" <<'FAKE'
#!/usr/bin/env bash
echo "git $*" >> "$FAKE_LOG"
[[ "$1" == -C ]] && shift 2
case "$1" in
	clone|init) dest="${*: -1}"; mkdir -p "$dest/.git" ;;
	rev-parse) case "$*" in *--short*) echo "${FAKE_COMMIT:-abc1234}" ;; *--abbrev-ref*) echo "${FAKE_BRANCH:-bxrig}" ;; esac ;;
	ls-remote) printf '%s\trefs/heads/bxrig\n' "$sha" ;;
esac
exit 0
FAKE
sed -i "s/\$sha/$sha/" "$tmp/bin/git"
cat > "$tmp/bin/cargo" <<'FAKE'
#!/usr/bin/env bash
echo "cargo $* (in $PWD)" >> "$FAKE_LOG"
profile=debug; [[ " $* " == *" --release "* ]] && profile=release
mkdir -p "target/$profile"
printf '#!/usr/bin/env bash\necho "matchbox version %s"\n' "${FAKE_MB_VERSION:-$MB_VERSION}" > "target/$profile/matchbox"
chmod +x "target/$profile/matchbox"
FAKE
cat > "$tmp/bin/curl" <<'FAKE'
#!/usr/bin/env bash
echo "curl $*" >> "$FAKE_LOG"
out=""; url=""
while (( $# )); do case "$1" in -o) out="$2"; shift 2 ;; -*) shift ;; *) url="$1"; shift ;; esac; done
case "$url" in
	*matchbox-linux-x86_64.sha256) sha256sum "$FAKE_PUBLISHED" | sed 's/ .*/  matchbox-linux-x86_64/' > "$out" ;;
	*matchbox-linux-x86_64) cp "$FAKE_PUBLISHED" "$out" ;;
	*) [[ "$out" == /dev/null ]] || echo ok > "$out" ;;
esac
FAKE
chmod +x "$tmp/bin/"*

n=0
# fresh: a scratch repo with the scripts under test (root = $w/repo, so ../matchbox is $w/matchbox and .cache is $w/repo/.cache)
fresh() {
	n=$((n+1)); w="$tmp/case$n"; r="$w/repo"; log="$w/log"
	mkdir -p "$r/scripts/lib" "$r/bootstrap" "$r/tests"
	cp "$src/box.json" "$r/"; cp "$src/scripts/setup-local.sh" "$src/scripts/get-matchbox.sh" "$src/scripts/dev-build.sh" "$r/scripts/"
	cp "$src/scripts/lib/matchbox-ref.sh" "$r/scripts/lib/"
	: > "$log"
}
# run SCRIPT ARGS...: output in $w/out, exit code in $rc; env: BXRIG_MATCHBOX_* are cleared unless the case sets them
run() {
	local s="$1"; shift
	set +e
	env -u BXRIG_MATCHBOX_BRANCH -u BXRIG_MATCHBOX_REPO "${extra_env[@]}" PATH="$tmp/bin:$PATH" FAKE_LOG="$log" MB_VERSION="$manifest_version" \
		bash "$r/scripts/$s" "$@" </dev/null > "$w/out" 2>&1
	rc=$?
	set -e
}
extra_env=(HOME="$tmp/home")
mbdir() { echo "$r/.cache/matchbox-src/$1"; }

# ---- step 1: default flows are unchanged ----
fresh; run setup-local.sh --matchbox source --no-build
[[ $rc == 0 ]] || fail "plain source: exit $rc: $(cat "$w/out")"
has "$log" "git clone --branch bxrig $manifest_repo $w/matchbox" "plain source clones ../matchbox on bxrig"
has "$log" "cargo build --features bif-tui (in $w/matchbox)" "plain source builds ../matchbox in debug"
lacks "$log" "--release" "plain source is a debug build"
[[ ! -d "$r/.cache/matchbox-src" ]] || fail "plain source must not create a dedicated clone"
[[ "$(cat "$r/.cache/dev.env")" == "# written by scripts/setup-local.sh (source)
MATCHBOX=$w/matchbox/target/debug/matchbox" ]] || fail "plain source dev.env: $(cat "$r/.cache/dev.env")"

fresh; run setup-local.sh --matchbox source --release --no-build
has "$log" "cargo build --release --features bif-tui (in $w/matchbox)" "--release for plain source"
has "$r/.cache/dev.env" "MATCHBOX=$w/matchbox/target/release/matchbox" "--release path in dev.env"

# an existing ../matchbox on another branch is used as it is
fresh; mkdir -p "$w/matchbox/.git"
extra_env=(HOME="$tmp/home" FAKE_BRANCH=feature/mine); run setup-local.sh --matchbox source --no-build; extra_env=(HOME="$tmp/home")
has "$w/out" "Using $w/matchbox as it is (branch feature/mine" "existing ../matchbox kept"
lacks "$log" "git -C $w/matchbox pull" "no pull on another branch"

# edge: the published build of the manifest branch, no clone
fresh; printf '#!/usr/bin/env bash\necho "matchbox version %s"\n' "$manifest_version" > "$w/published"; chmod +x "$w/published"
extra_env=(HOME="$tmp/home" FAKE_PUBLISHED="$w/published"); run setup-local.sh --matchbox edge --no-build; extra_env=(HOME="$tmp/home")
[[ $rc == 0 ]] || fail "edge: exit $rc: $(cat "$w/out")"
has "$log" "matchbox-linux-x86_64" "edge downloads the published build"
lacks "$log" "git clone" "edge does not clone"
[[ "$(cat "$r/.cache/dev.env")" == "# written by scripts/setup-local.sh (edge)
MATCHBOX=$r/.cache/matchbox/matchbox" ]] || fail "edge dev.env: $(cat "$r/.cache/dev.env")"

# --matchbox-branch equal to box.json's ref is still the plain flow
fresh; run setup-local.sh --matchbox source --matchbox-branch bxrig --no-build
has "$log" "git clone --branch bxrig $manifest_repo $w/matchbox" "the manifest ref is the plain source flow"

# ---- step 1: --matchbox-branch, --matchbox-repo, env vars ----
fresh; run setup-local.sh --matchbox-branch develop --no-build
[[ $rc == 0 ]] || fail "branch: exit $rc: $(cat "$w/out")"
d="$(mbdir ortus-boxlang-matchbox-develop)"
has "$log" "git clone --quiet --depth 1 --branch develop $manifest_repo $d" "shallow clone into the dedicated dir"
has "$log" "cargo build --features bif-tui (in $d)" "debug build of the dedicated clone"
lacks "$log" "--release" "debug by default"
[[ ! -e "$w/matchbox" ]] || fail "../matchbox must not be touched for an arbitrary branch"
[[ "$(cat "$r/.cache/dev.env")" == "# written by scripts/setup-local.sh (source-branch)
MATCHBOX=$d/target/debug/matchbox
MATCHBOX_REPO=$manifest_repo
MATCHBOX_REF=develop
MATCHBOX_COMMIT=abc1234" ]] || fail "branch dev.env: $(cat "$r/.cache/dev.env")"

fresh; run setup-local.sh --matchbox-branch=develop --release --no-build
has "$log" "cargo build --release --features bif-tui (in $(mbdir ortus-boxlang-matchbox-develop))" "--release for a branch"
has "$r/.cache/dev.env" "MATCHBOX=$(mbdir ortus-boxlang-matchbox-develop)/target/release/matchbox" "release path"

# a branch with slashes; --matchbox source is allowed with it
fresh; run setup-local.sh --matchbox source --matchbox-branch feature/x+y@2 --no-build
has "$log" "--branch feature/x+y@2 $manifest_repo $(mbdir ortus-boxlang-matchbox-feature-x-y-2)" "slashes become dashes in the dir name"

# repo: shorthand, full URL (with .git), repo alone (then the manifest branch)
fresh; run setup-local.sh --matchbox-repo someone/matchbox-fork --matchbox-branch topic --no-build
d="$(mbdir someone-matchbox-fork-topic)"
has "$log" "--branch topic https://github.com/someone/matchbox-fork $d" "owner/name is a GitHub repo"
has "$r/.cache/dev.env" "MATCHBOX_REPO=https://github.com/someone/matchbox-fork" "repo recorded"
fresh; run setup-local.sh --matchbox-repo=https://github.com/someone/matchbox-fork.git --matchbox-branch topic --no-build
has "$log" "--branch topic https://github.com/someone/matchbox-fork.git $(mbdir someone-matchbox-fork-topic)" "a full URL is kept, .git is not in the dir name"
fresh; run setup-local.sh --matchbox-repo https://git.example.org/team/mb --no-build
has "$log" "--branch bxrig https://git.example.org/team/mb $(mbdir git.example.org-team-mb-bxrig)" "another host, manifest ref"
fresh; run setup-local.sh --matchbox source --matchbox-repo ORTUS-BoxLang/MatchBox --no-build   # the same repo (case, no change)
has "$log" "git clone --branch bxrig $manifest_repo $w/matchbox" "the manifest repo in other spelling is the plain flow"

# environment variables, and the flags win
env_run() { set +e; env PATH="$tmp/bin:$PATH" FAKE_LOG="$log" MB_VERSION="$manifest_version" "$@" bash "$r/scripts/setup-local.sh" --no-build </dev/null > "$w/out" 2>&1; rc=$?; set -e; }
fresh; env_run BXRIG_MATCHBOX_BRANCH=develop BXRIG_MATCHBOX_REPO=someone/fork
has "$log" "--branch develop https://github.com/someone/fork $(mbdir someone-fork-develop)" "env vars"
fresh; env_run BXRIG_MATCHBOX_BRANCH=develop
has "$log" "--branch develop $manifest_repo $(mbdir ortus-boxlang-matchbox-develop)" "env branch alone"
fresh
set +e; env PATH="$tmp/bin:$PATH" FAKE_LOG="$log" MB_VERSION="$manifest_version" BXRIG_MATCHBOX_BRANCH=develop bash "$r/scripts/setup-local.sh" --matchbox-branch other --no-build </dev/null > "$w/out" 2>&1; rc=$?; set -e
has "$log" "--branch other " "flag wins over the env var"
lacks "$log" "--branch develop" "env var overridden"

# a second run refreshes the dedicated clone with a fetch, no second clone
fresh; run setup-local.sh --matchbox-branch develop --no-build; : > "$log"; run setup-local.sh --matchbox-branch develop --no-build
d="$(mbdir ortus-boxlang-matchbox-develop)"
lacks "$log" "git clone" "no second clone"
has "$log" "git -C $d remote set-url origin $manifest_repo" "origin refreshed"
has "$log" "git -C $d fetch --quiet --depth 1 origin develop" "refresh is a shallow fetch"
has "$log" "git -C $d checkout --quiet --force --detach FETCH_HEAD" "refresh checks out FETCH_HEAD"

# a full commit id is fetched by itself
fresh; run setup-local.sh --matchbox-branch "$sha" --no-build
d="$(mbdir ortus-boxlang-matchbox-$sha)"
has "$log" "git init --quiet $d" "commit: init"
has "$log" "git -C $d remote add origin $manifest_repo" "commit: remote"
has "$log" "git -C $d fetch --quiet --depth 1 origin $sha" "commit: fetch of that sha"
lacks "$log" "git clone" "commit: no clone"
has "$r/.cache/dev.env" "MATCHBOX_REF=$sha" "commit recorded as ref"

# a dedicated dir that is not a clone is refused, not reused
fresh; mkdir -p "$(mbdir ortus-boxlang-matchbox-develop)"; run setup-local.sh --matchbox-branch develop --no-build
[[ $rc == 4 ]] || fail "dir that is not a clone: exit $rc"; has "$w/out" "is not a git clone" "dir that is not a clone"

# ---- step 1: bad values are refused before anything runs ----
bad() { # FLAG VALUE
	fresh; run setup-local.sh "$1" "$2" --no-build
	[[ $rc == 2 ]] || fail "$1 '$2': exit $rc, expected 2: $(cat "$w/out")"
	has "$w/out" "invalid MatchBox" "$1 '$2' message"
	[[ ! -s "$log" ]] || fail "$1 '$2' ran something: $(cat "$log")"
	[[ ! -e "$r/.cache" ]] || fail "$1 '$2' wrote .cache"
}
for v in "a b" "a;b" 'a$(id)' '$(id)' "a\`id\`" "-x" "--upload-pack=x" "" "a|b" "a&b" "a>b" "a'b" 'a"b' "a*" "a..b" "a/" "$(printf 'a\nb')" "a:b" "a\\b"; do bad --matchbox-branch "$v"; done
for v in "a b" "x;y/z" 'o/$(id)' "-owner/name" "" "name" "http://github.com/a/b" "https://host/a b" "https://host/a;b" "../x/y" "a/b/c" "git@github.com:a/b" "file:///etc"; do bad --matchbox-repo "$v"; done
fresh; set +e; env PATH="$tmp/bin:$PATH" FAKE_LOG="$log" BXRIG_MATCHBOX_BRANCH='x;y' bash "$r/scripts/setup-local.sh" --no-build </dev/null > "$w/out" 2>&1; rc=$?; set -e
[[ $rc == 2 ]] || fail "bad env branch: exit $rc"; has "$w/out" "BXRIG_MATCHBOX_BRANCH" "the message names the env var"; [[ ! -s "$log" ]] || fail "bad env branch ran something"
fresh; run setup-local.sh --matchbox-branch; [[ $rc == 2 ]] || fail "--matchbox-branch without a value: $rc"
# nothing was executed through a shell: no file made by an injected command
[[ ! -e "$tmp/pwned" ]] || fail "injection"

# edge and stable only exist for the manifest branch
fresh; run setup-local.sh --matchbox edge --matchbox-branch develop --no-build
[[ $rc == 2 ]] || fail "edge + branch: exit $rc"; has "$w/out" "only builds of that branch are published" "edge + branch says why"
[[ ! -s "$log" ]] || fail "edge + branch ran something: $(cat "$log")"
fresh; run setup-local.sh --matchbox edge --matchbox-repo someone/fork --no-build
[[ $rc == 2 ]] || fail "edge + repo: exit $rc"; has "$w/out" "only builds of that branch are published" "edge + repo says why"
fresh; run setup-local.sh --matchbox stable --matchbox-branch develop --no-build
[[ $rc == 2 ]] || fail "stable + branch: exit $rc"
fresh; printf '#!/usr/bin/env bash\necho "matchbox version %s"\n' "$manifest_version" > "$w/published"; chmod +x "$w/published"
extra_env=(HOME="$tmp/home" FAKE_PUBLISHED="$w/published"); run setup-local.sh --matchbox edge --matchbox-branch bxrig --no-build; extra_env=(HOME="$tmp/home")
[[ $rc == 0 ]] || fail "edge + the manifest branch is allowed: $rc: $(cat "$w/out")"

# ---- step 1: the interactive menu (a real terminal through a pty) ----
if command -v python3 >/dev/null; then
	pty() { # ANSWERS... ; runs setup-local.sh --no-build on a pty and feeds the answers
		python3 -I - "$r/scripts/setup-local.sh" "$@" > "$w/out" 2>&1 <<'PY' || true
import os, pty, sys, time
script, answers = sys.argv[1], sys.argv[2:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash", script, "--no-build"])
out = b""
for a in answers:
    time.sleep(0.4)
    os.write(fd, (a + "\n").encode())
while True:
    try:
        d = os.read(fd, 4096)
    except OSError:
        break
    if not d:
        break
    out += d
os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
PY
	}
	fresh; extra_env=(HOME="$tmp/home")
	export PATH="$tmp/bin:$PATH" FAKE_LOG="$log" MB_VERSION="$manifest_version"
	pty 4 someone/fork x\;y feature/q
	has "$w/out" "4) any GitHub branch" "the menu lists the fourth choice"
	has "$w/out" "Not a valid ref" "an invalid branch is asked again"
	d="$(mbdir someone-fork-feature-q)"
	has "$log" "--branch feature/q https://github.com/someone/fork $d" "choice 4 asks for repo and branch"
	fresh; export FAKE_LOG="$log"; pty 4 "" develop
	has "$log" "--branch develop $manifest_repo $(mbdir ortus-boxlang-matchbox-develop)" "choice 4 defaults the repo"
	fresh; export FAKE_LOG="$log"; pty 3
	has "$log" "git clone --branch bxrig $manifest_repo $w/matchbox" "choice 3 is the plain source flow"
else
	echo "skip: interactive menu (no python3)"
fi
# ---- step 2: the version check: a warning for a branch build, still an error on the default path ----
fresh; extra_env=(HOME="$tmp/home" FAKE_MB_VERSION=0.99.0); run setup-local.sh --matchbox-branch develop --no-build; extra_env=(HOME="$tmp/home")
[[ $rc == 0 ]] || fail "version mismatch must not fail: $rc: $(cat "$w/out")"
has "$w/out" "warning:" "mismatch warns"
has "$w/out" "0.99.0" "the warning names the MatchBox version"
has "$w/out" "$manifest_version" "the warning names the box.json version"
has "$r/.cache/dev.env" "MATCHBOX=" "the mismatching build is still recorded"
fresh; run setup-local.sh --matchbox-branch develop --no-build
lacks "$w/out" "warning:" "no warning when the version matches"

# get-matchbox.sh: default behaviour first
published() { printf '#!/usr/bin/env bash\necho "matchbox version %s"\n' "$1" > "$w/published"; chmod +x "$w/published"; }
fresh; published "$manifest_version"
extra_env=(HOME="$tmp/home" FAKE_PUBLISHED="$w/published"); run get-matchbox.sh "$w/out-mb"; extra_env=(HOME="$tmp/home")
[[ $rc == 0 ]] || fail "get-matchbox default: $rc: $(cat "$w/out")"
lacks "$log" "cargo" "the default path takes the published build"
has "$w/out-mb.info" "version=$manifest_version" "default .info"
lacks "$w/out-mb.info" "repo=" "the default .info has no repo line"
fresh; run get-matchbox.sh "$w/out-mb" --from-source
[[ $rc == 0 ]] || fail "get-matchbox --from-source: $rc: $(cat "$w/out")"
has "$log" "git clone --quiet --depth 1 --branch bxrig $manifest_repo" "--from-source clones the manifest branch"
has "$log" "cargo build --release --locked --features bif-tui" "--from-source keeps --locked"
# the check is not weakened: a published build with another version is refused, and so is a source build of it
fresh; published 0.99.0
extra_env=(HOME="$tmp/home" FAKE_PUBLISHED="$w/published" FAKE_MB_VERSION=0.99.0); run get-matchbox.sh "$w/out-mb"; extra_env=(HOME="$tmp/home")
[[ $rc != 0 ]] || fail "a wrong published version was accepted"; has "$w/out" "box.json wants $manifest_version" "published version mismatch is an error"
[[ ! -e "$w/out-mb" ]] || fail "a refused MatchBox was installed"
fresh; extra_env=(HOME="$tmp/home" FAKE_MB_VERSION=0.99.0); run get-matchbox.sh "$w/out-mb" --from-source; extra_env=(HOME="$tmp/home")
[[ $rc != 0 ]] || fail "a wrong source build was accepted by default"
# the same --ref/--repo as box.json is the default path
fresh; run get-matchbox.sh "$w/out-mb" --ref bxrig --repo ortus-boxlang/matchbox --from-source
has "$log" "cargo build --release --locked" "the manifest ref and repo keep the default path"

# --ref / --repo: built from source, a version difference is a warning
fresh; extra_env=(HOME="$tmp/home" FAKE_MB_VERSION=0.99.0); run get-matchbox.sh "$w/out-mb" --ref develop; extra_env=(HOME="$tmp/home")
[[ $rc == 0 ]] || fail "get-matchbox --ref: $rc: $(cat "$w/out")"
has "$log" "git clone --quiet --depth 1 --branch develop $manifest_repo" "--ref clones that ref"
has "$log" "cargo build --release --features bif-tui" "--ref builds in release mode"
lacks "$log" "--locked" "--ref does not insist on the lock file"
lacks "$log" "matchbox-linux-x86_64" "--ref never downloads the published build"
has "$w/out" "warning:" "--ref version mismatch warns"; has "$w/out" "$manifest_version" "--ref warning names box.json's version"
[[ -x "$w/out-mb" ]] || fail "--ref left no executable"
has "$w/out-mb.info" "ref=develop" ".info ref"; has "$w/out-mb.info" "repo=$manifest_repo" ".info repo"; has "$w/out-mb.info" "commit=abc1234" ".info commit"
fresh; run get-matchbox.sh "$w/out-mb" --repo=someone/fork --ref=topic
has "$log" "--branch topic https://github.com/someone/fork" "--repo shorthand and the = forms"
lacks "$w/out" "warning:" "no warning when the version matches"
fresh; run get-matchbox.sh "$w/out-mb" --repo someone/fork     # repo alone: the manifest branch of the fork
has "$log" "--branch bxrig https://github.com/someone/fork" "--repo alone keeps the manifest ref"
fresh; run get-matchbox.sh "$w/out-mb" --ref "$sha"
has "$log" "fetch --quiet --depth 1 origin $sha" "--ref with a full commit id fetches it"
for v in "a b" "a;b" 'a$(id)' "-x" ""; do
	fresh; run get-matchbox.sh "$w/out-mb" --ref "$v"
	[[ $rc == 2 ]] || fail "get-matchbox --ref '$v': $rc"; [[ ! -s "$log" ]] || fail "get-matchbox --ref '$v' ran something"
done
for v in "a b" "x;y/z" "-o/n" "" "name"; do
	fresh; run get-matchbox.sh "$w/out-mb" --repo "$v"
	[[ $rc == 2 ]] || fail "get-matchbox --repo '$v': $rc"; [[ ! -s "$log" ]] || fail "get-matchbox --repo '$v' ran something"
done

# dev-build.sh: warns about a mismatching MatchBox and builds anyway
fresh
printf '#!/usr/bin/env bash\n' | tee "$r/bootstrap/gen-assets.sh" "$r/bootstrap/gen-version.sh" "$r/scripts/get-modules.sh" > /dev/null
chmod +x "$r/bootstrap/gen-assets.sh" "$r/bootstrap/gen-version.sh" "$r/scripts/get-modules.sh"
mkdir -p "$r/src"; : > "$r/src/Main.bx"
cat > "$w/mb" <<'MB'
#!/usr/bin/env bash
[[ "$1" == --version ]] && { echo "matchbox version $MB_REPORTS"; exit 0; }
while (( $# )); do [[ "$1" == --output ]] && { echo built > "$2"; }; shift; done
MB
chmod +x "$w/mb"
extra_env=(HOME="$tmp/home" MATCHBOX="$w/mb" MB_REPORTS=0.99.0); run dev-build.sh; extra_env=(HOME="$tmp/home")
[[ $rc == 0 && -f "$r/dist/bxrig" ]] || fail "dev-build with a mismatching MatchBox: $rc: $(cat "$w/out")"
has "$w/out" "warning:" "dev-build warns"; has "$w/out" "0.99.0" "dev-build names the version"
extra_env=(HOME="$tmp/home" MATCHBOX="$w/mb" MB_REPORTS="$manifest_version"); run dev-build.sh; extra_env=(HOME="$tmp/home")
lacks "$w/out" "warning:" "dev-build is quiet when the version matches"

export FAKE_LOG=/dev/null

echo "setup-local tests passed"
