# =============================================================================
# STAGE 1: Extract MPLAB X & XC8 from prebuilt image
# =============================================================================
FROM xanderhendriks/mplabx:2.0 AS mplabx

# Remove 16-bit and 32-bit compilers to reduce image size
RUN rm -rf /opt/microchip/xc16 /opt/microchip/xc32 2>/dev/null || true

# =============================================================================
# STAGE 2: Final Desktop Environment
# =============================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install system dependencies, desktop UI, VNC, and GUI runtime libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ca-certificates gnupg unzip \
    tigervnc-standalone-server tigervnc-common \
    websockify python3 \
    openbox tint2 lxterminal \
    libgtk-3-0t64 libgtk2.0-0t64 libglib2.0-0t64 \
    libgl1 libglu1-mesa libgl1-mesa-dri libegl1 \
    libx11-6 libxrender1 libxtst6 libxi6 libxfixes3 libxext6 \
    libxcomposite1 libxdamage1 libxrandr2 libxkbfile1 \
    x11-utils x11-xserver-utils wmctrl \
    libfreetype6 fontconfig fonts-dejavu-core \
    libasound2t64 libusb-1.0-0 make git \
    dbus-x11 at-spi2-core \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install noVNC v1.5.0
RUN curl -L https://github.com/novnc/noVNC/archive/refs/tags/v1.5.0.tar.gz \
    | tar -xz -C /opt \
    && mv /opt/noVNC-1.5.0 /opt/novnc \
    && echo 'export { initLogging as init_logging };' >> /opt/novnc/core/util/logging.js

# Create User-Activity Tracker Script
RUN cat > /opt/novnc/activity-tracker.js <<'JS'
(function () {
    const MESSAGE_TYPE = "container_user_activity";
    const THROTTLE_MS = 5000;
    let lastSent = 0;

    function sendActivity(eventName) {
        const now = Date.now();
        if (now - lastSent < THROTTLE_MS) {
            return;
        }
        lastSent = now;
        console.log("[IdleTracker]", eventName);

        try {
            window.parent.postMessage({
                type: MESSAGE_TYPE,
                source: window.location.hostname,
                event: eventName,
                timestamp: now
            }, "*");
        } catch (err) {
            console.error("[IdleTracker]", err);
        }
    }

    const events = [
        "mousemove", "mousedown", "mouseup", "click", "wheel",
        "touchstart", "touchmove", "keydown", "keyup"
    ];

    events.forEach((eventName) => {
        document.addEventListener(eventName, () => sendActivity(eventName), true);
    });

    console.log("[IdleTracker] Loaded");
})();
JS

# Custom noVNC Fullscreen HTML page with Activity Tracker injected
RUN cat > /opt/novnc/mplabx-picsimlab.html <<'HTML'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>MPLAB X + PICSimLab</title>
<style>
  html, body { margin:0; padding:0; height:100%; overflow:hidden; background:#1e1e2e; }
  #screen { width:100vw; height:100vh; }
</style>
</head>
<body>
<div id="screen"></div>
<script src="./activity-tracker.js"></script>
<script type="module">
  import RFB from './core/rfb.js';
  const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
  const rfb = new RFB(document.getElementById('screen'), proto + '//' + location.host + '/websockify');
  rfb.scaleViewport = true;
  rfb.resizeSession = false;
</script>
</body>
</html>
HTML

RUN printf '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0; url=/mplabx-picsimlab.html" /></head></html>\n' \
    > /opt/novnc/index.html

# Install PICSimLab from SourceForge
ARG PICSIMLAB_VERSION=0.9.2
ARG PICSIMLAB_DEB=PICSimLab_0.9.2_241005_Ubuntu_24.04.1_LTS_amd64.deb
RUN PICSIMLAB_URL="https://downloads.sourceforge.net/project/picsim/v${PICSIMLAB_VERSION}/${PICSIMLAB_DEB}" \
    && curl -L --fail --retry 3 "${PICSIMLAB_URL}" -o /tmp/picsimlab.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/picsimlab.deb \
    && rm -f /tmp/picsimlab.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy MPLAB X IDE and XC8 binaries from Stage 1
COPY --from=mplabx /opt/microchip /opt/microchip
RUN MPLAB_IDE="$(ls -d /opt/microchip/mplabx/v*/mplab_platform/bin/mplab_ide 2>/dev/null | head -1)" \
    && test -n "${MPLAB_IDE}" \
    && printf '#!/bin/bash\nexec "%s" "$@"\n' "${MPLAB_IDE}" > /usr/local/bin/mplab_ide \
    && chmod +x /usr/local/bin/mplab_ide

# Setup non-root developer user
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix && \
    userdel -r ubuntu 2>/dev/null || true && \
    useradd -m -s /bin/bash -u 1000 developer && \
    usermod -aG tty developer

USER developer
WORKDIR /home/developer

# Copy window manager and panel configurations
RUN mkdir -p /home/developer/.config/openbox /home/developer/.config/tint2 /home/developer/.local/share/applications
COPY --chown=developer:developer config/openbox/autostart /home/developer/.config/openbox/autostart
COPY --chown=developer:developer config/openbox/rc.xml    /home/developer/.config/openbox/rc.xml
COPY --chown=developer:developer config/openbox/menu.xml  /home/developer/.config/openbox/menu.xml
COPY --chown=developer:developer config/tint2/tint2rc     /home/developer/.config/tint2/tint2rc
COPY --chown=developer:developer config/tint2/terminal.desktop /home/developer/.local/share/applications/terminal.desktop

USER root
RUN mkdir -p /home/workspace && chown 1000:1000 /home/workspace && chmod 755 /home/workspace

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

USER developer
VOLUME ["/home/workspace"]

EXPOSE 6080 5901

ENV DISPLAY=:1
ENV VNC_PORT=5901
ENV NOVNC_PORT=6080
ENV NO_AT_BRIDGE=1
ENV VNC_GEOMETRY=1920x1080
ENV PICSIMLAB_UI_SCALE=1.0
ENV MPLABX_FONTSIZE=12

# Health check to monitor noVNC service health
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:6080/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]