#!/usr/bin/env bash
# Install the companion Laya server as a system service on this machine — the machine that runs
# PostgreSQL. `make install` runs this after installing the extension files; `make install-serve`
# runs it on its own.
#
#   Linux:   systemd unit   /etc/systemd/system/laya.service   (sudo when not root)
#   macOS:   launchd agent  ~/Library/LaunchAgents/laya.serve.plist   (no sudo)
#   neither: no service manager (containers, CI) — prints how to start the server by hand and exits 0
#
# The service runs `python3 -m laya.serve` (the [serve] extra of the PyPI `laya` package) on
# LAYA_HOST:LAYA_PORT (default 127.0.0.1:8000) — where the extension's default laya.api_url points.
# LAYA_API_KEY (optional) turns on bearer auth on the server; the extension then needs the same key
# (laya.api_key GUC or LAYA_API_KEY in the server process environment). LAYA_MODELS / LAYA_THREADS /
# LAYA_DEVICE (all optional) are passed through to the server when set.
#
#   make install NO_SERVE=1                     # skip the service entirely
#   LAYA_HOST=... LAYA_PORT=... LAYA_API_KEY=... LAYA_MODELS=english make install-serve
set -euo pipefail
cd "$(dirname "$0")/.."

host="${LAYA_HOST:-127.0.0.1}"
port="${LAYA_PORT:-8000}"
key="${LAYA_API_KEY:-}"
python="${LAYA_PYTHON:-}"

if [ -z "$python" ]; then
  python="$(command -v python3 || true)"
fi
if [ -z "$python" ]; then
  echo "laya: python3 not found on PATH; the Laya server needs Python >= 3.10." >&2
  echo "  install Python, or point at one with LAYA_PYTHON=/path/to/python3, then re-run: make install-serve" >&2
  echo "  (or install just the extension for now:  make install NO_SERVE=1)" >&2
  exit 1
fi

echo "laya: checking the 'laya[serve]' Python package ($python)"
if ! "$python" -c 'import laya.serve' >/dev/null 2>&1; then
  echo "laya: installing laya[serve] from PyPI (torch + friends; model checkpoints are downloaded on first start)"
  "$python" -m pip install "laya[serve]"
fi

wait_health() {
  # The first start preloads the checkpoints (downloaded from Hugging Face when not yet cached),
  # which can take a while; poll the health probe for up to 5 minutes.
  local i out
  for i in $(seq 1 60); do
    if out="$(curl -fsS "http://$host:$port/health" 2>/dev/null)"; then
      echo "laya: server is up: $out"
      return 0
    fi
    sleep 5
  done
  echo "laya: /health has not answered yet (checkpoints still loading?). The service keeps starting in" >&2
  echo "  the background; check its logs, then re-probe with:  curl -fsS http://$host:$port/health" >&2
  return 0
}

have_systemd=0
have_launchd=0
command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && have_systemd=1
command -v launchctl >/dev/null 2>&1 && have_launchd=1

if [ "$have_systemd" = 1 ]; then
  sudo=""
  [ "$(id -u)" = 0 ] || sudo="sudo"
  envf="$(mktemp)"; unitf="$(mktemp)"
  {
    echo "LAYA_HOST=$host"
    echo "LAYA_PORT=$port"
    echo "LAYA_PRELOAD=1"
    [ -n "$key" ] && echo "LAYA_API_KEY=$key"
    [ -n "${LAYA_MODELS:-}" ] && echo "LAYA_MODELS=$LAYA_MODELS"
    [ -n "${LAYA_THREADS:-}" ] && echo "LAYA_THREADS=$LAYA_THREADS"
    [ -n "${LAYA_DEVICE:-}" ] && echo "LAYA_DEVICE=$LAYA_DEVICE"
    echo "LAYA_LOG_LEVEL=info"
  } > "$envf"
  sed "s|__PYTHON3__|$python|" scripts/laya.conf > "$unitf"
  "$sudo" install -d /etc/laya
  "$sudo" install -m 600 "$envf" /etc/laya/env
  "$sudo" install -m 644 "$unitf" /etc/systemd/system/laya.service
  rm -f "$envf" "$unitf"
  "$sudo" systemctl daemon-reload
  "$sudo" systemctl enable --now laya.service
  echo "laya: systemd service 'laya' installed and started (logs: journalctl -u laya -f)"
  wait_health
elif [ "$have_launchd" = 1 ]; then
  mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
  plist="$HOME/Library/LaunchAgents/laya.serve.plist"
  optlines=""
  add_kv() { optlines="${optlines}    <key>$1</key><string>$2</string>
"; }
  [ -n "$key" ] && add_kv LAYA_API_KEY "$key"
  [ -n "${LAYA_MODELS:-}" ] && add_kv LAYA_MODELS "$LAYA_MODELS"
  [ -n "${LAYA_THREADS:-}" ] && add_kv LAYA_THREADS "$LAYA_THREADS"
  [ -n "${LAYA_DEVICE:-}" ] && add_kv LAYA_DEVICE "$LAYA_DEVICE"
  optlines="${optlines%$'\n'}"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.pglaya.serve</string>
  <key>ProgramArguments</key>
  <array>
    <string>$python</string>
    <string>-m</string>
    <string>laya.serve</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>LAYA_HOST</key><string>$host</string>
    <key>LAYA_PORT</key><string>$port</string>
    <key>LAYA_PRELOAD</key><string>1</string>
$optlines
    <key>LAYA_LOG_LEVEL</key><string>info</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/laya.serve.out.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/laya.serve.err.log</string>
</dict>
</plist>
PLIST
  uid="$(id -u)"
  launchctl bootout "gui/$uid/com.pglaya.serve" 2>/dev/null || true
  launchctl bootstrap "gui/$uid" "$plist"
  echo "laya: launchd agent com.pglaya.serve installed and started (logs: ~/Library/Logs/laya.serve.*.log)"
  wait_health
else
  echo "laya: no service manager found (no systemd, no launchd) — skipping the service install."
  echo "  The extension files are installed; start the Laya server by hand when you need it:  make serve"
fi

if [ "$port" = "8000" ]; then
  echo "laya: done. The extension's default laya.api_url (http://$host:8000/v1/systemone) points at this server."
else
  echo "laya: done. The server listens on http://$host:$port/v1/systemone — that is not the extension's"
  echo "  default port, so point the extension at it:  SET laya.api_url = 'http://$host:$port/v1/systemone';"
fi
