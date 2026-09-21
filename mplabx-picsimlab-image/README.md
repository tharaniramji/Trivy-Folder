# MPLAB X + PICSimLab Combined Image (PIC track)

A single self-contained Docker image that runs **MPLAB X IDE** (Microchip's PIC
IDE, with the XC8 compiler) and
[PICSimLab](https://picsimlab.com/) (a real-time PIC / AVR / ESP
development-board simulator) in a browser via noVNC.

This is the **PIC track**. The sister image `../edsim51-stm32-image` is the
**ARM track** (PICSimLab + STM32CubeIDE + STM32CubeMX). They were split because
a single all-in-one image is too large to build on a 48 GB host.

Both tools are installed in one Ubuntu 24.04 desktop. When the container starts,
**both launch automatically** as separate maximized windows; the bottom **tint2
taskbar** switches between them and restores minimized windows. If either is
closed it **auto-restarts** within a few seconds.

## Features

- **TigerVNC** + **noVNC** (v1.5.0) for full-screen browser access (no toolbars)
- **MPLAB X IDE + XC8** copied from `xanderhendriks/mplabx:2.0` (a multi-stage
  build source — no Microchip download needed; Docker Hub access required at
  build time)
- **PICSimLab** (Qt5) — its runtime deps resolve automatically from its `.deb`
- **Openbox** window manager + **tint2** launcher/taskbar
- Runs as non-root `developer` user
- Projects persist in `/home/workspace` (Docker volume)

## Ports

| Port | Service |
|------|---------|
| 6080 | noVNC web interface |
| 5901 | VNC server |

## Build

No local files needed — MPLAB X + XC8 are pulled from `xanderhendriks/mplabx:2.0`
(the `docker pull` happens automatically during the multi-stage build, so the
build host needs Docker Hub access), and PICSimLab is downloaded from SourceForge
at build time.

```bash
# from the repo root
docker build -t mplabx-picsimlab mplabx-picsimlab-image/
```

## Security scan

Install [Trivy](https://aquasecurity.github.io/trivy/latest/getting-started/installation/),
build the image, then scan it before publishing:

```powershell
docker build -t mplabx-picsimlab:latest mplabx-picsimlab-image/
.\mplabx-picsimlab-image\scripts\scan-image.ps1 -Image mplabx-picsimlab:latest
```

The scan fails when an `HIGH` or `CRITICAL` vulnerability, misconfiguration,
or secret is found. To exclude vulnerabilities without an available fix:

```powershell
.\mplabx-picsimlab-image\scripts\scan-image.ps1 `
  -Image mplabx-picsimlab:latest `
  -IgnoreUnfixed
```

Override versions / filenames at build time:

```bash
docker build -t mplabx-picsimlab \
    --build-arg PICSIMLAB_VERSION=0.9.2 \
    --build-arg PICSIMLAB_DEB=PICSimLab_0.9.2_241005_Ubuntu_24.04.1_LTS_amd64.deb \
    mplabx-picsimlab-image/
```

## Run

```bash
docker run -d -p 6080:6080 -p 5901:5901 mplabx-picsimlab
```

Open the browser at `http://localhost:6080/`.

### Tuning (runtime env vars, no rebuild needed)

| Env var | Default | Effect |
|---------|---------|--------|
| `VNC_GEOMETRY` | `1920x1080` | virtual desktop size (enlarge for more space) |
| `PICSIMLAB_UI_SCALE` | `1.0` | PICSimLab Qt UI scale factor |
| `MPLABX_FONTSIZE` | *(unset)* | MPLAB X IDE font size (NetBeans `--fontsize`) |

```bash
docker run -d -p 6080:6080 -e PICSIMLAB_UI_SCALE=1.3 -e MPLABX_FONTSIZE=16 mplabx-picsimlab
```

> **Note:** MPLAB X (from `xanderhendriks/mplabx:2.0`) is an older release (~v5.40)
> running on Ubuntu 24.04. It's a Java/NetBeans app with a bundled JRE, so it
> should launch; if it doesn't, check `docker exec <container> cat /tmp/mplabx.log`.
> The XC8 binaries may need 32-bit libs (`libc6:i386`) on some setups — add them
> if compilation fails.

## Download sources

- MPLAB X + XC8: https://hub.docker.com/r/xanderhendriks/mplabx (`docker pull xanderhendriks/mplabx:2.0`)
- PICSimLab: https://sourceforge.net/projects/picsim/ · https://picsimlab.com/download/
