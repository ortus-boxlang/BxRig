#!/usr/bin/env bash
# Shared by scripts/setup-local.sh, scripts/get-matchbox.sh and scripts/dev-build.sh (source it, do not run it): validates the
# MatchBox repo and ref a person asks for, names the dedicated clone for them and fetches a shallow checkout. Values reach git
# only as argv items, never through eval or a shell string.

# A ref is a branch, tag or commit of the MatchBox repo: letters, digits and . _ / @ + - only, no leading dash, no "..", no
# trailing slash, not empty.
mb_valid_ref() {
	local re='^[A-Za-z0-9._/@+-]+$'
	[[ "${1:-}" =~ $re && "$1" != -* && "$1" != *..* && "$1" != */ ]]
}
# A repo is https://HOST/PATH or the GitHub shorthand owner/name, with the same restrictions.
mb_valid_repo() {
	local url='^https://[A-Za-z0-9.-]+/[A-Za-z0-9._/+-]+$' short='^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'
	[[ -n "${1:-}" && "$1" != -* && "$1" != *..* && "$1" != */ ]] || return 1
	[[ "$1" =~ $url || "$1" =~ $short ]]
}
# owner/name becomes https://github.com/owner/name; a full URL is kept.
mb_repo_url() {
	if [[ "$1" == https://* ]]; then printf '%s\n' "$1"; else printf 'https://github.com/%s\n' "$1"; fi
}
# The comparable form of a repo URL: lower case, no trailing .git.
mb_repo_key() {
	local k="${1,,}"
	printf '%s\n' "${k%.git}"
}
# A name that is safe as a directory: owner-name for GitHub, host-owner-name for other hosts.
mb_repo_slug() {
	local s="${1#https://}"
	s="${s#github.com/}"; s="${s%.git}"
	printf '%s\n' "${s//[^A-Za-z0-9._-]/-}"
}
mb_ref_slug() { printf '%s\n' "${1//[^A-Za-z0-9._-]/-}"; }
# A full 40 character commit id is fetched by itself; anything else is a branch or tag name.
mb_is_sha() { [[ "${1:-}" =~ ^[0-9a-fA-F]{40}$ ]]; }

# mb_git_checkout URL REF DIR: DIR holds a depth 1 checkout of REF (detached). A missing DIR is cloned (or initialised and fetched,
# for a commit id); an existing clone gets its origin set to URL and REF fetched again. Returns non-zero when git fails.
mb_git_checkout() {
	local url="$1" ref="$2" dir="$3"
	export GIT_TERMINAL_PROMPT=0
	if [[ ! -d "$dir/.git" ]]; then
		[[ ! -e "$dir" ]] || { echo "$dir exists but is not a git clone" >&2; return 4; }
		mkdir -p "$(dirname "$dir")" || return
		if mb_is_sha "$ref"; then
			git init --quiet "$dir" && git -C "$dir" remote add origin "$url" || return
		else
			git clone --quiet --depth 1 --branch "$ref" "$url" "$dir"
			return
		fi
	else
		git -C "$dir" remote set-url origin "$url" || return
	fi
	git -C "$dir" fetch --quiet --depth 1 origin "$ref" && git -C "$dir" checkout --quiet --force --detach FETCH_HEAD
}

# mb_builds_bxrig BINARY: can this MatchBox compile BxRig? BxRig draws its terminal UI with the canvas classes that only a build with the
# bif-tui feature registers (`createObject( "rust", "tui.TUI" )`). The probe runs a four line script that creates one and draws a frame; a
# MatchBox without the feature stops with "Native class 'tui.TUI' not found" and exits 1. Stable and snapshot builds do not have the feature
# yet. (bootstrap/install.sh has the same probe: it ships alone in the install bundle and cannot source this file.)
mb_builds_bxrig() {
	local mb="$1" dir out rc=0
	dir="$(mktemp -d)" || return 1
	printf '%s\n' 'tui = createObject( "rust", "tui.TUI" );' 'tui.begin_frame();' 'tui.render_to_string( 2, 1 );' 'println( "bxrig-tui-ok" );' > "$dir/probe.bxs"
	if command -v timeout >/dev/null 2>&1; then out="$(cd "$dir" && timeout 60 "$mb" probe.bxs </dev/null 2>/dev/null)" || rc=1
	else out="$(cd "$dir" && "$mb" probe.bxs </dev/null 2>/dev/null)" || rc=1; fi
	rm -rf "$dir"
	(( rc == 0 )) && [[ "$out" == *bxrig-tui-ok* ]]
}
# mb_require_bxrig_capable BINARY: returns 0, or prints why this MatchBox cannot compile BxRig and returns 1. Never switches to another MatchBox.
mb_require_bxrig_capable() {
	mb_builds_bxrig "$1" && return 0
	{
		printf 'This MatchBox (%s) cannot compile BxRig: it has no terminal UI support (the bif-tui feature), which the stable and snapshot builds lack until the BxRig changes ship.\n' "$("$1" --version 2>&1 | head -n 1)"
		echo "  Use the branch build: bash scripts/setup-local.sh --matchbox branch --matchbox-branch bxrig"
	} >&2
	return 1
}
