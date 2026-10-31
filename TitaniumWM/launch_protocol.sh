#!/bin/bash
# launch_protocol.sh - Xephyr test harness for the Titanium suite
# Starts: Xephyr → titaniumbg → titaniumwm → xterm
# PATH includes local suite bins so Alt+D finds titaniumrun without system install.
set -euo pipefail

WM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "$WM_DIR/.." && pwd)"
cd "$WM_DIR"

AUTH_FILE="$WM_DIR/launch_auth.dat"
EXPECTED_CHECKSUM="a8cf7f9197e68cefbf848b54a35c43450d6612391700e936b6ad8540f2131a41"

XEPHYR_DISPLAY=":1"
for i in {1..10}; do
    if ! xdpyinfo -display ":$i" >/dev/null 2>&1; then
        XEPHYR_DISPLAY=":$i"
        break
    fi
done

RESOLUTION="1600x900"
WM_BINARY="$WM_DIR/bin/titanium"
BG_BINARY="$SUITE_ROOT/TitaniumBG/bin/titaniumbg"
RUN_BINARY="$SUITE_ROOT/TitaniumRun/bin/titaniumrun"
CLIENT_APP="/usr/bin/xterm"

# Local suite tools first (Run spawn uses bare "titaniumrun")
export PATH="$SUITE_ROOT/TitaniumRun/bin:$SUITE_ROOT/TitaniumBG/bin:$WM_DIR/bin:$PATH"

if [ ! -f "$AUTH_FILE" ]; then
    echo "CRITICAL ERROR: Launch authorization file ($AUTH_FILE) missing."
    exit 1
fi

ACTUAL_CHECKSUM=$(sha256sum "$AUTH_FILE" | awk '{print $1}')
if [ "$ACTUAL_CHECKSUM" != "$EXPECTED_CHECKSUM" ]; then
    echo "SECURITY ALERT: Checksum mismatch!"
    echo "Target:   $EXPECTED_CHECKSUM"
    echo "Actual:   $ACTUAL_CHECKSUM"
    exit 1
fi

echo "[*] Verifying system integrity..."
for bin in Xephyr xterm awk grep; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "ERROR: Required component '$bin' not found in PATH."
        exit 1
    fi
done

if [ ! -x "$WM_BINARY" ]; then
    echo "ERROR: WM binary missing ($WM_BINARY). Run ../build-all.sh first."
    exit 1
fi
if [ ! -x "$BG_BINARY" ]; then
    echo "ERROR: BG binary missing ($BG_BINARY). Run ../build-all.sh first."
    exit 1
fi
if [ ! -x "$RUN_BINARY" ]; then
    echo "ERROR: Run binary missing ($RUN_BINARY). Run ../build-all.sh first."
    exit 1
fi

if xdpyinfo -display "$XEPHYR_DISPLAY" >/dev/null 2>&1; then
    echo "[!] Display $XEPHYR_DISPLAY is already active."
    read -r -p "Type 'PURGE' to kill existing session and proceed: " CONFIRM
    if [ "$CONFIRM" == "PURGE" ]; then
        pkill -f "Xephyr $XEPHYR_DISPLAY" || true
        sleep 1
    else
        echo "Launch aborted."
        exit 1
    fi
fi

echo "[*] PROTOCOL INITIATED."
echo "    Display:    $XEPHYR_DISPLAY"
echo "    Resolution: $RESOLUTION"
echo "    BG:         titaniumbg"
echo "    WM:         titanium"
echo "    Run PATH:   $SUITE_ROOT/TitaniumRun/bin"

Xephyr "$XEPHYR_DISPLAY" -ac -screen "$RESOLUTION" &
XEPHYR_PID=$!

echo -n "Waiting for display..."
TIMEOUT=5
COUNT=0
while ! xdpyinfo -display "$XEPHYR_DISPLAY" >/dev/null 2>&1; do
    sleep 0.2
    COUNT=$((COUNT+1))
    if [ "$COUNT" -ge "$((TIMEOUT * 5))" ]; then
        echo ""
        echo "TIMEOUT: Xephyr failed to initialize."
        kill "$XEPHYR_PID" 2>/dev/null || true
        exit 1
    fi
    echo -n "."
done
echo " Online."

# Wallpaper companion (separate process; paints root)
DISPLAY="$XEPHYR_DISPLAY" "$BG_BINARY" &
BG_PID=$!
echo "TitaniumBG (PID $BG_PID) active."
sleep 0.3

DISPLAY="$XEPHYR_DISPLAY" "$WM_BINARY" &
WM_PID=$!
echo "TitaniumWM (PID $WM_PID) active."

sleep 0.5
DISPLAY="$XEPHYR_DISPLAY" "$CLIENT_APP" &
CLIENT_PID=$!
echo "Client (PID $CLIENT_PID) deployed."

echo ""
echo "System Running. Alt+D = titaniumrun. Press Ctrl+C to terminate."

cleanup() {
    echo ""
    echo "[!] Shutting down..."
    kill "$CLIENT_PID" 2>/dev/null || true
    kill "$WM_PID" 2>/dev/null || true
    kill "$BG_PID" 2>/dev/null || true
    kill "$XEPHYR_PID" 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT

wait "$XEPHYR_PID"
