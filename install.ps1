# Livebarn Tools Installer for Windows
# Run with: powershell -ExecutionPolicy Bypass -File install.ps1
# Or paste: iwr -useb https://raw.githubusercontent.com/johnsonch/concat_videos/main/install.ps1 | iex

$ErrorActionPreference = "Stop"
$InstallDir = "$env:USERPROFILE\.livebarn-tools"

function Info($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "==> $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "==> $msg" -ForegroundColor Yellow }

# --- Check for Docker Desktop ---
$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
    Write-Host ""
    Write-Host "Error: Docker Desktop is required but not installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install Docker Desktop from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "After installing, restart this script."
    exit 1
}

# Check Docker is running
$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Error: Docker Desktop is installed but not running." -ForegroundColor Red
    Write-Host ""
    Write-Host "Start Docker Desktop and try again."
    exit 1
}

# --- Check for Git ---
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host ""
    Write-Host "Error: Git is required but not installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install Git from: https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "After installing, restart this script."
    exit 1
}

# --- Clone or update ---
if (Test-Path $InstallDir) {
    Info "Updating existing installation..."
    Push-Location $InstallDir
    git pull --ff-only
    Pop-Location
} else {
    Info "Downloading livebarn tools..."
    git clone https://github.com/johnsonch/concat_videos.git $InstallDir
}

# --- Create config directory ---
$ConfigDir = "$env:USERPROFILE\.config\livebarn_tools"
if (-not (Test-Path $ConfigDir)) {
    Info "Creating config directory..."
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

# --- Build Docker image ---
Info "Building the web UI (this may take a few minutes on first run)..."
Push-Location $InstallDir
docker compose build
Pop-Location

Write-Host ""
Ok "Livebarn Tools installed!"
Write-Host ""
Write-Host "  To start the web UI:"
Write-Host "    cd $InstallDir"
Write-Host "    docker compose up"
Write-Host ""
Write-Host "  Then open http://localhost:4567 in your browser."
Write-Host ""
Write-Host "  To stop: press Ctrl+C in the terminal, or run:"
Write-Host "    docker compose down"
Write-Host ""
Write-Host "  Run this script again to update."
Write-Host ""
