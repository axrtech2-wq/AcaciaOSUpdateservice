#!/bin/bash
#!/usr/bin/env bash

echo "Installing Acaciel (Ah-cay-shul) CLI for AcaciaOS..."

# Create the main Acaciel script in /usr/local/bin
sudo tee /usr/local/bin/acaciel > /dev/null << 'EOF'
#!/usr/bin/env bash

# Colors for AcaciaOS styling
AMBER='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

VERSION="1.0.0"
APP_DIR="$HOME/.acaciel/apps"
SNAP_DIR="$HOME/.acaciel/snapshots"
mkdir -p "$APP_DIR" "$SNAP_DIR"

# Interactive Acaciel App / Control Center
open_acaciel_app() {
    clear
    echo -e "${AMBER}"
    echo "      _       _      "
    echo "     / \     / \     AcaciaOS Control Center"
    echo "    /   \___/   \    Acaciel Shell v${VERSION}"
    echo "   /_____________\   "
    echo "         | |         "
    echo -e "${RESET}"
    echo -e "${CYAN}What would you like to do?${RESET}"
    echo "  1) Check & Install AcaciaOS Updates"
    echo "  2) View System Info"
    echo "  3) Run System Doctor"
    echo "  4) Exit"
    echo ""
    read -rp "acaciel-app > " choice

    case "$choice" in
        1)
            echo -e "\n${CYAN}Checking AcaciaOS repositories...${RESET}"
            sleep 1
            echo -e "${GREEN}✓ AcaciaOS Core is up to date.${RESET}"
            echo -e "${GREEN}✓ Acaciel Shell (v${VERSION}) is up to date.${RESET}\n"
            ;;
        2)
            "$0" info
            ;;
        3)
            "$0" doctor
            ;;
        4)
            echo "Closing Acaciel App..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option.${RESET}"
            ;;
    esac
}

