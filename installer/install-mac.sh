#!/usr/bin/env bash
# BagIdea Office - macOS Web Installer.
#
# Installs EVERYTHING needed on a bare Mac:
#   Xcode CLT (git) · Homebrew · Node.js · Rust · Godot 4.6.3 · Claude Code CLI
# Then clones the repo to ~/BagIdeaOffice, downloads Godot into the checkout,
# builds the shell (build-mac.sh), wires hooks, and you're ready to run.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/bagidea/bagidea-office/main/installer/install-mac.sh | bash
#
# Options (env): override the source to test a fork/branch -
#   BAGIDEA_REPO   source repo   (default: the public BagIdea Office)
#   BAGIDEA_BRANCH branch        (default: main)
set -e

APP_DIR="$HOME/BagIdeaOffice"
REPO_URL="${BAGIDEA_REPO:-https://github.com/bagidea/bagidea-office.git}"
BRANCH="${BAGIDEA_BRANCH:-main}"
GODOTV="4.6.3"

have() { command -v "$1" >/dev/null 2>&1; }
step() { echo ""; echo "  [$1] $2"; }
ok()   { echo "      + $1"; }
warn() { echo "      ! $1"; }

echo ""
echo "  ==========================================="
echo "   BagIdea Office - macOS WEB INSTALLER"
echo "  ==========================================="

# 1. Xcode Command Line Tools (provides git + the C toolchain). The popup is
#    GUI-driven and can't be scripted headlessly, so if git is missing we kick
#    it off and ask the user to re-run once it finishes.
step 1 "Xcode Command Line Tools (git)"
if have git; then
  ok "git present ($(git --version))"
else
  warn "git not found - launching the Command Line Tools installer..."
  xcode-select --install 2>/dev/null || true
  warn "Finish the popup, then re-run this same command."
  exit 1
fi

# 2. Homebrew (the package manager we use for Node).
step 2 "Homebrew"
if have brew; then
  ok "already installed"
else
  warn "installing Homebrew (non-interactive)..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ok "installed"
fi
# Put brew on THIS session's PATH (Apple Silicon vs Intel prefix).
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
[ -x /usr/local/bin/brew ]    && eval "$(/usr/local/bin/brew shellenv)"

# 3. Node.js.
step 3 "Node.js"
if have node; then ok "already installed ($(node --version))"
else brew install node && ok "installed"; fi

# 4. Rust toolchain (compiles the desktop shell + wallpaper shim).
step 4 "Rust toolchain"
if have cargo; then ok "already installed ($(cargo --version))"
else
  warn "installing rustup (non-interactive)..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  ok "installed"
fi
# shellcheck disable=SC1090
source "$HOME/.cargo/env" 2>/dev/null || true

# 5. Claude Code CLI (the brain of every agent). Not needed to BUILD, so a
#    failure here is a warning, not a hard stop.
step 5 "Claude Code CLI"
if have claude; then ok "already installed"
elif have npm; then
  npm install -g @anthropic-ai/claude-code && ok "installed - log in later: run 'claude'" \
    || warn "couldn't install now - later run: npm install -g @anthropic-ai/claude-code"
else
  warn "npm not on PATH yet - reopen a terminal, then: npm install -g @anthropic-ai/claude-code"
fi

# 6. Clone (or update) the repo.
step 6 "Get the app -> $APP_DIR"
if [ ! -d "$APP_DIR" ]; then
  git clone -b "$BRANCH" "$REPO_URL" "$APP_DIR"
  ok "cloned ($BRANCH)"
else
  git -C "$APP_DIR" pull origin "$BRANCH" || warn "pull skipped (local changes?) - using existing checkout"
  ok "updated existing checkout"
fi

# 7. Godot 4.6.3 (universal) into the checkout. The OFFICIAL build ships the
#    entitlements the wallpaper shim needs (allow-dyld-environment-variables +
#    disable-library-validation), so NO re-signing is required - just drop it in.
step 7 "Godot $GODOTV (renders the office world)"
GODOT_APP="$APP_DIR/godot/bin-mac/Godot.app"
if [ -d "$GODOT_APP" ]; then
  ok "already present"
else
  mkdir -p "$APP_DIR/godot/bin-mac"
  TMP="$(mktemp -d)"
  URL="https://github.com/godotengine/godot/releases/download/$GODOTV-stable/Godot_v$GODOTV-stable_macos.universal.zip"
  warn "downloading Godot (~120 MB)..."
  curl -fsSL "$URL" -o "$TMP/godot.zip"
  unzip -q "$TMP/godot.zip" -d "$TMP"
  SRC_APP="$(/usr/bin/find "$TMP" -maxdepth 2 -name 'Godot*.app' -type d | head -1)"
  if [ -z "$SRC_APP" ]; then warn "Godot.app not found in the zip"; rm -rf "$TMP"; exit 1; fi
  mv "$SRC_APP" "$GODOT_APP"
  rm -rf "$TMP"
  # Strip the download quarantine so Gatekeeper doesn't block first launch
  # (the app is Developer-ID signed + notarized, so this only drops the flag).
  xattr -dr com.apple.quarantine "$GODOT_APP" 2>/dev/null || true
  ok "installed -> $GODOT_APP"
fi

# 8. Build the shell + wallpaper shim and wire the hooks for this machine.
step 8 "Build the shell (first build can take a few minutes)"
cd "$APP_DIR"
chmod +x build-mac.sh
./build-mac.sh

EXE="$APP_DIR/shell/target/release/bagidea-office-shell"
echo ""
if [ -x "$EXE" ]; then
  echo "  ============================================="
  echo "   Done - BagIdea Office is installed!"
  echo "  ============================================="
  echo "   1) First time: run 'claude' once to log in to Claude."
  echo "   2) Start it:   $EXE"
  echo "      (quit from the menu-bar tray icon)"
else
  echo "  Build didn't finish - see the messages above."
fi
echo ""
