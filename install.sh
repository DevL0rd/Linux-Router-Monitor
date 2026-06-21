#!/bin/bash
set -e

REPO_DIR=$(pwd)
if [ ! -f "$REPO_DIR/bin/routermon-collect" ]; then
    echo "Please run this script from the repository directory."
    exit 1
fi

APP="Linux-Router-Monitor"
CFG_DIR="$HOME/.config/$APP"
BIN_DIR="$HOME/.local/bin"
PLASMOID_SRC="$REPO_DIR/plasmoids"

# --- sanity check for tooling the widgets shell out to ---
for bin in ssh jq curl python3 kpackagetool6; do
    command -v "$bin" >/dev/null 2>&1 || echo "Warning: '$bin' is not installed or not in PATH."
done

# --- 1. config (git-ignored, holds router + AdGuard credentials) ---
mkdir -p "$CFG_DIR"
if [ ! -f "$CFG_DIR/config.json" ]; then
    cp "$REPO_DIR/config.example.json" "$CFG_DIR/config.json"
    echo "Created $CFG_DIR/config.json from the template."
    echo "  -> Edit it to set your router host/user and AdGuard Home login."
else
    echo "Keeping existing $CFG_DIR/config.json"
fi

# --- 2. helper scripts onto PATH (symlinked back to the repo) ---
mkdir -p "$BIN_DIR"
chmod +x "$REPO_DIR/bin/routermon-collect" "$REPO_DIR/bin/routermon-ctl" "$REPO_DIR/bin/routermon-speedtest" "$REPO_DIR/router/collect.sh"
ln -sf "$REPO_DIR/bin/routermon-collect" "$BIN_DIR/routermon-collect"
ln -sf "$REPO_DIR/bin/routermon-ctl" "$BIN_DIR/routermon-ctl"
ln -sf "$REPO_DIR/bin/routermon-speedtest" "$BIN_DIR/routermon-speedtest"
echo "Linked helper scripts into $BIN_DIR"

# --- resident collector (systemd --user): keeps the tmpfs snapshot fresh so the
#     widgets only ever read a file in-process (no per-poll process spawns) ---
mkdir -p ~/.config/systemd/user
# Pin the light resident collector to efficiency/compact cores when the CPU is
# hybrid (Intel E, AMD Zen 5c, ARM LITTLE). Detector returns nothing otherwise.
AFFINITY=""
ECORES=$(python3 -S "$REPO_DIR/bin/routermon-ecores" 2>/dev/null)
[ -n "$ECORES" ] && AFFINITY="CPUAffinity=$ECORES" && echo "Pinning collector to efficiency cores: $ECORES"
cat <<EOF > ~/.config/systemd/user/linux-router-monitor.service
[Unit]
Description=Linux-Router-Monitor resident collector
After=graphical-session.target

[Service]
Type=simple
WorkingDirectory=$REPO_DIR
ExecStart=/usr/bin/python3 -S $REPO_DIR/bin/routermon-collect --serve
Restart=always
RestartSec=3
Nice=19
$AFFINITY

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now linux-router-monitor.service
echo "Enabled resident collector service (linux-router-monitor.service)"

# --- allow the widgets to read the tmpfs snapshot in-process via QML XHR ---
# (Qt blocks file:// XHR unless this is set.) Use environment.d so the systemd
# user manager always provides it -- including a mid-session `systemctl --user
# restart plasma-plasmashell`, which the login-only plasma-workspace/env misses.
mkdir -p ~/.config/environment.d
echo 'QML_XHR_ALLOW_FILE_READ=1' > ~/.config/environment.d/linux-router-monitor.conf
systemctl --user set-environment QML_XHR_ALLOW_FILE_READ=1 2>/dev/null || true  # apply now, no relogin
rm -f ~/.config/plasma-workspace/env/linux-router-monitor.sh                    # migrate off old login-only location
echo "Set QML_XHR_ALLOW_FILE_READ=1 (environment.d; survives plasma restarts)"
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "  Note: $BIN_DIR is not in your PATH (widgets use absolute paths, so this is fine)." ;;
esac

# --- 3. push the remote collector to the router ---
read_cfg() { python3 -c "import json;print(json.load(open('$CFG_DIR/config.json')).get('$1',''))"; }
read_cfg_nested() { python3 -c "import json;print(json.load(open('$CFG_DIR/config.json')).get('$1',{}).get('$2',''))"; }
HOST=$(read_cfg host); USER=$(read_cfg user); KEY=$(read_cfg ssh_key)
REMOTE=$(read_cfg remote_script); [ -z "$REMOTE" ] && REMOTE="/jffs/lrm-collect.sh"
KEY="${KEY/#\~/$HOME}"
if [ -n "$HOST" ] && [ -n "$KEY" ]; then
    echo "Pushing remote collector to $USER@$HOST:$REMOTE ..."
    if ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
           -i "$KEY" "$USER@$HOST" "cat > $REMOTE && chmod +x $REMOTE" < "$REPO_DIR/router/collect.sh"; then
        echo "  Remote collector installed."
    else
        echo "  Could not reach the router. Fix SSH/config and re-run, or push manually:"
        echo "    ssh $USER@$HOST 'cat > $REMOTE && chmod +x $REMOTE' < router/collect.sh"
    fi
fi

# --- 4. install the plasmoids ---
echo "Installing widgets..."
for d in "$PLASMOID_SRC"/org.devl0rd.routermon.*; do
    cp -r "$REPO_DIR/shared/lib" "$d/contents/ui/"   # sync shared components into each
    if kpackagetool6 -t Plasma/Applet -u "$d" >/dev/null 2>&1; then
        echo "  upgraded $(basename "$d")"
    else
        kpackagetool6 -t Plasma/Applet -i "$d" >/dev/null 2>&1 && echo "  installed $(basename "$d")"
    fi
done

echo ""
echo "Done! Six widgets are available: System, Network, WiFi, DNS, Clients, Speed Test."
echo "Add them via right-click desktop/panel -> Add Widgets -> search \"Router\"."
echo "If they don't appear yet, run:  kquitapp6 plasmashell && kstart plasmashell"
echo "Logs: $HOME/.local/state/$APP/monitor.log"

echo "Reloading Plasma…"
systemctl --user restart plasma-plasmashell.service 2>/dev/null \
    || { kquitapp6 plasmashell 2>/dev/null; (kstart plasmashell >/dev/null 2>&1 &); }
