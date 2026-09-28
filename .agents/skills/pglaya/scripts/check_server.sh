#!/usr/bin/env bash
# Preflight for pglaya: can this PostgreSQL server run the laya extension, and is it set up?
#
#   bash check_server.sh [psql connection args]        e.g.  bash check_server.sh -h db.example.com -U postgres -d app
#
# Uses PGHOST / PGPORT / PGUSER / PGDATABASE / PGPASSWORD like psql. Exit code 0 = ready to CREATE EXTENSION or
# already installed, 1 = something blocks it (the report says what), 2 = could not connect.
set -uo pipefail

if ! command -v psql >/dev/null 2>&1; then
  echo "psql not found on PATH. Install the PostgreSQL client tools first." >&2; exit 2
fi

q() { psql "$@" -X -A -t -v ON_ERROR_STOP=1 2>&1; }

if ! out=$(q "$@" -c "SELECT 1"); then
  echo "Cannot connect: $out" >&2; exit 2
fi

version=$(q "$@" -c "SELECT split_part(current_setting('server_version'), ' ', 1)")
major=$(q "$@" -c "SELECT current_setting('server_version_num')::int / 10000")
superuser=$(q "$@" -c "SELECT rolsuper FROM pg_roles WHERE rolname = current_user")
dbname=$(q "$@" -c "SELECT current_database()")
plpy_avail=$(q "$@" -c "SELECT count(*) FROM pg_available_extensions WHERE name = 'plpython3u'")
plpy_inst=$(q "$@" -c "SELECT count(*) FROM pg_extension WHERE extname = 'plpython3u'")
laya_avail=$(q "$@" -c "SELECT coalesce(max(default_version), '') FROM pg_available_extensions WHERE name = 'laya'")
laya_inst=$(q "$@" -c "SELECT coalesce(max(extversion), '') FROM pg_extension WHERE extname = 'laya'")
key_guc=$(q "$@" -c "SELECT CASE WHEN coalesce(current_setting('laya.api_key', true), '') <> '' THEN 'set' ELSE '' END")

blockers=0
ok()   { printf '  [ok]   %s\n' "$1"; }
warn() { printf '  [warn] %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; blockers=$((blockers + 1)); }

# Is the local model server reachable? (the extension's default laya.api_url is http://127.0.0.1:11435/v1/systemone)
if (exec 3<>"/dev/tcp/127.0.0.1/11435") 2>/dev/null; then
  exec 3>&- 3<&- 2>/dev/null || true
  ok "local model server (Ollaya) reachable on 127.0.0.1:11435 (the default laya.api_url)"
else
  warn "no local model server on 127.0.0.1:11435; 'make install' normally starts one (systemd 'ollaya' / launchd com.pglaya.ollaya), or run 'make serve', or point laya.api_url elsewhere"
fi

echo "pglaya preflight on database '$dbname'"
if [ "$major" -ge 14 ] && [ "$major" -le 17 ]; then ok "PostgreSQL $version (supported: 14-17)"
elif [ "$major" -gt 17 ]; then warn "PostgreSQL $version is newer than the tested majors (14-17); it will probably work"
else bad "PostgreSQL $version is too old; pglaya needs 14 or newer"; fi

if [ "$plpy_avail" = "1" ]; then ok "plpython3u is available$( [ "$plpy_inst" = "1" ] && echo ' (and already created in this database)')"
else bad "plpython3u is not available. Install postgresql-plpython3-$major (Debian/Ubuntu) or postgresql$major-plpython3 (RHEL). Managed hosts (Supabase, Neon, RDS...) cannot add it."; fi

if [ "$superuser" = "t" ]; then ok "connected as a superuser ($(q "$@" -c 'SELECT current_user'))"
else
  if [ -n "$laya_inst" ]; then warn "not a superuser; fine for using laya, but CREATE/ALTER EXTENSION needs one"
  else bad "not a superuser; CREATE EXTENSION laya requires one because plpython3u is untrusted"; fi
fi

if [ -n "$laya_inst" ]; then
  if [ -n "$laya_avail" ] && [ "$laya_avail" != "$laya_inst" ]; then
    warn "laya $laya_inst is installed; version $laya_avail is on disk. Run: ALTER EXTENSION laya UPDATE;"
  else ok "laya $laya_inst is installed in this database"; fi
elif [ -n "$laya_avail" ]; then
  ok "laya $laya_avail files are on disk; run CREATE EXTENSION laya CASCADE; in this database"
else
  echo "  [todo] laya files are not installed for this server: run scripts/install.sh (make install), then CREATE EXTENSION laya CASCADE"
fi

if [ "$key_guc" = "set" ]; then ok "laya.api_key is set for this session/role/database"
else echo "  [info] laya.api_key is not set; fine while the model server runs without OLLAYA_API_KEY (the default). If the server (or a cloud endpoint) requires a key: SET laya.api_key = '...' or ALTER ROLE ... SET laya.api_key = '...'"; fi

echo
if [ "$blockers" -eq 0 ]; then echo "Verdict: this server can run pglaya."; exit 0
else echo "Verdict: $blockers blocker(s) above must be resolved first."; exit 1; fi
