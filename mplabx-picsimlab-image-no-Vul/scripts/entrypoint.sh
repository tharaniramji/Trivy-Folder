#!/bin/bash
set -e

DISPLAY_NUM=1
export DISPLAY=:${DISPLAY_NUM}
VNC_PORT=${VNC_PORT:-5901}
NOVNC_PORT=${NOVNC_PORT:-6080}
# Virtual desktop size. noVNC scales this whole framebuffer to fit the browser
# (scaleViewport). 1920x1080 suits the maximized windows; enlarge for more space.
VNC_GEOMETRY=${VNC_GEOMETRY:-1920x1080}
# PICSimLab Qt UI scale factor. MPLAB X font size (NetBeans --fontsize) is set
# only when MPLABX_FONTSIZE is non-empty. Tune both with -e at run time.
PICSIMLAB_UI_SCALE=${PICSIMLAB_UI_SCALE:-1.0}
MPLABX_FONTSIZE=${MPLABX_FONTSIZE:-}
export XDG_RUNTIME_DIR=/tmp/runtime-${UID:-1000}

echo "============================================"
echo "  MPLAB X + PICSimLab Desktop Starting..."
echo "  Browser: http://localhost:${NOVNC_PORT}/"
echo "============================================"

# Clean up stale X11 locks from previous runs
rm -f /tmp/.X${DISPLAY_NUM}-lock /tmp/.X11-unix/X${DISPLAY_NUM} 2>/dev/null || true

# Setup dirs
mkdir -p /home/workspace
cd /home/workspace
mkdir -p "${XDG_RUNTIME_DIR}" && chmod 700 "${XDG_RUNTIME_DIR}"

# xstartup — runs inside the VNC session to start the window manager
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup << 'XSTARTUP'
#!/bin/sh
xsetroot -solid "#2b2b2b"
exec openbox-session
XSTARTUP
chmod +x ~/.vnc/xstartup

# [1/4] TigerVNC — standalone X11 display + VNC server, no password
#       (EKS ingress handles auth)
echo "[1/4] Starting TigerVNC on display ${DISPLAY}, port ${VNC_PORT}..."
vncserver ${DISPLAY} \
    -rfbport ${VNC_PORT} \
    -SecurityTypes None \
    --I-KNOW-THIS-IS-INSECURE \
    -geometry ${VNC_GEOMETRY} \
    -depth 24 \
    -localhost no
sleep 3
echo "  TigerVNC running"

# [2/4] D-Bus
echo "[2/4] Starting D-Bus..."
eval $(dbus-launch --sh-syntax) || true
echo "  D-Bus running"

# [3/4] Auto-launch BOTH tools, each in its own restart loop so closing a window
# just brings it back. They open as separate maximized windows (Openbox rule) —
# switch / minimize / restore them from the bottom taskbar (tint2).
echo "[3/4] Launching MPLAB X + PICSimLab..."

# ── PICSimLab (real-time PIC/AVR/ESP board simulator, Qt) ─────────────────────
(
    while true; do
        NO_AT_BRIDGE=1 \
        QT_SCALE_FACTOR=${PICSIMLAB_UI_SCALE} \
        picsimlab > /tmp/picsimlab.log 2>&1 || true
        echo "  PICSimLab exited — restarting in 3s..."
        sleep 3
    done
) &

# ── MPLAB X IDE (Microchip PIC development, NetBeans/Java) ────────────────────
# Like Eclipse, MPLAB X locks its user directory, so exactly ONE instance must
# run. Its launcher may fork, so a naive `while true` could start a second copy;
# we (re)launch only when none is alive. MPLABX_FONTSIZE (if set) maps to the
# NetBeans --fontsize option to enlarge the IDE font.
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

# Backup maximize: the Openbox <applications> rule is the primary mechanism, but
# some apps set their own geometry on start, so we also nudge each window to
# maximized ONCE the first time it appears. Once-only (tracked in maxed[]) so it
# never fights the minimize button by re-maximizing.
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

echo ""
echo "============================================"
echo "  READY!"
echo "  Open browser: http://YOUR_IP:${NOVNC_PORT}/"
echo "  MPLAB X + PICSimLab launch automatically (maximized)."
echo "  Switch/minimize/restore via the bottom taskbar."
echo "  Projects saved to: /home/workspace"
echo "============================================"

# [4/4] noVNC — foreground process, keeps container alive
echo "[4/4] Starting noVNC on port ${NOVNC_PORT}..."
exec websockify --web=/opt/novnc --heartbeat=30 \
    0.0.0.0:${NOVNC_PORT} localhost:${VNC_PORT}
