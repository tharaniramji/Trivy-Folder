# syntax=docker/dockerfile:1.7
# =============================================================================
# STAGE 1: Extract MPLAB X & XC8 from prebuilt image
# =============================================================================
FROM xanderhendriks/mplabx:2.0 AS mplabx

# Remove 16-bit/32-bit compilers and known-vulnerable, unused JARs
RUN rm -rf /opt/microchip/xc16 /opt/microchip/xc32 2>/dev/null || true
RUN find /opt/microchip/mplabx -type f \( \
        -name 'log4j-1.2*.jar' -o \
        -name 'mysql-connector-java-*.jar' \
    \) -print -delete

# =============================================================================
# STAGE 2: Patch vulnerable bundled JARs (tools stay out of the final image)
# =============================================================================
FROM ubuntu:24.04 AS patcher
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends curl ca-certificates unzip zip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=mplabx /opt/microchip /opt/microchip

ARG MPLABX_HOME=/opt/microchip/mplabx/v5.40/mplab_platform
ARG MAVEN_CENTRAL=https://repo1.maven.org/maven2
# Versions are build args so you can bump them when a scan reports new fixes.
# Optional: set *_SHA1 (Maven publishes .jar.sha1 files) to pin integrity.
ARG JGIT_VERSION=5.13.3.202401111512-r
ARG INI4J_VERSION=0.5.4
ARG JLINE_VERSION=3.30.15
ARG COMPRESS_VERSION=1.26.2
# commons-compress 1.26+ needs commons-io / commons-lang3 classes at runtime
ARG COMMONS_IO_VERSION=2.16.1
ARG COMMONS_LANG3_VERSION=3.14.0
ARG FREEMARKER_VERSION=2.3.35

# Helper: download a Maven artifact and verify it against Maven Central's sha1
RUN cat > /usr/local/bin/mvnget <<'SH' && chmod +x /usr/local/bin/mvnget
#!/bin/sh
set -eu
url="$1"; out="$2"
curl -fsSL --retry 3 "$url" -o "$out"
want="$(curl -fsSL --retry 3 "$url.sha1" | cut -d' ' -f1)"
have="$(sha1sum "$out" | cut -d' ' -f1)"
[ "$want" = "$have" ] || { echo "Checksum mismatch for $url" >&2; exit 1; }
unzip -tq "$out" >/dev/null
SH

# Replace JAR contents in place (filenames unchanged: module manifests reference them)
RUN set -eux; \
    mvnget "${MAVEN_CENTRAL}/org/eclipse/jgit/org.eclipse.jgit/${JGIT_VERSION}/org.eclipse.jgit-${JGIT_VERSION}.jar" \
           "${MPLABX_HOME}/ide/modules/org-eclipse-jgit.jar"; \
    mvnget "${MAVEN_CENTRAL}/org/ini4j/ini4j/${INI4J_VERSION}/ini4j-${INI4J_VERSION}.jar" \
           "${MPLABX_HOME}/ide/modules/ext/ini4j-0.5.1.jar"; \
    # NOTE: the original used jline-remote-telnet, which is a different
    # artifact from jline. The 'jline' bundle is the correct replacement.
    mvnget "${MAVEN_CENTRAL}/org/jline/jline/${JLINE_VERSION}/jline-${JLINE_VERSION}.jar" \
           "${MPLABX_HOME}/mplablibs/modules/ext/jline.jar"

# commons-compress lives as class files inside mchp-jython-standalone.jar
WORKDIR /tmp/compress-patch
RUN set -eux; \
    JYTHON_JAR="${MPLABX_HOME}/mplablibs/modules/ext/mchp-jython-standalone.jar"; \
    mvnget "${MAVEN_CENTRAL}/org/apache/commons/commons-compress/${COMPRESS_VERSION}/commons-compress-${COMPRESS_VERSION}.jar" cc.jar; \
    mvnget "${MAVEN_CENTRAL}/commons-io/commons-io/${COMMONS_IO_VERSION}/commons-io-${COMMONS_IO_VERSION}.jar" cio.jar; \
    mvnget "${MAVEN_CENTRAL}/org/apache/commons/commons-lang3/${COMMONS_LANG3_VERSION}/commons-lang3-${COMMONS_LANG3_VERSION}.jar" cl3.jar; \
    # Remove old classes AND old Maven metadata (Trivy reads the metadata for the version)
    zip -q -d "${JYTHON_JAR}" \
        'org/apache/commons/compress/*' \
        'META-INF/maven/org.apache.commons/commons-compress/*' || true; \
    unzip -q cc.jar  'org/apache/commons/compress/*' 'META-INF/maven/org.apache.commons/commons-compress/*'; \
    unzip -qn cio.jar 'org/apache/commons/io/*'    -x 'META-INF/*' || true; \
    unzip -qn cl3.jar 'org/apache/commons/lang3/*' -x 'META-INF/*' || true; \
    zip -qr "${JYTHON_JAR}" org META-INF; \
    unzip -tq "${JYTHON_JAR}" >/dev/null; \
    unzip -p "${JYTHON_JAR}" META-INF/maven/org.apache.commons/commons-compress/pom.properties | grep "version=${COMPRESS_VERSION}"; \
    rm -rf /tmp/compress-patch

