#!/usr/bin/env bash
# Sets up a local BxRig development environment: picks a MatchBox, records it in .cache/dev.env
# (read by scripts/dev-build.sh and tests/run-all.sh), builds dist/bxrig and runs a smoke test.
#   scripts/setup-local.sh [--matchbox stable|edge|source] [--matchbox-branch REF] [--matchbox-repo REPO] [--release] [--no-build]
#     stable  the released MatchBox, installed with mvm (cannot build BxRig until the bxrig fixes ship)
#     edge    the build of the MatchBox `bxrig` branch that CI publishes (scripts/get-matchbox.sh)
#     source  clone or reuse ../matchbox (branch bxrig) and build it with cargo
#   --matchbox-branch REF   test any branch, tag or commit (full 40 character id) of the MatchBox repo: a shallow clone in
#                           .cache/matchbox-src/<repo>-<ref> (../matchbox is not touched) built with cargo (debug)
#   --matchbox-repo REPO    a fork: https://host/owner/name or owner/name on GitHub (default: box.json toolchain.matchbox.repo)
#   --release               build MatchBox in release mode (source builds)
#   BXRIG_MATCHBOX_BRANCH and BXRIG_MATCHBOX_REPO set the two options (the flags win). A branch other than box.json's
#   (bxrig) or another repo means a source build; `edge` is only published for the bxrig branch and refuses them.
#   .cache/dev.env records the MatchBox path, repo, ref and commit. Switch back: scripts/setup-local.sh --matchbox edge
# Without --matchbox it asks (1 stable, 2 edge, 3 source, 4 any GitHub branch).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
. "$root/scripts/lib/matchbox-ref.sh"
envfile="$root/.cache/dev.env"
choice=""; build=1; release=0
branch="${BXRIG_MATCHBOX_BRANCH:-}"; branch_set=0; [[ -z "$branch" ]] || branch_set=1
repo_in="${BXRIG_MATCHBOX_REPO:-}"; repo_set=0; [[ -z "$repo_in" ]] || repo_set=1
branch_from="BXRIG_MATCHBOX_BRANCH"; repo_from="BXRIG_MATCHBOX_REPO"
die() { echo "$1" >&2; exit "${2:-2}"; }
while (( $# )); do
	case "$1" in
		--matchbox) [[ $# -ge 2 ]] || die "--matchbox needs a value"; choice="$2"; shift 2 ;;
		--matchbox=*) choice="${1#*=}"; shift ;;
		--matchbox-branch) [[ $# -ge 2 ]] || die "--matchbox-branch needs a value"; branch="$2"; branch_set=1; branch_from="--matchbox-branch"; shift 2 ;;
		--matchbox-branch=*) branch="${1#*=}"; branch_set=1; branch_from="--matchbox-branch"; shift ;;
		--matchbox-repo) [[ $# -ge 2 ]] || die "--matchbox-repo needs a value"; repo_in="$2"; repo_set=1; repo_from="--matchbox-repo"; shift 2 ;;
		--matchbox-repo=*) repo_in="${1#*=}"; repo_set=1; repo_from="--matchbox-repo"; shift ;;
		--release) release=1; shift ;;
		--no-build) build=0; shift ;;
		-h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
		*) echo "unknown argument: $1" >&2; exit 2 ;;
	esac
done

