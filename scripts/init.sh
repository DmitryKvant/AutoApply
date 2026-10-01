#!/usr/bin/env bash
set -euo pipefail

pacman -S --noconfirm --needed novnc python-websockify

mkdir -p /root/.vnc /app/data
chmod 700 /root/.vnc

echo "=== Installed versions ==="
uv --version
python --version
chromium --version
Xvnc -version 2>&1 | head -5 || true

echo "=== noVNC ==="
command -v websockify
ls -l /usr/share/novnc/
