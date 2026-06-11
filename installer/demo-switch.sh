#!/usr/bin/env bash
# BagIdea Office - DEMO switch (macOS).
#
# Stops the installed office, repoints it at a FORK + BRANCH, reinstalls
# (clean checkout + rebuild via the canonical installer), and relaunches - so
# testers can try a feature branch BEFORE it's merged to the public `main`.
#
# One-liner (defaults to the macOS-updates demo on the spondanai fork):
#   curl -fsSL https://raw.githubusercontent.com/spondanai/bagidea-office/main/installer/demo-switch.sh | bash
#
# Point it at any fork/branch by overriding env vars:
#   curl -fsSL .../installer/demo-switch.sh \
#     | BAGIDEA_REPO=https://github.com/you/bagidea-office.git BAGIDEA_BRANCH=my-branch bash
#
# Installs IN PLACE over ~/BagIdeaOffice (replaces the main install, not a
# side-by-side copy). Your data (daemon/*.json) is gitignored, so it survives.
# To go back to stable: repoint origin to bagidea/bagidea-office and re-run the
# normal installer with no env vars.
set -e

APP="$HOME/BagIdeaOffice"
REPO="${BAGIDEA_REPO:-https://github.com/spondanai/bagidea-office.git}"
BRANCH="${BAGIDEA_BRANCH:-main}"

echo ""
echo "  ==========================================="
echo "   BagIdea Office - DEMO switch"
echo "   $REPO  #$BRANCH"
echo "  ==========================================="

# 1) Stop a running office (no-op on a fresh machine). macOS has no `bagidea`
#    PATH wiring, so kill the processes directly - same sweep as update-mac.sh.
#    This also frees the shell binary the rebuild is about to overwrite.
echo ""
echo "  [1/4] Stopping the running office..."
pkill -f "node.*server\.js"        || true
pkill -f "bagidea-office-shell"    || true
pkill -f "Godot"                   || true
pkill -f "BagIdeaOffice"           || true
sleep 1

# 2) Clean-switch an existing clone to the fork/branch. install-mac.sh's update
#    path runs `git pull origin <branch>`, which on a divergent branch would try
#    to MERGE into the wrong HEAD; doing the checkout + reset here first makes
#    that pull a no-op fast-forward. Data files are gitignored, so they stay.
if [ -d "$APP/.git" ]; then
  echo ""
  echo "  [2/4] Pointing the existing install at the fork..."
  git -C "$APP" remote set-url origin "$REPO"
  git -C "$APP" fetch origin "$BRANCH"
  git -C "$APP" checkout -B "$BRANCH" "origin/$BRANCH"
  git -C "$APP" reset --hard "origin/$BRANCH"
  echo "      origin -> $REPO ($BRANCH)"
else
  echo ""
  echo "  [2/4] No existing install - the installer will clone fresh."
fi

# 3) Hand off to the installer FROM THE SAME fork/branch (so the bare-machine
#    dependency bootstrap + Godot download ride along). It clones (if missing),
#    installs deps, downloads Godot, and runs build-mac.sh. Derive the raw URL
#    from $REPO/$BRANCH so an override fetches the matching installer.
echo ""
echo "  [3/4] Installing the demo (deps + Godot + rebuild - can take a few minutes)..."
RAW_BASE="$(printf '%s' "${REPO%.git}" | sed -E 's#^https://github.com/#https://raw.githubusercontent.com/#')"
INSTALLER_URL="$RAW_BASE/$BRANCH/installer/install-mac.sh"
curl -fsSL "$INSTALLER_URL" | BAGIDEA_REPO="$REPO" BAGIDEA_BRANCH="$BRANCH" bash

# 4) Launch the demo (detached). The native shell spawns the daemon + Godot
#    wallpaper + chat orb itself; quit from the menu-bar tray icon.
echo ""
echo "  [4/4] Launching the demo..."
EXE="$APP/shell/target/release/bagidea-office-shell"
if [ -x "$EXE" ]; then
  ( cd "$APP" && nohup "$EXE" >/tmp/bagidea-shell.log 2>&1 & )
  echo "      launched -> $EXE"
  echo "      log: /tmp/bagidea-shell.log  ·  quit from the menu-bar tray icon"
else
  echo "      ! build incomplete - the shell binary isn't there; see messages above"
  exit 1
fi

echo ""
echo "  Done - running the demo branch '$BRANCH'."
echo ""
