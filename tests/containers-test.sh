#!/usr/bin/env bash
# `bxrig containers` and `bxrig editor lazyvim` with fake podman, docker, pacman, sudo, systemctl and git. Usage: containers-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/etc" "$tmp/installed"; export LOG="$tmp/log"; : > "$LOG"
cat > "$tmp/bin/podman" <<'SH'
#!/usr/bin/env bash
echo "podman $*" >> "$LOG"
[[ "$1" == info ]] && echo "${ROOTLESS:-true}"
if [[ "$1" == ps ]]; then
	printf 'web|docker.io/library/nginx:1.27|running|0.0.0.0:8080->80/tcp, [::]:8080->80/tcp|2026-11-10 09:00:00 +0000 UTC\n'
	printf 'bxrig-db-postgres-default|docker.io/library/postgres:17|exited||2026-11-09 10:00:00 +0000 UTC\n'
	printf 'bxrig-vm-lab|lscr.io/linuxserver/webtop:ubuntu-xfce|running|127.0.0.1:3001->3001/tcp|2026-11-08 10:00:00 +0000 UTC\n'
fi
if [[ "$1" == container && "$2" == inspect ]]; then
	case "$5" in web|bxrig-vm-lab) echo running ;; stopped|broken) echo exited ;; *) exit 1 ;; esac