need() { # tool...
	local missing=()
	for t in "$@"; do command -v "$t" >/dev/null || missing+=("$t"); done
	(( ${#missing[@]} == 0 )) || { echo "Missing tools: ${missing[*]}" >&2; exit 4; }
}
check_ref() { mb_valid_ref "$1" || { printf 'invalid MatchBox branch/ref (%s): %q\n  use letters, digits and . _ / @ + - only, no leading dash\n' "$2" "$1" >&2; exit 2; }; }
check_repo() { mb_valid_repo "$1" || { printf 'invalid MatchBox repo (%s): %q\n  use https://host/owner/name or owner/name\n' "$2" "$1" >&2; exit 2; }; }
(( ! branch_set )) || check_ref "$branch" "$branch_from"
(( ! repo_set )) || check_repo "$repo_in" "$repo_from"

# What box.json pins: the repo and branch that CI publishes a build of
manifest_repo="$(jq -r '.toolchain.matchbox.repo // empty' "$root/box.json" 2>/dev/null || true)"
[[ -n "$manifest_repo" ]] || manifest_repo=https://github.com/ortus-boxlang/matchbox
manifest_ref="$(jq -r '.toolchain.matchbox.ref // empty' "$root/box.json" 2>/dev/null || true)"
[[ -n "$manifest_ref" ]] || manifest_ref=bxrig
manifest_version="$(jq -r '.toolchain.matchbox.version // empty' "$root/box.json" 2>/dev/null || true)"

# dedicated=1: build the repo and ref asked for from a clone of its own under .cache/matchbox-src
dedicated=0; want_repo="$manifest_repo"; want_ref="$manifest_ref"
resolve_wanted() {
	want_repo="$manifest_repo"; want_ref="$manifest_ref"
	(( ! repo_set )) || want_repo="$(mb_repo_url "$repo_in")"
	(( ! branch_set )) || want_ref="$branch"
	if [[ "$want_ref" != "$manifest_ref" || "$(mb_repo_key "$want_repo")" != "$(mb_repo_key "$manifest_repo")" ]]; then dedicated=1; fi
}
resolve_wanted
if (( dedicated )); then
	case "$choice" in
		"") choice=source ;;
		source) ;;
		edge) die "--matchbox edge is the published build of branch $manifest_ref of $manifest_repo; only builds of that branch are published, so it cannot be combined with a MatchBox branch or repo that differs ($want_ref of $want_repo). Use --matchbox source (or leave --matchbox out) to build it from source." ;;
		*) die "--matchbox $choice cannot be combined with a MatchBox branch or repo other than $manifest_ref of $manifest_repo ($want_ref of $want_repo); that is built from source (--matchbox source)" ;;
	esac
fi

if [[ -z "$choice" ]]; then
	[[ -t 0 ]] || { echo "No terminal to ask on: pass --matchbox stable|edge|source (or --matchbox-branch REF)" >&2; exit 2; }
	echo "Which MatchBox should BxRig use?"
	echo "  1) stable  released MatchBox via mvm (cannot build BxRig until the bxrig fixes ship)"
	echo "  2) edge    the bxrig branch build CI publishes (fast download)"
	echo "  3) source  clone or reuse ../matchbox and build the bxrig branch (needs Rust)"
	echo "  4) any GitHub branch  shallow clone of a repo and branch you name, built with cargo (needs Rust)"
	while [[ -z "$choice" ]]; do
		read -rp "Choose 1, 2, 3 or 4: " a
		case "$a" in 1|stable) choice=stable ;; 2|edge) choice=edge ;; 3|source) choice=source ;; 4|branch) choice=source; dedicated=1 ;; esac
	done
	if (( dedicated && ! repo_set )); then
		while true; do
			read -rp "Repository (owner/name or https URL) [$manifest_repo]: " a
			[[ -n "$a" ]] || a="$manifest_repo"
			mb_valid_repo "$a" && break; echo "Not a valid repository: use https://host/owner/name or owner/name"
		done
		repo_in="$a"; repo_set=1
	fi
	if (( dedicated && ! branch_set )); then
		while true; do
			read -rp "Branch, tag or full commit id: " a
			mb_valid_ref "$a" && break; echo "Not a valid ref: letters, digits and . _ / @ + - only, no leading dash"
		done
		branch="$a"; branch_set=1
	fi
	(( ! dedicated )) || resolve_wanted
fi

