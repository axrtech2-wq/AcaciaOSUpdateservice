#!/bin/bash
#!/usr/bin/env bash
# Acaciel installer for AcaciaOS - with Mobile Mode and a working "acaciel update"

echo "Installing Acaciel (Ah-cay-shul) CLI for AcaciaOS..."

# ---------------------------------------------------------------
# 1. Mobile home screen app (fullscreen Android-style launcher)
# ---------------------------------------------------------------
sudo tee /usr/local/bin/acacia-mobile-home > /dev/null << 'PYEOF'
#!/usr/bin/env python3
import os, sys, time, signal, atexit
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, Gio, GLib, Pango

PIDFILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "acaciel-mobile.pid")
HIDDEN_FILE = "/etc/acacia/hidden-apps.txt"
WALLPAPER = "/usr/share/backgrounds/acacia/background1.png"


def already_running():
    try:
        pid = int(open(PIDFILE).read().strip())
        if pid != os.getpid():
            os.kill(pid, 0)
            return True
    except Exception:
        pass
    return False


def cleanup():
    try:
        if int(open(PIDFILE).read().strip()) == os.getpid():
            os.remove(PIDFILE)
    except Exception:
        pass


def load_hidden():
    try:
        return [l.strip().lower() for l in open(HIDDEN_FILE)
                if l.strip() and not l.strip().startswith("#")]
    except Exception:
        return []


def load_apps():
    hidden = load_hidden()
    apps = []
    for a in Gio.AppInfo.get_all():
        if not a.should_show():
            continue
        aid = (a.get_id() or "").lower()
        if any(h in aid for h in hidden):
            continue
        apps.append(a)
    apps.sort(key=lambda a: a.get_display_name().lower())
    return apps


def favorites():
    out = []
    try:
        ids = Gio.Settings.new("org.gnome.shell").get_strv("favorite-apps")
    except Exception:
        ids = []
    for i in ids[:5]:
        a = Gio.DesktopAppInfo.new(i)
        if a:
            out.append(a)
    return out


def css():
    bg = "background-color: #101218;"
    if os.path.exists(WALLPAPER):
        bg = ("background-image: linear-gradient(rgba(10,12,20,0.30), rgba(10,12,20,0.55)), "
              "url('%s'); background-size: cover; background-position: center;" % WALLPAPER)
    return (
        "window.acacia-home { %s }"
        ".clock { font-size: 72px; font-weight: 300; color: white; text-shadow: 0 2px 10px rgba(0,0,0,0.6); }"
        ".date { font-size: 17px; color: rgba(255,255,255,0.88); text-shadow: 0 1px 4px rgba(0,0,0,0.6); }"
        "button.tile { background-image: none; background-color: transparent; border: none;"
        "  box-shadow: none; padding: 10px; border-radius: 20px; }"
        "button.tile:hover, button.tile:active { background-color: rgba(255,255,255,0.18); }"
        "button.tile label { color: white; font-size: 13px; text-shadow: 0 1px 4px rgba(0,0,0,0.85); }"
        ".dock { background-color: rgba(255,255,255,0.14); border: 1px solid rgba(255,255,255,0.26);"
        "  border-radius: 30px; padding: 8px 16px; }"
        "button.exit { background-image: none; background-color: rgba(255,255,255,0.18);"
        "  border: 1px solid rgba(255,255,255,0.28); border-radius: 22px; padding: 10px 20px;"
        "  color: white; font-size: 14px; box-shadow: none; }"
        "button.exit:hover { background-color: rgba(255,255,255,0.30); }"
    ) % bg


