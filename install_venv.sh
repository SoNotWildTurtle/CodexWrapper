#!/usr/bin/env bash
set -euo pipefail

# Install Codex wrappers into the currently active Python virtual environment
if [ -z "${VIRTUAL_ENV:-}" ]; then
  echo "No active virtual environment detected. Activate one and rerun." >&2
  exit 1
fi

INSTALL_DIR="$VIRTUAL_ENV/.cx"
BIN_DIR="$VIRTUAL_ENV/bin"

mkdir -p "$INSTALL_DIR/metrics" "$INSTALL_DIR/context" "$INSTALL_DIR/offline" "$INSTALL_DIR/responses" "$INSTALL_DIR/prompts" "$INSTALL_DIR/topics" "$INSTALL_DIR/grid" "$INSTALL_DIR/audit" "$INSTALL_DIR/inspect" "$INSTALL_DIR/hotspots" "$INSTALL_DIR/stale" "$BIN_DIR"
touch "$INSTALL_DIR/relations"

# Seed dictionary if missing
if [ ! -f "$INSTALL_DIR/dict" ]; then
  cp .cx/dict "$INSTALL_DIR/dict"
fi

# Seed usage file if missing
if [ ! -f "$INSTALL_DIR/usage" ]; then
  cp .cx/usage "$INSTALL_DIR/usage"
fi

# Install decompression spec if missing
if [ ! -f "$INSTALL_DIR/decompression_spec.md" ]; then
  cp decompression_spec.md "$INSTALL_DIR/decompression_spec.md"
fi

# Install tiktoken inside the virtual environment for token estimates
if ! python -c 'import tiktoken' >/dev/null 2>&1; then
  python -m pip install tiktoken >/dev/null 2>&1 || true
fi

# Install cx and cx5 wrappers into the venv
cp cx "$BIN_DIR/cx"
chmod +x "$BIN_DIR/cx"
cp cx5 "$BIN_DIR/cx5"
chmod +x "$BIN_DIR/cx5"

echo "Installed cx to $BIN_DIR/cx"
echo "Installed cx5 to $BIN_DIR/cx5"
echo "Dictionary and decompression spec ensured under $INSTALL_DIR"
