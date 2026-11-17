sudo bash <<'ACACIA'
set -e
export DEBIAN_FRONTEND=noninteractive

# --- find the AcaciaOS folder on the flash drive ---
LOGO=$(find /media /mnt /run/media /home -maxdepth 5 -name logow.png 2>/dev/null | head -1)
[ -z "$LOGO" ] && { echo "Could not find logow.png. Is the flash drive plugged in?"; exit 1; }
SRC=$(dirname "$LOGO"); echo "Using $SRC"
for f in logow.png logob.png backround1.png backround2.png backround3.png; do
  [ -f "$SRC/$f" ] || { echo "Missing $f in $SRC"; exit 1; }
done

# --- tools ---
apt-get update -qq
apt-get install -y imagemagick plymouth libglib2.0-bin gtk-update-icon-cache git curl zenity unzip python3-gi gir1.2-gtk-3.0 >/dev/null
IM=$(command -v magick || command -v convert)

# --- OS identity (diverted so Ubuntu updates don't overwrite it) ---
if ! dpkg-divert --list /usr/lib/os-release | grep -q acacia; then
  dpkg-divert --package acacia-branding --add --rename --divert /usr/lib/os-release.ubuntu /usr/lib/os-release
fi
sed -e '/^\(NAME\|PRETTY_NAME\|ID\|ID_LIKE\|HOME_URL\|SUPPORT_URL\|BUG_REPORT_URL\|PRIVACY_POLICY_URL\|LOGO\)=/d' /usr/lib/os-release.ubuntu > /usr/lib/os-release
printf 'NAME="AcaciaOS"\nPRETTY_NAME="AcaciaOS"\nID=acaciaos\nID_LIKE="ubuntu debian"\nLOGO=acaciaos-logo\n' >> /usr/lib/os-release
printf 'AcaciaOS \\n \\l\n\n' > /etc/issue
echo "AcaciaOS" > /etc/issue.net
chmod -x /etc/update-motd.d/10-help-text /etc/update-motd.d/50-motd-news 2>/dev/null || true
[ -f /etc/acacia-version ] || echo "1.0.0" > /etc/acacia-version

# --- wallpapers ---
B=/usr/share/backgrounds/acacia; mkdir -p $B
for i in 1 2 3; do cp "$SRC/backround$i.png" $B/background$i.png; done
{
echo '<?xml version="1.0"?><!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd"><wallpapers>'
for i in 1 2 3; do
echo "<wallpaper deleted=\"false\"><name>Acacia $i</name><filename>$B/background$i.png</filename><filename-dark>$B/background$i.png</filename-dark><options>zoom</options><shade_type>solid</shade_type><pcolor>#000000</pcolor><scolor>#000000</scolor></wallpaper>"
done
echo '</wallpapers>'
} > /usr/share/gnome-background-properties/acacia.xml

cat > /usr/share/glib-2.0/schemas/90_acacia.gschema.override <<EOF
[org.gnome.desktop.background]
picture-uri='file://$B/background1.png'
picture-uri-dark='file://$B/background1.png'

[org.gnome.desktop.screensaver]
picture-uri='file://$B/background1.png'

[org.gnome.desktop.interface]
icon-theme='AcaciaOS'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas

# --- icon theme + logos (logow = light windows, logob = dark windows) ---
T=/usr/share/icons/AcaciaOS; DIRS=""; IDX=""
for s in 16 24 32 48 64 128 256; do
  mkdir -p $T/${s}x${s}/apps $T/${s}x${s}/places /usr/share/icons/hicolor/${s}x${s}/apps
  for n in acaciaos-logo distributor-logo; do $IM "$SRC/logow.png" -resize ${s}x${s} $T/${s}x${s}/apps/$n.png; done
  $IM "$SRC/logow.png" -resize ${s}x${s} $T/${s}x${s}/places/start-here.png
  $IM "$SRC/logob.png" -resize ${s}x${s} $T/${s}x${s}/apps/acaciaos-logo-dark.png
  cp $T/${s}x${s}/apps/acaciaos-logo.png $T/${s}x${s}/apps/acaciaos-logo-dark.png /usr/share/icons/hicolor/${s}x${s}/apps/
  DIRS="$DIRS${s}x${s}/apps,${s}x${s}/places,"
  IDX="$IDX
