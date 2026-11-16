#!/usr/bin/env bash
# Sets up a local BxRig development environment: picks a MatchBox, records it in .cache/dev.env
# (read by scripts/dev-build.sh and tests/run-all.sh), builds dist/bxrig and runs a smoke test.
#   scripts/setup-local.sh [--matchbox stable|edge|source] [--no-build]
#     stable  the released MatchBox, installed with mvm (cannot build BxRig until the bxrig fixes ship)
#     edge    the build of the MatchBox `bxrig` branch that CI publishes (scripts/get-matchbox.sh)
#     source  clone or reuse ../matchbox (branch bxrig) and build it with cargo
# Without --matchbox it asks.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
envfile="$root/.cache/dev.env"
choice=""; build=1
while (( $# )); do
	case "$1" in
		--matchbox) choice="${2:-}"; shift 2 ;;
		--matchbox=*) choice="${1#*=}"; shift ;;
		--no-build) build=0; shift ;;
		-h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "unknown argument: $1" >&2; exit 2 ;;
	esac
done

need() { # tool...
	local missing=()
	for t in "$@"; do command -v "$t" >/dev/null || missing+=("$t"); done
	(( ${#missing[@]} == 0 )) || { echo "Missing tools: ${missing[*]}" >&2; exit 4; }
}

if [[ -z "$choice" ]]; then
	[[ -t 0 ]] || { echo "No terminal to ask on: pass --matchbox stable|edge|source" >&2; exit 2; }
	echo "Which MatchBox should BxRig use?"
	echo "  1) stable  released MatchBox via mvm (cannot build BxRig until the bxrig fixes ship)"
	echo "  2) edge    the bxrig branch build CI publishes (fast download)"
	echo "  3) source  clone or reuse ../matchbox and build the bxrig branch (needs Rust)"
	while [[ -z "$choice" ]]; do
		read -rp "Choose 1, 2 or 3: " a
		case "$a" in 1|stable) choice=stable ;; 2|edge) choice=edge ;; 3|source) choice=source ;; esac
	done
fi

mkdir -p "$root/.cache"
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
		;;
	edge)
		need curl jq sha256sum
		mb="$root/.cache/matchbox/matchbox"
		"$root/scripts/get-matchbox.sh" "$mb"
		;;
	source)
		need git cargo
		src="$(cd "$root/.." && pwd)/matchbox"
		repo="$(jq -r .toolchain.matchbox.repo "$root/box.json" 2>/dev/null || echo https://github.com/ortus-boxlang/matchbox)"
		if [[ ! -d "$src/.git" ]]; then
			[[ ! -e "$src" ]] || { echo "$src exists but is not a git clone" >&2; exit 4; }
			git clone --branch bxrig "$repo" "$src"
		else
			branch="$(git -C "$src" rev-parse --abbrev-ref HEAD)"
			if [[ "$branch" == bxrig && -z "$(git -C "$src" status --porcelain)" ]]; then
				git -C "$src" pull --ff-only origin bxrig
			else
				echo "Using $src as it is (branch $branch, local changes left alone)"
			fi
		fi
		(cd "$src" && cargo build --features bif-tui)
		mb="$src/target/debug/matchbox"
		;;
	*) echo "unknown MatchBox choice: $choice (stable, edge or source)" >&2; exit 2 ;;
esac

[[ -x "$mb" ]] || { echo "No MatchBox at $mb" >&2; exit 4; }
printf '# written by scripts/setup-local.sh (%s)\nMATCHBOX=%q\n' "$choice" "$mb" > "$envfile"
echo "MatchBox: $("$mb" --version 2>&1 | head -n1) ($mb), saved in .cache/dev.env"

(( build )) || exit 0
MATCHBOX="$mb" "$root/scripts/dev-build.sh"
"$root/dist/bxrig" version
(cd "$root/src" && "$mb" ../tests/init_plan_test.bxs >/dev/null) && echo "smoke test passed"
echo
echo "Ready. Next:"
echo "  scripts/dev-build.sh            rebuild dist/bxrig"
echo "  tests/run-all.sh                run every test"
echo "  tests/run-all.sh dist/bxrig X   run the tests whose name contains X"