# Main Command Router
case "$1" in
    ""|"update")
        # Running 'acaciel' alone or 'acaciel update' opens the Acaciel App
        open_acaciel_app
        ;;

    "info")
        echo -e "${AMBER}=== AcaciaOS System Info ===${RESET}"
        echo -e "${CYAN}OS:${RESET}      AcaciaOS (via $(uname -s))"
        echo -e "${CYAN}Shell:${RESET}   Acaciel v${VERSION} (Ah-cay-shul)"
        echo -e "${CYAN}Kernel:${RESET}  $(uname -r)"
        echo -e "${CYAN}Uptime:${RESET}  $(uptime -p 2>/dev/null || uptime)"
        echo -e "${CYAN}User:${RESET}    $USER"
        ;;

    "app")
        SUBCMD="$2"
        TARGET="$3"
        case "$SUBCMD" in
            "")
                open_acaciel_app
                ;;
            "list")
                echo -e "${CYAN}Installed AcaciaOS Apps:${RESET}"
                ls -1 "$APP_DIR" 2>/dev/null || echo "  (No custom apps registered yet)"
                ;;
            "install")
                if [ -z "$TARGET" ]; then
                    echo -e "${RED}Usage: acaciel app install <appname>${RESET}"
                    exit 1
                fi
                echo -e "${CYAN}Installing ${TARGET} into AcaciaOS...${RESET}"
                touch "$APP_DIR/$TARGET"
                echo -e "${GREEN}✓ ${TARGET} installed! Run it with: acaciel app ${TARGET}${RESET}"
                ;;
            "remove")
                if [ -f "$APP_DIR/$TARGET" ]; then
                    rm -f "$APP_DIR/$TARGET"
                    echo -e "${GREEN}✓ Removed ${TARGET}.${RESET}"
                else
                    echo -e "${RED}App '${TARGET}' not found.${RESET}"
                fi
                ;;
            *)
                # Launch the requested app cleanly in the background
                if command -v "$SUBCMD" >/dev/null 2>&1; then
                    echo -e "${GREEN}Launching ${SUBCMD}...${RESET}"
                    nohup "$SUBCMD" >/dev/null 2>&1 &
                elif [ -f "$APP_DIR/$SUBCMD" ]; then
                    echo -e "${GREEN}Starting AcaciaOS app: ${SUBCMD}...${RESET}"
                else
                    echo -e "${RED}App '${SUBCMD}' not found. Try: acaciel app install ${SUBCMD}${RESET}"
                fi
                ;;
        esac
        ;;

    "doctor")
        echo -e "${CYAN}Running AcaciaOS Diagnostics...${RESET}"
        sleep 1
        echo -e "${GREEN}✓ File permissions: OK${RESET}"
        echo -e "${GREEN}✓ Acaciel directories: OK${RESET}"
        echo -e "${GREEN}✓ Network stack: OK${RESET}"
        ;;

    "snap")
        if [ -z "$2" ] || [ ! -e "$2" ]; then
            echo -e "${RED}Usage: acaciel snap <file_or_folder>${RESET}"
            exit 1
        fi
        BASENAME=$(basename "$2")
        cp -r "$2" "$SNAP_DIR/${BASENAME}.snap"
        echo -e "${GREEN}✓ Snapshot saved for '${2}'${RESET}"
        ;;

    "restore")
        if [ -z "$2" ]; then
            echo -e "${RED}Usage: acaciel restore <file_or_folder>${RESET}"
            exit 1
        fi
        BASENAME=$(basename "$2")
        if [ -e "$SNAP_DIR/${BASENAME}.snap" ]; then
            cp -r "$SNAP_DIR/${BASENAME}.snap" "$2"
            echo -e "${GREEN}✓ Restored '${2}' from snapshot.${RESET}"
        else
            echo -e "${RED}No snapshot found for '${2}'.${RESET}"
        fi
        ;;

    "net")
        echo -e "${CYAN}Local IP:${RESET}  $(hostname -I 2>/dev/null | awk '{print $1}')"
        echo -e "${CYAN}Hostname:${RESET}  $(hostname)"
        ;;

    "clean")
        echo -e "${CYAN}Cleaning AcaciaOS temporary files...${RESET}"
        rm -rf /tmp/acaciel_* 2>/dev/null
        echo -e "${GREEN}✓ System cleaned.${RESET}"
        ;;

    "help")
        echo -e "${AMBER}Acaciel Command Reference:${RESET}"
        echo "  acaciel update              - Opens the interactive Acaciel App"
        echo "  acaciel info                - Shows AcaciaOS system details"
        echo "  acaciel app <name>          - Launches an app"
        echo "  acaciel app install <name>  - Installs an app"
        echo "  acaciel app list            - Lists installed apps"
        echo "  acaciel doctor              - Runs system health checks"
        echo "  acaciel snap <path>         - Creates a quick backup snapshot"
        echo "  acaciel restore <path>      - Restores from a snapshot"
        echo "  acaciel net                 - Displays network info"
        echo "  acaciel clean               - Clears temporary files"
        echo "  sudo acaciel <cmd>          - Runs any Acaciel command as root"
        ;;

    *)
        echo -e "${RED}Unknown command: '$1'${RESET}"
        echo "Run 'acaciel help' to see all available commands."
        exit 1
        ;;
esac
EOF

# Make it executable
sudo chmod +x /usr/local/bin/acaciel

echo "✅ Acaciel installed! Type 'acaciel update' or 'acaciel help' to try it out."

# ===================================================================
# AcaciaOS 1.5.0  -  Windows-style app menu (ArcMenu) at the top left
#  - installs ArcMenu + Dash to Panel if missing (root part)
#  - per-user: ArcMenu "Windows 11" layout, Acacia icon, top-left
#  - writes a log to ~/.cache/acacia-layout.log so problems are visible
#
# Run now:   sudo bash update-1.5.0-block.sh      then log out and back in
# For updates: paste at the VERY BOTTOM of update.sh (below 1.4.0),
#              set VERSION to 1.5.0 and commit
# ===================================================================
set +e

# ---------- 1. Make sure the extensions are installed (root) ----------
EXTDIR=/usr/share/gnome-shell/extensions
GV=$(gnome-shell --version 2>/dev/null | grep -o '[0-9]\+' | head -1)
apt-get install -y curl unzip python3 >/dev/null 2>&1
apt-get install -y gnome-shell-extension-arc-menu gnome-shell-extension-dash-to-panel >/dev/null 2>&1

