#!/usr/bin/env bash
# Run Ollaya's local model server in the foreground (the backend for the laya extension).
#
# laya reaches this at http://127.0.0.1:11435/v1/systemone by default; the server also serves the
# TypeSafe-compatible /v1 API, so the extension works unchanged against any /v1/systemone endpoint.
#
#   make serve                       # one-shot on this host (127.0.0.1:11435)
#   OLLAYA_API_KEY=secret make serve # require bearer auth (set the same key in laya.api_key)
#   make install-serve               # install the service (systemd on Linux, launchd on macOS) and start it
#
# Configuration is read from the environment (see scripts/ollaya.conf for the unit): OLLAYA_HOST
# (127.0.0.1:11435), OLLAYA_DEVICE (auto), OLLAYA_KEEP_ALIVE (5m), OLLAYA_API_KEY, ...
# The 'ollaya' binary is installed by https://ollaya.dev/install.sh (make install-serve does it).

set -euo pipefail

if ! command -v ollaya >/dev/null 2>&1; then
  echo "laya: the 'ollaya' binary was not found on PATH." >&2
  echo "  Install it:  curl -fsSL https://ollaya.dev/install.sh | sh" >&2
  echo "  then re-run: make serve" >&2
  exit 1
fi

export OLLAYA_HOST="${OLLAYA_HOST:-127.0.0.1:11435}"

exec ollaya serve
