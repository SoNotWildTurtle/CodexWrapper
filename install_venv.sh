#!/usr/bin/env bash
set -euo pipefail

# Install Codex wrappers into the currently active Python virtual environment
if [ -z "${VIRTUAL_ENV:-}" ]; then
  echo "No active virtual environment detected. Activate one and rerun." >&2
  exit 1
fi

INSTALL_DIR="$VIRTUAL_ENV/.cx"
if [ -d "$VIRTUAL_ENV/bin" ]; then
  BIN_DIR="$VIRTUAL_ENV/bin"
else
  BIN_DIR="$VIRTUAL_ENV/Scripts"
fi

ensure_python_module() {
  local module="$1"
  shift
  if ! python -c "import $module" >/dev/null 2>&1; then
    if ! python -m pip install "$@" >/dev/null 2>&1; then
      echo "Warning: failed to install Python module '$module' inside the virtualenv. Install it manually." >&2
    fi
  fi
}

if ! python -m pip --version >/dev/null 2>&1; then
  if ! python -m ensurepip --upgrade >/dev/null 2>&1; then
    echo "Warning: python -m pip unavailable in the virtualenv; install pip to enable dependency setup." >&2
  fi
fi

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

# Install helper environment script
cp cx-env.sh "$INSTALL_DIR/cx-env.sh"
chmod +x "$INSTALL_DIR/cx-env.sh"

# Install required Python modules inside the virtual environment
ensure_python_module tiktoken tiktoken
ensure_python_module openai openai

# Install cx and cx5 wrappers into the venv
cp cx "$BIN_DIR/cx"
chmod +x "$BIN_DIR/cx"
cp cx5 "$BIN_DIR/cx5"
chmod +x "$BIN_DIR/cx5"

echo "Installed cx to $BIN_DIR/cx"
echo "Installed cx5 to $BIN_DIR/cx5"
echo "Dictionary and decompression spec ensured under $INSTALL_DIR"
echo "Environment helper written to $INSTALL_DIR/cx-env.sh"
