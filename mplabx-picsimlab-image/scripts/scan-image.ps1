param(
    [string]$Image = "mplabx-picsimlab:latest",
    [switch]$IgnoreUnfixed
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command trivy -ErrorAction SilentlyContinue)) {
    throw "Trivy is required. Install it from https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
}

if (-not (docker image inspect $Image 2>$null)) {
    throw "Docker image '$Image' was not found. Build it before scanning."
}

$arguments = @(
    "image",
    "--severity", "HIGH,CRITICAL",
    "--exit-code", "1",
    "--scanners", "vuln,misconfig,secret"
)

if ($IgnoreUnfixed) {
    $arguments += "--ignore-unfixed"
}

$arguments += $Image
& trivy @arguments
exit $LASTEXITCODE