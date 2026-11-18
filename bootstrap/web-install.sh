#!/usr/bin/env bash
# BxRig installer (published as install.sh): one line, then the setup wizard.
#   curl -fsSL https://downloads.ortussolutions.com/ortussolutions/bxrig/install.sh | bash
# No human input:
#   curl -fsSL .../install.sh | bash -s -- --yes [--answers answers.json] [--channel beta]
# Options: --yes|-y (never ask), --answers FILE (the wizard answers to apply), --channel stable|beta, --no-wizard, --dry-run,
#          --base-url URL (default https://downloads.ortussolutions.com/ortussolutions/bxrig; BXRIG_BASE_URL), -h|--help.
#          --source stable|beta|github:OWNER/REPO@REF (BXRIG_SOURCE; the github source is for testing a branch: UNSIGNED, needs --yes
#          or the typed word "unsigned"; github:@REF and github:REF mean the default repository ortus-boxlang/BxRig),
#          MatchBox: stable by default (the prebuilt bxrig only needs it as the toolchain); --snapshot (BXRIG_MATCHBOX_CHANNEL=snapshot) installs the
#          snapshot build; --matchbox-branch REF [--matchbox-repo OWNER/NAME] (BXRIG_MATCHBOX_BRANCH, BXRIG_MATCHBOX_REPO) builds that branch with cargo
#          (see bootstrap/install.sh). A github source compiles bxrig, so it builds the manifest's MatchBox branch (bxrig) unless you name another.
# It downloads the channel's bxrig binary and bootstrap bundle, verifies the Ed25519 signature of the release information and the SHA-256 of both files, runs the install stages (packages, toolchains,
# binary, core apps) and then the wizard. Everything is logged to ~/.cache/bxrig/install.log. Needs CachyOS or Arch, a normal user, sudo.
set -Eeuo pipefail

BASE="${BXRIG_BASE_URL:-https://downloads.ortussolutions.com/ortussolutions/bxrig}"
CHANNEL="${BXRIG_CHANNEL:-stable}"
YES=no; ANSWERS=""; WIZARD=yes; DRY=no; MB_REPO_FLAG=no; MB_SNAPSHOT_FLAG=no; MB_BRANCH_FLAG=no
TOKEN=""; SOURCE="${BXRIG_SOURCE:-}"; CHANNEL_SET=no; SRC_KIND=channel; GH_OWNER=""; GH_REPO=""; GH_REF=""; GH_SHA=""; TREE=""
MB_BRANCH_ARG="${BXRIG_MATCHBOX_BRANCH:-}"; MB_REPO_ARG="${BXRIG_MATCHBOX_REPO:-}"; MB_FROM_SOURCE=no; MB_SNAPSHOT=no
[[ "${BXRIG_MATCHBOX_CHANNEL:-}" != snapshot ]] || MB_SNAPSHOT=yes
MBARGS=()
GH_DEFAULT_REPO="ortus-boxlang/BxRig"
# Test hooks: where the github source talks to (never set these in real use; the token is sent to these hosts).
GH_API="${BXRIG_GITHUB_API:-https://api.github.com}"; GH_CODELOAD="${BXRIG_GITHUB_CODELOAD:-https://codeload.github.com}"; GH_GIT="${BXRIG_GITHUB_GIT:-https://github.com}"
TTY="${BXRIG_TTY:-/dev/tty}"
# The release public key (Ed25519, base64 of the PEM). CI fills it in when it publishes install.sh; left as is, a development copy only
# checks SHA-256. BXRIG_PUBKEY_B64 overrides it (tests).
PUBKEY_B64="${BXRIG_PUBKEY_B64:-@@PUBKEY_B64@@}"
C_RESET="" C_BOLD="" C_DIM="" C_OK="" C_WARN="" C_ERR="" C_ACC=""
RICH=no; INSTALL_LOG=""; TMP=""; PID=""

