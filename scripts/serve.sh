#!/usr/bin/env bash
# Run Laya's local HTTP server (the drop-in backend for the laya extension).
#
# laya reaches this at http://127.0.0.1:8000/v1/systemone; both endpoints share the /v1/systemone
# protocol, so the extension needs no code change to switch from api.typesafe.ai here.
#
#   make serve               # one-shot on this host
#   LAYA_API_KEY=secret make serve   # require bearer auth (matches laya.api_key)
#   make install-serve       # install the systemd unit and start it
#
# Configuration is read from the environment (see scripts/laya.conf for the unit). Defaults:
#   LAYA_HOST=127.0.0.1  LAYA_PORT=8000  LAYA_PRELOAD=1
#
# NOTE: `pip install "laya[serve]"` must have been run on this host (Makefile `install-serve`).

set -euo pipefail

export LAYA_HOST="${LAYA_HOST:-127.0.0.1}"
export LAYA_PORT="${LAYA_PORT:-8000}"
export LAYA_PRELOAD="${LAYA_PRELOAD:-1}"

exec python3 -m laya.serve
