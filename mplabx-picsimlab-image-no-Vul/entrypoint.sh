#!/bin/bash
set -e

DISPLAY_NUM=1
export DISPLAY=:${DISPLAY_NUM}
VNC_PORT=${VNC_PORT:-5901}
NOVNC_PORT=${NOVNC_PORT:-6080}
VNC_GEOMETRY=${VNC_GEOMETRY:-1920x1080}
PICSIMLAB_UI_SCALE=${PICSIMLAB_UI_SCALE:-1.0}
MPLABX_FONTSIZE=${MPLABX_FONTSIZE:-}
export XDG_RUNTIME_DIR=/tmp/runtime-${UID:-1000}

echo "============================================"
echo "  MPLAB X + PICSimLab Desktop Starting..."
echo "  Browser: http://localhost:${NOVNC_PORT}/"
echo "============================================"

# Clean up stale locks
rm -f /tmp/.X${DISPLAY_NUM}-lock /tmp/.X11-unix/X${DISPLAY_NUM} 2>/dev/null || true

# Setup execution space
mkdir -p /home/workspace
cd /home/workspace
mkdir -p "${XDG_RUNTIME_DIR}" && chmod 700 "${XDG_RUNTIME_DIR}"

# Define xstartup for VNC session
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup << 'XSTARTUP'
#!/bin/sh
xsetroot -solid "#2b2b2b"
exec openbox-session
XSTARTUP
chmod +x ~/.vnc/xstartup

# Launch TigerVNC Server
echo "[1/4] Starting TigerVNC..."
vncserver ${DISPLAY} \
    -rfbport ${VNC_PORT} \
    -SecurityTypes None \
    --I-KNOW-THIS-IS-INSECURE \
    -geometry ${VNC_GEOMETRY} \
    -depth 24 \
    -localhost no
sleep 3

# Launch D-Bus
echo "[2/4] Starting D-Bus..."
eval $(dbus-launch --sh-syntax) || true

echo "[3/4] Launching MPLAB X + PICSimLab..."

# Start PICSimLab in loop
(
    while true; do
        NO_AT_BRIDGE=1 \
        QT_SCALE_FACTOR=${PICSIMLAB_UI_SCALE} \
        picsimlab > /tmp/picsimlab.log 2>&1 || true
        echo "  PICSimLab exited — restarting in 3s..."
        sleep 3
    done
) &

# Start MPLAB X IDE in loop
(
    while true; do
        if ! pgrep -f "mplab_platform" >/dev/null 2>&1; then
            NO_AT_BRIDGE=1 \
            mplab_ide ${MPLABX_FONTSIZE:+--fontsize ${MPLABX_FONTSIZE}} \
                > /tmp/mplabx.log 2>&1 || true
            echo "  MPLAB X not running — (re)launching..."
        fi
        sleep 5
    done
) &

# Window maximization supervisor
(
    declare -A maxed
    while true; do
        for app in picsimlab "mplab x"; do
            WID=$(wmctrl -l 2>/dev/null | grep -i "${app}" | head -1 | awk '{print $1}')
            if [ -n "${WID}" ] && [ -z "${maxed[$WID]}" ]; then
                wmctrl -i -r "${WID}" -b add,maximized_vert,maximized_horz 2>/dev/null || true
                maxed[$WID]=1
            fi
        done
        sleep 2
    done
) &

# Start noVNC bridge
echo "[4/4] Starting noVNC on port ${NOVNC_PORT}..."
exec websockify --web=/opt/novnc --heartbeat=30 \
    0.0.0.0:${NOVNC_PORT} localhost:${VNC_PORT}