#!/usr/bin/env bash
# The BoxLang modules embedded in bxrig (box.json toolchain.modules), unpacked into OUTDIR, one folder per module. Prints the folders, one per line,
# for `matchbox --module`. Usage: get-modules.sh OUTDIR
# Each module's release zip is downloaded once (cached in OUTDIR/.zips) and checked against its sha256. When the module has a MatchBox native plugin
# that cannot load on this machine (a prebuilt library linked against a newer glibc), the plugin is rebuilt from the module's tag with cargo and its
# path and sha256 in the module's box.json are updated, so the binary built here runs here.
#   MATCHBOX=/path/to/matchbox   the compiler used to check that a module loads (default: matchbox on PATH)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:?usage: get-modules.sh OUTDIR}"
mb="${MATCHBOX:-matchbox}"
for tool in jq curl unzip sha256sum; do command -v "$tool" >/dev/null || { echo "get-modules: $tool is required" >&2; exit 4; }; done
mkdir -p "$out/.zips"
count="$(jq '.toolchain.modules // [] | length' "$root/box.json")"

# True when a script that only starts runs with the module loaded.
loads() {
	local probe; probe="$(mktemp -d)"
	echo 'println( "ok" );' > "$probe/probe.bxs"
	local result; result="$("$mb" --module "$1" "$probe/probe.bxs" 2>&1 || true)"
	rm -rf "$probe"
	[[ "$result" == ok* ]]
}

for ((i = 0; i < count; i++)); do
	mod="$(jq -c ".toolchain.modules[$i]" "$root/box.json")"
	slug="$(jq -r .slug <<<"$mod")"; version="$(jq -r .version <<<"$mod")"
	url="$(jq -r .url <<<"$mod")"; sum="$(jq -r .sha256 <<<"$mod")"
	zip="$out/.zips/$slug-$version.zip"; dir="$out/$slug"
	if [[ ! -f "$zip" ]] || ! echo "$sum  $zip" | sha256sum -c --quiet - 2>/dev/null; then
		curl -fsSL --retry 3 -o "$zip.part" "$url" || { echo "get-modules: could not download $slug $version ($url)" >&2; exit 5; }
		echo "$sum  $zip.part" | sha256sum -c --quiet - || { echo "get-modules: $slug $version does not match its sha256" >&2; rm -f "$zip.part"; exit 5; }
		mv "$zip.part" "$zip"
	fi
	stamp="$dir/.bxrig-module"
	if [[ ! -f "$stamp" || "$(cat "$stamp")" != "$version $sum" ]]; then
		rm -rf "$dir"; mkdir -p "$dir"
		unzip -q "$zip" -d "$dir"
		echo "$version $sum" > "$stamp"
	fi
	if ! loads "$dir"; then
		target="x86_64-unknown-linux-gnu"
		artifact="$(jq -r --arg t "$target" '.matchbox.artifacts[$t].path // empty' "$dir/box.json")"
		[[ -n "$artifact" ]] || { echo "get-modules: $slug does not load and has no $target plugin to rebuild" >&2; exit 4; }
		command -v cargo >/dev/null || { echo "get-modules: $slug's plugin does not load here and cargo is needed to rebuild it" >&2; exit 4; }
		echo "get-modules: rebuilding the $slug plugin from $(jq -r .tag <<<"$mod") for this machine" >&2
		src="$(mktemp -d)"
		git -c advice.detachedHead=false clone -q --depth 1 --branch "$(jq -r .tag <<<"$mod")" "$(jq -r .repo <<<"$mod")" "$src/repo"
		cargo build -q --release --manifest-path "$src/repo/native/Cargo.toml" --target-dir "$src/target" >&2
		cp "$src/target/release/$(basename "$artifact")" "$dir/$artifact"
		jq --arg t "$target" --arg s "$(sha256sum "$dir/$artifact" | awk '{print $1}')" '.matchbox.artifacts[$t].sha256 = $s' "$dir/box.json" > "$dir/box.json.new"
		mv "$dir/box.json.new" "$dir/box.json"
		rm -rf "$src"
		loads "$dir" || { echo "get-modules: $slug still does not load after the rebuild" >&2; exit 4; }
	fi
	echo "$dir"
done