mkdir -p "$root/.cache"
s_repo=""; s_ref=""; s_commit=""
case "$choice" in
	stable)
		need curl
		if ! command -v mvm >/dev/null; then
			installer="$(jq -r .toolchain.mvm.installer "$root/box.json" 2>/dev/null || true)"
			[[ -n "$installer" && "$installer" != null ]] || installer="https://raw.githubusercontent.com/ortus-boxlang/matchbox-quick-installer/main/install/install.sh"
			echo "mvm is not installed. Install it with:"
			echo "  curl -fsSL $installer | bash"
			echo "then open a new shell and run this script again."
			exit 4
		fi
		mvm install latest
		mvm use latest
		mb="$(command -v matchbox || true)"
		[[ -n "$mb" ]] || mb="$(find "${MVM_HOME:-$HOME/.mvm}" -type f -name matchbox -perm -u+x 2>/dev/null | head -n1)"
		[[ -n "$mb" ]] || { echo "mvm installed MatchBox but it is not on PATH; open a new shell and run this again" >&2; exit 4; }
		echo "Note: the released MatchBox lacks the bxrig branch fixes, so building BxRig may fail."
		s_repo="released (mvm)"; s_ref="latest"
		;;
	edge)
		need curl jq sha256sum
		mb="$root/.cache/matchbox/matchbox"
		"$root/scripts/get-matchbox.sh" "$mb"
		s_repo="$manifest_repo"; s_ref="$manifest_ref"
		[[ ! -f "$mb.info" ]] || s_commit="$(. "$mb.info" && echo "${commit:-}")"
		;;
	source)
		need git cargo
		if (( dedicated )); then
			src="$root/.cache/matchbox-src/$(mb_repo_slug "$want_repo")-$(mb_ref_slug "$want_ref")"
			echo "Getting $want_repo $want_ref into $src"
			mb_git_checkout "$want_repo" "$want_ref" "$src" || { echo "Could not get $want_ref of $want_repo (is the repo and the branch, tag or full commit id right?)" >&2; exit 4; }
			s_repo="$want_repo"; s_ref="$want_ref"
		else
			src="$(cd "$root/.." && pwd)/matchbox"
			if [[ ! -d "$src/.git" ]]; then
				[[ ! -e "$src" ]] || { echo "$src exists but is not a git clone" >&2; exit 4; }
				git clone --branch bxrig "$manifest_repo" "$src"
			else
				cur="$(git -C "$src" rev-parse --abbrev-ref HEAD)"
				if [[ "$cur" == bxrig && -z "$(git -C "$src" status --porcelain)" ]]; then
					git -C "$src" pull --ff-only origin bxrig
				else
					echo "Using $src as it is (branch $cur, local changes left alone)"
				fi
			fi
			s_repo="$manifest_repo"; s_ref="$(git -C "$src" rev-parse --abbrev-ref HEAD)"
		fi
		s_commit="$(git -C "$src" rev-parse --short HEAD)"
		if (( release )); then
			(cd "$src" && cargo build --release --features bif-tui)
			mb="$src/target/release/matchbox"
		else
			(cd "$src" && cargo build --features bif-tui)
			mb="$src/target/debug/matchbox"
		fi
		;;
	*) echo "unknown MatchBox choice: $choice (stable, edge or source)" >&2; exit 2 ;;
esac

[[ -x "$mb" ]] || { echo "No MatchBox at $mb" >&2; exit 4; }
if (( dedicated )); then
	printf '# written by scripts/setup-local.sh (source-branch)\nMATCHBOX=%q\nMATCHBOX_REPO=%q\nMATCHBOX_REF=%q\nMATCHBOX_COMMIT=%q\n' "$mb" "$s_repo" "$s_ref" "$s_commit" > "$envfile"
else
	printf '# written by scripts/setup-local.sh (%s)\nMATCHBOX=%q\n' "$choice" "$mb" > "$envfile"
fi
echo "MatchBox: $("$mb" --version 2>&1 | head -n1) ($mb), saved in .cache/dev.env"
# a branch can report another version than box.json: a warning, the build goes on
(( ! dedicated )) || mb_version_warn "$mb" "$manifest_version" || true

(( build )) || exit 0
MATCHBOX="$mb" "$root/scripts/dev-build.sh"
"$root/dist/bxrig" version
(cd "$root/src" && "$mb" ../tests/init_plan_test.bxs >/dev/null) && echo "smoke test passed"
echo
echo "Ready. Next:"
echo "  scripts/dev-build.sh            rebuild dist/bxrig"
echo "  tests/run-all.sh                run every test"
echo "  tests/run-all.sh dist/bxrig X   run the tests whose name contains X"
