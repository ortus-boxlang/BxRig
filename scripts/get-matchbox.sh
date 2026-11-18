#!/usr/bin/env bash
# Provides the MatchBox that compiles BxRig (box.json toolchain.matchbox): the build of the MatchBox
# `bxrig` branch that CI publishes to S3, or, when it is not published yet or --from-source is given, a
# release build of that branch made here.
#   get-matchbox.sh DEST_FILE [--from-source] [--ref REF] [--repo REPO]
# Writes DEST_FILE (executable) and DEST_FILE.info (version, ref, commit, source) and prints one summary line.
# --ref REF / --repo REPO build another branch, tag or full commit id of the MatchBox repo (owner/name on GitHub or an https URL) from
# source instead: only builds of the box.json branch are published. Such a build may report another version than box.json: that is a
# warning, not an error (the default path still insists on box.json's version).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
. "$root/scripts/lib/matchbox-ref.sh"
dest="${1:-}"; shift || true
from_source=0; ref_arg=""; ref_set=0; repo_arg=""; repo_set=0
while (( $# )); do
	case "$1" in
		--from-source) from_source=1; shift ;;
		--ref) [[ $# -ge 2 ]] || { echo "--ref needs a value" >&2; exit 2; }; ref_arg="$2"; ref_set=1; shift 2 ;;
		--ref=*) ref_arg="${1#*=}"; ref_set=1; shift ;;
		--repo) [[ $# -ge 2 ]] || { echo "--repo needs a value" >&2; exit 2; }; repo_arg="$2"; repo_set=1; shift 2 ;;
		--repo=*) repo_arg="${1#*=}"; repo_set=1; shift ;;
		*) echo "unknown argument: $1" >&2; exit 2 ;;
	esac
done
[[ -n "$dest" ]] || { echo "usage: get-matchbox.sh DEST_FILE [--from-source] [--ref REF] [--repo REPO]" >&2; exit 2; }
if (( ref_set )); then mb_valid_ref "$ref_arg" || { printf 'invalid --ref: %q (letters, digits and . _ / @ + - only, no leading dash)\n' "$ref_arg" >&2; exit 2; }; fi
if (( repo_set )); then mb_valid_repo "$repo_arg" || { printf 'invalid --repo: %q (https://host/owner/name or owner/name)\n' "$repo_arg" >&2; exit 2; }; fi
command -v jq >/dev/null || { echo "jq is required" >&2; exit 4; }
manifest="${BXRIG_MANIFEST:-$root/box.json}"
want="$(jq -r .toolchain.matchbox.version "$manifest")"
repo="$(jq -r '.toolchain.matchbox.repo // empty' "$manifest")"
ref="$(jq -r '.toolchain.matchbox.ref // empty' "$manifest")"
base="$(jq -r '.toolchain.matchbox.downloads // empty' "$manifest")"
# another branch or repo than the manifest's is never published: it is built from source and its version is only warned about
override=0
if (( ref_set )) && [[ "$ref_arg" != "$ref" ]]; then override=1; fi
if (( repo_set )) && [[ "$(mb_repo_key "$(mb_repo_url "$repo_arg")")" != "$(mb_repo_key "$repo")" ]]; then override=1; fi
if (( override )); then
	(( ! repo_set )) || repo="$(mb_repo_url "$repo_arg")"
	(( ! ref_set )) || ref="$ref_arg"
	from_source=1
fi
mkdir -p "$(dirname "$dest")"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

