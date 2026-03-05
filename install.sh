#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/johnsonch/concat_videos.git"
INSTALL_DIR="$HOME/.livebarn-tools"
BIN_DIR="/usr/local/bin"
BINS=(concat_videos trim_video upload_youtube process_game livebarn-server)

info()  { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
ok()    { printf "\033[1;32m==>\033[0m %s\n" "$1"; }
warn()  { printf "\033[1;33m==>\033[0m %s\n" "$1"; }
fail()  { printf "\033[1;31mError:\033[0m %s\n" "$1"; exit 1; }

# --- Check dependencies ---
missing=()
for cmd in git ruby ffmpeg ffprobe; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done

if [ ${#missing[@]} -gt 0 ]; then
  echo ""
  fail "Missing required tools: ${missing[*]}

Install them first:
  macOS:   brew install ffmpeg ruby git
  Ubuntu:  sudo apt install ffmpeg ruby-full git"
fi

# Check for bundler
if ! gem list bundler -i >/dev/null 2>&1; then
  info "Installing bundler..."
  gem install bundler
fi

# --- Install or update ---
if [ -d "$INSTALL_DIR" ]; then
  info "Updating existing installation..."
  cd "$INSTALL_DIR"
  git pull --ff-only
else
  info "Downloading livebarn tools..."
  git clone "$REPO" "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

# --- Install gems ---
info "Installing Ruby dependencies..."
bundle install --quiet

# --- Symlink binaries ---
info "Linking commands to $BIN_DIR (may need your password)..."
for bin in "${BINS[@]}"; do
  src="$INSTALL_DIR/bin/$bin"
  dest="$BIN_DIR/$bin"
  if [ -L "$dest" ] || [ ! -e "$dest" ]; then
    sudo ln -sf "$src" "$dest"
  else
    warn "Skipping $dest - file exists and is not a symlink"
  fi
done

echo ""
ok "Livebarn tools installed!"
echo ""
echo "  Commands available:"
echo "    livebarn-server - start the web UI"
echo "    process_game    - all-in-one: concat, trim, upload"
echo "    concat_videos   - merge Livebarn segments"
echo "    trim_video      - trim front/end of a video"
echo "    upload_youtube  - upload to YouTube"
echo ""
echo "  Run 'livebarn-server' to start the web UI."
echo "  Run 'process_game --help' for CLI usage."
echo "  Run this script again to update."
echo ""
