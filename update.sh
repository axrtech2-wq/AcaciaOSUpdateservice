#!/bin/bash
# ===================================================================
# AcaciaOS 1.3.1
#  - makes sure Dash to Panel is installed (root part, runs in the update)
#  - re-applies the app-drawer layout once per user at login
# Paste at the VERY BOTTOM of update.sh (below the 1.3.0 block),
# delete the "set -e" line near the top of update.sh, set VERSION to 1.3.1
# ===================================================================
set +e

# ---------- 1. Install Dash to Panel if missing (root) ----------
D2P=dash-to-panel@jderose9.github.com
ED=/usr/share/gnome-shell/extensions/$D2P
if [ ! -d "$ED" ]; then
  apt-get install -y gnome-shell-extension-dash-to-panel unzip curl >/dev/null 2>&1
fi
if [ ! -d "$ED" ]; then
  GV=$(gnome-shell --version 2>/dev/null | grep -o '[0-9]\+' | head -1)
  URL=$(curl -fsSL "https://extensions.gnome.org/extension-info/?pk=1160&shell_version=$GV" 2>/dev/null \
    | python3 -c 'import sys,json;print(json.load(sys.stdin)["download_url"])' 2>/dev/null)
  if [ -n "$URL" ]; then
    curl -fsSL "https://extensions.gnome.org$URL" -o /tmp/d2p.zip \
      && mkdir -p "$ED" && unzip -oq /tmp/d2p.zip -d "$ED"
  fi
fi
[ -d "$ED/schemas" ] && [ ! -f "$ED/schemas/gschemas.compiled" ] && glib-compile-schemas "$ED/schemas"
[ -d "$ED" ] || echo "WARNING: Dash to Panel could not be installed for this GNOME version."

# ---------- 2. Per-user layout (runs once per user at login) ----------
cat > /tmp/acacia-layout-setup <<'LAYOUTEOF'
#!/bin/bash
M="$HOME/.config/acacia-layout-1.3.1"
[ -f "$M" ] && exit 0
D2P=dash-to-panel@jderose9.github.com
ED=/usr/share/gnome-shell/extensions/$D2P
[ -d "$ED" ] || exit 0
sleep 8

gnome-extensions disable ubuntu-dock@ubuntu.com 2>/dev/null
gnome-extensions disable arcmenu@arcmenu.com 2>/dev/null
gnome-extensions enable $D2P 2>/dev/null
sleep 3

G() { gsettings --schemadir "$ED/schemas" "$@" 2>/dev/null; }
P=org.gnome.shell.extensions.dash-to-panel
ICON=/usr/share/pixmaps/acacia-drawer.png
[ -f "$ICON" ] || ICON=/usr/share/pixmaps/acaciaos-logo.png

