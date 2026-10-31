#!/bin/bash
# install-all.sh — Install full Titanium suite system-wide
set -euo pipefail

SUITE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "CRITICAL ERROR: Root privileges required."
    echo "Run: sudo ./install-all.sh"
    exit 1
fi

BG_BIN="$SUITE_ROOT/TitaniumBG/bin/titaniumbg"
RUN_BIN="$SUITE_ROOT/TitaniumRun/bin/titaniumrun"
WM_BIN="$SUITE_ROOT/TitaniumWM/bin/titanium"
LOGIN_BIN="$SUITE_ROOT/TitaniumLogin/bin/titaniumlogin"
SESSION_SRC="$SUITE_ROOT/TitaniumLogin/session.sh"

if [ ! -x "$BG_BIN" ] || [ ! -x "$RUN_BIN" ] || [ ! -x "$WM_BIN" ] || [ ! -x "$LOGIN_BIN" ]; then
    echo "[*] Binaries missing — building suite first..."
    if [ -n "${SUDO_USER:-}" ]; then
        sudo -u "$SUDO_USER" "$SUITE_ROOT/build-all.sh"
    else
        "$SUITE_ROOT/build-all.sh"
    fi
fi

install_bin() {
    local src="$1"
    local dst="$2"
    if [ ! -f "$src" ]; then
        echo "ERROR: missing $src"
        exit 1
    fi
    if [ -f "$dst" ]; then
        mv "$dst" "${dst}.bak.$(date +%s)"
    fi
    cp "$src" "$dst"
    chmod 755 "$dst"
    echo "    Installed $dst"
}

echo "[*] Installing suite binaries..."
install_bin "$BG_BIN"    /usr/bin/titaniumbg
install_bin "$RUN_BIN"   /usr/bin/titaniumrun
install_bin "$WM_BIN"    /usr/bin/titaniumwm
install_bin "$LOGIN_BIN" /usr/bin/titaniumlogin

mkdir -p /usr/lib/titanium
cp "$SESSION_SRC" /usr/lib/titanium/session.sh
chmod 755 /usr/lib/titanium/session.sh
echo "    Installed /usr/lib/titanium/session.sh"

# Optional PAM service hint (does not overwrite existing)
if [ ! -f /etc/pam.d/titaniumlogin ] && [ -f /etc/pam.d/login ]; then
    cp /etc/pam.d/login /etc/pam.d/titaniumlogin
    echo "    Created /etc/pam.d/titaniumlogin (copied from login)"
fi

XSESSIONS_DIR="/usr/share/xsessions"
mkdir -p "$XSESSIONS_DIR"
cat > "$XSESSIONS_DIR/titanium.desktop" <<EOF
[Desktop Entry]
Name=Titanium WM
Comment=Titanium suite (WM + BG + Run)
Exec=/usr/bin/titaniumwm
Type=Application
DesktopNames=Titanium
EOF
echo "    Registered $XSESSIONS_DIR/titanium.desktop"

USER_HOME=$(eval echo "~${SUDO_USER:-$USER}")
XINITRC="$USER_HOME/.xinitrc"

if [ -t 0 ]; then
    read -r -p "    Configure $XINITRC for startx (BG + WM)? [y/N] " response
else
    response="n"
fi

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    if [ -f "$XINITRC" ]; then
        cp "$XINITRC" "${XINITRC}.bak.$(date +%s)"
        if [ -n "${SUDO_USER:-}" ]; then
            chown "$SUDO_USER":"$SUDO_USER" "${XINITRC}.bak."* 2>/dev/null || true
        fi
    fi
    cat > "$XINITRC" <<'EOF'
#!/bin/sh
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources
titaniumbg &
xterm &
exec titaniumwm
EOF
    if [ -n "${SUDO_USER:-}" ]; then
        chown "$SUDO_USER":"$SUDO_USER" "$XINITRC"
    fi
    chmod +x "$XINITRC"
    echo "    Wrote $XINITRC"
else
    echo "    Skipping .xinitrc"
fi

echo ""
echo "[*] Suite install complete."
echo "    /usr/bin/titaniumbg"
echo "    /usr/bin/titaniumrun"
echo "    /usr/bin/titaniumwm"
echo "    /usr/bin/titaniumlogin   (console DM; run as root on a VT)"
echo "    /usr/lib/titanium/session.sh"