usage() { sed -n '2,16p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//' || true; }

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--yes|-y) YES=yes ;;
			--answers) [[ $# -ge 2 ]] || die "--answers needs a file"; ANSWERS="$2"; shift ;;
			--answers=*) ANSWERS="${1#*=}" ;;
			--channel) [[ $# -ge 2 ]] || die "--channel needs stable or beta"; CHANNEL="$2"; CHANNEL_SET=yes; shift ;;
			--channel=*) CHANNEL="${1#*=}"; CHANNEL_SET=yes ;;
			--source) [[ $# -ge 2 ]] || die "--source needs stable, beta or github:OWNER/REPO@REF"; SOURCE="$2"; shift ;;
			--source=*) SOURCE="${1#*=}" ;;
			--matchbox-branch) [[ $# -ge 2 ]] || die "--matchbox-branch needs a branch name"; MB_BRANCH_ARG="$2"; MB_BRANCH_FLAG=yes; shift ;;
			--matchbox-branch=*) MB_BRANCH_ARG="${1#*=}"; MB_BRANCH_FLAG=yes ;;
			--matchbox-repo) [[ $# -ge 2 ]] || die "--matchbox-repo needs OWNER/NAME"; MB_REPO_ARG="$2"; MB_REPO_FLAG=yes; shift ;;
			--matchbox-repo=*) MB_REPO_ARG="${1#*=}"; MB_REPO_FLAG=yes ;;
			--matchbox-from-source) MB_FROM_SOURCE=yes ;;
			--snapshot) MB_SNAPSHOT=yes; MB_SNAPSHOT_FLAG=yes ;;
			--base-url) [[ $# -ge 2 ]] || die "--base-url needs a URL"; BASE="$2"; shift ;;
			--base-url=*) BASE="${1#*=}" ;;
			--no-wizard) WIZARD=no ;;
			--dry-run) DRY=yes ;;
			-h|--help) usage; exit 0 ;;
			*) die "unknown option: $1 (try --help)" ;;
		esac
		shift
	done
	[[ "$CHANNEL" == stable || "$CHANNEL" == beta ]] || die "the channel must be stable or beta"
	[[ -z "$ANSWERS" || -f "$ANSWERS" ]] || die "answers file not found: $ANSWERS"
	parse_source
	# the MatchBox options go to install.sh as they are; it validates them again, this stops a bad one before anything is downloaded
	# flags beat the environment: a flag for one MatchBox drops the other one that only the environment asked for
	if [[ $MB_SNAPSHOT_FLAG == yes && ( $MB_BRANCH_FLAG == yes || $MB_FROM_SOURCE == yes ) ]]; then die "--snapshot and --matchbox-branch cannot be combined: pick one MatchBox"; fi
	if [[ $MB_SNAPSHOT_FLAG == yes && $MB_BRANCH_FLAG == no ]]; then MB_BRANCH_ARG=""; fi
	if [[ $MB_SNAPSHOT_FLAG == no && ( $MB_BRANCH_FLAG == yes || $MB_FROM_SOURCE == yes ) ]]; then MB_SNAPSHOT=no; fi
	if [[ $MB_SNAPSHOT == yes && -n "$MB_BRANCH_ARG" ]]; then die "BXRIG_MATCHBOX_CHANNEL=snapshot and BXRIG_MATCHBOX_BRANCH cannot be combined: pick one MatchBox"; fi
	if [[ $MB_BRANCH_FLAG == yes && -z "$MB_BRANCH_ARG" ]] || { [[ -n "$MB_BRANCH_ARG" ]] && ! valid_ref "$MB_BRANCH_ARG"; }; then
		die "bad MatchBox branch '$(printable "$MB_BRANCH_ARG")' (letters, digits and . _ / @ + - only; no leading dash, no ..)"
	fi
	[[ -z "$MB_REPO_ARG" ]] || valid_repo "$MB_REPO_ARG" || die "bad MatchBox repository '$(printable "$MB_REPO_ARG")' (OWNER/NAME: letters, digits and . _ - only)"
	[[ $MB_REPO_FLAG == no || -n "$MB_BRANCH_ARG" || $MB_FROM_SOURCE == yes ]] || die "--matchbox-repo needs --matchbox-branch REF"
	if [[ $MB_SNAPSHOT == yes ]]; then MBARGS+=(--snapshot)
	elif [[ -n "$MB_BRANCH_ARG" ]]; then MBARGS+=(--matchbox-branch "$MB_BRANCH_ARG"); [[ -z "$MB_REPO_ARG" ]] || MBARGS+=(--matchbox-repo "$MB_REPO_ARG")
	elif [[ $MB_FROM_SOURCE == yes ]]; then MBARGS+=(--matchbox-from-source)
	fi
}