finish() {  # FILE SOURCE COMMIT
	chmod 755 "$1"
	local out; out="$("$1" --version 2>&1 | head -n 1)" || true
	if (( override )); then
		[[ "$out" == *"$want"* ]] || echo "warning: the MatchBox built from $ref of $repo reports '${out:-nothing}', box.json wants $want; continuing (bootstrap/install.sh insists on $want)" >&2
		want="${out:-unknown}"
	else
		[[ "$out" == *"$want"* ]] || { echo "The MatchBox found reports '${out:-nothing}', box.json wants $want" >&2; return 1; }
	fi
	cp "$1" "$dest.new"; mv -f "$dest.new" "$dest"
	# shell-safe: the file is sourced by the workflow (values contain spaces)
	printf 'version=%q\nref=%q\ncommit=%q\nsource=%q\n' "$want" "$ref" "$3" "$2" > "$dest.info"
	(( ! override )) || printf 'repo=%q\n' "$repo" >> "$dest.info"
	echo "MatchBox $want ($2${3:+, $3}) -> $dest"
}

# The evergreen files can be served stale by the CDN (version-latest.properties too, for about a day), so the build is taken
# from its immutable folder (<version>-<commit>/): the one for the commit the branch is on now (git ls-remote). When the branch head is
# known but that build is not published yet, nothing is returned: an older published build (version-latest.properties, or the evergreen
# file) is behind the branch and can lack what BxRig and its modules need (a stale 0.14.0 build lacked matchbox.types.v1, so bx-image did
# not load), so the caller builds the head from source. Only when the head cannot be read (no git, no network to the repo) the build named
# in version-latest.properties, or else the evergreen folder, is used.
build_base() {
	local props v c head
	if [[ -n "$repo" && -n "$ref" ]] && command -v git >/dev/null; then
		head="$(git ls-remote "$repo" "refs/heads/$ref" 2>/dev/null | awk '{print substr($1, 1, 7); exit}')" || head=""
		if [[ -n "$head" ]] && curl -fsSL -m 30 -o /dev/null "$base/$want-$head/version.properties" 2>/dev/null; then echo "$base/$want-$head"; return; fi
		[[ -z "$head" ]] || return 1
	fi
	props="$(curl -fsSL -m 30 "$base/version-latest.properties" 2>/dev/null)" || { echo "$base"; return; }
	v="$(sed -n 's/^version=//p' <<<"$props" | head -n1)"; c="$(sed -n 's/^commit=//p' <<<"$props" | head -n1)"
	if [[ -n "$v" && -n "$c" ]]; then echo "$base/$v-$c"; else echo "$base"; fi
}

if (( ! from_source )) && [[ -n "$base" ]]; then
	if dl="$(build_base)" && curl -fsSL -m 300 -o "$work/matchbox" "$dl/matchbox-linux-x86_64" \
		 && curl -fsSL -m 30 -o "$work/matchbox.sha256" "$dl/matchbox-linux-x86_64.sha256"; then
		expected="$(awk '{print $1; exit}' "$work/matchbox.sha256")"
		actual="$(sha256sum "$work/matchbox" | awk '{print $1}')"
		[[ -n "$expected" && "$expected" == "$actual" ]] || { echo "Checksum mismatch for the published MatchBox" >&2; exit 1; }
		finish "$work/matchbox" "published" "" && exit 0
		echo "The published MatchBox does not match box.json; building from source instead" >&2
	else
		echo "No published MatchBox at $base for the $ref branch head; building from source" >&2
	fi
fi

[[ -n "$repo" && -n "$ref" ]] || { echo "box.json has no toolchain.matchbox.repo and ref to build from" >&2; exit 1; }
command -v cargo >/dev/null || { echo "cargo is required to build MatchBox from source" >&2; exit 4; }
mb_git_checkout "$repo" "$ref" "$work/src" || { echo "Could not get $ref of $repo" >&2; exit 4; }
commit="$(git -C "$work/src" rev-parse --short HEAD)"
if (( override )); then locked=(); else locked=(--locked); fi   # a branch under test may have changed its dependencies
( cd "$work/src" && cargo build --release ${locked[@]+"${locked[@]}"} --features bif-tui 2>&1 | tail -n 5 )
finish "$work/src/target/release/matchbox" "built from $ref" "$commit"
