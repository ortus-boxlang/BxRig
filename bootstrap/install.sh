#!/usr/bin/env bash
set -euo pipefail

# Tool versions, installer URLs and the Java package live in box.json at the repository root (loaded below).
# BoxLang follows the latest stable release (owner decision 2026-11-09); BXRIG_BOXLANG_VERSION=x.y.z pins it.
# MatchBox stays pinned in box.json: it compiles bxrig itself, so the tested version matters.
# MatchBox is the build of the head of the box.json toolchain.matchbox.ref branch (see "MatchBox: the head of the bxrig branch" below).
# BXRIG_MVM_VERSION=x.y.z asks the MVM installer for a specific release.
MIN_FREE_GB=5
BOXLANG_LATEST_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang/version-latest.properties"

usage() {
	cat >&2 <<'USAGE'
Usage: install.sh [--yes] [--dry-run] [--matchbox-branch REF] [--matchbox-from-source]
                                          install everything: packages, toolchains, the bxrig binary, the core apps
       install.sh check                   read-only report of what is installed
       install.sh packages|toolchains|binary|core --yes [--binary PATH --force]   re-run one stage
                                          (toolchains also takes --matchbox-branch REF and --matchbox-from-source)
       install.sh wizard                  the setup wizard (bxrig init); the full install ends with it at a terminal
USAGE
	exit 2
}
# Public words: no word = the whole install. Stage words re-run one stage. Internally the stages keep their old mode names.
mode=full; yes=0; dry=0; force=0; binary_arg=""; mb_branch_arg=""; mb_branch_set=0; mb_source=0
# The MatchBox branch to install (default: the manifest's toolchain.matchbox.ref). Only [A-Za-z0-9._/@+-], no leading dash, no "..", no
# leading or trailing slash: it ends up in a git argument and in an API path, never in a shell string.
valid_ref() { [[ "$1" =~ ^[A-Za-z0-9._/@+-]+$ && "$1" != -* && "$1" != *..* && "$1" != /* && "$1" != */ ]]; }
case "${1:-}" in
	check) mode=--check; shift ;;
	packages) mode=--install; shift ;;
	toolchains) mode=--install-toolchains; shift ;;
	binary) mode=--install-binary; shift ;;
	core) mode=--core; shift ;;
	wizard) mode=--wizard; shift ;;
esac
case "$mode" in
	--check|--wizard) [[ $# -eq 0 ]] || usage ;;
	full|--install-toolchains)
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--yes) yes=1 ;;
				--dry-run) [[ "$mode" == full ]] || usage; dry=1 ;;
				--matchbox-branch) [[ $# -ge 2 ]] || usage; mb_branch_arg="$2"; mb_branch_set=1; shift ;;
				--matchbox-from-source) mb_source=1 ;;
				*) usage ;;
			esac
			shift
		done
		[[ "$mode" == full || $yes -eq 1 ]] || usage ;;
	--install|--core)
		[[ $# -eq 1 && "$1" == --yes ]] || usage; yes=1 ;;
	--install-binary)
		while [[ $# -gt 0 ]]; do
			case "$1" in
				--yes) yes=1; shift ;;
				--force) force=1; shift ;;
				--binary) [[ $# -ge 2 ]] || usage; binary_arg="$2"; shift 2 ;;
				*) usage ;;
			esac
		done
		[[ $yes -eq 1 ]] || usage ;;
esac

MB_BRANCH_REQ="${mb_branch_arg:-${BXRIG_MATCHBOX_BRANCH:-}}"
if { (( mb_branch_set )) || [[ -n "$MB_BRANCH_REQ" ]]; } && ! valid_ref "$MB_BRANCH_REQ"; then
	echo "Invalid MatchBox branch: '$MB_BRANCH_REQ' (letters, digits and . _ / @ + - only; no leading dash, no ..)" >&2
	exit 2
fi
command -v pacman >/dev/null 2>&1 || {
	echo "BxRig requires Arch Linux/CachyOS (pacman)" >&2
	exit 1
}
packages=(git curl unzip rustup base-devel jq)   # the Java package is added from box.json
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || true)"

# ---- box.json: the single place that names tool versions (needs jq, so --install installs jq first) ----
MANIFEST="${BXRIG_MANIFEST:-$root/box.json}"
manifest_error=""
load_manifest() {
	manifest_error=""
	command -v jq >/dev/null 2>&1 || { manifest_error="jq is required to read box.json"; return 1; }
	[[ -f "$MANIFEST" ]] || { manifest_error="box.json not found at $MANIFEST (run this script from a BxRig checkout)"; return 1; }
	jq -e . "$MANIFEST" >/dev/null 2>&1 || { manifest_error="box.json is not valid JSON: $MANIFEST"; return 1; }
	local key
	for key in .toolchain.java.version .toolchain.java.package .toolchain.boxlang.version .toolchain.bvm.installer \
						 .toolchain.mvm.installer .toolchain.matchbox.version .toolchain.rust.channel; do
		jq -e "$key" "$MANIFEST" >/dev/null 2>&1 || { manifest_error="box.json is missing ${key#.}"; return 1; }
	done
	JAVA_MAJOR="$(jq -r .toolchain.java.version "$MANIFEST")"
	JAVA_PKG="$(jq -r .toolchain.java.package "$MANIFEST")"
	MATCHBOX_VERSION="$(jq -r .toolchain.matchbox.version "$MANIFEST")"
	# With "downloads" set, MatchBox is not installed by mvm: it is the build of the MatchBox `bxrig` branch
	# that CI publishes to S3 (see .github/workflows/matchbox.yml), checked against its sha256 and kept in
	# $MATCHBOX_HOME so it never replaces the `matchbox` that mvm manages.
	MATCHBOX_DOWNLOADS="$(jq -r '.toolchain.matchbox.downloads // empty' "$MANIFEST")"
	MATCHBOX_HOME="${BXRIG_HOME:-$HOME/.local/share/bxrig}/matchbox"
	# The branch whose head is installed: box.json toolchain.matchbox.ref, or --matchbox-branch / BXRIG_MATCHBOX_BRANCH. Another
	# branch has no published builds, so it needs --matchbox-from-source (clone, cargo build).
	MATCHBOX_REPO="$(jq -r '.toolchain.matchbox.repo // empty' "$MANIFEST")"
	MATCHBOX_REF="$(jq -r '.toolchain.matchbox.ref // empty' "$MANIFEST")"
	MB_BRANCH="${MB_BRANCH_REQ:-$MATCHBOX_REF}"
	MB_CUSTOM=0; [[ -z "$MB_BRANCH_REQ" || "$MB_BRANCH_REQ" == "$MATCHBOX_REF" ]] || MB_CUSTOM=1
	BVM_URL="$(jq -r .toolchain.bvm.installer "$MANIFEST")"
	MVM_URL="$(jq -r .toolchain.mvm.installer "$MANIFEST")"
	RUST_CHANNEL="$(jq -r .toolchain.rust.channel "$MANIFEST")"
	BOXLANG_VERSION="${BXRIG_BOXLANG_VERSION:-$(jq -r .toolchain.boxlang.version "$MANIFEST")}"
	packages=("$JAVA_PKG" git curl unzip rustup base-devel jq)
}
if load_manifest; then manifest_ok=1; else manifest_ok=0; fi
need_manifest() {  # for modes that cannot work without it
	(( manifest_ok )) && return 0
	echo "$manifest_error" >&2
	[[ "$manifest_error" == jq* ]] && echo "Run install.sh packages --yes first: it installs jq, then reads box.json." >&2
	exit 1
}