OUT=$(G get $P panel-positions | python3 -c '
import sys, json, ast
ids = ["0"]
try:
    ids = list(json.loads(ast.literal_eval(sys.stdin.read().strip())).keys()) or ["0"]
except Exception:
    pass
el = [
 {"element": "showAppsButton",   "visible": True,  "position": "stackedTL"},
 {"element": "activitiesButton", "visible": False, "position": "stackedTL"},
 {"element": "leftBox",          "visible": True,  "position": "stackedTL"},
 {"element": "taskbar",          "visible": True,  "position": "stackedBR"},
 {"element": "centerBox",        "visible": True,  "position": "stackedBR"},
 {"element": "rightBox",         "visible": True,  "position": "stackedBR"},
 {"element": "dateMenu",         "visible": True,  "position": "stackedBR"},
 {"element": "systemMenu",       "visible": True,  "position": "stackedBR"},
 {"element": "desktopButton",    "visible": False, "position": "stackedBR"}
]
print(json.dumps({i: "TOP" for i in ids}))
print(json.dumps({i: 38 for i in ids}))
print(json.dumps({i: el for i in ids}))
')
G set $P panel-positions "'$(echo "$OUT" | sed -n 1p)'"
G set $P panel-sizes "'$(echo "$OUT" | sed -n 2p)'"
G set $P panel-element-positions "'$(echo "$OUT" | sed -n 3p)'"
G set $P show-apps-icon-file "'$ICON'"
G set $P show-favorites true
G set $P group-apps true
G set $P appicon-margin 4
G set $P trans-use-custom-bg true
G set $P trans-bg-color "'#2d2d2d'"

mkdir -p "$HOME/.config"; touch "$M"
LAYOUTEOF
chmod 755 /tmp/acacia-layout-setup
mv /tmp/acacia-layout-setup /usr/local/bin/acacia-layout-setup

cat > /etc/xdg/autostart/acacia-layout.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Acacia Layout Setup
Exec=/usr/local/bin/acacia-layout-setup
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

echo "AcaciaOS 1.3.1 applied. Log out and back in."
# ===================== end of 1.3.1 =====================

# ===================================================================
# AcaciaOS 1.2.0
#  - hidden updater with a percentage window (no terminal)
#  - Acacia logo in Settings -> About
#  - removes the default Ubuntu wallpapers and logos
# Paste this at the VERY BOTTOM of update.sh, then set VERSION to 1.2.0
# ===================================================================


# ---------- 1. Hidden updater with percentage ----------
# (written to a temp file, then moved, so a running updater is never edited in place)

cat > /tmp/acacia-update-apply <<'APPLYEOF'
#!/bin/bash
# Prints only percentages and "# text" lines so the progress window can read them.
REPO="https://github.com/axrtech2-wq/AcaciaOSUpdateservice"
D=/var/lib/acacia/repo
LOG=/var/lib/acacia/update.log
mkdir -p /var/lib/acacia
: > "$LOG"

step() { echo "$1"; echo "# $2"; }
fail() { echo "# Update failed"; echo 100; exit 1; }

step 5 "Contacting the update server..."
if [ -d "$D/.git" ]; then
  git -C "$D" fetch --depth 1 origin >>"$LOG" 2>&1 \
    && git -C "$D" reset --hard FETCH_HEAD >>"$LOG" 2>&1 || fail
else
  rm -rf "$D"
  git clone --depth 1 "$REPO" "$D" >>"$LOG" 2>&1 || fail
fi

step 30 "Installing AcaciaOS update..."
if [ -f "$D/update.sh" ]; then
  bash "$D/update.sh" >>"$LOG" 2>&1 &
  PID=$!
  pct=30
  while kill -0 "$PID" 2>/dev/null; do
    [ "$pct" -lt 88 ] && pct=$((pct + 1))
    echo "$pct"
    sleep 2
  done
  wait "$PID" || fail
fi

step 92 "Finishing up..."
[ -f "$D/VERSION" ] && cp "$D/VERSION" /etc/acacia-version
step 100 "Update complete"
exit 0
APPLYEOF
chmod 755 /tmp/acacia-update-apply
mv /tmp/acacia-update-apply /usr/local/bin/acacia-update-apply

cat > /tmp/acacia-updates <<'GUIEOF'
#!/bin/bash
RAW="https://raw.githubusercontent.com/axrtech2-wq/AcaciaOSUpdateservice/HEAD"
T="AcaciaUpdates"

zenity --question --title="$T" --width=320 --text="Check for AcaciaOS updates?" --ok-label="Check" --cancel-label="Cancel" || exit 0

LOCAL=$(cat /etc/acacia-version 2>/dev/null || echo 0)
REMOTE=$(curl -fsSL --max-time 20 "$RAW/VERSION" 2>/dev/null | tr -d '[:space:]')
if [ -z "$REMOTE" ]; then
  zenity --error --title="$T" --width=320 --text="Could not reach the update server. Check your internet connection."
  exit 1
fi
if [ "$(printf '%s\n%s\n' "$LOCAL" "$REMOTE" | sort -V | tail -1)" = "$LOCAL" ]; then
  zenity --info --title="$T" --width=320 --text="AcaciaOS is up to date (version $LOCAL)."
  exit 0
fi
zenity --question --title="$T" --width=340 --text="Update available: $LOCAL -> $REMOTE\n\nInstall it now?" --ok-label="Install" --cancel-label="Later" || exit 0

( pkexec /usr/local/bin/acacia-update-apply 2>/dev/null; rc=$?; [ "$rc" -ne 0 ] && echo 100; exit "$rc" ) \
  | zenity --progress --title="$T" --text="Starting update..." --percentage=0 --auto-close --no-cancel --width=380
RC=${PIPESTATUS[0]}

if [ "$RC" -eq 0 ]; then
  NEW=$(cat /etc/acacia-version 2>/dev/null)
  zenity --question --title="$T" --width=340 --text="AcaciaOS is now version $NEW.\n\nRestart now to finish?" --ok-label="Restart now" --cancel-label="Later" && systemctl reboot
elif [ "$RC" -eq 126 ] || [ "$RC" -eq 127 ]; then
  zenity --info --title="$T" --width=320 --text="Update cancelled."
else
  zenity --error --title="$T" --width=340 --text="The update did not finish.\n\nDetails are saved in /var/lib/acacia/update.log"
fi
GUIEOF
chmod 755 /tmp/acacia-updates
mv /tmp/acacia-updates /usr/local/bin/acacia-updates

# ---------- 2. Replace Ubuntu logos (About page, menus, boot) ----------
command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1 || apt-get install -y imagemagick >/dev/null 2>&1
IM=$(command -v magick || command -v convert)
IDENT=identify
[ "$(basename "$IM")" = magick ] && IDENT="magick identify"

LOGOW=/usr/share/pixmaps/acaciaos-logo.png                 # white-window logo (logow.png)
LOGOB=/usr/share/plymouth/themes/acacia/logo.png           # boot splash logo (logob.png)

swap_logo() {   # $1 = file to overwrite, $2 = Acacia png to use
  f="$1"; src="$2"
  case "$f" in
    *.png)
      d=$($IDENT -format '%wx%h' "${f}[0]" 2>/dev/null) || return 0
      $IM "$src" -background none -resize "$d" -gravity center -extent "$d" "$f" 2>/dev/null
      ;;
    *.svg|*.svgz)
      B64=$(base64 -w0 "$src")
      tmp=$(mktemp)
      printf '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="256" height="256" viewBox="0 0 256 256"><image width="256" height="256" href="data:image/png;base64,%s" xlink:href="data:image/png;base64,%s"/></svg>\n' "$B64" "$B64" > "$tmp"
      if [ "${f##*.}" = svgz ]; then gzip -c "$tmp" > "$f"; else cat "$tmp" > "$f"; fi
      rm -f "$tmp"
      ;;
  esac
}

