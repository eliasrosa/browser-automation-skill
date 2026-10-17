#!/bin/bash
# Connect to user's Chrome via CDP
# Usage: ./attach.sh [-s session_name]
#
# Reads DevToolsActivePort from Chrome's config and attaches playwright-cli.
# Returns 0 on success, 1 if Chrome not running or no debugging port.

set -euo pipefail

SESSION_NAME=""
while getopts "s:" opt; do
  case $opt in
    s) SESSION_NAME="-s=$OPTARG" ;;
    *) echo "Usage: $0 [-s session_name]" >&2; exit 1 ;;
  esac
done

DEVTOOLS_FILE="$HOME/.config/google-chrome/DevToolsActivePort"

if [[ ! -f "$DEVTOOLS_FILE" ]]; then
  echo "Chrome not running with remote debugging enabled." >&2
  echo "Enable at chrome://inspect/#remote-debugging" >&2
  exit 1
fi

PORT=$(sed -n 1p "$DEVTOOLS_FILE")
WS_PATH=$(sed -n 2p "$DEVTOOLS_FILE")

if [[ -z "$PORT" || -z "$WS_PATH" ]]; then
  echo "Invalid DevToolsActivePort file" >&2
  exit 1
fi

CDP_URL="ws://127.0.0.1:${PORT}${WS_PATH}"

# Check if already attached
if playwright-cli $SESSION_NAME tab-list &>/dev/null; then
  echo "Already connected"
  playwright-cli $SESSION_NAME tab-list
  exit 0
fi

# Attach
echo "Connecting to Chrome at $CDP_URL..."
playwright-cli $SESSION_NAME attach --cdp="$CDP_URL"

echo "Connected. Tabs:"
playwright-cli $SESSION_NAME tab-list