# ---- Read-only inspection (used by --check and --plan; never changes the system) ----
BIN_DIR="${BXRIG_BIN_DIR:-$HOME/.local/bin}"
BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
MVM_HOME="${MVM_HOME:-$HOME/.mvm}"
probe_path="$BVM_HOME/bin:$BVM_HOME/current/bin:$MVM_HOME/bin:$HOME/.cargo/bin:$BIN_DIR:$PATH"
[[ -z "${MATCHBOX_DOWNLOADS:-}" ]] || probe_path="${MATCHBOX_HOME}/bin:$probe_path"

tool_path() { PATH="$probe_path" command -v "$1" 2>/dev/null; }
first_version() { grep -m1 -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' || true; }
tool_version() {  # NAME [ARG]: first x.y[.z] printed by the tool, empty if unknown
	local bin; bin="$(tool_path "$1")" || return 0
	PATH="$probe_path" "$bin" "${2:---version}" 2>&1 | first_version || true
}
is_interactive() { [[ "${BXRIG_INTERACTIVE:-0}" == 1 || ( -t 0 && -t 1 ) ]]; }
# Refuse early, with a reason, when the machine cannot be provisioned. Needs inspect() to have run.
preflight_common() {
	[[ "$os_ok" == 1 ]] || { echo "Unsupported OS: $os_name (BxRig supports CachyOS and Arch Linux)" >&2; exit 1; }
	[[ "$cpu" == x86_64 ]] || { echo "Unsupported CPU: $cpu (x86_64 only)" >&2; exit 1; }
	(( free_gb >= MIN_FREE_GB )) || { echo "Not enough free disk space: ${free_gb} GB free in $HOME, need at least $MIN_FREE_GB GB" >&2; exit 1; }
}
step_run() { local what="$1"; shift; "$@" || { echo "Failed: $what" >&2; exit 1; }; }
# Like step_run, but tries up to three times (0s, 10s, 30s apart): GitHub answers 403 to anonymous API calls
# when a shared address is rate limited, and that is usually brief.
step_retry() {
	local what="$1" wait; shift
	for wait in ${BXRIG_RETRY_WAITS:-0 10 30}; do
		(( wait )) && { echo "Retrying in ${wait}s: $what" >&2; sleep "$wait"; }
		"$@" && return 0
	done
	echo "Failed after 3 attempts: $what (if GitHub reports HTTP 403, wait a while and rerun; this is a rate limit)" >&2; exit 1
}
# ---- MatchBox: the head of the bxrig branch (box.json toolchain.matchbox.ref) ----
# version-latest.properties and the evergreen files can be served stale (for about a day, and one build behind the branch is enough for
# bx-image to fail with "Missing required capability: matchbox.types.v1"), so the build is the one the branch head names:
# <downloads>/<version>-<head7>/ (immutable), where head7 comes from `git ls-remote REPO refs/heads/REF` (or the GitHub API without git).
# When that folder is not published yet the install STOPS (exit 1) and says how to go on; it never falls back to the older build.
# Only when the head cannot be read at all (no network to GitHub) the build named in version-latest.properties is used, with a warning.
# BXRIG_MATCHBOX_FILE=PATH installs a local build instead. --matchbox-from-source clones the branch and builds it with cargo (Rust comes
# from the packages stage, which runs before this one). A branch other than the manifest's has no published builds.
MB_LOOKUP=0; MB_HEAD=""; MB_HS=""; MB_STATE=""; MB_BASE=""
mb_marker() { sed -n "s/^$1=//p" "$MATCHBOX_HOME/build.info" 2>/dev/null | head -n 1 || true; }   # version, branch, commit, source of the installed build
# The GitHub API answer for a branch head; needs no login. 0 head in MB_HEAD, 1 cannot be read, 2 rate limited, 3 no such branch.
mb_head_api() {
	local slug tmpb http
	slug="$(sed -nE 's#^https://github\.com/([A-Za-z0-9._-]+/[A-Za-z0-9._-]+)$#\1#p' <<<"${MATCHBOX_REPO%.git}")"
	[[ -n "$slug" ]] && command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 1
	tmpb="$(mktemp)"
	http="$(curl -sS -m 20 -o "$tmpb" -w '%{http_code}' -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$slug/git/ref/heads/$MB_BRANCH" 2>/dev/null)" || http=000
	case "$http" in
		200) MB_HEAD="$(jq -r '.object.sha // empty' "$tmpb" 2>/dev/null | cut -c1-7)"; rm -f "$tmpb"; [[ "$MB_HEAD" =~ ^[0-9a-f]{7}$ ]] || { MB_HEAD=""; return 1; } ;;
		404) rm -f "$tmpb"; return 3 ;;
		403|429) rm -f "$tmpb"; return 2 ;;
		*) rm -f "$tmpb"; return 1 ;;
	esac
}
# Sets MB_HEAD (7 characters) and MB_HS: ok, nobranch, ratelimit, unreadable, skipped (no lookup in this mode or BXRIG_SKIP_NETWORK=1).
matchbox_head_resolve() {
	MB_HEAD=""; MB_HS=skipped
	(( MB_LOOKUP )) && [[ "${BXRIG_SKIP_NETWORK:-0}" != 1 && -n "$MATCHBOX_REPO" && -n "$MB_BRANCH" ]] || return 0
	local out rc
	if command -v git >/dev/null 2>&1 && out="$(git ls-remote "$MATCHBOX_REPO" "refs/heads/$MB_BRANCH" 2>/dev/null)"; then
		MB_HEAD="$(awk '{print substr($1, 1, 7); exit}' <<<"$out")"
		if [[ -n "$MB_HEAD" ]]; then MB_HS=ok; else MB_HS=nobranch; fi
		return 0
	fi
	if mb_head_api; then MB_HS=ok; else
		rc=$?
		case "$rc" in 2) MB_HS=ratelimit ;; 3) MB_HS=nobranch ;; *) MB_HS=unreadable ;; esac
	fi
}
# MB_STATE: file, published (MB_BASE is its folder), unpublished, custom (a branch without builds), nobranch, ratelimit,
# unreadable (use the version-latest.properties build, warn), skipped.
matchbox_resolve() {
	MB_STATE=""; MB_BASE=""
	if [[ -n "${BXRIG_MATCHBOX_FILE:-}" ]]; then MB_STATE=file; return 0; fi
	matchbox_head_resolve
	case "$MB_HS" in
		skipped) MB_STATE=skipped ;;
		nobranch|ratelimit|unreadable) MB_STATE="$MB_HS" ;;
		ok)
			if (( MB_CUSTOM )); then MB_STATE=custom
			elif curl -fsSL -m 30 -o /dev/null "$MATCHBOX_DOWNLOADS/$MATCHBOX_VERSION-$MB_HEAD/version.properties" 2>/dev/null; then
				MB_STATE=published; MB_BASE="$MATCHBOX_DOWNLOADS/$MATCHBOX_VERSION-$MB_HEAD"
			else MB_STATE=unpublished; fi ;;
	esac
}
matchbox_stop() {  # the reason; every stop leaves the system as it was
	echo "$*" >&2
	exit 1
}
matchbox_stop_state() {
	case "$MB_STATE" in
		unpublished) matchbox_stop "MatchBox build $MATCHBOX_VERSION-$MB_HEAD (the head of the $MB_BRANCH branch) is not published yet; nothing was installed.
  Try again in a few minutes while CI publishes it ($MATCHBOX_DOWNLOADS/$MATCHBOX_VERSION-$MB_HEAD/),
  or install a MatchBox you built yourself: BXRIG_MATCHBOX_FILE=PATH install.sh toolchains --yes,
  or build the branch here: install.sh toolchains --yes --matchbox-from-source." ;;
		custom) matchbox_stop "The MatchBox branch $MB_BRANCH has no published builds (only $MATCHBOX_REF has); nothing was installed.
  Build it here: add --matchbox-from-source (clones $MATCHBOX_REPO and runs cargo build --release --features bif-tui),
  or install a MatchBox you built yourself: BXRIG_MATCHBOX_FILE=PATH." ;;
		nobranch) matchbox_stop "The MatchBox branch $MB_BRANCH does not exist in $MATCHBOX_REPO; nothing was installed." ;;
		ratelimit) matchbox_stop "GitHub is rate limiting this address, so the head of the MatchBox branch $MB_BRANCH could not be read; nothing was installed.
  Try again in a while, or install a MatchBox you built yourself: BXRIG_MATCHBOX_FILE=PATH." ;;
	esac
}
# The older published build, only when the head is unreadable: version-latest.properties names an immutable folder.
matchbox_legacy_base() {
	local props v c
	props="$(curl -fsSL -m 30 "$MATCHBOX_DOWNLOADS/version-latest.properties" 2>/dev/null)" || { echo "$MATCHBOX_DOWNLOADS"; return; }
	v="$(sed -n 's/^version=//p' <<<"$props" | head -n1)"; c="$(sed -n 's/^commit=//p' <<<"$props" | head -n1)"
	if [[ -n "$v" && -n "$c" ]]; then echo "$MATCHBOX_DOWNLOADS/$v-$c"; else echo "$MATCHBOX_DOWNLOADS"; fi
}
# Clone BRANCH shallow and build it into DEST (a file); prints the short commit in MB_BUILT_COMMIT.
MB_BUILT_COMMIT=""
matchbox_build_source() {
	local dest="$1" work="$2"
	[[ -n "$MATCHBOX_REPO" && -n "$MB_BRANCH" ]] || { echo "box.json has no toolchain.matchbox.repo and ref to build from" >&2; exit 1; }
	command -v git >/dev/null 2>&1 || { echo "git is required to build MatchBox from source" >&2; exit 1; }
	PATH="$probe_path" command -v cargo >/dev/null 2>&1 || { echo "cargo is required to build MatchBox from source (run install.sh packages --yes first: it sets up Rust)" >&2; exit 1; }
	echo "Building MatchBox from source: branch $MB_BRANCH of $MATCHBOX_REPO (cargo build --release --features bif-tui)"
	step_run "clone $MATCHBOX_REPO branch $MB_BRANCH" git clone --quiet --depth 1 --branch "$MB_BRANCH" "$MATCHBOX_REPO" "$work/mbsrc"
	MB_BUILT_COMMIT="$(git -C "$work/mbsrc" rev-parse --short=7 HEAD)"
	( cd "$work/mbsrc" && PATH="$probe_path" cargo build --release --features bif-tui ) || { echo "The MatchBox build failed; nothing was installed" >&2; exit 1; }
	[[ -x "$work/mbsrc/target/release/matchbox" ]] || { echo "The MatchBox build produced no executable; nothing was installed" >&2; exit 1; }
	cp "$work/mbsrc/target/release/matchbox" "$dest"
}
# Whether the toolchains stage has to install MatchBox: the version differs, another branch is wanted, or the head moved since the
# installed build (the marker $MATCHBOX_HOME/build.info; a build without a marker counts as stale once the head can be read).
mb_need() {
	local have; have="$(tool_version matchbox)"
	[[ -n "$have" ]] || return 0
	(( MB_CUSTOM )) || [[ "$have" == "$MATCHBOX_VERSION" ]] || return 0
	[[ -n "$MATCHBOX_DOWNLOADS" && -z "${BXRIG_MATCHBOX_FILE:-}" ]] || return 1
	(( ! MB_CUSTOM )) || [[ "$(mb_marker branch)" == "$MB_BRANCH" ]] || return 0
	matchbox_head_resolve
	[[ "$MB_HS" != ok || "$(mb_marker commit)" == "$MB_HEAD" ]] || return 0
	return 1
}
# MatchBox from the build of the branch head: download, verify the sha256, replace atomically.
install_matchbox_download() {
	local arch=linux-x86_64 tmp expected actual dl source commit="" file_src="${BXRIG_MATCHBOX_FILE:-}"
	tmp="$(mktemp -d)"
	if [[ -n "$file_src" ]]; then
		[[ -f "$file_src" && -x "$file_src" && ! -L "$file_src" ]] || { echo "BXRIG_MATCHBOX_FILE must be an executable regular file: $file_src" >&2; rm -rf "$tmp"; exit 1; }
		cp "$file_src" "$tmp/matchbox"; source=file
	elif (( mb_source )); then
		matchbox_build_source "$tmp/matchbox" "$tmp"; source="built from $MB_BRANCH"; commit="$MB_BUILT_COMMIT"
	else
		matchbox_resolve
		matchbox_stop_state
		case "$MB_STATE" in
			published) dl="$MB_BASE"; source=published; commit="$MB_HEAD" ;;
			*) echo "Warning: the head of the MatchBox branch $MB_BRANCH could not be read (no network to GitHub?); using the build named in version-latest.properties, which can be older than the branch head." >&2
				dl="$(matchbox_legacy_base)"; source="published (head unreadable)" ;;
		esac
		step_retry "download MatchBox" curl -fsSL -m 300 -o "$tmp/matchbox" "$dl/matchbox-$arch"
		step_retry "download the MatchBox checksum" curl -fsSL -m 30 -o "$tmp/matchbox.sha256" "$dl/matchbox-$arch.sha256"
		expected="$(awk '{print $1; exit}' "$tmp/matchbox.sha256")"
		actual="$(sha256sum "$tmp/matchbox" | awk '{print $1}')"
		[[ -n "$expected" && "$expected" == "$actual" ]] || { echo "MatchBox checksum mismatch (expected ${expected:-none}, got $actual); nothing was installed" >&2; rm -rf "$tmp"; exit 1; }
	fi
	chmod 755 "$tmp/matchbox"
	# run it once before it replaces anything
	"$tmp/matchbox" --version >/dev/null 2>&1 || { echo "The MatchBox build does not run; nothing was installed" >&2; rm -rf "$tmp"; exit 1; }
	mkdir -p "$MATCHBOX_HOME/bin"
	mv -f "$tmp/matchbox" "$MATCHBOX_HOME/bin/.matchbox.new" && mv -f "$MATCHBOX_HOME/bin/.matchbox.new" "$MATCHBOX_HOME/bin/matchbox"
	printf 'version=%s\nbranch=%s\ncommit=%s\nsource=%s\n' "$MATCHBOX_VERSION" "$MB_BRANCH" "$commit" "$source" > "$MATCHBOX_HOME/build.info"
	rm -rf "$tmp"
}
# BoxLang's active version, read from BVM's `current` symlink. Running `boxlang --version` starts the whole
# runtime, which rewrites its logs under ~/.boxlang on every call, so routine probes avoid it. Falls back to
# running boxlang only when BVM is not managing it. Install steps still run the real binary to verify.
bl_version() {
	local t
	if [[ -L "$BVM_HOME/current" ]] && t="$(basename "$(readlink "$BVM_HOME/current")")" && [[ "$t" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		printf '%s\n' "$t"
	else
		tool_version boxlang
	fi
}
# What "want" means for BoxLang: the pinned version, or the newest stable (empty when it cannot be looked up).
boxlang_want() {
	if [[ "$BOXLANG_VERSION" != latest ]]; then printf '%s\n' "$BOXLANG_VERSION"; return 0; fi
	command -v curl >/dev/null 2>&1 || return 0
	curl -fsS -m 8 "$BOXLANG_LATEST_URL" 2>/dev/null | sed -n 's/^version=\([0-9][0-9.]*\).*/\1/p' | head -n 1 || true
}
os_id() { ( . "${BXRIG_OS_RELEASE:-/etc/os-release}" 2>/dev/null; echo "${ID:-unknown}|${ID_LIKE:-}" ) || echo "unknown|"; }

inspect() {
	missing_pkgs=()
	for pkg in "${packages[@]}"; do pacman -Qq "$pkg" >/dev/null 2>&1 || missing_pkgs+=("$pkg"); done
	IFS='|' read -r os_name os_like <<<"$(os_id)"
	if [[ "$os_name" == cachyos || "$os_name" == arch || " $os_like " == *" arch "* ]]; then os_ok=1; else os_ok=0; fi
	cpu="$(uname -m)"
	if [[ "$(id -u)" == 0 ]]; then is_root=1; else is_root=0; fi
	have_sudo=0; command -v sudo >/dev/null 2>&1 && have_sudo=1
	free_gb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2{printf "%d", $4/1048576}')"; free_gb="${free_gb:-0}"
	if [[ "${BXRIG_SKIP_NETWORK:-0}" == 1 ]]; then net="skipped"
	elif curl -fsSI -m 6 -o /dev/null https://downloads.ortussolutions.com/ >/dev/null 2>&1; then net="ok"; else net="unreachable"; fi
	java_ver=""; if jb="$(tool_path java)"; then java_ver="$(PATH="$probe_path" "$jb" -version 2>&1 | grep -m1 -oE 'version "[0-9][0-9.]*' | grep -oE '[0-9][0-9.]*' || true)"; fi
  java_major="${java_ver%%.*}"
  have_yay=0; tool_path yay >/dev/null && have_yay=1
  mvm_ver="$(tool_version mvm)"; have_mvm=0; tool_path mvm >/dev/null && have_mvm=1
  mb_ver="$(tool_version matchbox)"
  have_bvm=0; tool_path bvm >/dev/null && have_bvm=1; bvm_ver="$(tool_version bvm)"
  bl_ver="$(bl_version)"; bl_want="$(boxlang_want)"
  rust_ver="$(tool_version rustc)"; have_rustup=0; tool_path rustup >/dev/null && have_rustup=1
  have_bxrig=0; tool_path bxrig >/dev/null && have_bxrig=1; bx_ver="$(tool_version bxrig version)"
  case ":$PATH:" in *":$BIN_DIR:"*) bin_on_path=1 ;; *) bin_on_path=0 ;; esac
}

