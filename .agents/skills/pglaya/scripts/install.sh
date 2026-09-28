#!/usr/bin/env bash
# Install the laya extension: `pgxn install laya` (--pgxn) or clone + `make install`, then CREATE EXTENSION.
#
#   bash install.sh [--pgxn | --source DIR] [--ref vX.Y.Z] [--pg-config PATH] [--db NAME] [--no-create] [--sudo]
#
#   --pgxn            install the released distribution from pgxn.org with the pgxn client (pip install pgxnclient);
#                     no clone needed. --ref pins the version (`pgxn install laya=X.Y.Z`)
#   --source DIR      use an existing pg-laya checkout instead of cloning (default: clone into a temp dir;
#                     if the current directory is a pg-laya checkout it is used automatically)
#   --ref REF         git tag/branch to check out after cloning, or the version for --pgxn (default: latest)
#   --pg-config PATH  pg_config of the target server (default: pg_config on PATH)
#   --db NAME         database in which to CREATE EXTENSION (default: $PGDATABASE or the psql default)
#   --no-create       stop after `make install`; print the SQL to run instead
#   --sudo            run `make install` with sudo (needed when the extension dir is owned by root)
#
# psql connection details come from PGHOST/PGPORT/PGUSER/PGPASSWORD. Nothing here is compiled: make install
 # copies laya.control and sql/laya--*.sql into `pg_config --sharedir`/extension, and (unless NO_SERVE=1)
 # installs the companion model server (Ollaya) as a system service on the target machine.
set -euo pipefail

REPO=https://github.com/realZachi/pg-laya.git
source_dir="" ref="" pg_config="${PG_CONFIG:-pg_config}" db="${PGDATABASE:-}" create=1 use_sudo=0 use_pgxn=0
while [ $# -gt 0 ]; do
  case "$1" in
    --pgxn) use_pgxn=1; shift ;;
    --source) source_dir=$2; shift 2 ;;
    --ref) ref=$2; shift 2 ;;
    --pg-config) pg_config=$2; shift 2 ;;
    --db) db=$2; shift 2 ;;
    --no-create) create=0; shift ;;
    --sudo) use_sudo=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if ! command -v "$pg_config" >/dev/null 2>&1; then
  echo "pg_config not found ($pg_config). Install the server dev package (postgresql-server-dev-NN / postgresqlNN-devel) or pass --pg-config." >&2
  exit 2
fi
command -v make >/dev/null 2>&1 || { echo "make not found. Install build-essential / make." >&2; exit 2; }

extdir="$("$pg_config" --sharedir)/extension"
if [ "$use_pgxn" -eq 1 ]; then
  command -v pgxn >/dev/null 2>&1 || { echo "pgxn client not found. Install it with: pip install pgxnclient (or apt install pgxn-client / brew install pgxnclient), or run without --pgxn to install from source." >&2; exit 2; }
  spec="laya${ref:+=${ref#v}}"
  echo "Installing $spec from pgxn.org into $extdir (server: $("$pg_config" --version))"
  pgxn_cmd=(pgxn install "$spec" --pg_config "$pg_config" --yes)
  libdir="$("$pg_config" --pkglibdir)"          # pgxn also wants this writable (it runs the full PGXS install)
  if [ "$use_sudo" -eq 1 ] || { { [ ! -w "$extdir" ] || [ ! -w "$libdir" ]; } && command -v sudo >/dev/null 2>&1; }; then
    pgxn_cmd+=(--sudo)
  else
    pgxn_cmd+=(--nosudo)
  fi
  "${pgxn_cmd[@]}" || { echo "pgxn install failed. If it said the distribution was not found, laya may not be on PGXN yet: re-run without --pgxn to install from source." >&2; exit 1; }
else
  if [ -z "$source_dir" ] && [ -f laya.control ] && [ -d sql ]; then source_dir=$PWD; fi
  if [ -z "$source_dir" ]; then
    command -v git >/dev/null 2>&1 || { echo "git not found." >&2; exit 2; }
    source_dir=$(mktemp -d "${TMPDIR:-/tmp}/pg-laya.XXXXXX")
    echo "Cloning $REPO into $source_dir"
    git clone --quiet --depth 1 ${ref:+--branch "$ref"} "$REPO" "$source_dir"
  fi
  [ -f "$source_dir/laya.control" ] || { echo "$source_dir is not a pg-laya checkout (no laya.control)." >&2; exit 2; }

  version=$(sed -n "s/default_version *= *'\(.*\)'/\1/p" "$source_dir/laya.control")
  echo "Installing laya $version into $extdir (server: $("$pg_config" --version))"

  install_cmd=(make -C "$source_dir" install "PG_CONFIG=$pg_config")
  if [ "$use_sudo" -eq 1 ]; then sudo "${install_cmd[@]}"
  elif [ -w "$extdir" ]; then "${install_cmd[@]}"
  elif command -v sudo >/dev/null 2>&1; then
    echo "$extdir is not writable by $(whoami); running make install with sudo."
    sudo "${install_cmd[@]}"
  else
    echo "$extdir is not writable by $(whoami) and sudo is not available. Run as a user that owns it:" >&2
    echo "  ${install_cmd[*]}" >&2
    exit 1
  fi
fi

sql="CREATE EXTENSION IF NOT EXISTS laya CASCADE; SELECT laya_version();"
if [ "$create" -eq 0 ]; then
  echo "Files installed. Now run as a superuser in each database that needs it:"; echo "  $sql"; exit 0
fi

command -v psql >/dev/null 2>&1 || { echo "psql not found; run this as a superuser in your database:"; echo "  $sql"; exit 0; }
echo "Creating the extension${db:+ in database $db}"
if psql ${db:+-d "$db"} -X -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS laya CASCADE" -c "SELECT laya_version()"; then
  echo "Done. The local model server needs no API key by default; run scripts/smoke_test.sql to verify"
  echo "(make install also installed the server as a system service on this machine — NO_SERVE=1 skips that)."
else
  echo "CREATE EXTENSION failed. Common causes: not a superuser, plpython3u not installed for this server, or the" >&2
  echo "files went into a different Postgres than the one psql connects to (compare --pg-config with the server)." >&2
  exit 1
fi
