#!/usr/bin/env bash
# Source this file to configure the Codex wrapper environment.
# It adjusts PATH, establishes the Codex data home, and optionally
# loads a saved OpenAI API key for convenience.

if [ -n "${VIRTUAL_ENV:-}" ]; then
  DEFAULT_CX_HOME="$VIRTUAL_ENV/.cx"
  # Most virtual environments place executables in bin/; fall back to Scripts/ on Windows-style venvs.
  if [ -d "$VIRTUAL_ENV/bin" ]; then
    DEFAULT_CX_BIN_DIR="$VIRTUAL_ENV/bin"
  else
    DEFAULT_CX_BIN_DIR="$VIRTUAL_ENV/Scripts"
  fi
else
  DEFAULT_CX_HOME="$HOME/.cx"
  DEFAULT_CX_BIN_DIR="$HOME/.local/bin"
fi

export CX_HOME="${CX_HOME:-$DEFAULT_CX_HOME}"
export CX_BIN_DIR="${CX_BIN_DIR:-$DEFAULT_CX_BIN_DIR}"

case ":$PATH:" in
  *":$CX_BIN_DIR:"*) ;;
  *) export PATH="$CX_BIN_DIR:$PATH" ;;
esac

export CX_DICTIONARY="${CX_DICTIONARY:-$CX_HOME/dict}"
export CX_USAGE_FILE="${CX_USAGE_FILE:-$CX_HOME/usage}"
export CX_DECOMP_SPEC="${CX_DECOMP_SPEC:-$CX_HOME/decompression_spec.md}"

API_KEY_FILE="$CX_HOME/openai_api_key"
if [ -z "${OPENAI_API_KEY:-}" ] && [ -f "$API_KEY_FILE" ]; then
  OPENAI_API_KEY="$(head -n 1 "$API_KEY_FILE" 2>/dev/null)"
  if [ -n "$OPENAI_API_KEY" ]; then
    export OPENAI_API_KEY
  fi
fi
