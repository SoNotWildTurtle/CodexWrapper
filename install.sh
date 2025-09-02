#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.cx"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$INSTALL_DIR/metrics" "$BIN_DIR"

# Seed dictionary if missing
if [ ! -f "$INSTALL_DIR/dict" ]; then
  cp .cx/dict "$INSTALL_DIR/dict"
fi

# Install decompression spec if missing
if [ ! -f "$INSTALL_DIR/decompression_spec.md" ]; then
  cp decompression_spec.md "$INSTALL_DIR/decompression_spec.md"
fi

# Install cx and cx5 wrappers
cp cx "$BIN_DIR/cx"
chmod +x "$BIN_DIR/cx"
cp cx5 "$BIN_DIR/cx5"
chmod +x "$BIN_DIR/cx5"

echo "Installed cx to $BIN_DIR/cx"
echo "Installed cx5 to $BIN_DIR/cx5"
echo "Dictionary and decompression spec ensured under $INSTALL_DIR"
echo "Make sure $BIN_DIR is in your PATH"

# Optionally install PowerShell helpers if available
if command -v pwsh >/dev/null 2>&1; then
  pwsh ./install.ps1
elif command -v powershell >/dev/null 2>&1; then
  powershell -ExecutionPolicy Bypass -File ./install.ps1
else
  echo "PowerShell not detected; install from https://learn.microsoft.com/powershell/ to use PowerShell helpers." >&2
fi