[${s}x${s}/apps]
Size=$s
Context=Applications
Type=Fixed

[${s}x${s}/places]
Size=$s
Context=Places
Type=Fixed
"
done
printf '[Icon Theme]\nName=AcaciaOS\nComment=AcaciaOS icons\nInherits=Yaru,hicolor\nDirectories=%s\n%s' "${DIRS%,}" "$IDX" > $T/index.theme
$IM "$SRC/logow.png" -resize 256x256 /usr/share/pixmaps/acaciaos-logo.png
gtk-update-icon-cache -f $T || true
gtk-update-icon-cache -f /usr/share/icons/hicolor || true

# --- boot splash (logob.png on black) ---
P=/usr/share/plymouth/themes/acacia; mkdir -p $P
$IM "$SRC/logob.png" -resize 300x300 $P/logo.png
cat > $P/acacia.plymouth <<EOF
[Plymouth Theme]
Name=AcaciaOS
Description=AcaciaOS boot splash
ModuleName=script

[script]
ImageDir=$P
ScriptFile=$P/acacia.script
EOF
cat > $P/acacia.script <<'EOF'
Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetX(Window.GetX() + Window.GetWidth() / 2 - logo.image.GetWidth() / 2);
logo.sprite.SetY(Window.GetY() + Window.GetHeight() / 2 - logo.image.GetHeight() / 2);
EOF
update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth $P/acacia.plymouth 200
update-alternatives --set default.plymouth $P/acacia.plymouth

# --- GRUB name ---
sed -i 's|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR="AcaciaOS"|' /etc/default/grub
update-grub
update-initramfs -u

# =====================================================================
# NEW: My Acacia app (device info, RAM, tasks)
# =====================================================================
cat > /usr/local/bin/my-acacia <<'PYAPP'
#!/usr/bin/env python3
import gi, os, signal, shutil, platform, socket, subprocess
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, GdkPixbuf

LOGO = "/usr/share/pixmaps/acaciaos-logo.png"

def read(p, d=""):
    try:
        return open(p).read().strip()
    except Exception:
        return d

def osrel():
    r = {}
    for l in read("/usr/lib/os-release").splitlines():
        if "=" in l:
            k, v = l.split("=", 1)
            r[k] = v.strip('"')
    return r

def gb(kb):
    return "%.1f GB" % (kb / 1048576)

