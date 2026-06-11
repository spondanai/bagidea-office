# BagIdea Office - DEMO switch (Windows 11).
#
# Stops the installed office, repoints it at a FORK + BRANCH, reinstalls
# (clone/reset + rebuild via the canonical installer), and relaunches - so
# testers can try a feature branch BEFORE it's merged to the public `main`.
#
# One-liner (defaults to the macOS-updates demo on the spondanai fork):
#   irm https://raw.githubusercontent.com/spondanai/bagidea-office/main/installer/demo-switch.ps1 | iex
#
# Point it at any fork/branch by overriding before you run:
#   $env:BAGIDEA_REPO="https://github.com/you/bagidea-office.git"
#   $env:BAGIDEA_BRANCH="my-branch"
#   irm https://raw.githubusercontent.com/spondanai/bagidea-office/main/installer/demo-switch.ps1 | iex
#
# Installs IN PLACE over %LOCALAPPDATA%\BagIdeaOffice (replaces the main install,
# not a side-by-side copy). Your data (daemon\*.json) is gitignored, so it
# survives. To go back to stable: repoint origin to bagidea/bagidea-office and
# re-run the normal installer with no env vars.
param(
  [string]$Repo   = $(if ($env:BAGIDEA_REPO)   { $env:BAGIDEA_REPO }   else { "https://github.com/spondanai/bagidea-office.git" }),
  [string]$Branch = $(if ($env:BAGIDEA_BRANCH) { $env:BAGIDEA_BRANCH } else { "main" })
)
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$APP = Join-Path (Join-Path $env:LOCALAPPDATA "BagIdeaOffice") "app"

function Step($m) { Write-Host ""; Write-Host "  >> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "     + $m" -ForegroundColor Green }
function Warn($m) { Write-Host "     ! $m" -ForegroundColor Yellow }

Write-Host ""
Write-Host "  ===========================================" -ForegroundColor Magenta
Write-Host "   BagIdea Office - DEMO switch" -ForegroundColor Magenta
Write-Host "   $Repo  #$Branch" -ForegroundColor DarkGray
Write-Host "  ===========================================" -ForegroundColor Magenta

# 1) Stop a running office (no-op on a fresh machine). `bagidea stop` is the
#    clean path; the taskkill sweep is a belt-and-braces fallback that also
#    clears file locks the rebuild would otherwise hit.
Step "Stopping the running office..."
$cmd = Join-Path $APP "bagidea.cmd"
if (Test-Path $cmd) { & $cmd stop 2>$null | Out-Null }
Get-CimInstance Win32_Process | Where-Object {
  ($_.Name -eq "node.exe" -and $_.CommandLine -match "server\.js") -or
  $_.Name -eq "bagidea-office-shell.exe" -or
  $_.Name -eq "BagIdeaOffice.exe" -or
  $_.Name -like "Godot*"
} | ForEach-Object { taskkill /PID $_.ProcessId /T /F 2>$null | Out-Null }
Start-Sleep 1
Ok "stopped"

# 2) Repoint an existing clone at the fork. The installer's update path reuses
#    the existing `origin` (git fetch origin <branch>); without this it would
#    look for the branch on the WRONG repo and silently keep the old code.
if (Test-Path (Join-Path $APP ".git")) {
  Step "Pointing the existing install at the fork..."
  git -C $APP remote set-url origin $Repo 2>$null
  Ok "origin -> $Repo"
}

# 3) Hand off to the canonical installer with the fork/branch override. It does
#    the heavy lifting: fetch + reset --hard to the branch, rebuild the Rust
#    shell, re-brand the icon, rewire hooks, refresh the Start Menu shortcut.
Step "Installing the demo (this rebuilds the shell - can take a few minutes)..."
$env:BAGIDEA_REPO   = $Repo
$env:BAGIDEA_BRANCH = $Branch
irm https://raw.githubusercontent.com/spondanai/bagidea-office/main/installer/install.ps1 | iex

# 4) Launch the demo. `start` is idempotent (no-ops if the installer already
#    launched it from its own prompt).
Step "Launching the demo..."
if (Test-Path $cmd) { & $cmd start }
else { Warn "install looks incomplete - see the messages above before launching" }