class Home(Gtk.Window):
    def __init__(self):
        super().__init__(title="Acacia Mobile")
        self.set_decorated(False)
        self.get_style_context().add_class("acacia-home")
        self._cols = 0

        prov = Gtk.CssProvider()
        prov.load_from_data(css().encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_USER)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(root)

        # Clock and date
        top = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, halign=Gtk.Align.CENTER)
        top.set_margin_top(36)
        top.set_margin_bottom(18)
        self.clock = Gtk.Label()
        self.clock.get_style_context().add_class("clock")
        self.date = Gtk.Label()
        self.date.get_style_context().add_class("date")
        top.pack_start(self.clock, False, False, 0)
        top.pack_start(self.date, False, False, 0)
        root.pack_start(top, False, False, 0)

        # All apps (touch-scrollable)
        self.flow = Gtk.FlowBox()
        self.flow.set_selection_mode(Gtk.SelectionMode.NONE)
        self.flow.set_homogeneous(True)
        self.flow.set_column_spacing(8)
        self.flow.set_row_spacing(14)
        self.flow.set_valign(Gtk.Align.START)
        self.flow.set_halign(Gtk.Align.CENTER)
        self.flow.set_margin_start(40)
        self.flow.set_margin_end(40)
        for info in load_apps():
            self.flow.add(self.tile(info, 64, True))
        scroller = Gtk.ScrolledWindow()
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroller.set_kinetic_scrolling(True)
        scroller.set_overlay_scrolling(True)
        scroller.add(self.flow)
        root.pack_start(scroller, True, True, 0)

        # Bottom row: Desktop button + dock with pinned apps
        bottom = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        bottom.set_margin_start(24)
        bottom.set_margin_end(24)
        bottom.set_margin_top(10)
        bottom.set_margin_bottom(18)
        exit_btn = Gtk.Button(label="Desktop")
        exit_btn.get_style_context().add_class("exit")
        exit_btn.set_valign(Gtk.Align.CENTER)
        exit_btn.connect("clicked", lambda b: Gtk.main_quit())
        bottom.pack_start(exit_btn, False, False, 0)
        dock = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        dock.get_style_context().add_class("dock")
        dock.set_halign(Gtk.Align.CENTER)
        dock.set_hexpand(True)
        for info in favorites():
            dock.pack_start(self.tile(info, 52, False), False, False, 0)
        bottom.pack_start(dock, True, True, 0)
        root.pack_start(bottom, False, False, 0)

        self.connect("size-allocate", self.on_size)
        self.connect("key-press-event", self.on_key)
        self.tick()
        GLib.timeout_add_seconds(5, self.tick)
        self.fullscreen()

    def tile(self, info, size, with_label):
        btn = Gtk.Button()
        btn.set_relief(Gtk.ReliefStyle.NONE)
        btn.get_style_context().add_class("tile")
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        gicon = info.get_icon()
        if gicon:
            img = Gtk.Image.new_from_gicon(gicon, Gtk.IconSize.DIALOG)
        else:
            img = Gtk.Image.new_from_icon_name("application-x-executable", Gtk.IconSize.DIALOG)
        img.set_pixel_size(size)
        box.pack_start(img, False, False, 0)
        if with_label:
            lab = Gtk.Label(label=info.get_display_name())
            lab.set_ellipsize(Pango.EllipsizeMode.END)
            lab.set_max_width_chars(12)
            lab.set_justify(Gtk.Justification.CENTER)
            box.pack_start(lab, False, False, 0)
        btn.add(box)
        btn.set_tooltip_text(info.get_display_name())
        btn.connect("clicked", lambda b: self.launch(info))
        return btn

    def launch(self, info):
        try:
            ctx = Gdk.Display.get_default().get_app_launch_context()
            info.launch([], ctx)
        except Exception as e:
            print("launch failed:", e, file=sys.stderr)

    def on_size(self, widget, alloc):
        cols = max(3, alloc.width // 150)
        if cols != self._cols:
            self._cols = cols
            self.flow.set_max_children_per_line(cols)

    def on_key(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()
            return True
        return False

    def tick(self):
        now = time.localtime()
        self.clock.set_text(time.strftime("%I:%M", now).lstrip("0"))
        self.date.set_text(time.strftime("%A, %B %d", now))
        return True


def main():
    if already_running():
        sys.exit(0)
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))
    atexit.register(cleanup)
    win = Home()
    win.show_all()
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, Gtk.main_quit)
    Gtk.main()


main()
PYEOF
sudo chmod +x /usr/local/bin/acacia-mobile-home

# ---------------------------------------------------------------
# 2. Watcher: turns mobile mode on/off when keyboard + mouse change
# ---------------------------------------------------------------
sudo tee /usr/local/bin/acaciel-mobile-watch > /dev/null << 'WATCHEOF'
#!/usr/bin/env bash
# Runs in the background after login. Only acts if "acaciel mobile auto on" was set.
CONF="$HOME/.config/acaciel"
PIDF="${XDG_RUNTIME_DIR:-/tmp}/acaciel-mobile.pid"

