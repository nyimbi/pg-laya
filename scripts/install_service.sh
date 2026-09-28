#!/usr/bin/env bash
# Install Ollaya — the companion model server for the laya extension — as a system service on
# this machine (the machine that runs PostgreSQL). `make install` runs this after installing the
# extension files; `make install-serve` runs it on its own.
#
#   Linux:   systemd unit   /etc/systemd/system/ollaya.service   (sudo when not root)
#   macOS:   launchd agent  ~/Library/LaunchAgents/com.pglaya.ollaya.plist   (no sudo)
#   neither: no service manager (containers, CI) — prints how to start the server by hand and exits 0
#
# Ollaya (https://ollaya.dev) is a single binary — CLI plus server — that serves the Laya decision
# models over a TypeSafe-compatible /v1 API on 127.0.0.1:11435, where the extension's default
# laya.api_url points. The binary comes from ollaya.dev's sha256-verified release install script;
# the `laya` model (a router over laya:en / laya:multilingual) is pulled into the server's model
# store (~/.ollaya/models, ~1.5 GB, sha256-verified, resumable). Models load on first use;
# OLLAYA_KEEP_ALIVE (default 5m) keeps them warm.
#
#   make install NO_SERVE=1                       # skip the server entirely
#   OLLAYA_HOST=0.0.0.0:9000 make install-serve   # different bind address
#   OLLAYA_API_KEY=secret make install-serve      # require bearer auth (set the same key in laya.api_key)
#   OLLAYA_DEVICE=cpu make install-serve          # auto (default; GPU when available), cpu, cuda[:N]
#   LAYA_MODEL=laya:en make install-serve         # pull a specific checkpoint instead of the router
set -euo pipefail
cd "$(dirname "$0")/.."

host="${OLLAYA_HOST:-127.0.0.1:11435}"
key="${OLLAYA_API_KEY:-}"
device="${OLLAYA_DEVICE:-auto}"
keepalive="${OLLAYA_KEEP_ALIVE:-}"
model="${LAYA_MODEL:-laya}"

# ---------------------------------------------------------------- the ollaya binary
find_ollaya() {
  command -v ollaya && return 0
  for d in "$HOME/.local/bin" /usr/local/bin /opt/homebrew/bin /usr/bin; do
    [ -x "$d/ollaya" ] && { echo "$d/ollaya"; return 0; }
  done
  return 1
}

if [ -z "$(find_ollaya)" ]; then
  echo "laya: installing Ollaya from ollaya.dev (sha256-verified release download)"
  curl -fsSL https://ollaya.dev/install.sh | sh
fi
ollaya_bin="$(find_ollaya || true)"
if [ -z "$ollaya_bin" ]; then
  echo "laya: the 'ollaya' binary was not found on PATH after installation." >&2
  echo "  Run it yourself:  curl -fsSL https://ollaya.dev/install.sh | sh" >&2
  echo "  then re-run: make install-serve   (or install just the extension:  make install NO_SERVE=1)" >&2
  exit 1
fi
echo "laya: using $ollaya_bin ($("$ollaya_bin" -v 2>/dev/null | head -n1 || echo version unknown))"

wait_health() {
  # The server starts without any model loaded, so this is usually a couple of seconds.
  local i
  for i in $(seq 1 30); do
    if curl -fsS "http://$host/" >/dev/null 2>&1; then
      echo "laya: server is up on http://$host"
      return 0
    fi
    sleep 2
  done
  echo "laya: http://$host/ has not answered yet; check the service logs and re-probe with" >&2
  echo "  curl -fsS http://$host/" >&2
  return 0
}

pull_model() {
  # Pull through the running server (a bare `ollaya pull` would start its own background
  # server when none is running); the server stores the model in its own model directory.
  # Non-fatal: a failed download must not break the extension install — re-run `ollaya pull` later.
  echo "laya: pulling the '$model' model (sha256-verified, resumable; ~1.5 GB for the router)"
  "$ollaya_bin" pull "$model" || {
    echo "laya: the model pull did not finish (network?); re-run later with:  $ollaya_bin pull $model" >&2
    return 0
  }
  if ! curl -fsS "http://$host/api/tags" 2>/dev/null | grep -q '"model"'; then
    echo "laya: the model does not appear in /api/tags yet; check the service logs" >&2
    return 0
  fi
  echo "laya: model is available: $(curl -fsS "http://$host/api/tags" | tr -d ' \n' | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | paste -sd' ' -)"
}

have_systemd=0
have_launchd=0
command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && have_systemd=1
command -v launchctl >/dev/null 2>&1 && have_launchd=1