# Ordered list of steps still needed, derived from inspect(). One line per step.
build_steps() {
  steps=()
  if (( ${#missing_pkgs[@]} )); then
    steps+=("packages|sudo pacman -Syu --needed ${missing_pkgs[*]}|installs missing packages and also upgrades the system")
  fi
  if (( ! have_yay )); then
    steps+=("yay|sudo pacman -S --needed yay|AUR helper, found in the cachyos repository; only runs if yay is absent (part of the packages stage)")
  fi
  if (( ! have_mvm )); then
    steps+=("mvm|download and run $MVM_URL|external script, shown and run")
  fi
  if [[ -n "$MATCHBOX_DOWNLOADS" ]] && mb_need; then
    if (( mb_source )); then
      steps+=("matchbox|git clone --depth 1 --branch $MB_BRANCH $MATCHBOX_REPO, then cargo build --release --features bif-tui|MatchBox built from the $MB_BRANCH branch$( (( MB_CUSTOM )) && echo ", its version may differ from the $MATCHBOX_VERSION in box.json" ), installed under $MATCHBOX_HOME")
    elif (( MB_CUSTOM )); then
      steps+=("matchbox|STOP: the $MB_BRANCH branch has no published builds|add --matchbox-from-source to build it here (the install stops at this step otherwise)")
    elif [[ "$MB_HS" == ok && "$MB_STATE" == unpublished ]]; then
      steps+=("matchbox|STOP: $MATCHBOX_DOWNLOADS/$MATCHBOX_VERSION-$MB_HEAD/ is not published yet|the install stops at this step; try again in a few minutes, or BXRIG_MATCHBOX_FILE=PATH, or --matchbox-from-source")
    elif [[ -n "$MB_BASE" ]]; then
      steps+=("matchbox|download $MB_BASE/matchbox-linux-x86_64 and check its sha256|MatchBox $MATCHBOX_VERSION, the head ($MB_HEAD) of the $MB_BRANCH branch, installed under $MATCHBOX_HOME")
    else
      steps+=("matchbox|download $MATCHBOX_DOWNLOADS/matchbox-linux-x86_64 and check its sha256|MatchBox $MATCHBOX_VERSION from the ${MB_BRANCH:-bxrig} branch (the build of the branch head is looked up when the step runs), installed under $MATCHBOX_HOME")
    fi
  elif [[ -z "$MATCHBOX_DOWNLOADS" && "$mb_ver" != "$MATCHBOX_VERSION" ]]; then
    steps+=("matchbox|mvm install $MATCHBOX_VERSION && mvm use $MATCHBOX_VERSION|pinned MatchBox compiler")
  fi
  if (( ! have_bvm )); then
    steps+=("bvm|download and run $BVM_URL|external script, shown and run; it may add BVM to your shell startup files")
  fi
  if [[ -z "$bl_ver" ]]; then
    steps+=("boxlang|bvm install $BOXLANG_VERSION && bvm use $BOXLANG_VERSION|BoxLang runtime ($([[ $BOXLANG_VERSION == latest ]] && echo "latest stable${bl_want:+, $bl_want}" || echo "pinned"))")
  elif [[ -n "$bl_want" && "$bl_ver" != "$bl_want" ]]; then
    steps+=("boxlang|bvm install $BOXLANG_VERSION && bvm use $BOXLANG_VERSION|update BoxLang $bl_ver to $bl_want")
  fi
  if (( ! have_rustup )) || [[ -z "$rust_ver" ]]; then
    steps+=("rust|rustup default $RUST_CHANNEL|activates Rust and Cargo for your user (part of the packages stage)")
  fi
  if (( ! have_bxrig )); then
    steps+=("binary|install.sh binary --yes|builds src/Main.bx with MatchBox (or use --binary PATH), verifies it, installs to $BIN_DIR/bxrig, no sudo")
  fi
  if (( have_bxrig && ! bin_on_path )); then
    steps+=("path|add $BIN_DIR to PATH yourself|BxRig does not edit shell startup files; the commands are printed by the packages stage")
  fi
}

report_check() {
  echo "== system =="
  printf 'os: %s (%s)\n' "$os_name" "$([[ $os_ok == 1 ]] && echo supported || echo unsupported)"
  printf 'cpu: %s (%s)\n' "$cpu" "$([[ $cpu == x86_64 ]] && echo supported || echo unsupported)"
  printf 'user: %s\n' "$([[ $is_root == 1 ]] && echo 'root (run as a normal user)' || echo normal)"
  printf 'sudo: %s\n' "$([[ $have_sudo == 1 ]] && echo available || echo missing)"
  printf 'disk-free: %s GB (%s)\n' "$free_gb" "$([[ $free_gb -ge $MIN_FREE_GB ]] && echo ok || echo "need $MIN_FREE_GB")"
  printf 'network: %s\n' "$net"
  echo "== packages =="
  for pkg in "${packages[@]}"; do
    if [[ " ${missing_pkgs[*]-} " == *" $pkg "* ]]; then printf 'missing: %s\n' "$pkg"; else printf 'installed: %s\n' "$pkg"; fi
  done
  printf '%s: yay\n' "$([[ $have_yay == 1 ]] && echo installed || echo missing)"
  echo "== tools =="
  printf 'java: %s (want %s)\n' "${java_ver:-missing}" "$JAVA_MAJOR"
  printf 'mvm: %s\n' "$([[ $have_mvm == 1 ]] && echo "${mvm_ver:-installed}" || echo missing)"
  printf 'matchbox: %s (want %s)\n' "${mb_ver:-missing}" "$MATCHBOX_VERSION"
  printf 'bvm: %s\n' "$([[ $have_bvm == 1 ]] && echo "${bvm_ver:-installed}" || echo missing)"
  if [[ "$BOXLANG_VERSION" != latest ]]; then bl_desc="$BOXLANG_VERSION (pinned)"
  elif [[ -n "$bl_want" ]]; then bl_desc="latest = $bl_want"
  else bl_desc="latest, version lookup unavailable"; fi
  printf 'boxlang: %s (want %s)\n' "${bl_ver:-missing}" "$bl_desc"
  printf 'rust: %s\n' "${rust_ver:-no default toolchain}"
  printf 'bxrig: %s\n' "$([[ $have_bxrig == 1 ]] && echo "${bx_ver:-installed}" || echo missing)"
  echo "== path =="
  printf 'bin-dir: %s (%s)\n' "$BIN_DIR" "$([[ $bin_on_path == 1 ]] && echo on-PATH || echo not-on-PATH)"
  if (( ${#steps[@]} )); then printf 'summary: %d step(s) needed, run install.sh --dry-run\n' "${#steps[@]}"; else echo "summary: ready"; fi
}

# One line about the MatchBox that would be installed (full install only; needs the lookup done by matchbox_resolve).
report_matchbox() {
  [[ -n "$MATCHBOX_DOWNLOADS" ]] || return 0
  local what
  case "$MB_STATE" in
    file) what="the local build BXRIG_MATCHBOX_FILE=$BXRIG_MATCHBOX_FILE" ;;
    published) what="build $MATCHBOX_VERSION-$MB_HEAD, published ($MB_BASE/)" ;;
    unpublished) what="build $MATCHBOX_VERSION-$MB_HEAD is NOT published yet: the install would stop at the matchbox step" ;;
    custom) what="a branch without published builds: the install would stop unless --matchbox-from-source is given" ;;
    nobranch) what="the branch does not exist in $MATCHBOX_REPO: the install would stop" ;;
    ratelimit) what="the head could not be read (GitHub rate limit): the install would stop" ;;
    unreadable) what="the head could not be read; the build named in version-latest.properties would be used (with a warning)" ;;
    *) what="the head of the branch is looked up when the step runs" ;;
  esac
  (( ! mb_source )) || what="built from source (cargo build --release --features bif-tui), head ${MB_HEAD:-unknown}"
  printf 'MatchBox: branch %s%s, %s\n' "$MB_BRANCH" "$( (( MB_CUSTOM )) && echo " (not the manifest's $MATCHBOX_REF)" )" "$what"
}
report_plan() {
	echo "Read-only plan. Nothing below has been run."
	if (( ${#steps[@]} == 0 )); then echo "Nothing to do: everything is installed at the pinned versions."; return; fi
	local i=0 line name cmd why
	for line in "${steps[@]}"; do
		i=$((i+1)); IFS='|' read -r name cmd why <<<"$line"
		printf '%d. %s\n   run: %s\n   why: %s\n' "$i" "$name" "$cmd" "$why"
	done
	echo "Re-run one stage with: install.sh packages|toolchains|binary|core --yes"
}

if [[ "$mode" == --check || "$mode" == full ]] && (( ! manifest_ok )); then
	if [[ "$manifest_error" == jq* ]]; then
		if [[ "$mode" == --check ]]; then
			printf '== manifest ==\nbox.json: cannot be read (%s)\nsummary: 1 step(s) needed, run install.sh --dry-run\n' "$manifest_error"
		else
			printf 'Read-only plan. Nothing below has been run.\n1. jq\n   run: sudo pacman -S --needed jq\n   why: %s; the other steps depend on versions listed in box.json\nThen run install.sh again for the full list. (install.sh --install --yes installs jq first.)\n' "$manifest_error"
		fi
		exit 0
	fi
	echo "$manifest_error" >&2; exit 1
fi
if [[ "$mode" == --check ]]; then
	inspect; build_steps; report_check; exit 0
fi
if [[ "$mode" == full ]]; then
	# The whole install: show the plan, ask once (a terminal) or need --yes, then run every stage in order.
	# BXRIG_ALL_SCRIPT replaces the script the stages are delegated to (tests only).
	[[ "$(id -u)" != 0 ]] || { echo "Run as a regular user; sudo is used only for pacman steps" >&2; exit 1; }
	MB_LOOKUP=1
	if [[ -n "$MATCHBOX_DOWNLOADS" ]]; then matchbox_resolve; fi
	inspect; build_steps
	report_matchbox
	report_plan
	echo "Last: bxrig profile-install core --yes installs the core apps with pacman (a re-run installs nothing that is already there)."
	if (( dry )); then echo "Dry run: nothing was changed."; exit 0; fi
	if (( ! yes )); then
		if is_interactive; then
			printf 'Proceed? [Y/n] '; read -r answer || answer=n
			case "${answer:-Y}" in [Yy]*|"") ;; *) echo "Cancelled. Nothing was changed." >&2; exit 2 ;; esac
		else
			echo "Not running unattended without --yes. Nothing was changed." >&2; exit 2
		fi
	fi
	all_self="${BXRIG_ALL_SCRIPT:-${BASH_SOURCE[0]}}"
	mb_args=(); (( ! mb_source )) || mb_args+=(--matchbox-from-source)
	if [[ -n "$MB_BRANCH_REQ" ]]; then mb_args+=(--matchbox-branch "$MB_BRANCH_REQ"); export BXRIG_MATCHBOX_BRANCH="$MB_BRANCH_REQ"; fi   # the binary stage reads the env
	echo "== 1/4 packages, yay and Rust =="; bash "$all_self" packages --yes || exit $?
	echo "== 2/4 Java 21 check, mvm, MatchBox, bvm and BoxLang =="; bash "$all_self" toolchains --yes ${mb_args[@]+"${mb_args[@]}"} || exit $?
	echo "== 3/4 the bxrig binary =="; bash "$all_self" binary --yes || exit $?
	echo "== 4/4 the core apps =="; bash "$all_self" core --yes || exit $?
	echo "Everything is installed. Run: bxrig doctor"
	if is_interactive; then
		echo "== the setup wizard =="; bash "$all_self" wizard || exit $?
	else
		echo "Next: run bxrig init at a terminal to choose your desktop, shell, terminal and apps."
	fi
	exit 0
fi

if [[ "$mode" == --wizard ]]; then
	wiz_bin="$BIN_DIR/bxrig"
	[[ -x "$wiz_bin" ]] || { echo "bxrig is not installed at $wiz_bin (run install.sh binary --yes first)" >&2; exit 1; }
	exec "$wiz_bin" init
fi
if [[ "$mode" == --core ]]; then
	# The core profile through the installed binary (it names the apps, installs them with pacman, and re-runs safely).
	[[ "$(id -u)" != 0 ]] || { echo "Run as a regular user; sudo is used only for pacman steps" >&2; exit 1; }
	core_bin="$BIN_DIR/bxrig"
	[[ -x "$core_bin" ]] || { echo "bxrig is not installed at $core_bin (run install.sh binary --yes first)" >&2; exit 1; }
	exec "$core_bin" profile-install core --yes
fi

if [[ "$mode" == --install-toolchains ]]; then
	# Re-runnable: only the steps still needed are performed. Runs as the normal user.
	need_manifest
	command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
	[[ "$(id -u)" != 0 ]] || { echo "Toolchains must be installed as a regular user" >&2; exit 1; }
	inspect
	preflight_common
	[[ "$java_major" == "$JAVA_MAJOR" ]] || { echo "Java $JAVA_MAJOR is required (found: ${java_ver:-none})" >&2; exit 1; }
	export PATH="$probe_path"
	cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/bxrig/external"

	# Download an external installer, show what it is (url, saved copy, sha256), and run it as the normal user.
	# There is no confirmation gate: installing the toolchain is what the command is for (owner decision 2026-11-10).
	run_external() {  # NAME URL [VAR=VALUE ...]  (extra assignments are passed to the script)
		local name="$1" url="$2" file hash lines; shift 2
		mkdir -p "$cache_dir"; chmod 700 "$cache_dir"
		file="$(mktemp "$cache_dir/$name.XXXXXX.sh")"
		if ! curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$file"; then echo "Download failed: $url" >&2; rm -f "$file"; exit 1; fi
		[[ -s "$file" ]] || { echo "Empty download: $url" >&2; rm -f "$file"; exit 1; }
		chmod 600 "$file"
		hash="$(sha256sum "$file" | cut -d' ' -f1)"; lines="$(wc -l < "$file")"
		printf 'External script: %s\n  url:    %s\n  saved:  %s (%s lines)\n  sha256: %s\n' "$name" "$url" "$file" "$lines" "$hash"
		if ! env "$@" bash "$file"; then echo "$name installer failed (script kept at $file)" >&2; exit 1; fi
	}

	done_any=0
	if (( ! have_mvm )); then
		run_external mvm "$MVM_URL" ${BXRIG_MVM_VERSION:+MVM_VERSION="$BXRIG_MVM_VERSION"}; done_any=1
		tool_path mvm >/dev/null || { echo "MVM installation failed: mvm not found afterwards" >&2; exit 1; }
	fi
	MB_LOOKUP=1
	if [[ -z "$MATCHBOX_DOWNLOADS" ]] && { [[ -n "$MB_BRANCH_REQ" ]] || (( mb_source )); }; then
		echo "--matchbox-branch and --matchbox-from-source need box.json toolchain.matchbox.downloads and repo (this manifest installs MatchBox with mvm)" >&2; exit 1
	fi
	if mb_need; then
		if [[ -n "$MATCHBOX_DOWNLOADS" ]]; then
			install_matchbox_download; done_any=1
		else
			step_retry "mvm install $MATCHBOX_VERSION" mvm install "$MATCHBOX_VERSION"; step_run "mvm use $MATCHBOX_VERSION" mvm use "$MATCHBOX_VERSION"; done_any=1
		fi
		mb_now="$(tool_version matchbox)"
		if (( MB_CUSTOM )); then
			[[ -n "$mb_now" ]] || { echo "MatchBox is not active after install" >&2; exit 1; }
			[[ "$mb_now" == "$MATCHBOX_VERSION" ]] || echo "Warning: MatchBox $mb_now from the $MB_BRANCH branch is installed; box.json pins $MATCHBOX_VERSION, so the bxrig build may behave differently from the tested one." >&2
			echo "MatchBox $mb_now (branch $MB_BRANCH) installed and verified."
		else
			[[ "$mb_now" == "$MATCHBOX_VERSION" ]] || { echo "MatchBox $MATCHBOX_VERSION not active after install" >&2; exit 1; }
			echo "MatchBox $MATCHBOX_VERSION installed and verified."
		fi
	fi
	if (( ! have_bvm )); then
		run_external bvm "$BVM_URL"; done_any=1
		tool_path bvm >/dev/null || { echo "BVM installation failed: bvm not found afterwards" >&2; exit 1; }
		echo "Note: the BVM installer may add BVM to your shell startup files; open a new shell to pick that up."
	fi
	bl_now="$(bl_version)"; bl_target="$(boxlang_want)"
	if [[ -z "$bl_now" || ( -n "$bl_target" && "$bl_now" != "$bl_target" ) ]]; then
		step_run "bvm install $BOXLANG_VERSION" bvm install "$BOXLANG_VERSION"; step_run "bvm use $BOXLANG_VERSION" bvm use "$BOXLANG_VERSION"; done_any=1
		bl_real="$(tool_version boxlang)"   # the one place the runtime is started: proof that it works
		[[ -n "$bl_real" ]] || { echo "BoxLang does not run after install" >&2; exit 1; }
		[[ -z "$bl_target" || "$bl_real" == "$bl_target" ]] || { echo "BoxLang $bl_target not active after install (found: $bl_real)" >&2; exit 1; }
		echo "BoxLang $bl_real installed and verified."
	elif [[ -z "$bl_target" ]]; then
		echo "BoxLang $bl_now is installed; could not look up the latest version, so it was left as is."
	fi
	if (( ! done_any )); then echo "Nothing to do: MVM, MatchBox $MATCHBOX_VERSION, BVM, BoxLang ${bl_now:-?} are already installed."; fi
	echo "Rust and the bxrig binary are handled by later steps."
	exit 0
fi

if [[ "$mode" == --install-binary ]]; then
	# Build (or accept) the bxrig binary, verify it BEFORE touching the installed copy, then replace atomically.
	[[ "$(id -u)" != 0 ]] || { echo "Run as a regular user; no sudo is needed" >&2; exit 1; }
	need_manifest
	work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
	# The theme wallpapers travel in this bundle (not in the binary): copied for bxrig to pick up (it checks each one's SHA-256).
	copy_wallpapers() {
		local src="$root/assets/wallpapers" dest="${XDG_DATA_HOME:-$HOME/.local/share}/bxrig/wallpapers"
		compgen -G "$src/*.jpg" >/dev/null || return 0
		mkdir -p "$dest" || return 1
		# only the missing or changed ones, so running the installer again leaves the folder untouched
		local f
		for f in "$src"/*.jpg; do cmp -s "$f" "$dest/${f##*/}" || cp -f "$f" "$dest/" || return 1; done
		echo "Theme wallpapers ready in $dest"
	}
	installed="$BIN_DIR/bxrig"
	check_binary() {  # PATH -> prints its version line; fails unless it identifies itself as BxRig
		local out; out="$("$1" version 2>&1 | head -n 1)" || true
		[[ "$out" == BxRig\ * ]] || { echo "Not a working bxrig binary: $1 (version printed: ${out:-nothing})" >&2; return 1; }
		printf '%s\n' "$out"
	}
	if [[ -n "$binary_arg" ]]; then
		[[ -f "$binary_arg" && -x "$binary_arg" && ! -L "$binary_arg" ]] || { echo "--binary must be an executable regular file (not a symlink): $binary_arg" >&2; exit 1; }
		candidate="$binary_arg"
		new_version="$(check_binary "$candidate")" || exit 1
		if [[ -f "$installed" ]] && cmp -s "$candidate" "$installed" && (( ! force )); then echo "Nothing to do: $installed is identical ($new_version)."; copy_wallpapers; exit 0; fi
	else
		src="$root/src/Main.bx"
		[[ -n "$root" && -f "$src" ]] || { echo "Source not found ($src). Run this script from a BxRig checkout, or pass --binary PATH." >&2; exit 1; }
		# the version is generated from box.json into src/bxrig/util/Version.bx; bxrig prints it as "BxRig VERSION"
		want="$(sed -n 's/.*return "\([^"]*\)".*/BxRig \1/p' "$root/src/bxrig/util/Version.bx" 2>/dev/null | head -n 1 || true)"
    if (( ! force )) && [[ -x "$installed" && -n "$want" ]] && [[ "$(check_binary "$installed" 2>/dev/null || true)" == "$want" ]]; then
      echo "Nothing to do: $installed is already $want (use --force to rebuild)."; copy_wallpapers; exit 0
    fi
    mb_have="$(tool_version matchbox)"
    # a MatchBox from another branch (--matchbox-branch, kept in BXRIG_MATCHBOX_BRANCH by the full install) can report another version
    if (( MB_CUSTOM )) && [[ -n "$mb_have" ]]; then MATCHBOX_VERSION="$mb_have"; fi
    [[ "$mb_have" == "$MATCHBOX_VERSION" ]] || { echo "MatchBox $MATCHBOX_VERSION is required (found: ${mb_have:-none}). Run install.sh toolchains --yes first." >&2; exit 1; }
    cp -rL "$root/src" "$work/src"; chmod -R u+rwX,go+rX "$work/src"   # -L: src/resources links to the data folders
    echo "Building bxrig with MatchBox $MATCHBOX_VERSION"
    # the BoxLang modules bxrig embeds (box.json toolchain.modules); --module must come before the program
    mods=()
    if [[ -x "$root/scripts/get-modules.sh" && "${BXRIG_SKIP_NETWORK:-0}" != 1 ]]; then   # offline: built without them
      modlist="$(PATH="$probe_path" "$root/scripts/get-modules.sh" "$work/modules" 2>>"$work/build.log")" || { echo "Could not get the BoxLang modules bxrig embeds:" >&2; tail -n 5 "$work/build.log" >&2; exit 1; }
      while IFS= read -r m; do [[ -n "$m" ]] && mods+=( --module "$m" ); done <<<"$modlist"
    fi
    if ! ( cd "$work" && PATH="$probe_path" matchbox "${mods[@]}" --target native --output "$work/bxrig" src/Main.bx ) >> "$work/build.log" 2>&1; then
      echo "Build failed; the installed copy was not touched. Last lines of the build log:" >&2; tail -n 20 "$work/build.log" >&2; exit 1
    fi
    candidate="$work/bxrig"
    [[ -f "$candidate" && -x "$candidate" ]] || { echo "Build produced no executable; the installed copy was not touched" >&2; tail -n 20 "$work/build.log" >&2; exit 1; }
    new_version="$(check_binary "$candidate")" || { echo "The built binary failed its self-check; the installed copy was not touched" >&2; exit 1; }
  fi
  mkdir -p "$BIN_DIR"
  tmpdest="$(mktemp "$BIN_DIR/.bxrig.XXXXXX")"
  cp "$candidate" "$tmpdest"; chmod 755 "$tmpdest"; mv -f "$tmpdest" "$installed"
  final="$(check_binary "$installed")" || exit 1
  echo "Installed $installed ($final)"
  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "Note: $BIN_DIR is not on your PATH (see the packages stage for the line to add)." ;; esac
  copy_wallpapers
  exit 0
fi

# ---- --install --yes: packages, yay (only if absent), Rust. Runs as the normal user; sudo only for pacman. ----
[[ "$(id -u)" != 0 ]] || { echo "Run as a regular user; sudo is used only for pacman steps" >&2; exit 1; }
# At a terminal pacman shows its own transaction prompt (a full upgrade deserves a second look);
# unattended there is nobody to answer it, and --yes already approved the plan.
pm_flags=(); is_interactive || pm_flags=(--noconfirm)
# box.json needs jq to be read, so jq comes first.
if (( ! manifest_ok )) && ! command -v jq >/dev/null 2>&1; then
  command -v sudo >/dev/null 2>&1 || { echo "sudo is required to install packages but was not found" >&2; exit 1; }
  echo "Installing jq first (needed to read box.json)"
  sudo pacman -S "${pm_flags[@]}" --needed jq || { echo "Could not install jq; nothing else was changed" >&2; exit 1; }
  if load_manifest; then manifest_ok=1; else manifest_ok=0; fi
fi
need_manifest
inspect
preflight_common
if (( ${#missing_pkgs[@]} )) || ! tool_path yay >/dev/null; then
  (( have_sudo )) || { echo "sudo is required to install packages but was not found" >&2; exit 1; }
fi
changed=0
if (( ${#missing_pkgs[@]} )); then
  echo "Installing missing packages (this also upgrades the system): ${missing_pkgs[*]}"
  sudo pacman -Syu "${pm_flags[@]}" --needed "${missing_pkgs[@]}" || { echo "pacman failed; nothing else was changed" >&2; exit 1; }
  changed=1
else
  echo "packages: all installed"
fi
if ! tool_path yay >/dev/null; then
  echo "Installing yay (AUR helper) from your configured repositories"
  if ! sudo pacman -S "${pm_flags[@]}" --needed yay; then
    echo "yay is not available in your configured repositories. On CachyOS it is in the cachyos repo; otherwise install it from the AUR by hand." >&2
    exit 1
  fi
  changed=1
else
  echo "yay: already installed"
fi
if tool_path rustup >/dev/null && [[ -z "$(tool_version rustc)" ]]; then
  echo "Activating the stable Rust toolchain for your user"
  rustup default "$RUST_CHANNEL" || { echo "rustup could not install the stable toolchain" >&2; exit 1; }
  [[ -n "$(tool_version rustc)" ]] || { echo "Rust is still not available after rustup default $RUST_CHANNEL" >&2; exit 1; }
  changed=1
else
  echo "rust: ${rust_ver:-rustup not available}"
fi
if (( ! changed )); then echo "Nothing to do for packages, yay and Rust."; fi
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "Note: $BIN_DIR is not on your PATH. BxRig does not edit shell startup files. Add it yourself:"
     echo "  bash/zsh: export PATH=\"$BIN_DIR:\$PATH\""
     echo "  fish:     fish_add_path $BIN_DIR" ;;
esac
echo "Next: install.sh toolchains --yes (or run install.sh with no word to do every stage)"
