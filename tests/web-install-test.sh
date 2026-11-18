#!/usr/bin/env bash
# bootstrap/web-install.sh (the published one-line installer) with a fake download server and fake stages. Usage: web-install-test.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/bootstrap/web-install.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/srv/stable" "$tmp/srv/beta" "$tmp/bundle/bootstrap" "$tmp/binhome"; export LOG="$tmp/log"; : > "$LOG"
bash -n "$script" || fail 'syntax'
# fake tools
cat > "$tmp/bin/curl" <<'CURL'
#!/usr/bin/env bash
out=""; url=""; cfg=""
echo "curl $*" >> "@TMP@/curl.argv"
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift ;; -K) cfg="$2"; shift ;; http://*) url="$1" ;; esac; shift; done
[ "$cfg" = - ] && cat >> "@TMP@/curl.stdin"
src="@TMP@/srv/${url#http://fake/}"
[ -f "$src" ] || exit 22
if [ -n "$out" ]; then cp "$src" "$out"; else cat "$src"; fi
CURL
sed -i "s|@TMP@|$tmp|g" "$tmp/bin/curl"
printf '#!/usr/bin/env bash\n' > "$tmp/bin/pacman"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/sudo"
chmod +x "$tmp/bin"/*
# the bundle: a bootstrap/install.sh that logs its stage and installs the binary like the real binary stage
cat > "$tmp/bundle/bootstrap/install.sh" <<'INS'
#!/usr/bin/env bash
echo "stage $*" >> "$LOG"
if [[ "$1" == binary ]]; then
  while [[ $# -gt 0 ]]; do [[ "$1" == --binary ]] && { mkdir -p "$BXRIG_BIN_DIR"; cp "$2" "$BXRIG_BIN_DIR/bxrig"; chmod +x "$BXRIG_BIN_DIR/bxrig"; }; shift; done
fi
INS
chmod +x "$tmp/bundle/bootstrap/install.sh"
tar -czf "$tmp/srv/stable/bootstrap.tar.gz" -C "$tmp/bundle" bootstrap
printf '#!/usr/bin/env bash\necho "bxrig $*" >> "$LOG"\n' > "$tmp/srv/stable/bxrig-linux-x86_64"
for f in bxrig-linux-x86_64 bootstrap.tar.gz; do echo "$(sha256sum "$tmp/srv/stable/$f" | cut -d' ' -f1)  $f" > "$tmp/srv/stable/$f.sha256"; done
printf 'version=0.12.0\ncommit=abc\nsha256=x\nbuiltAt=now\n' > "$tmp/srv/stable/version-latest.properties"
cp -r "$tmp/srv/stable/." "$tmp/srv/beta/"
run() { env HOME="$tmp/home" BXRIG_BIN_DIR="$tmp/binhome" BXRIG_BASE_URL=http://fake BXRIG_INSTALL_ALLOW_ROOT=1 PATH="$tmp/bin:$PATH" LOG="$LOG" NO_COLOR=1 bash "$script" "$@"; }
code() { set +e; run "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }

# the banner, the wordmark and the tagline; a dry run downloads nothing
out="$(run --dry-run --yes 2>&1)"
[[ "$out" == *'██╔══██╗ ██╗  ██╗'* && "$out" == *'Your dev rig. Beautiful by default.'* && "$out" == *'Powered by BoxLang'* ]] || fail 'banner'
[[ ! -s "$LOG" ]] || fail 'a dry run did something'
# bad arguments
[[ "$(code --channel nightly)" == 1 ]] || fail 'a bad channel is refused'
[[ "$(code --answers "$tmp/nope.json")" == 1 ]] || fail 'a missing answers file is refused'
[[ "$(code --bogus)" == 1 ]] || fail 'an unknown option is refused'
# no human input: stages in order, then the wizard with the default answers
out="$(run --yes 2>&1)" || fail "install: $out"
[[ "$(grep -c '^stage' "$LOG")" == 4 ]] || fail "four stages: $(cat "$LOG")"
[[ "$(grep '^stage' "$LOG" | cut -d' ' -f2 | tr '\n' ' ')" == "packages toolchains binary core " ]] || fail "stage order: $(cat "$LOG")"
grep -q '^bxrig init --defaults --yes' "$LOG" || fail "the wizard runs with defaults: $(cat "$LOG")"
[[ -x "$tmp/binhome/bxrig" ]] || fail 'the binary was installed'
# answers file
: > "$LOG"; echo '{"desktops":"hyprland"}' > "$tmp/answers.json"; run --yes --answers "$tmp/answers.json" >/dev/null 2>&1
grep -q "^bxrig init --answers $tmp/answers.json --yes" "$LOG" || fail 'the wizard runs with your answers'
# no wizard
: > "$LOG"; run --yes --no-wizard >/dev/null 2>&1; ! grep -q '^bxrig init' "$LOG" || fail '--no-wizard'
# the beta channel downloads from beta/
echo "beta-build" >> "$tmp/srv/beta/bxrig-linux-x86_64"; echo "$(sha256sum "$tmp/srv/beta/bxrig-linux-x86_64" | cut -d' ' -f1)  bxrig-linux-x86_64" > "$tmp/srv/beta/bxrig-linux-x86_64.sha256"
: > "$LOG"; run --yes --channel beta --no-wizard >/dev/null 2>&1; grep -q beta-build "$tmp/binhome/bxrig" || fail 'the beta binary'
# a tampered download stops before any stage
echo "deadbeef  bxrig-linux-x86_64" > "$tmp/srv/stable/bxrig-linux-x86_64.sha256"
: > "$LOG"; [[ "$(code --yes)" == 1 ]] || fail 'a checksum mismatch fails'
! grep -q '^stage' "$LOG" || fail 'a stage ran after a checksum mismatch'
# signed releases: with a public key the release information must verify, and both files must match it
if command -v openssl >/dev/null; then
	openssl genpkey -algorithm ed25519 -out "$tmp/k.pem" 2>/dev/null; openssl pkey -in "$tmp/k.pem" -pubout -out "$tmp/pub.pem"
	openssl genpkey -algorithm ed25519 -out "$tmp/o.pem" 2>/dev/null; openssl pkey -in "$tmp/o.pem" -pubout -out "$tmp/o.pub"
	echo "$(sha256sum "$tmp/srv/stable/bxrig-linux-x86_64" | cut -d' ' -f1)" > /dev/null
	echo "good build" > "$tmp/srv/stable/bxrig-linux-x86_64"; echo "$(sha256sum "$tmp/srv/stable/bxrig-linux-x86_64" | cut -d' ' -f1)  bxrig-linux-x86_64" > "$tmp/srv/stable/bxrig-linux-x86_64.sha256"
	bsha="$(cut -d' ' -f1 "$tmp/srv/stable/bootstrap.tar.gz.sha256")"; asha="$(cut -d' ' -f1 "$tmp/srv/stable/bxrig-linux-x86_64.sha256")"
	printf 'version=0.12.0\ncommit=abc\nsha256=%s\nbootstrap_sha256=%s\n' "$asha" "$bsha" > "$tmp/srv/stable/version-latest.properties"
	sign() { openssl pkeyutl -sign -rawin -inkey "$tmp/k.pem" -in "$tmp/srv/stable/version-latest.properties" -out "$tmp/srv/stable/version-latest.properties.sig"; }
	prun() { env HOME="$tmp/home" BXRIG_BIN_DIR="$tmp/binhome" BXRIG_BASE_URL=http://fake BXRIG_INSTALL_ALLOW_ROOT=1 BXRIG_PUBKEY_B64="${PUB:-$(base64 -w0 "$tmp/pub.pem")}" PATH="$tmp/bin:$PATH" LOG="$LOG" NO_COLOR=1 bash "$script" "$@"; }
	pcode() { set +e; prun "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
	: > "$LOG"; rm -f "$tmp/srv/stable/version-latest.properties.sig"; [[ "$(pcode --yes --no-wizard)" == 1 ]] || fail 'a missing signature fails'
	! grep -q '^stage' "$LOG" || fail 'a stage ran without a signature'
	sign; [[ "$(pcode --yes --no-wizard)" == 0 ]] || fail "a valid signature installs: $(prun --yes --no-wizard 2>&1 | tail -4)"
	out="$(prun --yes --no-wizard 2>&1)"; [[ "$out" == *"signature verified"* ]] || fail "the signature is reported: $out"
	: > "$LOG"; PUB="$(base64 -w0 "$tmp/o.pub")" pcode --yes --no-wizard | grep -q . ; [[ "$(PUB="$(base64 -w0 "$tmp/o.pub")" pcode --yes --no-wizard)" == 1 ]] || fail 'a signature by another key fails'
	! grep -q '^stage' "$LOG" || fail 'a stage ran after a bad signature'
	printf 'version=0.12.0\ncommit=abc\nsha256=%s\nbootstrap_sha256=%s\nx=1\n' "$asha" "$bsha" > "$tmp/srv/stable/version-latest.properties"
	[[ "$(pcode --yes --no-wizard)" == 1 ]] || fail 'edited release information fails'
	printf 'version=0.12.0\ncommit=abc\nsha256=%s\nbootstrap_sha256=%s\n' "0000" "$bsha" > "$tmp/srv/stable/version-latest.properties"; sign
	[[ "$(pcode --yes --no-wizard)" == 1 ]] || fail 'a binary that does not match the signed hash fails'
fi
# ---- --source: stable, beta and the unsigned github source (fake codeload, API and git; nothing touches the network) ----
REALGIT="$(command -v git)"
echo "beta-build" > "$tmp/srv/beta/bxrig-linux-x86_64"; echo "$(sha256sum "$tmp/srv/beta/bxrig-linux-x86_64" | cut -d' ' -f1)  bxrig-linux-x86_64" > "$tmp/srv/beta/bxrig-linux-x86_64.sha256"
printf 'version=0.12.0\ncommit=abc\nsha256=x\n' > "$tmp/srv/beta/version-latest.properties"
echo "$(sha256sum "$tmp/srv/beta/bxrig-linux-x86_64" | cut -d' ' -f1)" > /dev/null
: > "$LOG"; run --yes --source beta --no-wizard >/dev/null 2>&1; grep -q beta-build "$tmp/binhome/bxrig" || fail '--source beta downloads from beta/'
rm -f "$tmp/binhome/bxrig"
: > "$LOG"; env BXRIG_SOURCE=beta HOME="$tmp/home" BXRIG_BIN_DIR="$tmp/binhome" BXRIG_BASE_URL=http://fake BXRIG_INSTALL_ALLOW_ROOT=1 PATH="$tmp/bin:$PATH" LOG="$LOG" NO_COLOR=1 bash "$script" --yes --no-wizard >/dev/null 2>&1; grep -q beta-build "$tmp/binhome/bxrig" || fail 'BXRIG_SOURCE=beta'
# a source tree: git archive records the commit in the tarball
mktree() {  # DIR PREFIX: a BxRig-looking repository archived the way codeload does
	mkdir -p "$1/r/bootstrap" "$1/r/src"; echo '{}' > "$1/r/box.json"; echo 'x' > "$1/r/src/Main.bx"
	cat > "$1/r/bootstrap/install.sh" <<'INS'
#!/usr/bin/env bash
echo "stage $*" >> "$LOG"
[[ "$1" == --dry-run ]] && echo "TREE-PLAN: matchbox build 0.14.0-425a294"
if [[ "$1" == binary ]]; then mkdir -p "$BXRIG_BIN_DIR"; printf '#!/usr/bin/env bash\necho "bxrig $*" >> "$LOG"\n' > "$BXRIG_BIN_DIR/bxrig"; chmod +x "$BXRIG_BIN_DIR/bxrig"; fi
INS
	( cd "$1/r" && "$REALGIT" init -q . && "$REALGIT" add -A && "$REALGIT" -c user.email=t@t -c user.name=t commit -q -m t && "$REALGIT" archive --format=tar.gz --prefix="$2/" HEAD > "$1/out.tgz" && "$REALGIT" rev-parse HEAD > "$1/sha" )
}
mktree "$tmp/t1" "proj-feat-x"; SHA1="$(cat "$tmp/t1/sha")"
mkdir -p "$tmp/srv/gh-codeload/acme/proj/tar.gz/feat" "$tmp/srv/gh-codeload/ortus-boxlang/BxRig/tar.gz" "$tmp/srv/gh-api/repos/acme/proj/commits/feat"
cp "$tmp/t1/out.tgz" "$tmp/srv/gh-codeload/acme/proj/tar.gz/feat/x"; cp "$tmp/t1/out.tgz" "$tmp/srv/gh-codeload/ortus-boxlang/BxRig/tar.gz/dev"
printf '%s' "$SHA1" > "$tmp/srv/gh-api/repos/acme/proj/commits/feat/x"
mkdir -p "$tmp/gbin"; ln -sf "$tmp/bin/curl" "$tmp/gbin/curl"
# a fake git: ls-remote answers $GIT_SHA (nothing when unset); everything else is the real git
cat > "$tmp/gbin/git" <<'G'
#!/usr/bin/env bash
if [[ "$1" == ls-remote ]]; then echo "git $*" >> "$GITLOG"; [[ -n "${GIT_SHA:-}" ]] && printf '%s\trefs/heads/x\n' "$GIT_SHA"; exit 0; fi
exec "@REAL@" "$@"
G
sed -i "s|@REAL@|$REALGIT|" "$tmp/gbin/git"; chmod +x "$tmp/gbin/git"
grun() { env -u GITHUB_TOKEN -u GH_TOKEN ${GHT:+"GITHUB_TOKEN=$GHT"} HOME="$tmp/home" BXRIG_BIN_DIR="$tmp/binhome" BXRIG_BASE_URL=http://fake BXRIG_INSTALL_ALLOW_ROOT=1 PATH="$tmp/gbin:$tmp/bin:$PATH" LOG="$LOG" GITLOG="$tmp/git.log" NO_COLOR=1 \
	BXRIG_GITHUB_CODELOAD=http://fake/gh-codeload BXRIG_GITHUB_API=http://fake/gh-api BXRIG_GITHUB_GIT=http://fake/gh-git BXRIG_TTY="${TTYF:-$tmp/no-tty}" GIT_SHA="${GIT_SHA-$SHA1}" "$@"; }
gcode() { set +e; grun bash "$script" "$@" >/dev/null 2>&1; local c=$?; set -e; echo "$c"; }
# bad --source values and conflicts are refused before anything is downloaded
: > "$tmp/curl.argv"; : > "$LOG"
for bad in nightly github: 'github:acme/proj@' 'github:acme/pr oj@x' 'github:acme/proj@-x' 'github:acme/proj@a..b' 'github:../proj@x' 'github:acme/a/b@x' 'github:acme/proj@x y' 'github:acme/proj@$(id)' 'github:acme/proj@x;ls' 'github:@' 'github:acme/proj@/x' 'github:acme/proj@x/' 'GITHUB:acme/proj@x'; do
	[[ "$(gcode --yes --source "$bad")" == 1 ]] || fail "--source '$bad' is refused"
done
[[ "$(gcode --yes --source github:acme/proj@feat/x --channel beta)" == 1 ]] || fail '--channel with a github source is refused'
[[ "$(gcode --yes --source stable --channel beta)" == 1 ]] || fail 'conflicting --source and --channel'
[[ "$(gcode --yes --matchbox-branch '-x')" == 1 && "$(gcode --yes --matchbox-branch 'a b')" == 1 && "$(gcode --yes --matchbox-branch '$(id)')" == 1 ]] || fail 'a bad --matchbox-branch is refused'
[[ "$(gcode --yes --matchbox-branch '')" == 1 ]] || fail 'an empty --matchbox-branch is refused'
[[ "$(gcode --yes --matchbox-branch ok --matchbox-repo '-a/b')" == 1 && "$(gcode --yes --matchbox-branch ok --matchbox-repo 'a b/c')" == 1 && "$(gcode --yes --matchbox-branch ok --matchbox-repo 'a')" == 1 && "$(gcode --yes --matchbox-branch ok --matchbox-repo '$(id)/x')" == 1 && "$(gcode --yes --matchbox-branch ok --matchbox-repo 'a/b/c')" == 1 ]] || fail 'a bad --matchbox-repo is refused'
[[ "$(gcode --yes --matchbox-repo a/b)" == 1 ]] || fail '--matchbox-repo without a branch is refused'
[[ "$(gcode --yes --snapshot --matchbox-branch x)" == 1 && "$(gcode --yes --snapshot --matchbox-from-source)" == 1 ]] || fail '--snapshot with a branch is refused'
[[ ! -s "$LOG" ]] || fail 'a stage ran after a bad option'; ! grep -q 'codeload\|gh-' "$tmp/curl.argv" || fail 'something was downloaded after a bad option'
# the github source is never silent: no --yes and no terminal, or a wrong word, stops before the download (exit 2)
: > "$tmp/curl.argv"; out="$(grun bash "$script" --source github:acme/proj@feat/x 2>&1)" && fail 'an unsigned source without consent installed'
[[ "$(gcode --source github:acme/proj@feat/x)" == 2 ]] || fail 'no consent is exit 2'
[[ "$out" == *'UNSIGNED DEVELOPMENT SOURCE'* && "$out" == *"commit $SHA1"* && "$out" == *'needs --yes'* ]] || fail "the warning and the demand for --yes: $out"
! grep -q 'gh-codeload' "$tmp/curl.argv" || fail 'the tarball was downloaded before consent'; ! grep -q '^stage' "$LOG" || fail 'a stage ran without consent'
echo yes > "$tmp/tty-yes"; [[ "$(TTYF="$tmp/tty-yes" gcode --source github:acme/proj@feat/x)" == 2 ]] || fail 'a wrong word cancels (exit 2)'
! grep -q '^stage' "$LOG" || fail 'a stage ran after a wrong word'
# the typed word, with a token: the install runs the TREE'S stages, builds the binary from it (no --binary), logs the source
echo unsigned > "$tmp/tty-ok"; : > "$LOG"; : > "$tmp/curl.argv"; : > "$tmp/curl.stdin"; rm -f "$tmp/binhome/bxrig" "$tmp/home/.local/share/bxrig/install-source"
out="$(TTYF="$tmp/tty-ok" GHT=ghp_SECRETtoken123 grun bash "$script" --source github:acme/proj@feat/x 2>&1)" || fail "typed word: $out"
[[ "$(grep '^stage' "$LOG" | cut -d' ' -f2- | tr '\n' '|')" == 'packages --yes|toolchains --yes --matchbox-from-source|binary --yes --force|core --yes|' ]] || fail "tree stages: $(cat "$LOG")"
grep -q '^bxrig init' "$LOG" || fail 'the wizard runs from the freshly built binary'
grep -q '^source: github:acme/proj@feat/x' "$tmp/home/.cache/bxrig/install.log" && grep -q "^commit: $SHA1" "$tmp/home/.cache/bxrig/install.log" && grep -q 'signed: no' "$tmp/home/.cache/bxrig/install.log" || fail 'the log records the source and the commit'
grep -q "commit=$SHA1" "$tmp/home/.local/share/bxrig/install-source" || fail 'the install-source file'
[[ "$out" == *'came from an unsigned source'* && "$out" == *'update apply'* ]] || fail 'the closing warning about update'
# the token reaches curl only through the config on stdin: never in the output, the log, or an argument
grep -q 'ghp_SECRETtoken123' "$tmp/curl.stdin" || fail 'the token is sent as a header'
for f in "$tmp/curl.argv" "$tmp/home/.cache/bxrig/install.log" "$tmp/home/.local/share/bxrig/install-source"; do ! grep -q 'SECRETtoken' "$f" || fail "the token leaked into $f"; done
[[ "$out" != *SECRETtoken* ]] || fail 'the token was printed'
# --yes consents; without a token no header is sent; the stable path never sends one
: > "$LOG"; : > "$tmp/curl.stdin"; rm -f "$tmp/binhome/bxrig"; [[ "$(gcode --yes --source github:acme/proj@feat/x --no-wizard)" == 0 ]] || fail '--yes installs the github source'
[[ ! -s "$tmp/curl.stdin" ]] || fail 'a header was sent without a token'
: > "$tmp/curl.argv"; GHT=ghp_SECRETtoken123 grun bash "$script" --yes --no-wizard >/dev/null 2>&1 || true; ! grep -q -- ' -K ' "$tmp/curl.argv" || fail 'the stable path sent the token'
# the plan: dry run downloads and unpacks, shows the commit and the tree's own plan, installs nothing and needs no consent
: > "$LOG"; rm -f "$tmp/binhome/bxrig"
out="$(grun bash "$script" --dry-run --source github:acme/proj@feat/x 2>&1)" || fail "dry run: $out"
[[ "$out" == *'UNSIGNED'* && "$out" == *"commit: $SHA1"* && "$out" == *'TREE-PLAN: matchbox build 0.14.0-425a294'* && "$out" == *'stages: packages, toolchains'* ]] || fail "dry-run plan: $out"
[[ "$(grep '^stage' "$LOG")" == 'stage --dry-run --matchbox-from-source' ]] || fail "a dry run ran stages: $(cat "$LOG")"; [[ ! -e "$tmp/binhome/bxrig" ]] || fail 'a dry run installed'
# no git answer: the API resolves the commit; a commit ref needs no lookup
: > "$tmp/git.log"; out="$(GIT_SHA= grun bash "$script" --dry-run --source github:acme/proj@feat/x 2>&1)"; [[ "$out" == *"commit feature"* || "$out" == *"commit $SHA1"* ]] || fail "API commit: $out"
grep -q 'gh-api/repos/acme/proj/commits/feat/x' "$tmp/curl.argv" || fail 'the API was asked for the commit'
# shorthands use the default repository
: > "$tmp/curl.argv"; grun bash "$script" --dry-run --source github:@dev >/dev/null 2>&1; grep -q 'gh-codeload/ortus-boxlang/BxRig/tar.gz/dev' "$tmp/curl.argv" || fail 'github:@REF'
: > "$tmp/curl.argv"; grun bash "$script" --dry-run --source github:dev >/dev/null 2>&1; grep -q 'gh-codeload/ortus-boxlang/BxRig/tar.gz/dev' "$tmp/curl.argv" || fail 'github:REF'
# MatchBox options pass through to the stages, for both sources. The github source compiles bxrig, so it builds the manifest's MatchBox
# branch (--matchbox-from-source = bxrig) unless the user chose another MatchBox; the binary stage then stops if that MatchBox cannot compile it.
stages() { grep '^stage' "$LOG" | cut -d' ' -f2- | tr '\n' '|'; }
gstages() { : > "$LOG"; rm -f "$tmp/binhome/bxrig"; gcode --yes --no-wizard --source github:acme/proj@feat/x "$@" >/dev/null; stages; }
sstages() { : > "$LOG"; rm -f "$tmp/binhome/bxrig"; run --yes --no-wizard "$@" >/dev/null 2>&1; stages; }
[[ "$(gstages --matchbox-branch feature/x)" == 'packages --yes|toolchains --yes --matchbox-branch feature/x|binary --yes --force|core --yes|' ]] || fail "github with a branch: $(cat "$LOG")"
[[ "$(gstages --matchbox-branch feature/x --matchbox-repo someone/fork)" == 'packages --yes|toolchains --yes --matchbox-branch feature/x --matchbox-repo someone/fork|binary --yes --force|core --yes|' ]] || fail "github with a branch and repo: $(cat "$LOG")"
[[ "$(gstages --snapshot)" == 'packages --yes|toolchains --yes --snapshot|binary --yes --force|core --yes|' ]] || fail "github with --snapshot is not silently switched to a branch build: $(cat "$LOG")"
[[ "$(gstages --matchbox-from-source)" == 'packages --yes|toolchains --yes --matchbox-from-source|binary --yes --force|core --yes|' ]] || fail "github with --matchbox-from-source: $(cat "$LOG")"
# the stable path: the prebuilt bxrig only needs the MatchBox toolchain, so the default asks for nothing special
[[ "$(sstages)" == 'packages --yes|toolchains --yes|binary --yes --binary '*' --force|core --yes|' ]] || fail "stable default stages: $(cat "$LOG")"
[[ "$(sstages --snapshot)" == *'|toolchains --yes --snapshot|'* ]] || fail "stable with --snapshot: $(cat "$LOG")"
[[ "$(sstages --matchbox-branch feature/x --matchbox-repo someone/fork)" == *'|toolchains --yes --matchbox-branch feature/x --matchbox-repo someone/fork|'* ]] || fail "stable with a branch and repo: $(cat "$LOG")"
[[ "$(sstages --matchbox-from-source)" == *'|toolchains --yes --matchbox-from-source|'* ]] || fail "stable with --matchbox-from-source: $(cat "$LOG")"
# the environment variables mean the same
: > "$LOG"; rm -f "$tmp/binhome/bxrig"; env BXRIG_MATCHBOX_CHANNEL=snapshot HOME="$tmp/home" BXRIG_BIN_DIR="$tmp/binhome" BXRIG_BASE_URL=http://fake BXRIG_INSTALL_ALLOW_ROOT=1 PATH="$tmp/bin:$PATH" LOG="$LOG" NO_COLOR=1 bash "$script" --yes --no-wizard >/dev/null 2>&1
[[ "$(stages)" == *'|toolchains --yes --snapshot|'* ]] || fail "BXRIG_MATCHBOX_CHANNEL=snapshot: $(cat "$LOG")"
: > "$LOG"; rm -f "$tmp/binhome/bxrig"; env BXRIG_MATCHBOX_BRANCH=dev BXRIG_MATCHBOX_REPO=acme/mb HOME="$tmp/home" BXRIG_BIN_DIR="$tmp/binhome" BXRIG_BASE_URL=http://fake BXRIG_INSTALL_ALLOW_ROOT=1 PATH="$tmp/bin:$PATH" LOG="$LOG" NO_COLOR=1 bash "$script" --yes --no-wizard >/dev/null 2>&1
[[ "$(stages)" == *'|toolchains --yes --matchbox-branch dev --matchbox-repo acme/mb|'* ]] || fail "BXRIG_MATCHBOX_BRANCH and BXRIG_MATCHBOX_REPO: $(cat "$LOG")"
# a tarball with paths that leave the folder, or that is no BxRig tree, is refused
printf 'not a tarball' > "$tmp/srv/gh-codeload/acme/proj/tar.gz/feat/x"; : > "$LOG"
[[ "$(gcode --yes --source github:acme/proj@feat/x)" == 1 ]] || fail 'a bad archive is refused'
mkdir -p "$tmp/t3/other-1/docs" && echo x > "$tmp/t3/other-1/docs/a"; tar -czf "$tmp/srv/gh-codeload/acme/proj/tar.gz/feat/x" -C "$tmp/t3" other-1
[[ "$(gcode --yes --source github:acme/proj@feat/x)" == 1 ]] || fail 'a tree without bootstrap/install.sh is refused'
mkdir -p "$tmp/t4/a" && echo x > "$tmp/t4/a/f" && ( cd "$tmp/t4" && tar -czf "$tmp/srv/gh-codeload/acme/proj/tar.gz/feat/x" a --transform 's|^a/f|../f|' 2>/dev/null ) || true
[[ "$(gcode --yes --source github:acme/proj@feat/x)" == 1 ]] || fail 'an archive with .. paths is refused'
! grep -q '^stage' "$LOG" || fail 'a stage ran for a bad archive'
# root is refused
rc=0; env HOME="$tmp/home" BXRIG_BASE_URL=http://fake PATH="$tmp/bin:$PATH" NO_COLOR=1 bash "$script" --yes >/dev/null 2>&1 || rc=$?
[[ "$(id -u)" != 0 || "$rc" == 1 ]] || fail 'root is refused'
echo "web-install-test ok"