if [ -f "$LOGOW" ]; then
  # Make sure os-release points at the Acacia logo
  grep -q '^LOGO=acaciaos-logo' /usr/lib/os-release || {
    sed -i '/^LOGO=/d' /usr/lib/os-release
    echo 'LOGO=acaciaos-logo' >> /usr/lib/os-release
  }

  # Every Ubuntu / distributor / start-here logo in the icon themes and pixmaps
  find /usr/share/icons /usr/share/pixmaps -not -path '/usr/share/icons/AcaciaOS/*' \
    \( -type f -o -type l \) \
    \( -iname 'ubuntu-logo*' -o -iname 'distributor-logo*' -o -iname 'start-here*' \) \
    -print0 | while IFS= read -r -d '' f; do swap_logo "$f" "$LOGOW"; done

  # Make the Acacia icon theme provide every name the About page may ask for
  for n in distributor-logo distributor-logo-icon distributor-logo-text distributor-logo-text-dark ubuntu-logo-icon ubuntu-logo; do
    cp "$LOGOW" "/usr/share/icons/AcaciaOS/256x256/apps/$n.png" 2>/dev/null
  done
fi

# Boot splash: replace Ubuntu logos with the black-background Acacia logo
if [ -f "$LOGOB" ]; then
  find /usr/share/plymouth -not -path '/usr/share/plymouth/themes/acacia/*' \
    \( -type f -o -type l \) \
    \( -iname '*ubuntu*.png' -o -iname 'watermark.png' -o -iname 'bgrt-fallback.png' \) \
    -print0 | while IFS= read -r -d '' f; do swap_logo "$f" "$LOGOB"; done
fi

