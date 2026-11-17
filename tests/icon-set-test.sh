#!/usr/bin/env bash
# `bxrig appearance icons bxrig|papirus|status`: the BxRig icon theme over Papirus-Dark, or Papirus alone. Fake gsettings, xfconf-query, pacman, sudo, id and a terminal.
# Usage: icon-set-test.sh BINARY
. "$(dirname "$0")/lib/harness.sh"
mkdir -p "$tmp/bin" "$tmp/home" "$tmp/cfg" "$tmp/data" "$tmp/fake"; export LOG="$tmp/log"; : > "$LOG"
stub_id; stub_sudo_log
for t in gsettings xfconf-query; do printf '#!/usr/bin/env bash\necho "%s $*" >> "$LOG"\n' "$t" > "$tmp/bin/$t"; done
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/bin/ghostty"
cat > "$tmp/bin/pacman" <<'FAKE'
#!/usr/bin/env bash
echo "pacman $*" >> "$LOG"
case "$1" in
  -Q|-Qq) exit 1 ;;
  -S) mkdir -p "$XDG_DATA_HOME/icons/Papirus-Dark/16x16/apps"; printf '[Icon Theme]\nName=Papirus-Dark\nDirectories=16x16/apps\n' > "$XDG_DATA_HOME/icons/Papirus-Dark/index.theme" ;;