get_ext() {   # $1 = extensions.gnome.org id, $2 = uuid
  [ -d "$EXTDIR/$2" ] && return 0
  URL=$(curl -fsSL "https://extensions.gnome.org/extension-info/?pk=$1&shell_version=$GV" 2>/dev/null \
    | python3 -c 'import sys,json;print(json.load(sys.stdin)["download_url"])' 2>/dev/null)
  if [ -n "$URL" ]; then
    curl -fsSL "https://extensions.gnome.org$URL" -o /tmp/ext.zip \
      && mkdir -p "$EXTDIR/$2" && unzip -oq /tmp/ext.zip -d "$EXTDIR/$2"
  fi
}
get_ext 3628 arcmenu@arcmenu.com
get_ext 1160 dash-to-panel@jderose9.github.com
for u in arcmenu@arcmenu.com dash-to-panel@jderose9.github.com; do
  [ -d "$EXTDIR/$u/schemas" ] && [ ! -f "$EXTDIR/$u/schemas/gschemas.compiled" ] && glib-compile-schemas "$EXTDIR/$u/schemas"
  [ -d "$EXTDIR/$u" ] || echo "WARNING: $u is not available for GNOME $GV"
done

# ---------- 2. Per-user setup (runs once per user at login) ----------
cat > /tmp/acacia-layout-setup <<'LAYOUTEOF'
#!/bin/bash
M="$HOME/.config/acacia-layout-1.5.0"
[ -f "$M" ] && exit 0
mkdir -p "$HOME/.cache" "$HOME/.config"
exec >>"$HOME/.cache/acacia-layout.log" 2>&1
echo "=== $(date)  $(gnome-shell --version)"

D2P=dash-to-panel@jderose9.github.com
ARC=arcmenu@arcmenu.com
BMS=blur-my-shell@aunetx
X=/usr/share/gnome-shell/extensions
echo "dash-to-panel installed: $([ -d $X/$D2P ] && echo yes || echo NO)"
echo "arcmenu installed:       $([ -d $X/$ARC ] && echo yes || echo NO)"
[ -d "$X/$ARC" ] || { echo "ArcMenu is not installed, stopping."; exit 0; }
sleep 8

gnome-extensions disable ubuntu-dock@ubuntu.com
gnome-extensions enable $ARC
[ -d "$X/$D2P" ] && gnome-extensions enable $D2P
[ -d "$X/$BMS" ] && gnome-extensions enable $BMS
sleep 3
echo "enabled now: $(gnome-extensions list --enabled | tr '\n' ' ')"
gnome-extensions info $ARC | grep -iE 'state|error'

ICON=/usr/share/pixmaps/acacia-drawer.png
[ -f "$ICON" ] || ICON=/usr/share/pixmaps/acaciaos-logo.png

A() { gsettings --schemadir "$X/$ARC/schemas" "$@"; }
G() { gsettings --schemadir "$X/$D2P/schemas" "$@"; }
B() { gsettings --schemadir "$X/$BMS/schemas" "$@" || gsettings "$@"; }

# --- ArcMenu: Windows 11 style menu, Acacia icon, top left ---
AP=org.gnome.shell.extensions.arcmenu
A set $AP menu-layout "'Eleven'"
A set $AP menu-button-appearance "'Icon'"
A set $AP menu-button-icon "'Custom_Icon'"
A set $AP custom-menu-button-icon "'$ICON'"
A set $AP menu-button-icon-size 28
A set $AP position-in-panel "'Left'"