fi
[[ "$1" == logs && "$4" == web ]] && printf 'line one\nline two\n'
[[ "$1" == start && "$2" == broken ]] && { echo "boom" >&2; exit 1; }
exit 0
SH
printf '#!/usr/bin/env bash\necho "podman version 6.2.0"\n' > "$tmp/bin/docker"
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "$LOG"\n[[ "$2" == is-active ]] && echo "${SOCK:-inactive}"\nexit 0\n' > "$tmp/bin/systemctl"
printf '#!/usr/bin/env bash\necho "sudo $*" >> "$LOG"\nexec "$@"\n' > "$tmp/bin/sudo"
cat > "$tmp/bin/pacman" <<'SH'
#!/usr/bin/env bash
echo "pacman $*" >> "$LOG"
if [[ "$1" == -Q ]]; then [[ -e "$INSTALLED/$2" ]]; exit $?; fi
if [[ "$1" == -S ]]; then for a in "$@"; do [[ "$a" != -* ]] && touch "$INSTALLED/$a"; done; fi
SH
printf '#!/usr/bin/env bash\necho "git $*" >> "$LOG"\nif [[ "$1" == clone ]]; then mkdir -p "$3/.git" "$3/lua"; echo init > "$3/init.lua"; fi\n' > "$tmp/bin/git"
chmod +x "$tmp/bin"/*
run() { env HOME="$tmp/home" USER=ada BXRIG_ETC="$tmp/etc" XDG_RUNTIME_DIR=/run/user/1000 XDG_CONFIG_HOME="$tmp/home/.config" INSTALLED="$tmp/installed" LOG="$LOG" ROOTLESS="${ROOTLESS:-true}" SOCK="${SOCK:-}" PATH="$tmp/bin:$PATH" "$@"; }

# doctor: everything missing it can fix is reported with the command that fixes it
echo "ada:100000:65536" > "$tmp/etc/subuid"; echo "ada:100000:65536" > "$tmp/etc/subgid"
out="$(run "$binary" containers doctor)" && fail 'doctor must exit 4 while something needs fixing' || true
[[ "$out" == *'FIX   compose'* && "$out" == *'bxrig containers docker-compat'* && "$out" == *'FIX   socket'* && "$out" == *'ok    docker-shim'* && "$out" == *'ok    subuid'* && "$out" == *'ok    rootless'* ]] || fail "doctor report: $out"
touch "$tmp/installed/x"; ln -sf "$tmp/bin/podman" "$tmp/bin/podman-compose"
SOCK=active run "$binary" containers doctor --json | jq -e '.ok == true and (.data.checks | length) == 6' >/dev/null || fail "doctor when all is well: $(SOCK=active run "$binary" containers doctor --json)"
{ ROOTLESS=false SOCK=active run "$binary" containers doctor --json || true; } | jq -e '.data.checks[] | select(.id=="rootless") | .ok == false' >/dev/null || fail 'doctor rootless'
rm "$tmp/etc/subuid"; { SOCK=active run "$binary" containers doctor --json || true; } | jq -e '.data.checks[] | select(.id=="subuid") | .ok == false and (.fix | contains("usermod"))' >/dev/null || fail 'doctor subuid'
mkdir -p "$tmp/nobin"; ln -sf "$(command -v sh)" "$tmp/nobin/sh"
set +e; env HOME="$tmp/home" PATH="$tmp/nobin" "$binary" containers doctor >/dev/null 2>&1; rc=$?; set -e; [[ "$rc" == 4 ]] || fail 'no podman exits 4'

# list, start, stop, restart, logs
out="$(run "$binary" containers list --json)"
echo "$out" | jq -e '.ok == true and .data.engine == "podman" and (.data.containers | length) == 3' >/dev/null || fail "containers list: $out"
echo "$out" | jq -e '.data.containers[0] | .name == "web" and .state == "running" and .ports == [8080] and .kind == "container" and .image == "docker.io/library/nginx:1.27" and (.created | startswith("2026-11-10"))' >/dev/null || fail "containers list row: $out"
echo "$out" | jq -e '[.data.containers[].kind] == ["container","database","vm"]' >/dev/null || fail 'containers list kinds'
run "$binary" containers list | grep -q '^web .*running .*nginx' || fail 'containers list text'
grep -q 'podman ps -a --format' "$LOG" || fail 'list uses ps -a'
: > "$LOG"; run "$binary" containers stop web | grep -q 'Stopped web' || fail 'stop'
grep -q '^podman stop web$' "$LOG" || fail "stop argv: $(cat "$LOG")"
: > "$LOG"; run "$binary" containers stop stopped | grep -q 'not running' || fail 'stop on an exited container is a no-op'
! grep -q '^podman stop' "$LOG" || fail 'stop ran for an exited container'
: > "$LOG"; run "$binary" containers start stopped | grep -q 'Started stopped' || fail 'start'
grep -q '^podman start stopped$' "$LOG" || fail 'start argv'
run "$binary" containers start web --json | jq -e '.ok and .data.already == true and .data.state == "running"' >/dev/null || fail 'start on a running container'
: > "$LOG"; run "$binary" containers restart web | grep -q 'Restarted web' || fail 'restart'
grep -q '^podman restart web$' "$LOG" || fail 'restart argv'
[[ "$(code "$binary" containers start nosuch)" == 4 ]] || fail 'a missing container exits 4'
[[ "$(code "$binary" containers start broken)" == 6 ]] || fail 'a failing start exits 6'
{ run "$binary" containers start broken --json 2>/dev/null || true; } | jq -e '.ok == false and .exit == 6 and (.data.error | contains("boom"))' >/dev/null || fail 'failing start json'
[[ "$(code "$binary" containers start -rf)" == 2 ]] || fail 'a bad name exits 2'
[[ "$(code "$binary" containers start 'a b')" == 2 ]] || fail 'a name with a space exits 2'
: > "$LOG"; out="$(run "$binary" containers logs web --lines=50)"; [[ "$out" == *'line two'* ]] || fail "logs: $out"
grep -q '^podman logs --tail 50 web$' "$LOG" || fail "logs argv: $(cat "$LOG")"
grep -q '^podman logs --tail 200 web$' <(: > "$LOG"; run "$binary" containers logs web >/dev/null; cat "$LOG") || fail 'logs default is 200 lines'
run "$binary" containers logs web --json | jq -e '.data.name == "web" and .data.lines == 200 and (.data.logs | contains("line one"))' >/dev/null || fail 'logs json'
[[ "$(code "$binary" containers logs web --lines=0)" == 2 ]] || fail '--lines=0 exits 2'
[[ "$(code "$binary" containers logs web --lines=abc)" == 2 ]] || fail '--lines=abc exits 2'
[[ "$(code "$binary" containers logs nosuch)" == 4 ]] || fail 'logs on a missing container exits 4'
# the chosen engine is used (docker here: the fake `docker` only answers --version)
mkdir -p "$tmp/home/.config/bxrig"; echo '{"engine":"docker"}' > "$tmp/home/.config/bxrig/db.json"
printf '#!/usr/bin/env bash\necho "docker $*" >> "$LOG"\n[[ "$1" == ps ]] && echo "api|img|exited||2026-11-10"\nexit 0\n' > "$tmp/bin/docker"; chmod +x "$tmp/bin/docker"
: > "$LOG"; run "$binary" containers list --json | jq -e '.data.engine == "docker" and .data.containers[0].name == "api" and .data.containers[0].state == "exited"' >/dev/null || fail 'list on docker'
rm "$tmp/home/.config/bxrig/db.json"
printf '#!/usr/bin/env bash\necho "podman version 6.2.0"\n' > "$tmp/bin/docker"
# no engine: exit 4 with a hint
set +e; env HOME="$tmp/home" PATH="$tmp/nobin" "$binary" containers list >/dev/null 2>&1; rc=$?; set -e
[[ "$rc" == 4 ]] || fail 'list without an engine exits 4'
{ env HOME="$tmp/home" PATH="$tmp/nobin" "$binary" containers list --json 2>/dev/null || true; } | jq -e '.exit == 4 and (.data.error | contains("not found"))' >/dev/null || fail 'list without an engine json'

# socket
[[ "$(code "$binary" containers socket enable)" == 2 ]] || fail 'socket enable without --yes exits 2'
: > "$LOG"; run "$binary" containers socket enable --yes | grep -q 'DOCKER_HOST=unix:///run/user/1000/podman/podman.sock' || fail 'socket enable prints DOCKER_HOST'
grep -q 'systemctl --user enable --now podman.socket' "$LOG" || fail 'socket command'

# docker-compat
rm -f "$tmp/installed/"*
[[ "$(code "$binary" containers docker-compat)" == 2 ]] || fail 'docker-compat without --yes exits 2'
: > "$LOG"; run "$binary" containers docker-compat --yes | grep -q 'Installed podman-docker, podman-compose' || fail 'docker-compat --yes'
grep -q 'sudo pacman -S --needed --noconfirm podman-docker podman-compose' "$LOG" || fail "install command: $(cat "$LOG")"
run "$binary" containers docker-compat --yes | grep -q 'Already in place' || fail 'docker-compat is idempotent'
touch "$tmp/installed/docker"; rm -f "$tmp/installed/podman-docker"; [[ "$(code "$binary" containers docker-compat --yes)" == 4 ]] || fail 'the docker package blocks podman-docker (exit 4)'
rm -f "$tmp/installed/docker"

# LazyVim
rm -f "$tmp/installed/"*
[[ "$(code "$binary" editor lazyvim)" == 2 ]] || fail 'lazyvim without --yes exits 2'
[[ ! -e "$tmp/home/.config/nvim" ]] || fail 'the plan cloned'
: > "$LOG"; run "$binary" editor lazyvim --yes | grep -q 'LazyVim starter is in' || fail 'lazyvim --yes'
grep -q 'sudo pacman -S --needed --noconfirm neovim git ripgrep fd lazygit' "$LOG" || fail "tools installed first: $(cat "$LOG")"
grep -q "git clone https://github.com/LazyVim/starter $tmp/home/.config/nvim" "$LOG" || fail 'clone command'
[[ -f "$tmp/home/.config/nvim/init.lua" && ! -e "$tmp/home/.config/nvim/.git" ]] || fail 'the .git folder is removed'
echo mine > "$tmp/home/.config/nvim/init.lua"; : > "$LOG"
[[ "$(code "$binary" editor lazyvim --yes)" == 4 ]] || fail 'an existing nvim config exits 4'
[[ "$(cat "$tmp/home/.config/nvim/init.lua")" == mine && ! -s "$LOG" ]] || fail 'an existing config was touched'
echo "containers-test: ok"
