#!/usr/bin/env bash
set -euo pipefail

# Install Codex wrappers into the currently active Python virtual environment
if [ -z "${VIRTUAL_ENV:-}" ]; then
  echo "No active virtual environment detected. Activate one and rerun." >&2
  exit 1
fi

INSTALL_DIR="$VIRTUAL_ENV/.cx"
BIN_DIR="$VIRTUAL_ENV/bin"

mkdir -p "$INSTALL_DIR/metrics" "$BIN_DIR"

# Seed dictionary if missing
if [ ! -f "$INSTALL_DIR/dict" ]; then
  cp .cx/dict "$INSTALL_DIR/dict"
fi

# Install decompression spec if missing
if [ ! -f "$INSTALL_DIR/decompression_spec.md" ]; then
  cp decompression_spec.md "$INSTALL_DIR/decompression_spec.md"
fi

# Install cx and cx5 wrappers into the venv
cp cx "$BIN_DIR/cx"
chmod +x "$BIN_DIR/cx"
cp cx5 "$BIN_DIR/cx5"
chmod +x "$BIN_DIR/cx5"

echo "Installed cx to $BIN_DIR/cx"
echo "Installed cx5 to $BIN_DIR/cx5"
echo "Dictionary and decompression spec ensured under $INSTALL_DIR"
