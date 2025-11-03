#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${CX_HOME:-$HOME/.cx}"
BIN_DIR="${CX_BIN_DIR:-$HOME/.local/bin}"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command '$cmd' not found. Install it and re-run the installer." >&2
    exit 1
  fi
}

ensure_python_module() {
  local module="$1"
  shift
  if ! python3 -c "import $module" >/dev/null 2>&1; then
    if ! python3 -m pip install --user "$@" >/dev/null 2>&1; then
      echo "Warning: failed to install Python module '$module'. Install it manually." >&2
    fi
  fi
}

ensure_pip() {
  if python3 -m pip --version >/dev/null 2>&1; then
    return
  fi
  if python3 -m ensurepip --upgrade >/dev/null 2>&1; then
    python3 -m pip --version >/dev/null 2>&1 && return
  fi
  echo "Warning: python3 -m pip is unavailable; install pip to enable automatic dependency setup." >&2
}

require_cmd python3
ensure_pip

mkdir -p "$INSTALL_DIR/metrics" "$INSTALL_DIR/context" "$INSTALL_DIR/offline" "$INSTALL_DIR/responses" "$INSTALL_DIR/prompts" "$INSTALL_DIR/topics" "$INSTALL_DIR/grid" "$INSTALL_DIR/audit" "$INSTALL_DIR/inspect" "$INSTALL_DIR/hotspots" "$INSTALL_DIR/stale" "$INSTALL_DIR/format" "$INSTALL_DIR/depscan" "$INSTALL_DIR/improve" "$INSTALL_DIR/additive" "$INSTALL_DIR/enhance" "$INSTALL_DIR/backlog" "$INSTALL_DIR/modules" "$INSTALL_DIR/scaffold" "$INSTALL_DIR/weakpoints" "$INSTALL_DIR/doctor" "$BIN_DIR"
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

# Install helper environment scripts
cp cx-env.sh "$INSTALL_DIR/cx-env.sh"
chmod +x "$INSTALL_DIR/cx-env.sh"
cp cx-env.ps1 "$INSTALL_DIR/cx-env.ps1"

# Install Python dependencies for accurate token estimates and OpenAI access
ensure_python_module tiktoken tiktoken
ensure_python_module openai openai

# Install cx and cx5 wrappers
cp cx "$BIN_DIR/cx"
chmod +x "$BIN_DIR/cx"
cp cx5 "$BIN_DIR/cx5"
chmod +x "$BIN_DIR/cx5"

echo "Installed cx to $BIN_DIR/cx"
echo "Installed cx5 to $BIN_DIR/cx5"
echo "Dictionary and decompression spec ensured under $INSTALL_DIR"
echo "Environment helpers written to $INSTALL_DIR/cx-env.{sh,ps1}"
echo "Add 'source $INSTALL_DIR/cx-env.sh' to your shell profile (or '. $INSTALL_DIR/cx-env.ps1' for PowerShell) to load paths automatically."

# Optionally install PowerShell helpers if available
if command -v pwsh >/dev/null 2>&1; then
  pwsh ./install.ps1
elif command -v powershell >/dev/null 2>&1; then
  powershell -ExecutionPolicy Bypass -File ./install.ps1
else
  echo "PowerShell not detected; install from https://learn.microsoft.com/powershell/ to use PowerShell helpers." >&2
fi