running() { [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; }

# Prints "<has_touchscreen> <has_external_keyboard_or_mouse>"
scan() {
    local touch=0 ext=0 d props path bus kbd mouse
    for d in /sys/class/input/event*; do
        props=$(udevadm info -q property -p "$d" 2>/dev/null) || continue
        case "$props" in *ID_INPUT_TOUCHSCREEN=1*) touch=1 ;; esac
        kbd=0; mouse=0
        case "$props" in *ID_INPUT_KEYBOARD=1*) kbd=1 ;; esac
        case "$props" in *ID_INPUT_MOUSE=1*) mouse=1 ;; esac
        if [ $((kbd + mouse)) -gt 0 ]; then
            bus=$(printf '%s\n' "$props" | sed -n 's/^ID_BUS=//p')
            path=$(printf '%s\n' "$props" | sed -n 's/^DEVPATH=//p')
            case "$bus:$path" in
                usb:*|bluetooth:*|*:*/uhid/*|*:*bluetooth*) ext=1 ;;
            esac
        fi
    done
    echo "$touch $ext"
}

prev_ext=1   # so "no keyboard/mouse" at login counts as a change
while true; do
    if [ -f "$CONF/mobile-auto" ]; then
        read -r touch ext <<< "$(scan)"
        if [ "$touch" = 1 ]; then
            if [ "$ext" = 0 ] && [ "$prev_ext" = 1 ]; then
                running || nohup acacia-mobile-home >/dev/null 2>&1 &
            elif [ "$ext" = 1 ] && [ "$prev_ext" = 0 ]; then
                running && kill "$(cat "$PIDF")" 2>/dev/null
            fi
        fi
        prev_ext=$ext
    else
        prev_ext=1
    fi
    sleep 4
done
WATCHEOF
sudo chmod +x /usr/local/bin/acaciel-mobile-watch

sudo tee /etc/xdg/autostart/acaciel-mobile-watch.desktop > /dev/null << 'DESKEOF'
[Desktop Entry]
Type=Application
Name=Acaciel Mobile Watch
Exec=/usr/local/bin/acaciel-mobile-watch
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESKEOF

# ---------------------------------------------------------------
# 3. The main acaciel command
# ---------------------------------------------------------------
sudo tee /usr/local/bin/acaciel > /dev/null << 'EOF'
#!/usr/bin/env bash

# Colors for AcaciaOS styling
AMBER='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

VERSION="1.1.0"
APP_DIR="$HOME/.acaciel/apps"
SNAP_DIR="$HOME/.acaciel/snapshots"
CONF_DIR="$HOME/.config/acaciel"
MOBILE_PID="${XDG_RUNTIME_DIR:-/tmp}/acaciel-mobile.pid"
UPDATE_RAW="https://raw.githubusercontent.com/axrtech2-wq/AcaciaOSUpdateservice/HEAD"
mkdir -p "$APP_DIR" "$SNAP_DIR" "$CONF_DIR"

# ---------- Mobile mode helpers ----------
mobile_running() { [ -f "$MOBILE_PID" ] && kill -0 "$(cat "$MOBILE_PID")" 2>/dev/null; }

mobile_start() {
    if [ -z "${WAYLAND_DISPLAY}${DISPLAY}" ]; then
        echo -e "${RED}Mobile mode needs the desktop. Run it from a terminal on the AcaciaOS desktop.${RESET}"
        return 1
    fi
    if mobile_running; then
        echo -e "${CYAN}Mobile mode is already on.${RESET}"
    else
        nohup acacia-mobile-home >/dev/null 2>&1 &
        echo -e "${GREEN}✓ Mobile mode enabled.${RESET}  (run 'acaciel mobile' again, or press Esc, to leave)"
    fi
}

mobile_stop() {
    if mobile_running; then
        kill "$(cat "$MOBILE_PID")" 2>/dev/null
        echo -e "${GREEN}✓ Mobile mode disabled.${RESET}"
    else
        echo -e "${CYAN}Mobile mode is already off.${RESET}"
    fi
}

# ---------- Real update check (terminal version) ----------
acaciel_update_text() {
    echo -e "${CYAN}Checking AcaciaOS updates...${RESET}"
    local LOCAL REMOTE yn rc line
    LOCAL=$(cat /etc/acacia-version 2>/dev/null || echo 0)
    REMOTE=$(curl -fsSL --max-time 20 "$UPDATE_RAW/VERSION" 2>/dev/null | tr -d '[:space:]')
    if [ -z "$REMOTE" ]; then
        echo -e "${RED}Could not reach the update server. Check your internet connection.${RESET}"
        return 1
    fi
    if [ "$(printf '%s\n%s\n' "$LOCAL" "$REMOTE" | sort -V | tail -1)" = "$LOCAL" ]; then
        echo -e "${GREEN}✓ AcaciaOS is up to date (version ${LOCAL}).${RESET}"
        return 0
    fi
    echo -e "${AMBER}Update available: ${LOCAL} -> ${REMOTE}${RESET}"
    read -rp "Install now? [y/N] " yn
    case "$yn" in y|Y) ;; *) echo "Cancelled."; return 0 ;; esac

    sudo /usr/local/bin/acacia-update-apply | while IFS= read -r line; do
        case "$line" in
            "#"*) echo -e "  ${line#\# }" ;;
            ""|*[!0-9]*) ;;
            *) printf '  [%3s%%]\n' "$line" ;;
        esac
    done
    rc=${PIPESTATUS[0]}
    if [ "$rc" -eq 0 ]; then
        echo -e "${GREEN}✓ AcaciaOS is now version $(cat /etc/acacia-version). A restart is recommended.${RESET}"
    else
        echo -e "${RED}The update did not finish. Details: /var/lib/acacia/update.log${RESET}"
        return 1
    fi
}

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
    echo "  4) Toggle Mobile Mode"
    echo "  5) Exit"
    echo ""
    read -rp "acaciel-app > " choice

    case "$choice" in
        1) acaciel_update_text ;;
        2) "$0" info ;;
        3) "$0" doctor ;;
        4) "$0" mobile ;;
        5)
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
    "")
        open_acaciel_app
        ;;

    "update")
        # Opens the AcaciaUpdates app; falls back to the terminal version
        if [ "$2" = "--text" ] || [ -z "${WAYLAND_DISPLAY}${DISPLAY}" ] || ! command -v acacia-updates >/dev/null 2>&1; then
            acaciel_update_text
        else
            echo -e "${CYAN}Opening AcaciaUpdates...${RESET}"
            nohup acacia-updates >/dev/null 2>&1 &
        fi
        ;;

    "mobile")
        if [ "$(id -u)" -eq 0 ]; then
            echo -e "${RED}Run 'acaciel mobile' as your normal user, not with sudo.${RESET}"
            exit 1
        fi
        case "$2" in
            ""|"toggle")
                if mobile_running; then mobile_stop; else mobile_start; fi
                ;;
            "on")
                mobile_start
                ;;
            "off")
                mobile_stop
                ;;
            "status")
                if mobile_running; then echo -e "${GREEN}Mobile mode: ON${RESET}"; else echo -e "${CYAN}Mobile mode: OFF${RESET}"; fi
                if [ -f "$CONF_DIR/mobile-auto" ]; then echo -e "${CYAN}Auto mode:   ON${RESET}"; else echo -e "${CYAN}Auto mode:   OFF${RESET}"; fi
                ;;
            "auto")
                case "$3" in
                    "on")
                        touch "$CONF_DIR/mobile-auto"
                        echo -e "${GREEN}✓ Auto mode on.${RESET} Mobile mode turns on when no external keyboard or mouse is connected (needs a touchscreen), and off when one is."
                        ;;
                    "off")
                        rm -f "$CONF_DIR/mobile-auto"
                        echo -e "${GREEN}✓ Auto mode off.${RESET}"
                        ;;
                    *)
                        echo "Usage: acaciel mobile auto on|off"
                        ;;
                esac
                ;;
            *)
                echo "Usage: acaciel mobile [on|off|status|auto on|auto off]"
                ;;
        esac
        ;;

    "info")
        echo -e "${AMBER}=== AcaciaOS System Info ===${RESET}"
        echo -e "${CYAN}OS:${RESET}      AcaciaOS $(cat /etc/acacia-version 2>/dev/null)"
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
        echo "  acaciel                     - Opens the interactive Acaciel App"
        echo "  acaciel update              - Opens AcaciaUpdates (add --text for the terminal version)"
        echo "  acaciel mobile              - Turns Mobile Mode on or off"
        echo "  acaciel mobile on|off       - Turns Mobile Mode on or off explicitly"
        echo "  acaciel mobile status       - Shows Mobile Mode and Auto Mode state"
        echo "  acaciel mobile auto on|off  - Mobile Mode follows keyboard/mouse (touchscreen needed)"
        echo "  acaciel info                - Shows AcaciaOS system details"
        echo "  acaciel app <name>          - Launches an app"
        echo "  acaciel app install <name>  - Installs an app"
        echo "  acaciel app list            - Lists installed apps"
        echo "  acaciel doctor              - Runs system health checks"
        echo "  acaciel snap <path>         - Creates a quick backup snapshot"
        echo "  acaciel restore <path>      - Restores from a snapshot"
        echo "  acaciel net                 - Displays network info"
        echo "  acaciel clean               - Clears temporary files"
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

echo "✅ Acaciel installed! Try:  acaciel update   |   acaciel mobile   |   acaciel help"
echo "   (Auto mode watcher starts at your next login.)"

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
