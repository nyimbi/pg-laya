# Installing pglaya

Docs: https://pglaya.com/docs/getting-started/where-it-runs.md,
https://pglaya.com/docs/getting-started/installation.md, https://pglaya.com/docs/getting-started/docker.md,
https://pglaya.com/docs/getting-started/quick-start.md

## Requirements (check before anything else)

| Requirement | Why | How to check |
| --- | --- | --- |
| PostgreSQL 14, 15, 16 or 17 | tested majors (CI runs all four) | `SHOW server_version;` |
| `plpython3u` available | the extension is one PL/Python function | `SELECT * FROM pg_available_extensions WHERE name = 'plpython3u';` |
| superuser | `plpython3u` is an untrusted language; only superusers may `CREATE EXTENSION laya` | `SELECT rolsuper FROM pg_roles WHERE rolname = current_user;` |
| Python ≥ 3.10 with `pip` on the Postgres machine | the companion Laya server (`pip` package `laya[serve]`) runs there; `make install` installs it as a system service | `python3 --version` |
| no API key, by default | the local server runs unauthenticated; a key is only needed if you enable `LAYA_API_KEY` or use the cloud Jev model | — |

`scripts/check_server.sh` runs the SQL checks and prints a verdict. It accepts the same connection arguments as
`psql` (`-h`, `-p`, `-U`, `-d`, or a URI) and honours `PGHOST`/`PGUSER`/`PGDATABASE`/`PGPASSWORD`.

### Hosts where it cannot run

Supabase, Neon, Crunchy Bridge, most Cloud SQL / RDS / Aurora / Azure Database setups: they withhold superuser
or do not ship `plpython3u`. There is no workaround short of running your own Postgres (VM, bare metal, Docker,
Kubernetes). Say so up front; do not send users down a build path that ends at `permission denied`.

### Getting `plpython3u`

| Platform | Package / note |
| --- | --- |
| Debian / Ubuntu (PGDG or distro packages) | `apt install postgresql-plpython3-NN` (NN = major, e.g. `16`) |
| RHEL / Fedora / Rocky (PGDG) | `dnf install postgresqlNN-plpython3` |
| macOS Postgres.app | included |
| EDB installers (Windows, macOS, Linux) | included (choose the language pack if asked) |
| Homebrew `postgresql@NN` | built with Python; `plpython3u` is available |
| Official `postgres:NN` Docker image | not included; the repo `Dockerfile` adds `postgresql-plpython3-NN` |

`laya.control` lists `plpython3u` in `requires`, but Postgres only creates a required extension for you with
`CASCADE`. Without it a fresh database fails with `required extension "plpython3u" is not installed`, so always
write `CREATE EXTENSION laya CASCADE` (or create `plpython3u` first).

## Install from PGXN

