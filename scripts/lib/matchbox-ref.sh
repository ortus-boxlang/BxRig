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

# mb_version_warn BINARY WANT: a warning (never an error) when BINARY's --version does not mention WANT, the version in box.json.
# Returns 1 when it warned.
mb_version_warn() {
	local out
	out="$("$1" --version 2>&1 | head -n 1)" || true
	[[ -z "${2:-}" || "$out" == *"$2"* ]] && return 0
	echo "warning: this MatchBox reports '${out:-nothing}' but box.json toolchain.matchbox.version is $2; continuing (a branch build can differ, but bootstrap/install.sh insists on $2)" >&2
	return 1
}