# A server that is already running but not ours (the desktop app, a manual `ollaya serve`, or
# ollaya's own installer) would make our unit's `ollaya serve` exit immediately — detect it and
# leave the running server alone instead of starting a competing service.
ours_running=0
[ "$have_launchd" = 1 ] && launchctl list "com.pglaya.ollaya" >/dev/null 2>&1 && ours_running=1
[ "$have_systemd" = 1 ] && systemctl is-active --quiet ollaya 2>/dev/null && ours_running=1
if curl -fsS "http://$host/" >/dev/null 2>&1 && [ "$ours_running" = 0 ]; then
  echo "laya: a model server is already running on http://$host and is not the pglaya service."
  echo "  The extension works against it as is (laya.api_url http://$host/v1/systemone, model 'laya')."
  echo "  To hand it over to the service, stop it first (pkill -f 'ollaya serve', or quit the Ollaya"
  echo "  desktop app), then re-run: make install-serve"
  pull_model
  exit 0
fi

if [ "$have_systemd" = 1 ]; then
  sudo=""
  [ "$(id -u)" = 0 ] || sudo="sudo"
  envf="$(mktemp)"; unitf="$(mktemp)"
  {
    echo "OLLAYA_HOST=$host"
    [ -n "$key" ] && echo "OLLAYA_API_KEY=$key"
    [ "$device" != "auto" ] && echo "OLLAYA_DEVICE=$device"
    [ -n "$keepalive" ] && echo "OLLAYA_KEEP_ALIVE=$keepalive"
  } > "$envf"
  sed "s|__OLLAYA__|$ollaya_bin|" scripts/ollaya.conf > "$unitf"
  "$sudo" install -d /etc/laya
  "$sudo" install -m 600 "$envf" /etc/laya/env
  # Replaces any unit a previous version (or ollaya's own installer) left behind: same name,
  # same binary, our environment file.
  "$sudo" install -m 644 "$unitf" /etc/systemd/system/ollaya.service
  rm -f "$envf" "$unitf"
  "$sudo" systemctl daemon-reload
  "$sudo" systemctl enable --now ollaya.service
  echo "laya: systemd service 'ollaya' installed and started (logs: journalctl -u ollaya -f)"
  wait_health
  pull_model
elif [ "$have_launchd" = 1 ]; then
  mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
  plist="$HOME/Library/LaunchAgents/com.pglaya.ollaya.plist"
  uid="$(id -u)"
  # Migrate the pre-Ollaya python service, if this machine has it.
  if [ -f "$HOME/Library/LaunchAgents/laya.serve.plist" ]; then
    launchctl bootout "gui/$uid/com.pglaya.serve" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/laya.serve.plist"
    echo "laya: removed the previous (python) com.pglaya.serve agent"
  fi
  launchctl bootout "gui/$uid/com.pglaya.ollaya" 2>/dev/null || true
  optlines=""
  add_kv() { optlines="${optlines}    <key>$1</key><string>$2</string>
"; }
  [ -n "$key" ] && add_kv OLLAYA_API_KEY "$key"
  [ "$device" != "auto" ] && add_kv OLLAYA_DEVICE "$device"
  [ -n "$keepalive" ] && add_kv OLLAYA_KEEP_ALIVE "$keepalive"
  optlines="${optlines%$'\n'}"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.pglaya.ollaya</string>
  <key>ProgramArguments</key>
  <array>
    <string>$ollaya_bin</string>
    <string>serve</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>OLLAYA_HOST</key><string>$host</string>
$optlines
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/ollaya.serve.out.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/ollaya.serve.err.log</string>
</dict>
</plist>
PLIST
  launchctl bootstrap "gui/$uid" "$plist"
  echo "laya: launchd agent com.pglaya.ollaya installed and started (logs: ~/Library/Logs/ollaya.serve.*.log)"
  wait_health
  pull_model
else
  echo "laya: no service manager found (no systemd, no launchd) — skipping the service install."
  echo "  The extension files are installed; start the server by hand when you need it:"
  echo "    $ollaya_bin serve          # then, from another shell:  $ollaya_bin pull $model"
  echo "  (or use the official installer:  curl -fsSL https://ollaya.dev/install.sh | sh)"
fi

if [ "$host" = "127.0.0.1:11435" ] && [ "$model" = "laya" ]; then
  echo "laya: done. The extension's defaults (laya.api_url http://$host/v1/systemone, laya.model 'laya') point at this server."
else
  echo "laya: done."
  if [ "$host" != "127.0.0.1:11435" ]; then
    echo "  the server listens on http://$host — that is not the extension's default, so point it at the server:"
    echo "    SET laya.api_url = 'http://$host/v1/systemone';"
  fi
  if [ "$model" != "laya" ]; then
    echo "  the extension's default model is 'laya'; for this server's model:"
    echo "    SET laya.model = '$model';"
  fi
fi
