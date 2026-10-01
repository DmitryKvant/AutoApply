#!/usr/bin/env bash
set -Eeuo pipefail

cd /app

export DISPLAY="${DISPLAY:-:0}"
export TZ="${TZ:-Europe/Barcelona}"
export HOME=/root
export PATH="/root/.local/bin:/root/.cargo/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

WIDTH="${DISPLAY_WIDTH:-1680}"
HEIGHT="${DISPLAY_HEIGHT:-1050}"
VNC_PORT=5900
NOVNC_PORT=6080

VNC_DIR="$HOME/.vnc"
VNC_PASSWD="$VNC_DIR/passwd"

mkdir -p "$VNC_DIR" /app/data
chmod 700 "$VNC_DIR"

if [[ -z "${VNC_PASSWD:-}" ]]; then
    echo "ERROR: Set VNC_PASSWD in docker-compose.yaml"
    exit 1
fi

umask 077
printf '%s\n' "$VNC_PASSWD" | vncpasswd -f > "$VNC_PASSWD"
chmod 600 "$VNC_PASSWD"

PIDS=()

cleanup() {
    echo "=== Stopping services ==="
    for pid in "${PIDS[@]:-}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait || true
}

trap cleanup EXIT INT TERM

echo "=== Starting TigerVNC display $DISPLAY ==="

Xvnc "$DISPLAY" \
    -geometry "${WIDTH}x${HEIGHT}" \
    -depth 24 \
    -rfbport "$VNC_PORT" \
    -rfbauth "$VNC_PASSWD" \
    -localhost yes \
    -AlwaysShared \
    > /tmp/xvnc.log 2>&1 &

PIDS+=("$!")

for i in $(seq 1 30); do
    if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    echo "ERROR: Xvnc failed to start"
    cat /tmp/xvnc.log
    exit 1
fi

echo "=== Starting i3 ==="
i3 > /tmp/i3.log 2>&1 &
PIDS+=("$!")

echo "=== Starting noVNC ==="
websockify \
    --web=/usr/share/novnc \
    "$NOVNC_PORT" \
    "localhost:$VNC_PORT" \
    > /tmp/novnc.log 2>&1 &
PIDS+=("$!")

echo "=== Waiting for noVNC ==="
for i in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:$NOVNC_PORT/vnc.html" >/dev/null; then
        break
    fi
    sleep 1
done

echo "=== Installing/syncing AutoApply dependencies ==="

if [[ -f uv.lock ]]; then
    uv sync --frozen
else
    uv sync
fi

echo "=== Starting AutoApply ==="
echo "DISPLAY=$DISPLAY"

exec uv run autoapply
