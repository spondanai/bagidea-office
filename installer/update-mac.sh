#!/usr/bin/env bash
# BagIdea Office updater for macOS.
#   .git present  -> git pull + rebuild the shell only if shell/ changed
#   no .git        -> inform the user
# Run via:  the in-app refresh button.

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo ""
echo "  ===== BagIdea Office - UPDATE ====="

# 1) Stop the running suite
echo "  [1/4] Stopping the app..."
pkill -f "node.*server\.js" || true
pkill -f "bagidea-office-shell" || true
pkill -f "Godot" || true
pkill -f "BagIdeaOffice" || true
sleep 2

# No git checkout fallback
if [ ! -d "$ROOT/.git" ]; then
  echo "  [2/2] Not a git checkout."
  echo "        Please download the latest version manually."
  sleep 5
  exit 0
fi

# 2) Pull the latest code.
echo "  [2/4] Pulling latest code..."
BEFORE=$(git rev-parse HEAD)
git pull --ff-only
AFTER=$(git rev-parse HEAD)

if [ "$BEFORE" == "$AFTER" ]; then
  echo "  - Already up to date"
fi

# 3) Rebuild the shell only when its source changed.
SHELL_CHANGED=$(git diff --name-only "$BEFORE" "$AFTER" -- shell/ | wc -l | tr -d ' ' || true)
if [ "$SHELL_CHANGED" -gt 0 ] || [ ! -f "$ROOT/shell/target/release/bagidea-office-shell" ]; then
  echo "  [3/4] Rebuilding the shell..."
  source "$HOME/.cargo/env" 2>/dev/null || true
  if command -v cargo >/dev/null; then
    ( cd "$ROOT/shell" && cargo build --release )
  else
    echo "  ! cargo not found. Please install Rust."
    sleep 5
  fi
else
  echo "  [3/4] shell unchanged - skipping the build"
fi

# 4) Relaunch.
echo "  [4/4] Relaunching..."
EXE="$ROOT/shell/target/release/bagidea-office-shell"
if [ -f "$EXE" ]; then
  nohup "$EXE" >/dev/null 2>&1 &
  echo ""
  echo "  Updated -> $(git rev-parse --short HEAD)"
  echo "  You can close this window now."
else
  echo "  ! shell exe not found - run 'cargo build --release' in shell/ first"
fi

sleep 3
exit 0