The release is published on the PostgreSQL Extension Network (https://pgxn.org/dist/laya/). `pgxn install`
downloads the distribution and runs the same `make install` as the source path, so it needs `make` and the
target server's `pg_config` too, but no git clone and no checkout to keep around.

```bash
pip install pgxnclient                   # once; also `apt install pgxn-client` / `brew install pgxnclient`
pgxn install laya                         # latest release, pg_config from PATH
pgxn install laya --pg_config=/usr/lib/postgresql/16/bin/pg_config
sudo pgxn install laya                    # when the extension directory is root-owned
pgxn install 'laya=0.2.0'                 # pin a version
```

Then `CREATE EXTENSION laya CASCADE;` as a superuser (see below). `scripts/install.sh --pgxn` does both steps and
maps `--pg-config`, `--ref` and `--sudo` onto the `pgxn` flags. If `pgxn install laya` reports that the
distribution is not found, the release is not on PGXN yet: fall back to source.

## Install from source (PGXS)

There is nothing to compile: `make install` copies `laya.control` and `sql/laya--*.sql` into the extension
directory of the Postgres that `pg_config` points at, **and installs the companion Laya server as a system
service on that machine** (systemd on Linux, launchd on macOS; `NO_SERVE=1` skips the service — containers,
CI, or when the server runs elsewhere). You need `make` and `pg_config` (package
`postgresql-server-dev-NN` on Debian/Ubuntu, `postgresqlNN-devel` on RHEL; included in Postgres.app/EDB/Homebrew),
plus Python ≥ 3.10 with `pip` for the service part.

```bash
git clone https://github.com/realZachi/pg-laya.git && cd pg-laya
make install                                   # pg_config from PATH
make install PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config   # or a specific server
```

`make install` may need `sudo` when the extension directory is owned by root (typical for distro packages):
`sudo make install PG_CONFIG=...`.

Then, connected as a superuser to the target database:

```sql
CREATE EXTENSION laya CASCADE;    -- CASCADE also creates plpython3u
SELECT laya_version();
```

`scripts/install.sh` automates this: it clones (or uses `--source DIR`, or `pgxn install` with `--pgxn`), runs `make install` with the chosen
`pg_config`, and runs `CREATE EXTENSION IF NOT EXISTS laya CASCADE` in `--db`. Use `--ref vX.Y.Z` to pin a release and
`--no-create` to skip the SQL step (e.g. when the SQL must run as a different user).

The extension is created per database. Repeat `CREATE EXTENSION laya CASCADE` in every database that needs it.

### Upgrading

```bash
git pull && make install PG_CONFIG=...
```

```sql
ALTER EXTENSION laya UPDATE;      -- runs sql/laya--OLD--NEW.sql
SELECT laya_version();
```

Session state (`GD`) is versioned, so already-connected sessions pick up the new code on their next call.

## Docker

For trying it out, or when the host Postgres cannot take `plpython3u`:

```bash
git clone https://github.com/realZachi/pg-laya.git && cd pg-laya
docker build -t pg-laya .                          # postgres:16 + plpython3u + laya files
docker build --build-arg PG_MAJOR=17 -t pg-laya .  # another major
docker run -d --name pg-laya -p 5432:5432 -e POSTGRES_PASSWORD=pw pg-laya
psql postgres://postgres:pw@localhost/postgres -c "CREATE EXTENSION laya CASCADE"
```

The image does not create the extension automatically, and it runs no service manager — so the companion
Laya server is not in the container. Run it elsewhere and point the extension at it
(`SET laya.api_url = 'http://<server-host>:8000/v1/systemone';`), or use the cloud Jev model. To have the
extension created on first start, mount an init script:
`echo 'CREATE EXTENSION laya CASCADE;' > init.sql` and add `-v $PWD/init.sql:/docker-entrypoint-initdb.d/laya.sql`.

## API key (optional)

No key is needed by default: the local Laya server runs unauthenticated, and the extension only sends an
`Authorization` header when a key is configured. If the server was started with `LAYA_API_KEY` (in
`/etc/laya/env` on Linux or the launchd plist on macOS), the extension must carry the same token.

`laya.api_key` is read on every cache miss with this precedence: GUC (`SET`, role, database,
`postgresql.conf`) → `LAYA_API_KEY` in the environment of the **postgres server process**
(`TYPESAFE_API_KEY` is still honoured as a deprecated fallback). The client's shell environment is irrelevant.

| Scope | How | Use when |
| --- | --- | --- |
| this session | `SET laya.api_key = '...';` | trying it out, notebooks |
| one role, persistent | `ALTER ROLE analyst SET laya.api_key = '...';` | per-team keys, shared server |
| one database | `ALTER DATABASE app SET laya.api_key = '...';` | one key per app |
| whole server | `LAYA_API_KEY` in the service environment (systemd `Environment=`, Docker `-e`) | single-tenant server |

For the cloud Jev model the key is a TypeSafe key (https://console.typesafe.ai), set the same way, together
with `SET laya.api_url = 'https://api.typesafe.ai/v1/systemone';`.

Role/database settings are visible to that role via `SHOW laya.api_key`; keep keys out of committed SQL files and
dashboards. `scripts/smoke_test.sql` never prints the key.

## Verify

```bash
psql -d mydb -f scripts/smoke_test.sql
```

Expected: a temp table of five rows, one result per function, a `NOTICE` like
`laya: noul → judged 5 rows of laya_smoke in 1 request, ~300 input tokens (≈$0.0000), … ms` and a `laya_stats()`
row with `requests ≥ 1` and `errors = 0`.

## Troubleshooting

| Message / symptom | What it means | Fix |
| --- | --- | --- |
| `could not open extension control file ".../laya.control"` | files were installed into another Postgres | `make install PG_CONFIG=<pg_config of the server you connect to>`; compare `pg_config --sharedir` with `SHOW data_directory`/version |
| `could not open extension control file ".../plpython3u.control"` | PL/Python not installed | install `postgresql-plpython3-NN`; on managed hosts: not possible |
| `required extension "plpython3u" is not installed` | `CREATE EXTENSION laya` without `CASCADE` on a database where PL/Python was never created | `CREATE EXTENSION laya CASCADE;` |
| `pgxn: command not found` | pgxnclient not installed | `pip install pgxnclient` (or the distro package), or use the source path |
| `pgxn install laya` → distribution not found / no release | not on PGXN (yet), or a typo in the pin | check https://pgxn.org/dist/laya/; install from source |
| `permission denied to create extension "laya"` / `must be superuser` | not a superuser | connect as one (`postgres`) or ask the DBA |
| `laya: API unreachable after retries: … Connection refused` (against 127.0.0.1:8000) | the local Laya server is not running | `systemctl status laya` (Linux) / `launchctl list \| grep com.pglaya.serve` (macOS); or `make serve` in the foreground; `make install` normally starts it |
| `laya: API error 401 {...}` | endpoint requires a bearer token that was not sent or is wrong | set `laya.api_key` to the server's `LAYA_API_KEY` (or the TypeSafe key for the cloud model) |
| `laya: API error 422 {...}` | request rejected (bad model name, malformed options) | check `laya.model`, options arrays |
| `laya: API error 413 {...}` | batch over the local server's limits (64 questions / 50k chars state / 2 MB body) | lower `laya.batch_size`, or a view with fewer, narrower columns |
| `laya: API error 429/5xx` after retries | cloud rate limit / outage; the extension retries with `Retry-After` | lower `laya.concurrency`, retry later |
| connection errors / timeouts against a cloud `laya.api_url` | server cannot reach `api.typesafe.ai:443` | egress firewall, proxy (`laya.api_url` can point at a proxy) |
| `laya: this statement would send N rows … above laya.max_rows_per_statement` | spend guard | pre-filter in SQL, or raise the guard deliberately |
| `NOTICE`s show one request per row | `laya()` on a CTE/subquery (`record`) | call it on the base table or a view |
| `CREATE EXTENSION` works but functions are missing in another database | extensions are per database | `CREATE EXTENSION laya CASCADE` there too |
| a `LIMIT 1` query still takes seconds | the first request on a fresh connection pays TLS + server setup (up to ~1.5 s); after that ~0.3 s | keep sessions alive; `laya.keepalive` (600 s) keeps pooled connections |

`SELECT laya_stats();` (`errors`, `retries`, `requests`, `api_ms`) tells you whether calls are reaching the API.
`SET laya.notices = on;` (default) prints progress per request.