# Rebuild icon caches
for d in /usr/share/icons/*/; do
  [ -f "${d}index.theme" ] && gtk-update-icon-cache -f -t "$d" >/dev/null 2>&1
done
update-initramfs -u >/dev/null 2>&1

# ---------- 3. Remove the default Ubuntu wallpapers ----------
# Only runs if the Acacia wallpapers are really installed, so you can never end up with none.
if [ -f /usr/share/backgrounds/acacia/background1.png ]; then
  find /usr/share/backgrounds -mindepth 1 -maxdepth 1 ! -name acacia -exec rm -rf {} + 2>/dev/null
  find /usr/share/gnome-background-properties -type f ! -name acacia.xml -delete 2>/dev/null
fi

# If a user's chosen wallpaper no longer exists, switch them to Acacia at login
cat > /usr/local/bin/acacia-wallpaper-fix <<'FIXEOF'
#!/bin/bash
B=/usr/share/backgrounds/acacia/background1.png
for k in picture-uri picture-uri-dark; do
  cur=$(gsettings get org.gnome.desktop.background "$k" 2>/dev/null | sed "s/^'file:\/\///;s/'\$//")
  cur=$(printf '%b' "${cur//%/\\x}")
  [ -f "$cur" ] || gsettings set org.gnome.desktop.background "$k" "file://$B"
done
FIXEOF
chmod 755 /usr/local/bin/acacia-wallpaper-fix
cat > /etc/xdg/autostart/acacia-wallpaper-fix.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Acacia Wallpaper Fix
Exec=/usr/local/bin/acacia-wallpaper-fix
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

echo "AcaciaOS 1.2.0 applied. Log out and back in to see the new logo and wallpapers."
# ===================== end of 1.2.0 =====================

# ===== AcaciaOS: block Ubuntu updates and release upgrades =====
# Stop automatic apt activity
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer unattended-upgrades 2>/dev/null || true
systemctl mask apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
rm -f /etc/apt/apt.conf.d/51acacia-unattended

# Never offer a new Ubuntu release
[ -f /etc/update-manager/release-upgrades ] && sed -i 's/^Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades

# Make do-release-upgrade refuse to run (divert only once)
if ! dpkg-divert --list /usr/bin/do-release-upgrade | grep -q 'do-release-upgrade.real'; then
  dpkg-divert --add --rename --divert /usr/bin/do-release-upgrade.real /usr/bin/do-release-upgrade 2>/dev/null || true
fi
cat > /usr/bin/do-release-upgrade <<'EOF'
#!/bin/sh
echo "AcaciaOS: release upgrades are disabled. Updates come from AcaciaUpdates only."
exit 1
EOF
chmod 755 /usr/bin/do-release-upgrade
apt-mark hold ubuntu-release-upgrader-core ubuntu-release-upgrader-gtk update-manager-core 2>/dev/null || true

# Hide update pop-ups and background downloads
for f in update-notifier org.gnome.Software; do
  A=/etc/xdg/autostart/$f.desktop
  [ -f "$A" ] && ! grep -q '^Hidden=true' "$A" && echo 'Hidden=true' >> "$A"
done
if gsettings list-schemas 2>/dev/null | grep -qx org.gnome.software; then
  printf '[org.gnome.software]\ndownload-updates=false\ndownload-updates-notify=false\n' > /usr/share/glib-2.0/schemas/91_acacia_noupdates.gschema.override
  glib-compile-schemas /usr/share/glib-2.0/schemas || true
fi

# Pause Snap auto-refresh
snap refresh --hold 2>/dev/null || true

# Keep the updater itself free of "apt upgrade" (written to a temp file, then moved)
cat > /tmp/acacia-update-apply <<'EOF'
#!/bin/bash
set -e
REPO="https://github.com/axrtech2-wq/AcaciaOSUpdateservice"
D=/var/lib/acacia/repo
mkdir -p /var/lib/acacia
echo "== Downloading AcaciaOS update =="
if [ -d "$D/.git" ]; then
  git -C "$D" fetch --depth 1 origin
  git -C "$D" reset --hard FETCH_HEAD
else
  rm -rf "$D"; git clone --depth 1 "$REPO" "$D"
fi
echo "== Applying AcaciaOS files =="
[ -f "$D/update.sh" ] && bash "$D/update.sh"
[ -f "$D/VERSION" ] && cp "$D/VERSION" /etc/acacia-version
echo "== Done. Version: $(cat /etc/acacia-version). A reboot is recommended. =="
EOF
chmod 755 /tmp/acacia-update-apply
mv /tmp/acacia-update-apply /usr/local/bin/acacia-update-apply
# ===== end of AcaciaOS update lock =====

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
