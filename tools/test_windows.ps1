# UniStream — Script de test Windows
# Usage : depuis la racine du repo, PowerShell :
#   .\tools\test_windows.ps1              # build + run debug
#   .\tools\test_windows.ps1 -Release     # build release + lance l'exe
#   .\tools\test_windows.ps1 -Clean       # clean avant build
#   .\tools\test_windows.ps1 -Doctor      # juste flutter doctor
#
# Logs horodatés dans tools\logs\test_windows_<timestamp>.log

[CmdletBinding()]
param(
    [switch]$Release,
    [switch]$Clean,
    [switch]$Doctor,
    [switch]$SkipPull
)

$ErrorActionPreference = "Stop"

# --- Setup logs ---
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$logDir = Join-Path $repoRoot "tools\logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $logDir "test_windows_$timestamp.log"

function Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "HH:mm:ss"), $Level, $Message
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

function Run {
    param([string]$Cmd, [string]$Label)
    Log "→ $Label"
    Log "  cmd: $Cmd" "DEBUG"
    $output = & cmd /c "$Cmd 2>&1"
    $exit = $LASTEXITCODE
    $output | ForEach-Object { Add-Content -Path $logFile -Value "  $_" }
    if ($exit -ne 0) {
        Log "FAIL ($exit) — voir $logFile" "ERROR"
        throw "$Label failed with exit code $exit"
    }
    Log "OK — $Label"
}

Log "===== UniStream Windows test — $timestamp ====="
Log "Repo: $repoRoot"
Log "Log:  $logFile"

# --- Doctor only ---
if ($Doctor) {
    Run "flutter doctor -v" "Flutter doctor"
    Log "Doctor terminé. Vérifie la sortie ci-dessus."
    exit 0
}

# --- Pré-requis ---
Log "--- Pré-requis ---"
try {
    $flutterVersion = (& flutter --version 2>&1 | Select-Object -First 1)
    Log "Flutter: $flutterVersion"
} catch {
    Log "Flutter introuvable dans le PATH" "ERROR"
    exit 1
}

# --- Git pull ---
if (-not $SkipPull) {
    Log "--- Git pull ---"
    try {
        Run "git pull --ff-only" "git pull --ff-only"
    } catch {
        Log "git pull a échoué (peut-être des changements locaux). Skip avec -SkipPull si voulu." "WARN"
        throw
    }
} else {
    Log "Git pull sauté (-SkipPull)" "WARN"
}

# --- Clean optionnel ---
if ($Clean) {
    Run "flutter clean" "flutter clean"
}

# --- Pub get ---
Run "flutter pub get" "flutter pub get"

# --- Build & run ---
if ($Release) {
    Log "--- Build release ---"
    Run "flutter build windows --release" "flutter build windows --release"

    $exePath = Join-Path $repoRoot "build\windows\x64\runner\Release\unistream.exe"
    if (-not (Test-Path $exePath)) {
        Log "Exécutable introuvable : $exePath" "ERROR"
        exit 1
    }

    # Vérif DLL media_kit présentes à côté du .exe
    $releaseDir = Split-Path -Parent $exePath
    $mediaKitDlls = Get-ChildItem -Path $releaseDir -Filter "*mpv*" -ErrorAction SilentlyContinue
    if ($mediaKitDlls.Count -eq 0) {
        Log "Aucune DLL libmpv détectée dans $releaseDir — lecture vidéo probablement KO" "WARN"
    } else {
        Log "DLL libmpv détectées : $($mediaKitDlls.Count) fichier(s)"
    }

    Log "--- Lancement de $exePath ---"
    Log "Le script rend la main. L'app tourne en fenêtre séparée."
    Start-Process -FilePath $exePath
    Log "App lancée. PID visible via: Get-Process unistream"

} else {
    Log "--- Flutter run (debug, -d windows) ---"
    Log "Ctrl+C pour arrêter. Logs temps réel ci-dessous ET dans $logFile"
    Log "-------------------------------------------------------------"
    # flutter run est interactif, on ne capture pas la sortie dans le fichier
    & flutter run -d windows
}

Log "===== FIN ====="