class App(Gtk.Window):
    def __init__(self):
        super().__init__(title="My Acacia")
        self.set_default_size(680, 580)
        if os.path.exists(LOGO):
            self.set_icon_from_file(LOGO)
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        root.set_border_width(16)
        self.add(root)

        head = Gtk.Box(spacing=14)
        root.pack_start(head, False, False, 0)
        if os.path.exists(LOGO):
            pb = GdkPixbuf.Pixbuf.new_from_file_at_size(LOGO, 72, 72)
            head.pack_start(Gtk.Image.new_from_pixbuf(pb), False, False, 0)
        title = Gtk.Label(xalign=0)
        title.set_markup("<span size='xx-large' weight='bold'>My Acacia</span>\n<span alpha='65%'>Your device at a glance</span>")
        head.pack_start(title, False, False, 0)

        nb = Gtk.Notebook()
        root.pack_start(nb, True, True, 0)

        # ---- Device tab ----
        dev = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        dev.set_border_width(14)
        grid = Gtk.Grid(column_spacing=20, row_spacing=8)
        dev.pack_start(grid, False, False, 0)
        self.v = {}
        for i, k in enumerate(["Device", "Name", "OS", "Version", "Kernel", "Processor", "Memory", "Storage", "Uptime"]):
            a = Gtk.Label(label=k, xalign=1)
            a.get_style_context().add_class("dim-label")
            b = Gtk.Label(label="", xalign=0, selectable=True)
            grid.attach(a, 0, i, 1, 1)
            grid.attach(b, 1, i, 1, 1)
            self.v[k] = b
        dev.pack_start(Gtk.Label(label="Memory in use", xalign=0), False, False, 0)
        self.ram_bar = Gtk.LevelBar(min_value=0, max_value=1)
        dev.pack_start(self.ram_bar, False, False, 0)
        dev.pack_start(Gtk.Label(label="Storage in use", xalign=0), False, False, 0)
        self.disk_bar = Gtk.LevelBar(min_value=0, max_value=1)
        dev.pack_start(self.disk_bar, False, False, 0)
        nb.append_page(dev, Gtk.Label(label="Device"))

        # ---- Tasks tab ----
        tk = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        tk.set_border_width(10)
        self.store = Gtk.ListStore(int, str, float, float)
        self.tree = Gtk.TreeView(model=self.store)
        for i, name in enumerate(["PID", "Task", "CPU %", "Memory (MB)"]):
            r = Gtk.CellRendererText()
            col = Gtk.TreeViewColumn(name, r, text=i)
            if i >= 2:
                col.set_cell_data_func(r, lambda c, cell, m, it, d, i=i: cell.set_property("text", "%.1f" % m[it][i]))
            col.set_sort_column_id(i)
            self.tree.append_column(col)
        sw = Gtk.ScrolledWindow()
        sw.add(self.tree)
        tk.pack_start(sw, True, True, 0)
        btn = Gtk.Button(label="End selected task")
        btn.connect("clicked", self.end_task)
        tk.pack_start(btn, False, False, 0)
        nb.append_page(tk, Gtk.Label(label="Tasks"))

        self.refresh()
        GLib.timeout_add_seconds(2, self.tick)

    def tick(self):
        self.refresh()
        return True

    def selected_pid(self):
        model, it = self.tree.get_selection().get_selected()
        return model[it][0] if it else None

    def end_task(self, _b):
        pid = self.selected_pid()
        if pid:
            try:
                os.kill(pid, signal.SIGTERM)
            except Exception as e:
                d = Gtk.MessageDialog(transient_for=self, message_type=Gtk.MessageType.ERROR,
                                      buttons=Gtk.ButtonsType.OK, text="Could not end task: %s" % e)
                d.run()
                d.destroy()

    def refresh(self):
        o = osrel()
        m = {}
        for l in read("/proc/meminfo").splitlines():
            k, v = l.split(":")
            m[k] = int(v.split()[0])
        tot, av = m["MemTotal"], m["MemAvailable"]
        used = tot - av
        du = shutil.disk_usage("/")
        up = float(read("/proc/uptime", "0").split()[0])
        cpu = next((l.split(":", 1)[1].strip() for l in read("/proc/cpuinfo").splitlines() if l.startswith("model name")), platform.processor())
        dev = (read("/sys/devices/virtual/dmi/id/sys_vendor") + " " + read("/sys/devices/virtual/dmi/id/product_name")).strip()
        self.v["Device"].set_text(dev or "Unknown")
        self.v["Name"].set_text(socket.gethostname())
        self.v["OS"].set_text(o.get("PRETTY_NAME", "AcaciaOS"))
        self.v["Version"].set_text(read("/etc/acacia-version", "unknown"))
        self.v["Kernel"].set_text(platform.release())
        self.v["Processor"].set_text("%s (%d threads)" % (cpu, os.cpu_count() or 1))
        self.v["Memory"].set_text("%s used of %s" % (gb(used), gb(tot)))
        self.v["Storage"].set_text("%.0f GB used of %.0f GB" % (du.used / 1e9, du.total / 1e9))
        self.v["Uptime"].set_text("%d h %d min" % (up // 3600, up % 3600 // 60))
        self.ram_bar.set_value(used / tot)
        self.disk_bar.set_value(du.used / du.total)

        sel = self.selected_pid()
        out = subprocess.run(["ps", "-eo", "pid=,pcpu=,rss=,comm=", "--sort=-rss"],
                             capture_output=True, text=True).stdout.splitlines()[:80]
        self.store.clear()
        for l in out:
            p = l.split(None, 3)
            if len(p) == 4:
                self.store.append([int(p[0]), p[3], float(p[1]), int(p[2]) / 1024])
        if sel:
            for row in self.store:
                if row[0] == sel:
                    self.tree.get_selection().select_iter(row.iter)

w = App()
w.connect("destroy", Gtk.main_quit)
w.show_all()
Gtk.main()
PYAPP
chmod 755 /usr/local/bin/my-acacia

cat > /usr/share/applications/my-acacia.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=My Acacia
Comment=Device info, memory and tasks
Exec=/usr/local/bin/my-acacia
Icon=acaciaos-logo
Terminal=false
Categories=System;Settings;
EOF

# =====================================================================
# NEW: AcaciaUpdates app (GitHub updater)
# =====================================================================
cat > /usr/local/bin/acacia-updates <<'UPD'
#!/bin/bash
REPO="https://github.com/axrtech2-wq/AcaciaOSUpdateservice"
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

CMD='pkexec /usr/local/bin/acacia-update-apply; echo; read -rp "Finished. Press Enter to close. "'
if command -v gnome-terminal >/dev/null; then gnome-terminal --title=AcaciaUpdates -- bash -c "$CMD"
elif command -v ptyxis >/dev/null; then ptyxis -- bash -c "$CMD"
elif command -v kgx >/dev/null; then kgx -e bash -c "$CMD"
else x-terminal-emulator -e bash -c "$CMD"; fi
UPD
chmod 755 /usr/local/bin/acacia-updates

cat > /usr/local/bin/acacia-update-apply <<'APPLY'
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
echo "== Updating system packages =="
apt-get update
apt-get -y upgrade
[ -f "$D/VERSION" ] && cp "$D/VERSION" /etc/acacia-version
echo "== Done. Version: $(cat /etc/acacia-version). A reboot is recommended. =="
APPLY
chmod 755 /usr/local/bin/acacia-update-apply

cat > /usr/share/applications/acacia-updates.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=AcaciaUpdates
Comment=Check for and install AcaciaOS updates
Exec=/usr/local/bin/acacia-updates
Icon=software-update-available
Terminal=false
Categories=System;Settings;
EOF

# =====================================================================
# NEW: blur everywhere (Blur my Shell extension)
# =====================================================================
EXT=blur-my-shell@aunetx; ED=/usr/share/gnome-shell/extensions/$EXT
if [ ! -d "$ED" ]; then apt-get install -y gnome-shell-extension-blur-my-shell >/dev/null 2>&1 || true; fi
if [ ! -d "$ED" ]; then
  GV=$(gnome-shell --version 2>/dev/null | grep -o '[0-9]\+' | head -1)
  URL=$(curl -fsSL "https://extensions.gnome.org/extension-info/?pk=3193&shell_version=$GV" | python3 -c 'import sys,json;print(json.load(sys.stdin)["download_url"])' 2>/dev/null) || true
  if [ -n "$URL" ]; then
    curl -fsSL "https://extensions.gnome.org$URL" -o /tmp/blur.zip && mkdir -p "$ED" && unzip -oq /tmp/blur.zip -d "$ED" || true
  fi
fi
[ -d "$ED" ] && echo "Blur extension installed." || echo "WARNING: could not install the blur extension (see notes)."

cat > /usr/local/bin/acacia-blur-setup <<'BLUR'
#!/bin/bash
M="$HOME/.config/acacia-blur-done"
[ -f "$M" ] && exit 0
EXT=blur-my-shell@aunetx
[ -d /usr/share/gnome-shell/extensions/$EXT ] || exit 0
sleep 6
if gnome-extensions enable $EXT 2>/dev/null; then
  S=/usr/share/gnome-shell/extensions/$EXT/schemas
  G() { gsettings --schemadir "$S" "$@" 2>/dev/null || gsettings "$@" 2>/dev/null || true; }
  G set org.gnome.shell.extensions.blur-my-shell.applications blur true
  G set org.gnome.shell.extensions.blur-my-shell.applications enable-all true
  G set org.gnome.shell.extensions.blur-my-shell.panel blur true
  G set org.gnome.shell.extensions.blur-my-shell.dash-to-dock blur true
  G set org.gnome.shell.extensions.blur-my-shell.overview blur true
  G set org.gnome.shell.extensions.blur-my-shell.lockscreen blur true
  mkdir -p "$HOME/.config"; touch "$M"
fi
BLUR
chmod 755 /usr/local/bin/acacia-blur-setup
cat > /etc/xdg/autostart/acacia-blur.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Acacia Blur Setup
Exec=/usr/local/bin/acacia-blur-setup
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

update-desktop-database /usr/share/applications 2>/dev/null || true
echo; echo "DONE. Reboot now:  sudo reboot"
ACACIA
