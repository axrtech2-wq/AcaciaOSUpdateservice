#!/bin/bash
# AcaciaOS 1.1.0 - top bar layout
set -e
export DEBIAN_FRONTEND=noninteractive
cd "$(dirname "$0")"
[ -d files ] && cp -a files/. /

apt-get update -qq
apt-get install -y curl unzip python3 >/dev/null
apt-get install -y gnome-shell-extension-dash-to-panel gnome-shell-extension-arc-menu >/dev/null 2>&1 || true

# Fall back to extensions.gnome.org if apt doesn't have them for this GNOME version
GV=$(gnome-shell --version 2>/dev/null | grep -o '[0-9]\+' | head -1)
fetch_ext() {  # $1 = extension page id, $2 = uuid
  [ -d /usr/share/gnome-shell/extensions/$2 ] && return 0
  URL=$(curl -fsSL "https://extensions.gnome.org/extension-info/?pk=$1&shell_version=$GV" \
    | python3 -c 'import sys,json;print(json.load(sys.stdin)["download_url"])') || return 0
  curl -fsSL "https://extensions.gnome.org$URL" -o /tmp/ext.zip \
    && mkdir -p /usr/share/gnome-shell/extensions/$2 \
    && unzip -oq /tmp/ext.zip -d /usr/share/gnome-shell/extensions/$2 || true
}
fetch_ext 1160 dash-to-panel@jderose9.github.com
fetch_ext 3628 arcmenu@arcmenu.com

# Per-user layout script, runs once per user at next login
cat > /usr/local/bin/acacia-layout-setup <<'LAYOUT'
#!/bin/bash
M="$HOME/.config/acacia-layout-1.1.0"
[ -f "$M" ] && exit 0
D2P=dash-to-panel@jderose9.github.com
ARC=arcmenu@arcmenu.com
[ -d /usr/share/gnome-shell/extensions/$D2P ] || exit 0
sleep 8

gnome-extensions disable ubuntu-dock@ubuntu.com 2>/dev/null || true
gnome-extensions enable $D2P 2>/dev/null || true
gnome-extensions enable $ARC 2>/dev/null || true

# helper: use the extension's own schema folder if it is not system-installed
G() { local ext=$1; shift
  S=/usr/share/gnome-shell/extensions/$ext/schemas
  if [ -d "$S" ]; then gsettings --schemadir "$S" "$@" 2>/dev/null || gsettings "$@" 2>/dev/null || true
  else gsettings "$@" 2>/dev/null || true; fi; }

# ---- Dash to Panel: one top bar, apps centered, clock + quick settings right ----
P=org.gnome.shell.extensions.dash-to-panel
G $D2P set $P panel-positions '{"0":"TOP"}'
G $D2P set $P panel-sizes '{"0":38}'
G $D2P set $P panel-element-positions '{"0":[{"element":"showAppsButton","visible":false,"position":"stackedTL"},{"element":"activitiesButton","visible":false,"position":"stackedTL"},{"element":"leftBox","visible":true,"position":"stackedTL"},{"element":"taskbar","visible":true,"position":"centerMonitor"},{"element":"centerBox","visible":true,"position":"stackedBR"},{"element":"rightBox","visible":true,"position":"stackedBR"},{"element":"systemMenu","visible":true,"position":"stackedBR"},{"element":"dateMenu","visible":true,"position":"stackedBR"},{"element":"desktopButton","visible":false,"position":"stackedBR"}]}'
G $D2P set $P show-favorites true
G $D2P set $P group-apps true
G $D2P set $P appicon-margin 4
G $D2P set $P trans-use-custom-bg true
G $D2P set $P trans-bg-color '#2d2d2d'

# ---- ArcMenu: your logo as the launcher button on the left ----
A=org.gnome.shell.extensions.arcmenu
G $ARC set $A menu-button-appearance 'Icon'
G $ARC set $A menu-button-icon 'Custom_Icon'
G $ARC set $A custom-menu-button-icon '/usr/share/pixmaps/acaciaos-logo.png'
G $ARC set $A menu-button-icon-size 24

# ---- Pinned apps ----
gsettings set org.gnome.shell favorite-apps "['google-chrome.desktop','org.gnome.Nautilus.desktop','my-acacia.desktop','acacia-updates.desktop','org.gnome.Settings.desktop']" 2>/dev/null || true

mkdir -p "$HOME/.config"; touch "$M"
LAYOUT
chmod 755 /usr/local/bin/acacia-layout-setup

cat > /etc/xdg/autostart/acacia-layout.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Acacia Layout Setup
Exec=/usr/local/bin/acacia-layout-setup
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

echo "AcaciaOS layout installed. Log out and back in to see it."