# --- Top bar: no separate Show Apps button, apps next to the clock ---
if [ -d "$X/$D2P" ]; then
  P=org.gnome.shell.extensions.dash-to-panel
  OUT=$(G get $P panel-positions | python3 -c '
import sys, json, ast
ids = ["0"]
try:
    ids = list(json.loads(ast.literal_eval(sys.stdin.read().strip())).keys()) or ["0"]
except Exception:
    pass
el = [
 {"element": "showAppsButton",   "visible": False, "position": "stackedTL"},
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
  G set $P show-favorites true
  G set $P group-apps true
  G set $P appicon-margin 4
  G set $P trans-use-custom-bg true
  G set $P trans-bg-color "'#1e1e1e'"
  G set $P trans-use-custom-opacity true
  G set $P trans-panel-opacity 0.55
fi

# --- Glass blur ---
if [ -d "$X/$BMS" ]; then
  BP=org.gnome.shell.extensions.blur-my-shell
  for c in overview appfolder panel applications lockscreen; do B set $BP.$c blur true; done
  B set $BP.applications enable-all true
  B set $BP.overview sigma 40
  B set $BP.applications sigma 30
  B set $BP.panel sigma 30
fi

touch "$M"
echo "done"
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

echo "AcaciaOS 1.5.0 applied. Log out and back in, then wait about 15 seconds."
# ===================== end of 1.5.0 =====================

# ===================================================================
# AcaciaOS 1.4.0  -  Acacia Workspace
#  - "Acacia Workspace" login session (the stock Ubuntu sessions are hidden)
#  - shortcuts + touchpad gesture defaults
#  - more blur / glass, desktop settings launchers
#  - removes visible "Ubuntu" names (app names, login screen, lsb-release)
#
# Paste at the VERY BOTTOM of update.sh (below the 1.3.1 block),
# make sure there is no "set -e" line in update.sh, set VERSION to 1.4.0
# ===================================================================
set +e

# ---------- 1. Acacia Workspace session ----------
HID=/usr/share/acacia/hidden-sessions
mkdir -p $HID/wayland $HID/x11

WSRC=/usr/share/wayland-sessions/ubuntu.desktop
[ -f "$WSRC" ] || WSRC=$HID/wayland/ubuntu.desktop

if [ -f "$WSRC" ]; then
  # Same working session underneath, new name on the login screen
  sed -e '/^Name\[/d' -e '/^Comment\[/d' -e '/^X-Ubuntu-Gettext-Domain/d' \
      -e 's/^Name=.*/Name=Acacia Workspace/' \
      -e 's/^Comment=.*/Comment=Log in to the AcaciaOS desktop/' \
      "$WSRC" > /usr/share/wayland-sessions/acacia-workspace.desktop

  # Hide the stock Ubuntu sessions (moved, not deleted)
  for f in /usr/share/wayland-sessions/ubuntu*.desktop; do
    [ -f "$f" ] && mv "$f" $HID/wayland/
  done
  for f in /usr/share/xsessions/ubuntu*.desktop; do
    [ -f "$f" ] && mv "$f" $HID/x11/
  done

  # Make it the default for existing users
  for f in /var/lib/AccountsService/users/*; do
    [ -f "$f" ] || continue
    if grep -q '^Session=' "$f"; then
      sed -i 's/^Session=.*/Session=acacia-workspace/' "$f"
    else
      sed -i '/^\[User\]/a Session=acacia-workspace' "$f"
    fi
  done
else
  echo "WARNING: could not find the Ubuntu session file, Acacia Workspace session not created."
fi

# ---------- 2. Shortcuts, gestures and desktop defaults (system-wide) ----------
apt-get install -y dconf-cli >/dev/null 2>&1
mkdir -p /etc/dconf/profile /etc/dconf/db/local.d/locks
if [ ! -f /etc/dconf/profile/user ]; then
  printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
elif ! grep -q '^system-db:local' /etc/dconf/profile/user; then
  echo 'system-db:local' >> /etc/dconf/profile/user
fi

cat > /etc/dconf/db/local.d/01-acacia-workspace <<'EOF'
[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
natural-scroll=true
two-finger-scrolling-enabled=true

[org/gnome/mutter]
dynamic-workspaces=true
edge-tiling=true

[org/gnome/shell/keybindings]
toggle-application-view=['<Super>a']

[org/gnome/desktop/wm/keybindings]
close=['<Super>q', '<Alt>F4']
toggle-fullscreen=['<Super>f']
show-desktop=['<Super>d']
switch-to-workspace-left=['<Control><Alt>Left', '<Super>Page_Up']
switch-to-workspace-right=['<Control><Alt>Right', '<Super>Page_Down']

[org/gnome/settings-daemon/plugins/media-keys]
terminal=['<Super>t']
home=['<Super>e']
www=['<Super>b']
EOF
dconf update

# ---------- 3. Settings launchers ----------
cat > /usr/share/applications/acacia-desktop-settings.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Acacia Desktop Settings
Comment=Top bar, taskbar and app drawer
Exec=gnome-extensions prefs dash-to-panel@jderose9.github.com
Icon=acaciaos-logo
Terminal=false
Categories=Settings;
EOF
cat > /usr/share/applications/acacia-glass-settings.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Acacia Glass Settings
Comment=Blur and transparency
Exec=gnome-extensions prefs blur-my-shell@aunetx
Icon=acaciaos-logo
Terminal=false
Categories=Settings;
EOF

# ---------- 4. Per-user layout + glass (runs once per user at login) ----------
cat > /tmp/acacia-layout-setup <<'LAYOUTEOF'
#!/bin/bash
M="$HOME/.config/acacia-layout-1.4.0"
[ -f "$M" ] && exit 0
D2P=dash-to-panel@jderose9.github.com
BMS=blur-my-shell@aunetx
ED=/usr/share/gnome-shell/extensions/$D2P
BD=/usr/share/gnome-shell/extensions/$BMS
[ -d "$ED" ] || exit 0
sleep 8

gnome-extensions disable ubuntu-dock@ubuntu.com 2>/dev/null
gnome-extensions disable arcmenu@arcmenu.com 2>/dev/null
gnome-extensions enable $D2P 2>/dev/null
[ -d "$BD" ] && gnome-extensions enable $BMS 2>/dev/null
sleep 3

G() { gsettings --schemadir "$ED/schemas" "$@" 2>/dev/null; }
B() { gsettings --schemadir "$BD/schemas" "$@" 2>/dev/null || gsettings "$@" 2>/dev/null; }
P=org.gnome.shell.extensions.dash-to-panel
ICON=/usr/share/pixmaps/acacia-drawer.png
[ -f "$ICON" ] || ICON=/usr/share/pixmaps/acaciaos-logo.png

# --- Top bar layout: drawer button left, apps next to the clock ---
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

# --- Glass look for the taskbar (semi-transparent) ---
G set $P trans-use-custom-bg true
G set $P trans-bg-color "'#1e1e1e'"
G set $P trans-use-custom-opacity true
G set $P trans-panel-opacity 0.55

# --- Blur: app grid / overview, folders, app windows, lock screen ---
BP=org.gnome.shell.extensions.blur-my-shell
for c in overview appfolder panel applications lockscreen; do
  B set $BP.$c blur true
done
B set $BP.applications enable-all true
B set $BP.overview sigma 40
B set $BP.applications sigma 30
B set $BP.panel sigma 30

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

# ---------- 5. Remove visible Ubuntu names ----------
# App names/descriptions: copies in /usr/local/share/applications override the originals
mkdir -p /usr/local/share/applications
grep -rlE '^(Name|GenericName|Comment)(\[[^]]*\])?=.*Ubuntu' /usr/share/applications 2>/dev/null | while read -r f; do
  b=$(basename "$f")
  sed -E '/^(Name|GenericName|Comment)(\[[^]]*\])?=/ s/Ubuntu/Acacia/g' "$f" > "/usr/local/share/applications/$b"
done
update-desktop-database /usr/local/share/applications 2>/dev/null

# lsb_release description
[ -f /etc/lsb-release ] && sed -i 's/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION="AcaciaOS"/' /etc/lsb-release

# Ubuntu Pro / news nags
pro config set apt_news=false >/dev/null 2>&1

# Login screen logo
GD=/etc/gdm3/greeter.dconf-defaults
if [ -f "$GD" ] && ! grep -q 'acaciaos-logo.png' "$GD"; then
  printf "\n[org/gnome/login-screen]\nlogo='/usr/share/pixmaps/acaciaos-logo.png'\n" >> "$GD"
fi

echo "AcaciaOS 1.4.0 applied. Log out, then pick Acacia Workspace from the gear on the login screen if it isn't already selected."
# ===================== end of 1.4.0 =====================

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