esac
FAKE
chmod +x "$tmp/bin"/*
printf 'com.mitchellh.ghostty.desktop\n' > "$tmp/cfg/xdg-terminals.list"
run() { env HOME="$tmp/home" XDG_DATA_HOME="$tmp/data" BXRIG_CONFIG_HOME="$tmp/cfg" BXRIG_STATE_HOME="$tmp/state" BXRIG_SHARE_DIR="$tmp/none" BXRIG_SELF=/opt/bxrig/bxrig XDG_CURRENT_DESKTOP=XFCE PATH="$tmp/bin:$PATH" LOG="$LOG" "$@"; }
plan() { run "$@" || true; }
has() { grep -qF -- "$1" "$LOG"; }
theme="$tmp/data/icons/BxRig"

# status on a fresh machine
run "$binary" appearance icons status --json | jq -e '.ok and .data.set == "" and .data.bxrig_installed == false and .data.papirus_installed == false' >/dev/null || fail 'fresh status'
[[ "$(code "$binary" appearance icons)" == 0 ]] || fail 'bare icons is status'
[[ "$(code "$binary" appearance icons nonsense)" == 2 && "$(code "$binary" appearance icons bxrig extra)" == 2 ]] || fail 'usage exits 2'

# a plan changes nothing and names the package (Papirus-Dark is missing) and the files
[[ "$(code "$binary" appearance icons bxrig)" == 2 ]] || fail 'no --yes is a plan (exit 2)'
[[ "$(code "$binary" appearance icons bxrig --dry-run)" == 0 ]] || fail 'dry run exits 0'
plan "$binary" appearance icons bxrig --json | jq -e '.exit == 2 and (.data.commands | join(" ") | contains("pacman -S --needed --noconfirm papirus-icon-theme")) and .data.theme == "BxRig"' >/dev/null || fail 'plan json'
plan "$binary" appearance icons bxrig | grep -q "write the BxRig icon theme to $theme" || fail 'plan names the theme folder'
[[ ! -e "$theme" && ! -e "$tmp/cfg/qt6ct" ]] || fail "a plan or dry run wrote files"
! grep -qE "^(sudo pacman -S|gsettings set|xfconf-query)" "$LOG" || fail "a plan or dry run ran a change: $(cat "$LOG")"
[[ "$(MOCK_UID=0 code "$binary" appearance icons bxrig --yes)" == 4 ]] || fail 'root exits 4'

# --yes: installs Papirus, writes the theme, sets GTK, Qt and the runner, remembers the set
mkdir -p "$tmp/cfg/gtk-3.0"; printf '[Settings]\ngtk-theme-name=adw-gtk3-dark\ngtk-font-name=Sans 10\n' > "$tmp/cfg/gtk-3.0/settings.ini"
[[ "$(code "$binary" appearance icons bxrig --yes)" == 0 ]] || fail "icons bxrig --yes: $(run "$binary" appearance icons bxrig --yes 2>&1 | tail -3)"
has 'sudo pacman -S --needed --noconfirm papirus-icon-theme' || fail 'papirus was not installed'
cmp "$theme/index.theme" "$root/assets/icons/theme/BxRig/index.theme" || fail 'index.theme differs'
grep -q '^Inherits=Papirus-Dark,hicolor$' "$theme/index.theme" || fail 'Inherits'
cmp "$theme/256x256/apps/bxrig-boxlang.png" "$root/assets/icons/theme/BxRig/256x256/apps/bxrig-boxlang.png" || fail 'a PNG differs'
cmp "$theme/scalable/categories/bxrig-develop.svg" "$root/assets/icons/theme/BxRig/scalable/categories/bxrig-develop.svg" || fail 'an SVG differs'
grep -q 'MIT License' "$theme/LICENSE-Phosphor.txt" || fail 'the Phosphor licence is not installed'
[[ "$(find "$theme" -name '*.png' | wc -l)" == "$(find "$root/assets/icons/theme/BxRig" -name '*.png' | wc -l)" ]] || fail 'PNG count'
has "gsettings set org.gnome.desktop.interface icon-theme BxRig" || fail 'gsettings'
has "xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s BxRig" || fail 'xfconf on XFCE'
grep -qx 'gtk-icon-theme-name=BxRig' "$tmp/cfg/gtk-3.0/settings.ini" || fail 'gtk-3.0 settings.ini'
grep -qx 'gtk-theme-name=adw-gtk3-dark' "$tmp/cfg/gtk-3.0/settings.ini" && grep -qx 'gtk-font-name=Sans 10' "$tmp/cfg/gtk-3.0/settings.ini" || fail 'the other settings were lost'
grep -qx 'icon_theme=BxRig' "$tmp/cfg/qt6ct/qt6ct.conf" && grep -qx '\[Appearance\]' "$tmp/cfg/qt6ct/qt6ct.conf" || fail 'qt6ct'
jq -e '.icon_theme == "BxRig"' "$tmp/cfg/bxrig/runner.json" >/dev/null || fail 'runner icon theme'
jq -e '.icons.set == "bxrig"' "$tmp/cfg/bxrig/appearance.json" >/dev/null || fail 'appearance.json icons.set'
run "$binary" appearance icons status --json | jq -e '.data.set == "bxrig" and .data.bxrig_installed and .data.bxrig_current and .data.papirus_installed and .data.runner == "BxRig"' >/dev/null || fail 'status after'

# idempotent: a second run has nothing to install
: > "$LOG"
[[ "$(code "$binary" appearance icons bxrig --yes)" == 0 ]] || fail 'second run'
! has 'pacman -S' || fail 'second run installed again'
plan "$binary" appearance icons bxrig --json | jq -e '(.data.files | length) == 0 and (.data.commands | length) == 0' >/dev/null || fail 'a second plan still has files and commands'

# launchers follow the set
[[ "$(code "$binary" launchers on --yes)" == 0 ]] || fail 'launchers on'
apps="$tmp/data/applications"; dd="$tmp/data/desktop-directories"
grep -qx 'Icon=bxrig-boxlang' "$apps/bxrig-tui-boxlang.desktop" || fail "page icon with the bxrig set: $(grep Icon "$apps/bxrig-tui-boxlang.desktop")"
grep -qx 'Icon=bxrig-wizard' "$apps/bxrig-wizard.desktop" && grep -qx 'Icon=bxrig-runner' "$apps/bxrig-runner.desktop" && grep -qx 'Icon=bxrig-control-center' "$apps/bxrig-controlcenter.desktop" || fail 'wizard, runner, control center icons'
grep -qx 'Icon=bxrig-develop' "$dd/bxrig-develop.directory" && grep -qx 'Icon=bxrig-system' "$dd/bxrig-system.directory" && grep -qx 'Icon=bxrig-look' "$dd/bxrig-look.directory" || fail 'folder icons'
grep -qx 'Icon=bxrig' "$dd/bxrig.directory" || fail 'the BxRig folder keeps the laptop'
# every icon name a launcher uses exists in the theme
for n in $(grep -h '^Icon=bxrig-' "$apps"/bxrig-*.desktop "$dd"/*.directory | cut -d= -f2 | sort -u); do
	[[ -f "$theme/scalable/apps/$n.svg" || -f "$theme/scalable/categories/$n.svg" ]] || fail "launcher icon $n is not in the theme"
done

# papirus: Papirus-Dark alone, the launchers go back to the stock names, the theme files stay
: > "$LOG"
[[ "$(code "$binary" appearance icons papirus --yes)" == 0 ]] || fail 'papirus'
has "gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark" || fail 'gsettings papirus'
grep -qx 'gtk-icon-theme-name=Papirus-Dark' "$tmp/cfg/gtk-3.0/settings.ini" || fail 'gtk papirus'
grep -qx 'icon_theme=Papirus-Dark' "$tmp/cfg/qt6ct/qt6ct.conf" || fail 'qt papirus'
jq -e '.icon_theme == "Papirus-Dark"' "$tmp/cfg/bxrig/runner.json" >/dev/null || fail 'runner papirus'
jq -e '.icons.set == "papirus"' "$tmp/cfg/bxrig/appearance.json" >/dev/null || fail 'state papirus'
grep -qx 'Icon=bxrig' "$apps/bxrig-tui-boxlang.desktop" || fail 'page launcher back to the plain icon'
grep -qx 'Icon=system-run' "$apps/bxrig-wizard.desktop" && grep -qx 'Icon=applications-development' "$dd/bxrig-develop.directory" || fail 'stock names with papirus'
[[ -f "$theme/index.theme" ]] || fail 'papirus removed the BxRig theme files'
echo "icon set tests passed"