# FreeMarker: replace content, keep filename (module manifest references it)
RUN mvnget "${MAVEN_CENTRAL}/org/freemarker/freemarker/${FREEMARKER_VERSION}/freemarker-${FREEMARKER_VERSION}.jar" \
           "${MPLABX_HOME}/ide/modules/ext/freemarker-2.3.19.jar"

# Strip signature files from patched JARs (stale signatures break class loading)
RUN for j in \
      "${MPLABX_HOME}/ide/modules/org-eclipse-jgit.jar" \
      "${MPLABX_HOME}/ide/modules/ext/ini4j-0.5.1.jar" \
      "${MPLABX_HOME}/mplablibs/modules/ext/jline.jar" \
      "${MPLABX_HOME}/mplablibs/modules/ext/mchp-jython-standalone.jar"; do \
        zip -q -d "$j" 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.DSA' 2>/dev/null || true; \
    done

# =============================================================================
# STAGE 3: Final Desktop Environment
# =============================================================================
FROM ubuntu:24.04
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# upgrade pulls in all available Ubuntu security fixes at build time
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    curl ca-certificates \
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

# Install noVNC (set NOVNC_SHA256 to pin the tarball; build fails on mismatch)
ARG NOVNC_VERSION=1.5.0
ARG NOVNC_SHA256=
RUN curl -fsSL --retry 3 "https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz" -o /tmp/novnc.tgz \
    && if [ -n "${NOVNC_SHA256}" ]; then echo "${NOVNC_SHA256}  /tmp/novnc.tgz" | sha256sum -c -; fi \
    && tar -xz -C /opt -f /tmp/novnc.tgz \
    && mv /opt/noVNC-${NOVNC_VERSION} /opt/novnc \
    && echo 'export { initLogging as init_logging };' >> /opt/novnc/core/util/logging.js \
    && rm -f /tmp/novnc.tgz

# User-activity tracker script
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

# Custom noVNC fullscreen page
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

# Install PICSimLab (set PICSIMLAB_SHA256 to pin the .deb)
ARG PICSIMLAB_VERSION=0.9.2
ARG PICSIMLAB_DEB=PICSimLab_0.9.2_241005_Ubuntu_24.04.1_LTS_amd64.deb
ARG PICSIMLAB_SHA256=
RUN curl -fL --retry 3 "https://downloads.sourceforge.net/project/picsim/v${PICSIMLAB_VERSION}/${PICSIMLAB_DEB}" -o /tmp/picsimlab.deb \
    && if [ -n "${PICSIMLAB_SHA256}" ]; then echo "${PICSIMLAB_SHA256}  /tmp/picsimlab.deb" | sha256sum -c -; fi \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/picsimlab.deb \
    && rm -f /tmp/picsimlab.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# MPLAB X + XC8 from the patched stage
COPY --from=patcher /opt/microchip /opt/microchip
RUN MPLAB_IDE="$(find /opt/microchip/mplabx -type f -path '*/mplab_platform/bin/mplab_ide' -print -quit)" \
    && test -n "${MPLAB_IDE}" \
    && printf '#!/bin/bash\nexec "%s" "$@"\n' "${MPLAB_IDE}" > /usr/local/bin/mplab_ide \
    && chmod +x /usr/local/bin/mplab_ide

# Non-root developer user
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix && \
    userdel -r ubuntu 2>/dev/null || true && \
    useradd -m -s /bin/bash -u 1000 developer && \
    usermod -aG tty developer

USER developer
WORKDIR /home/developer

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

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["sh", "-c", "curl -f http://localhost:6080/ || exit 1"]

ENTRYPOINT ["/entrypoint.sh"]