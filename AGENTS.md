# AGENTS.md

Guidance for AI coding agents (Claude Code, Codex, Cursor, Copilot, …) working in this repository.

`laya` is a PostgreSQL extension that adds plain-language predicates (`WHERE laya(people, 'the name is European')`).
Every row is judged by Laya, a local, non-autoregressive System-1 model, over the `/v1/systemone` protocol — by
default `http://127.0.0.1:11435`, [Ollaya](https://ollaya.dev), a single-binary model server that `make install`
installs as a system service on the Postgres machine; the cloud TypeSafe Jev endpoint is reachable via
`laya.api_url` (same wire protocol).
The whole extension is **one PL/Python function plus SQL wrappers**; there is nothing to compile.

## Documentation

When a question is about *what laya does* or *how to use it* (functions, settings, install, conditions, caveats,
performance), consult the docs at **https://pglaya.com/docs** before answering from the code. Every docs page has a
Markdown twin: append `.md` to the path (`https://pglaya.com/docs.md`, `https://pglaya.com/docs/functions.md`,
`https://pglaya.com/docs/settings.md`, `https://pglaya.com/docs/how-it-works.md`, …). See
https://pglaya.com/docs/for-agents.md.

The docs source lives in the sibling repo `/Users/mahmoudalikhan/dev/pglaya-site` (`content/docs/*.mdx`). Any change
to the SQL API, a setting, a default or documented behaviour must be mirrored there **and** in `README.md` here.
When pointing users at docs, link pglaya.com/docs rather than paraphrasing at length.

`.agents/skills/pglaya/` (symlinked as `.claude/skills/pglaya`) is the **user-facing agent skill** shipped with the
repo and installable via `npx skills add realZachi/pg-laya`: how to install, configure, query and explain pglaya,
plus `scripts/check_server.sh`, `scripts/install.sh` and `scripts/smoke_test.sql`. It states defaults, function
signatures and error messages, so update it together with README and docs when those change. This AGENTS.md is
for working *on* the extension; the skill is for working *with* it.

## Commands

```bash
make docker-test                  # full regression run in a throwaway container (PG_MAJOR=16 default)
make docker-test PG_MAJOR=14      # oldest supported major; CI runs 14, 15, 16, 17
make install                      # copy control + SQL into the server's extension dir AND install the companion
                                   # model server (Ollaya) as a system service on this machine (systemd/launchd;
                                   # NO_SERVE=1 skips, e.g. in containers — that's what test/Dockerfile and CI rely on)
make install PG_CONFIG=/path/to/pg_config
make install-serve                # (re)install just the companion model server's service
make serve                        # run the model server in the foreground (127.0.0.1:11435)
python3 test/mock_api.py &        # deterministic stand-in for the /v1/systemone API (Laya or TypeSafe) on 127.0.0.1:8765
make installcheck                 # pg_regress against a running server; needs mock_api.py running
bash test/run.sh                  # what CI does: temp cluster (PGPORT=5499) + mock API + make installcheck
make dist                         # PGXN zip from git HEAD
```

Run a single test: `make installcheck REGRESS="01_basic 03_streaming"` (tests are `test/sql/<name>.sql`, expected
output in `test/expected/<name>.out`, failures land in `test/regression.diffs` and `test/results/`). Only
`01_basic.sql` runs `CREATE EXTENSION laya`, so it must be included, or pass `REGRESS_OPTS="... --load-extension=laya"`.

When a test's output changes intentionally, copy `test/results/<name>.out` over `test/expected/<name>.out` and
review the diff. Tests **never** call the live API; `test/run.sh` unsets `LAYA_API_KEY`/`TYPESAFE_API_KEY`.

There is no linter. `.editorconfig` applies (4-space indent, tabs in the Makefile, 2 spaces in yml/json/md).

## Architecture

### Where the code is

- `sql/laya--<version>.sql` — the entire extension. `_laya_eval(rel_type, row_json, query, kind, options)` is a
  ~450-line `plpython3u` function; the public functions (`laya`, `laya_prob`, `laya_score`, `laya_score_norm`,
  `laya_choice`, `laya_confidence`, `laya_eval`) are thin SQL wrappers that call it with
  `pg_typeof(row)::text` and `to_json(row)::text`. `laya_stats`, `laya_cache_clear`, `laya_version` are separate.
- `sql/laya--<old>--<new>.sql` — upgrade scripts. Every object is `CREATE OR REPLACE`, so an upgrade script is a
  copy of the full script with the `\echo` guard changed to `ALTER EXTENSION laya UPDATE`.
- `laya.control` (`default_version`), `META.json` (PGXN), `CHANGELOG.md` — must all agree on the version; CI's
  `lint-meta` job checks `laya.control` == `META.json` and that `sql/laya--<version>.sql` exists.
- `scripts/install_service.sh` (+ the `scripts/ollaya.conf` systemd unit template, `scripts/serve.sh`) — installs
  the companion model server ([Ollaya](https://ollaya.dev), a single binary installed via
  `curl -fsSL https://ollaya.dev/install.sh | sh` if not already present) as a systemd unit `ollaya` on Linux or a
  launchd agent `com.pglaya.ollaya` on macOS, starts it and polls `http://127.0.0.1:11435/`, then pulls the
  `laya` model (~1.5 GB, non-fatal if the pull fails — models load on demand). Service config:
  `/etc/laya/env` + `/etc/systemd/system/ollaya.service` (Linux; logs via `journalctl -u ollaya`) or
  `~/Library/LaunchAgents/com.pglaya.ollaya.plist` (macOS; logs in `~/Library/Logs/ollaya.serve.*.log`).
  `OLLAYA_HOST` / `OLLAYA_API_KEY` / `OLLAYA_DEVICE` / `OLLAYA_KEEP_ALIVE` are passed through when set;
  `LAYA_MODEL` selects the checkpoint to pull (default `laya`, the router); a non-default `OLLAYA_HOST` makes the
  installer print the `laya.api_url` the extension needs. A server already listening on the address (not ours)
  is left running — the installer advises, pulls the model and exits. `make install` runs it as a prerequisite
  of the PGXS install; `NO_SERVE=1` skips it (containers, CI).
- `test/mock_api.py` — the fake API. Its rules decide expected output: `noul` → 0.9 if the *last word* of
  the condition appears in the row JSON else 0.1; `score`/`choice` → index = `len(row_json) % n`; a condition
  containing `trigger422` returns HTTP 422; auth requires `Bearer test-key` (requests without an Authorization
  header get 401 — the no-key path, since the extension only sends a key when one is configured). It accepts
  both request shapes: the `jev` state `{"condition", "rows"}` and `native` (state is the row itself, the noul
  condition is parsed out of the question's instructions) — `laya.state_mode = 'native'` forces one row per
  request regardless of `laya.batch_size`.

### How one statement runs (the part that needs several files to understand)

1. The SQL wrapper serialises the row with `to_json` (column order preserved) and passes the relation type name.
2. `_laya_eval` keys everything on `cache_key = [rel_type, query, kind, options]` and `row_hash = sha1(row_json)`.
   Cache hit → return immediately (no SPI call).
3. On the first miss for a table + question it creates a **job**: a read-ahead that streams the relation in
   physical order via SPI — TID range scans (`WHERE ctid >= $1 AND ctid < $2`) for tables/matviews, `OFFSET/LIMIT`
   pages for views/partitioned/foreign tables, `PAGE_ROWS = 1000` per SPI query. Rows from a subquery/CTE
   (anonymous `record`) have no relation and are judged one request at a time.
4. Rows are packed `laya.batch_size` (20) per request into one shared `state` with one question per row
   (`build_question`, `request_body`), sent from a per-session `ThreadPoolExecutor` over pooled keep-alive
   `http.client` connections (`borrow_conn`/`release_conn`, retries honour `Retry-After`). Up to
   2 × `laya.concurrency` requests are in flight; `answer()` waits on the row's future in 250 ms slices so
   `statement_timeout`/cancel work. `laya.state_mode = 'native'` (for the local Laya model, which smears
   answers across rows in a shared state) sends the row itself as `state` with the condition in the question,
   one row per request — `laya.batch_size` is forced to 1 by `load_cfg`.
5. Rows the executor never asks for (filtered by cheaper predicates, or cut off by `LIMIT`) are kept in
   `skipped`/`skipped_map` (bounded by `laya.max_prefetch_rows`) and batched with neighbours if requested later.
6. All state lives in PL/Python `GD["laya"]` for the backend session: cache, jobs, stats, prepared plans, thread
   pool, connection pool and the per-statement spend guard (`laya.max_rows_per_statement` /
   `laya.max_chars_per_statement`, keyed on `statement_timestamp()`). `STATE_VERSION` resets it on upgrade.
7. Settings are plain GUCs read in a single SPI query per cache miss (`load_cfg`); defaults live there and in
   the header comment of the SQL file, README and docs — keep all four in sync.

Threads must never touch `plpy`; only the main thread does SPI, `plpy.notice` and `plpy.error`.

## Rules for changes

- Every behaviour change needs a regression test in `test/sql/` with matching `test/expected/` output, written
  against the mock API's rules above.
- Keep the SQL API stable. New functions are fine; changing a signature needs a major version and an upgrade script.
- Changing the model prompt (`instructions`/`criteria` in `build_question`) changes results for every user: include
  what was measured on real data (see the "Why 20 rows per request" numbers in README/CHANGELOG for the bar).
- Don't raise `laya.batch_size` defaults above ~20: accuracy measurably drops because the model locates `rows[i]`
  by position.
- Release: bump `laya.control`, add `sql/laya--X.Y.Z.sql` and `sql/laya--OLD--X.Y.Z.sql`, update `laya_version()`,
  `META.json`, `CHANGELOG.md`, then tag `vX.Y.Z` (the release workflow builds the PGXN zip). Full checklist in
  `docs/PUBLISHING.md`.
- Supported: PostgreSQL 14–17 with `plpython3u`. Only superusers can `CREATE EXTENSION laya`.