printable() { printf '%s' "${1//[^[:print:]]/?}"; }
# A git ref (branch, tag or commit) as it may appear in a URL path or a git argument: [A-Za-z0-9._/@+-], no leading dash, no "..", no
# leading or trailing slash. Owner and repository names are stricter: [A-Za-z0-9._-]+, never only dots.
valid_ref() { [[ "$1" =~ ^[A-Za-z0-9._/@+-]+$ && "$1" != -* && "$1" != *..* && "$1" != /* && "$1" != */ ]]; }
valid_repo() { [[ "$1" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ && "$1" != -* && "$1" != *..* && "$1" != */-* ]]; }   # OWNER/NAME of the MatchBox repository
valid_name() { [[ "$1" =~ ^[A-Za-z0-9._-]+$ && ! "$1" =~ ^\.+$ && "$1" != -* ]]; }
# --source SPEC: stable (today's behaviour), beta (= --channel beta), github:OWNER/REPO@REF | github:@REF | github:REF.
parse_source() {
	local spec="$SOURCE" rest slug
	[[ -n "$spec" ]] || return 0
	case "$spec" in
		stable|beta)
			[[ $CHANNEL_SET == no || "$CHANNEL" == "$spec" ]] || die "--channel $CHANNEL and --source $spec disagree; use one of them"
			CHANNEL="$spec" ;;
		github:*)
			[[ $CHANNEL_SET == no ]] || die "--channel does not apply to a github source"
			rest="${spec#github:}"; slug="${rest%%@*}"
			if [[ "$rest" == @* ]]; then GH_REF="${rest#@}"; slug="$GH_DEFAULT_REPO"
			elif [[ "$rest" == *@* && "$slug" == */* ]]; then GH_REF="${rest#*@}"
			else GH_REF="$rest"; slug="$GH_DEFAULT_REPO"; fi
			GH_OWNER="${slug%%/*}"; GH_REPO="${slug#*/}"
			valid_name "$GH_OWNER" && valid_name "$GH_REPO" && [[ "$GH_REPO" != */* ]] || die "bad repository in --source '$(printable "$spec")': OWNER and REPO may use letters, digits and . _ - only"
			valid_ref "$GH_REF" || die "bad ref in --source '$(printable "$spec")': a branch, tag or commit with letters, digits and . _ / @ + - only, no leading dash"
			SRC_KIND=github ;;
		*) die "bad --source '$(printable "$spec")': use stable, beta or github:OWNER/REPO@REF" ;;
	esac
}

setup_terminal() {
	if [[ -t 1 && ${TERM:-dumb} != dumb && -z ${NO_COLOR:-} ]]; then
		C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m' C_OK=$'\033[38;2;0;255;120m' C_WARN=$'\033[33m' C_ERR=$'\033[31m' C_ACC=$'\033[38;2;0;219;255m'
		RICH=yes
	fi
}

info() { printf '  %s✓%s  %s\n' "$C_OK" "$C_RESET" "$*"; }
note() { printf '  %s·%s  %s\n' "$C_DIM" "$C_RESET" "$*"; }
warn() { printf '  %s!%s  %s\n' "$C_WARN" "$C_RESET" "$*" >&2; }
die()  { printf '  %s×%s  %s\n' "$C_ERR" "$C_RESET" "$*" >&2; [[ -z "$INSTALL_LOG" ]] || printf '  %sLog: %s%s\n' "$C_DIM" "$INSTALL_LOG" "$C_RESET" >&2; exit 1; }
section() { printf '\n  %s%s%s%s\n\n' "$C_ACC" "$C_BOLD" "$*" "$C_RESET"; }

cleanup() {
	[[ -z "$PID" ]] || kill "$PID" 2>/dev/null || true
	[[ -z "$TMP" ]] || rm -rf "$TMP"
	[[ "$RICH" != yes ]] || printf '\033[?25h'
}
trap cleanup EXIT
trap 'printf "\n"; die "cancelled"' INT TERM

# The wordmark in the Ortus gradient (cyan #00DBFF to green #00FF78), one colour per row.
banner() {
	local -a rows=(
		'██████╗           ██████╗  ██╗'
		'██╔══██╗ ██╗  ██╗ ██╔══██╗ ╚═╝  ██████╗'
		'██████╔╝ ╚██╗██╔╝ ██████╔╝ ██╗ ██╔════╝'
		'██╔══██╗  ██╔██╗  ██╔══██╗ ██║ ██║  ███╗'
		'██████╔╝ ██╔╝ ██╗ ██║  ██║ ██║ ██║   ██║'
		'╚═════╝  ╚═╝  ╚═╝ ╚═╝  ╚═╝ ╚═╝ ╚██████╔╝'
		'                                ╚═════╝'
	)
	local i n=${#rows[@]} r g b
	printf '\n'
	for ((i = 0; i < n; i++)); do
		if [[ $RICH == yes ]]; then
			r=0; g=$((219 + (255 - 219) * i / (n - 1))); b=$((255 + (120 - 255) * i / (n - 1)))
			printf '  \033[38;2;%d;%d;%dm%s%s\n' "$r" "$g" "$b" "${rows[i]}" "$C_RESET"
		else
			printf '  %s\n' "${rows[i]}"
		fi
	done
	printf '\n  %sYour dev rig. Beautiful by default.%s\n' "$C_BOLD" "$C_RESET"
	printf '  %sPowered by BoxLang · www.boxlang.io%s\n' "$C_DIM" "$C_RESET"
}

# run_task LABEL CMD...: a spinner while CMD runs, its output in the log; failures print the tail of the log.
run_task() {
	local label=$1 result frame=0
	local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
	shift
	printf '\n--- %s ---\n' "$label" >>"$INSTALL_LOG"
	if [[ $RICH == yes ]]; then
		"$@" >>"$INSTALL_LOG" 2>&1 &
		PID=$!
		printf '\033[?25l'
		while kill -0 "$PID" 2>/dev/null; do
			printf '\r  %s%s%s  %s\033[K' "$C_ACC" "${frames[frame % 10]}" "$C_RESET" "$label"
			frame=$((frame + 1)); sleep 0.1
		done
		if wait "$PID"; then result=0; else result=$?; fi
		PID=""
		printf '\r\033[K\033[?25h'
	else
		printf '  …  %s\n' "$label"
		if "$@" >>"$INSTALL_LOG" 2>&1; then result=0; else result=$?; fi
	fi
	if ((result != 0)); then
		tail -n 15 "$INSTALL_LOG" >&2
		die "$label failed"
	fi
	info "$label"
}

# A task that needs the terminal (sudo password, the wizard): no spinner, output live and logged.
run_live() {
	local label=$1
	shift
	printf '\n--- %s ---\n' "$label" >>"$INSTALL_LOG"
	"$@" || die "$label failed"
}

fetch() { curl -fsSL --retry 3 --retry-delay 2 --max-time 600 -o "$2" "$1"; }

verify_sha() {   # verify_sha FILE SHAFILE
	local want got
	want="$(awk '{print $1}' "$2")"; got="$(sha256sum "$1" | awk '{print $1}')"
	[[ -n "$want" && "$want" == "$got" ]]
}

# verify_properties FILE SIGFILE: the release information is signed (Ed25519); with a key a missing or bad signature is fatal.
verify_properties() {
	[[ "$PUBKEY_B64" != "@@PUBKEY_B64@@" && -n "$PUBKEY_B64" ]] || { note "unsigned development copy: checking SHA-256 only"; return 0; }
	command -v openssl >/dev/null 2>&1 || die "openssl is required to verify the release signature"
	printf '%s' "$PUBKEY_B64" | base64 -d > "$TMP/release.pub" 2>/dev/null || die "the embedded release key is malformed"
	[[ -s "$TMP/release.pub" ]] || die "the embedded release key is empty"
	openssl pkeyutl -verify -pubin -inkey "$TMP/release.pub" -rawin -in "$1" -sigfile "$2" >/dev/null 2>&1 \
		|| die "the release signature is invalid; nothing was installed"
	info "release signature verified (Ed25519)"
}

prop() { sed -n "s/^$2=//p" "$1" | head -n 1; }

preflight() {
	# BXRIG_INSTALL_ALLOW_ROOT=1 is for the test suite only
	[[ "$(id -u)" != 0 || "${BXRIG_INSTALL_ALLOW_ROOT:-}" == 1 ]] || die "run this as your normal user, not as root (sudo is used only where needed)"
	command -v pacman >/dev/null 2>&1 || die "BxRig needs CachyOS or Arch Linux (pacman was not found)"
	command -v curl >/dev/null 2>&1 || die "curl is required"
	command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"
	[[ "$(uname -m)" == x86_64 ]] || die "only x86_64 is supported for now (found $(uname -m))"
	command -v sudo >/dev/null 2>&1 || die "sudo is required"
	info "CachyOS or Arch, normal user, x86_64"
}

ask_sudo() {
	if [[ $YES == yes ]]; then
		sudo -n true 2>/dev/null || die "--yes needs passwordless sudo (or run sudo -v first): sudo asked for a password"
	else
		printf '  %sAdministrator access is needed for pacman.%s\n' "$C_DIM" "$C_RESET"
		sudo -v <"$TTY" || die "sudo was not granted"
	fi
}

confirm() {
	[[ $YES == yes ]] && return 0
	[[ -r "$TTY" ]] || { note "no terminal to ask on; continuing (use --yes to silence this)"; return 0; }
	printf '\n  Install BxRig (%s channel) and start the setup wizard? [Y/n] ' "$CHANNEL" >"$TTY"
	local a; IFS= read -r a <"$TTY" || a=n
	case "${a:-Y}" in [Yy]*|"") ;; *) printf '  Cancelled. Nothing was changed.\n'; exit 2 ;; esac
}

# ---- --source github:OWNER/REPO@REF: an UNSIGNED development tree (no release signature, no S3 checksum) ----
# curl with the token as a config on stdin, so it is neither in the process list nor in any log
gh_curl() {
	if [[ -n "$TOKEN" ]]; then printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" | curl -K - "$@"; else curl "$@"; fi
}
gh_fetch() { gh_curl -fsSL --retry 3 --retry-delay 2 --max-time 600 -o "$2" "$1"; }
gh_api_sha() {  # the commit of REF through the API (works for branches, tags and commits; the only way for a private repository)
	local out
	out="$(gh_curl -fsSL -m 20 -H 'Accept: application/vnd.github.sha' "$GH_API/repos/$GH_OWNER/$GH_REPO/commits/$GH_REF" 2>/dev/null)" || return 0
	[[ "$out" =~ ^[0-9a-f]{40}$ ]] && printf '%s\n' "$out"
	return 0
}
resolve_github_sha() {  # the 40-character commit REF points at now, empty when it cannot be found
	local sha="" lines
	if [[ "$GH_REF" =~ ^[0-9a-f]{40}$ ]]; then printf '%s\n' "$GH_REF"; return 0; fi
	[[ -z "$TOKEN" ]] || sha="$(gh_api_sha)"
	if [[ -z "$sha" ]] && command -v git >/dev/null 2>&1; then
		lines="$(GIT_TERMINAL_PROMPT=0 git ls-remote "$GH_GIT/$GH_OWNER/$GH_REPO.git" "refs/heads/$GH_REF" "refs/tags/$GH_REF" "refs/tags/$GH_REF^{}" 2>/dev/null || true)"
		sha="$(awk '/\^\{\}$/ {print $1; found=1; exit} !first {first=$1} END {if (!found) print first}' <<<"$lines")"
		[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || sha=""
	fi
	[[ -n "$sha" ]] || sha="$(gh_api_sha)"
	printf '%s\n' "$sha"
}
unsigned_warning() {
	printf '\n'
	warn "${C_BOLD}UNSIGNED DEVELOPMENT SOURCE${C_RESET}"
	warn "github:$GH_OWNER/$GH_REPO@$GH_REF, commit ${GH_SHA:-not resolved yet}"
	warn "This is not a release: there is no signature and no checksum from the BxRig downloads. It builds and runs whatever that branch"
	warn "contains, as your user and with sudo for the package steps. Only continue for a source you trust."
	printf '\n' >&2
}
confirm_unsigned() {  # never silent: --yes, or the word "unsigned" typed at a terminal; otherwise nothing is installed (exit 2)
	local a=""
	if [[ $YES == yes ]]; then note "--yes given: continuing with the unsigned source"; return 0; fi
	[[ -r "$TTY" ]] || { printf '  An unsigned source needs --yes (there is no terminal to ask on). Nothing was changed.\n' >&2; exit 2; }
	printf '  Type the word unsigned to continue, anything else cancels: ' >&2
	IFS= read -r a <"$TTY" || a=""
	[[ "$a" == unsigned ]] || { printf '  Cancelled. Nothing was changed.\n'; exit 2; }
}
tarball_commit() {  # the commit git archive recorded in the tarball (pax header), else a 40-hex top folder name
	local c
	c="$(gzip -dc "$1" 2>/dev/null | head -c 4096 | grep -a -m1 -o 'comment=[0-9a-f]\{40\}' | cut -d= -f2 || true)"
	[[ -n "$c" ]] || c="$(sed -nE 's/^.*-([0-9a-f]{40})$/\1/p' <<<"$2")"
	printf '%s\n' "$c"
}
fetch_tree() {  # download and unpack the tarball of REF into $TMP/tree; sets TREE and GH_SHA
	local url="$GH_CODELOAD/$GH_OWNER/$GH_REPO/tar.gz/$GH_REF" top got
	[[ -n "$TOKEN" ]] || note "public repositories only; for a private one set GITHUB_TOKEN or GH_TOKEN"
	run_task "the source of $GH_OWNER/$GH_REPO@$GH_REF" gh_fetch "$url" "$TMP/source.tar.gz"
	tar -tzf "$TMP/source.tar.gz" >"$TMP/source.list" 2>/dev/null || die "the download is not a tar.gz archive"
	[[ -s "$TMP/source.list" ]] || die "the source archive is empty"
	grep -qE '(^/|(^|/)\.\.(/|$))' "$TMP/source.list" && die "the source archive has unsafe paths; nothing was installed"
	top="$(head -n 1 "$TMP/source.list" | cut -d/ -f1)"
	awk -F/ -v t="$top" '$1 != t {bad = 1} END {exit bad}' "$TMP/source.list" || die "the source archive has no single top folder; nothing was installed"
	mkdir -p "$TMP/tree" && tar -xzf "$TMP/source.tar.gz" -C "$TMP/tree"
	TREE="$TMP/tree/$top"
	[[ -f "$TREE/bootstrap/install.sh" && -f "$TREE/box.json" && -f "$TREE/src/Main.bx" ]] || die "that source is not a BxRig tree (no bootstrap/install.sh, box.json or src/Main.bx)"
	got="$(tarball_commit "$TMP/source.tar.gz" "$top")"
	if [[ -n "$got" ]]; then
		[[ -z "$GH_SHA" || "$GH_SHA" == "$got" ]] || warn "the branch moved while downloading: resolved $GH_SHA, downloaded $got"
		GH_SHA="$got"
	fi
	info "unpacked ${GH_SHA:-(commit unknown)}"
}
record_source() {  # the log and a small file next to the MatchBox home; bxrig update does not read it (see the docs)
	local dir="${BXRIG_HOME:-$HOME/.local/share/bxrig}"
	printf 'source: github:%s/%s@%s\ncommit: %s\nsigned: no (unsigned development source)\n' "$GH_OWNER" "$GH_REPO" "$GH_REF" "${GH_SHA:-unknown}" >>"$INSTALL_LOG"
	[[ "${1:-}" == log ]] && return 0
	mkdir -p "$dir" && printf 'source=github:%s/%s@%s\ncommit=%s\nsigned=no\ninstalled=%s\n' "$GH_OWNER" "$GH_REPO" "$GH_REF" "${GH_SHA:-unknown}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$dir/install-source" && chmod 600 "$dir/install-source"
	return 0
}
github_main() {
	# this source is compiled, and only a MatchBox with the terminal UI can: build the manifest's branch (bxrig) unless the user chose a MatchBox
	(( ${#MBARGS[@]} )) || MBARGS+=(--matchbox-from-source)
	TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
	[[ -z "$TOKEN" || "$TOKEN" =~ ^[A-Za-z0-9_.-]+$ ]] || die "the GitHub token has characters a token never has (it is not printed); check GITHUB_TOKEN or GH_TOKEN"
	note "source: github:$GH_OWNER/$GH_REPO@$GH_REF (unsigned)${TOKEN:+, with a GitHub token}"
	GH_SHA="$(resolve_github_sha)"
	unsigned_warning
	[[ -n "$GH_SHA" ]] || note "could not resolve $GH_REF to a commit before the download (private repository without a token, or no network to GitHub)"
	TMP="$(mktemp -d)"
	if [[ $DRY == yes ]]; then
		section "Plan"
		note "dry run: the unsigned source is downloaded and unpacked, nothing is installed"
		fetch_tree
		note "commit: ${GH_SHA:-unknown}"
		note "stages: packages, toolchains, the bxrig binary built from src/Main.bx of this tree, the core apps, then the wizard$( [[ -n "$ANSWERS" ]] && echo " with $ANSWERS" )"
		bash "$TREE/bootstrap/install.sh" --dry-run ${MBARGS[@]+"${MBARGS[@]}"} || die "the plan of this tree failed"
		exit 0
	fi
	confirm_unsigned
	section "Downloading"
	fetch_tree
	record_source log
	local inst="$TREE/bootstrap/install.sh"
	section "Installing"
	ask_sudo
	run_live "packages (pacman)" bash "$inst" packages --yes
	run_task "toolchains (Java, bvm, mvm, BoxLang, MatchBox, Rust)" bash "$inst" toolchains --yes ${MBARGS[@]+"${MBARGS[@]}"}
	run_task "the bxrig program, built from this tree" bash "$inst" binary --yes --force
	run_live "the core apps" bash "$inst" core --yes
	record_source
	finish_install
}

main() {
	parse_args "$@"
	setup_terminal
	mkdir -p "$HOME/.cache/bxrig"
	INSTALL_LOG="$HOME/.cache/bxrig/install.log"; : >"$INSTALL_LOG"
	banner
	section "Checking this machine"
	preflight
	if [[ $SRC_KIND == github ]]; then github_main; exit 0; fi
	note "channel: $CHANNEL · from $BASE"
	if [[ $DRY == yes ]]; then
		note "dry run: would download, verify and install, then run the wizard$( [[ -n "$ANSWERS" ]] && echo " with $ANSWERS" )"
		exit 0
	fi
	confirm
	TMP="$(mktemp -d)"
	section "Downloading"
	run_task "the $CHANNEL release information" fetch "$BASE/$CHANNEL/version-latest.properties" "$TMP/version.properties"
	if [[ "$PUBKEY_B64" != "@@PUBKEY_B64@@" && -n "$PUBKEY_B64" ]]; then
		run_task "its signature" fetch "$BASE/$CHANNEL/version-latest.properties.sig" "$TMP/version.properties.sig"
	fi
	verify_properties "$TMP/version.properties" "$TMP/version.properties.sig"
	run_task "the bxrig program" fetch "$BASE/$CHANNEL/bxrig-linux-x86_64" "$TMP/bxrig"
	run_task "its checksum" fetch "$BASE/$CHANNEL/bxrig-linux-x86_64.sha256" "$TMP/bxrig.sha256"
	verify_sha "$TMP/bxrig" "$TMP/bxrig.sha256" || die "the bxrig download does not match its SHA-256; nothing was installed"
	if [[ "$PUBKEY_B64" != "@@PUBKEY_B64@@" && -n "$PUBKEY_B64" ]]; then
		[[ "$(prop "$TMP/version.properties" sha256)" == "$(sha256sum "$TMP/bxrig" | awk '{print $1}')" ]] || die "bxrig does not match the signed release information; nothing was installed"
	fi
	info "bxrig verified (SHA-256$( [[ "$PUBKEY_B64" != "@@PUBKEY_B64@@" && -n "$PUBKEY_B64" ]] && echo ' and signature'))"
	run_task "the install bundle" fetch "$BASE/$CHANNEL/bootstrap.tar.gz" "$TMP/bootstrap.tar.gz"
	run_task "its checksum" fetch "$BASE/$CHANNEL/bootstrap.tar.gz.sha256" "$TMP/bootstrap.sha256"
	verify_sha "$TMP/bootstrap.tar.gz" "$TMP/bootstrap.sha256" || die "the install bundle does not match its SHA-256; nothing was installed"
	if [[ "$PUBKEY_B64" != "@@PUBKEY_B64@@" && -n "$PUBKEY_B64" ]]; then
		[[ "$(prop "$TMP/version.properties" bootstrap_sha256)" == "$(sha256sum "$TMP/bootstrap.tar.gz" | awk '{print $1}')" ]] || die "the install bundle does not match the signed release information; nothing was installed"
	fi
	info "install bundle verified (SHA-256$( [[ "$PUBKEY_B64" != "@@PUBKEY_B64@@" && -n "$PUBKEY_B64" ]] && echo ' and signature'))"
	mkdir -p "$TMP/src" && tar -xzf "$TMP/bootstrap.tar.gz" -C "$TMP/src"
	[[ -x "$TMP/src/bootstrap/install.sh" || -f "$TMP/src/bootstrap/install.sh" ]] || die "the install bundle has no bootstrap/install.sh"
	chmod +x "$TMP/bxrig"
	local inst="$TMP/src/bootstrap/install.sh"
	section "Installing"
	ask_sudo
	run_live "packages (pacman)" bash "$inst" packages --yes
	run_task "toolchains (Java, bvm, mvm, BoxLang, MatchBox, Rust)" bash "$inst" toolchains --yes ${MBARGS[@]+"${MBARGS[@]}"}
	run_task "the bxrig program" bash "$inst" binary --yes --binary "$TMP/bxrig" --force
	run_live "the core apps" bash "$inst" core --yes
	finish_install
}

# After the core apps: the check that the binary is there, the wizard, the closing lines (the stable and the github paths share it).
finish_install() {
	local bx="${BXRIG_BIN_DIR:-$HOME/.local/bin}/bxrig"
	[[ -x "$bx" ]] || die "bxrig was not installed at $bx"
	if [[ $WIZARD == yes ]]; then
		section "Setup wizard"
		if [[ -n "$ANSWERS" ]]; then run_live "your answers" "$bx" init --answers "$ANSWERS" --yes
		elif [[ $YES == yes || ! -r "$TTY" ]]; then run_live "the default answers" "$bx" init --defaults --yes
		else "$bx" init <"$TTY" || warn "the wizard did not finish; run: bxrig init"
		fi
	fi
	section "Ready"
	info "BxRig is installed: $bx"
	[[ $SRC_KIND != github ]] || warn "this BxRig came from an unsigned source (github:$GH_OWNER/$GH_REPO@$GH_REF, ${GH_SHA:-unknown}); bxrig update apply would replace it with the $CHANNEL build"
	note "Open a new terminal, then try: bxrig status, bxrig menu, bxrig update check"
	note "Log: $INSTALL_LOG"
}

main "$@"
