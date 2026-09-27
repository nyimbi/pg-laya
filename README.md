<p align="center">
  <img src="docs/assets/header.svg" alt="pg-laya — ask your Postgres tables questions in plain language" width="100%">
</p>

# laya — ask your Postgres tables questions in plain language

[![CI](https://github.com/realZachi/pg-laya/actions/workflows/ci.yml/badge.svg)](https://github.com/realZachi/pg-laya/actions/workflows/ci.yml)
[![PGXN](https://badge.fury.io/pg/laya.svg)](https://pgxn.org/dist/laya/)
[![License](https://img.shields.io/badge/license-PostgreSQL-blue.svg)](LICENSE)
[![Website](https://img.shields.io/badge/website-pglaya.com-0a56cf.svg)](https://pglaya.com)

Write the condition the way you would say it. Postgres does the rest.

`laya` lets you filter, rank and classify rows with plain-language conditions. Every row is judged by
[Laya](https://github.com/NandhaKishorM/laya), a local, non-autoregressive System-1 model that returns
calibrated probabilities instead of generated text. No index, no embeddings, no vector column.

The model is pluggable over the `/v1/systemone` protocol: by default every row is judged by a local
companion Laya server on the same machine (`http://127.0.0.1:8000`, installed by `make install`), and
`laya.api_url` can point at the cloud [TypeSafe Jev](https://docs.typesafe.ai) model instead (same wire
protocol, no code change). Laya runs one inference at a time, so keep `laya.concurrency` low (2-4).

Website: [pglaya.com](https://pglaya.com)

```sql
CREATE EXTENSION laya CASCADE;

SELECT * FROM people WHERE laya(people, 'the name is European');

SELECT subject, laya_prob(tickets, 'the customer is angry') AS p
FROM tickets ORDER BY p DESC LIMIT 20;

SELECT laya_choice(tickets, 'which team should handle this?',
                  ARRAY['billing', 'technical', 'security', 'sales']) AS team, count(*)
FROM tickets GROUP BY 1;

SELECT name, laya_score(products, 'how luxurious is this product?',
                       ARRAY['budget', 'mid-range', 'premium', 'luxury']) AS luxury
FROM products ORDER BY luxury DESC;
```

`laya()` is an ordinary boolean function, so it composes with everything else in SQL: `AND age > 40`,
joins, `GROUP BY`, `LIMIT`, `ORDER BY laya_prob(...)`.

## How it works

1. `laya(table, 'condition')` receives the row as a composite value. The first call for a table + condition starts a
   read-ahead that streams the table in physical order (TID range scans; `OFFSET` pages for views), so memory stays
   constant whatever the table size.
2. Rows are packed `laya.batch_size` (20) per request into one shared *state*
   (`{"condition": ..., "rows": [...]}`) with one yes/no [Noul](https://docs.typesafe.ai/primitives/noul)
   question per row. Laya evaluates all questions over one state in a single forward pass, which amortises
   the ~270-token request overhead (about 435 tokens for one row alone vs 175 per row in batches of 20).
3. Up to 2 × `laya.concurrency` requests are in flight over persistent HTTPS connections, and every row is answered
   as soon as its batch returns, so a `LIMIT` stops the read-ahead after the in-flight window, and rows that cheaper
   predicates filter out before `laya()` runs (`WHERE age > 60 AND laya(...)`) are skipped rather than judged.
4. Answers are cached per row content for the session, so re-running, changing the threshold or sorting by
   probability is free. Rows from a subquery or CTE (anonymous `record` type) can't be read ahead and are judged
   one request at a time; put `laya()` on base tables or views when you can.

Measured against the cloud Jev API on a 2,000-row table from Europe (~190 ms to the API): first run ≈ 3.5 s in
100 requests, ≈ 296k input tokens, ≈ $0.012; second run ≈ 50 ms; `LIMIT 3` on a new condition ≈ 0.6 s. A new
condition in a session that still holds its pooled connections (idle for less than `laya.keepalive`) takes
≈ 2.3 s: the first request on each fresh connection is the slow one. Version 0.1.0 needed 8.5 s (and 338k
tokens) for the full query and 8.4 s for the `LIMIT`. Against the local server the same numbers are local
inference time instead of network round trips.

### Why 20 rows per request

The model has to find `rows[i]` by position in the array, and that gets unreliable in long arrays. Against
ground truth from structured columns (job title, EU membership, a phrase in a free-text field; 400 rows
each), batches of 1–20 rows were 100 % correct, batches of 40 were 92–98 % and batches of 80 were 77–94 %.
Wider rows (1,000 characters) made no difference at 20. Naming rows instead of indexing them did not help.
Batches of 20 cost 4 % more tokens than batches of 40 and are just as fast, because a request's latency
barely depends on its size.

## Install

Requirements: PostgreSQL 14–17 with `plpython3u` (package `postgresql-plpython3-NN` on Debian/Ubuntu,
included in the EDB and Postgres.app builds), and a superuser. The Laya model runs in a companion server
on the same machine, so no cloud API key is required. `make install` installs the extension **and** the
companion server as a system service (Python ≥ 3.10 with `pip` is needed for that part). Managed hosts
that withhold superuser or `plpython3u` (Supabase, Neon, RDS, …) cannot run it; see
[Where it runs](https://pglaya.com/docs/getting-started/where-it-runs).

### The local Laya server

`laya` talks to a local server by default, and `make install` sets it up for you: it installs the
`laya[serve]` Python package and starts the server as a system service — a systemd unit (`laya.service`)
on Linux, a launchd agent (`com.pglaya.serve`) on macOS — bound to `http://127.0.0.1:8000`, where the
extension's default `laya.api_url` points. In containers and CI there is no service manager, so it prints
how to start the server by hand instead. `NO_SERVE=1 make install` skips the service entirely.

Useful knobs (all optional):

```bash
make serve                        # run it in the foreground instead (127.0.0.1:8000, preloads checkpoints)
LAYA_HOST=0.0.0.0 LAYA_PORT=9000 make install-serve   # re-install the service with different host/port
LAYA_API_KEY=secret make install-serve                # require bearer auth (set the same key in laya.api_key)
curl -fsS http://127.0.0.1:8000/health               # health probe
```

The service preloads the model checkpoints at boot (`LAYA_PRELOAD=1`) so the first `laya()` isn't paying
model load. To query the cloud [TypeSafe Jev](https://docs.typesafe.ai) model instead,
`SET laya.api_url = 'https://api.typesafe.ai/v1/systemone';` and set a TypeSafe API key (see below).

### With an AI agent (easiest)

The repo ships an [agent skill](.agents/skills/pglaya/SKILL.md) on [skills.sh](https://skills.sh). Install it into
your project and tell Claude Code, Codex, Cursor or any other skill-aware agent to finish the job:

```bash
npx skills add realZachi/pg-laya
```

> Install pglaya on this server and set it up.

The agent runs a preflight (PostgreSQL version, `plpython3u`, superuser), `pgxn install laya` or `make install` against the right
`pg_config` (which also installs the companion Laya server as a service), `CREATE EXTENSION laya CASCADE`
and runs a smoke test. Afterwards it also knows how to write cost-conscious `laya()` queries ("find the tickets
where the customer threatens to cancel") and to explain what pglaya can do. The docs are readable as Markdown
for agents too: append `.md` to any page under https://pglaya.com/docs (see [For agents](https://pglaya.com/docs/for-agents)).

### From PGXN

```bash
pip install pgxnclient       # once; also available as `pgxn-client` in Debian/Ubuntu and Homebrew
pgxn install laya             # downloads the release from pgxn.org and runs `make install` against pg_config on PATH
psql -c "CREATE EXTENSION laya CASCADE"
```

Use `pgxn install laya --pg_config=/path/to/pg_config` (or `sudo pgxn install laya`) when the server's `pg_config`
is not on PATH or the extension directory is not writable.

### From source (PGXS)

```bash
git clone https://github.com/realZachi/pg-laya.git && cd pg-laya
make install            # uses pg_config on PATH; or: make install PG_CONFIG=/path/to/pg_config
                        # also installs the companion Laya server as a service (NO_SERVE=1 skips it)
psql -c "CREATE EXTENSION laya CASCADE"   # superuser required (plpython3u is untrusted); CASCADE creates plpython3u
```

### Docker

```bash
docker build -t pg-laya .                       # add --build-arg PG_MAJOR=17 for another major
docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=pw pg-laya
psql postgres://postgres:pw@localhost/postgres -c "CREATE EXTENSION laya CASCADE"
```

The container runs no service manager, so `make install` inside the image skips the companion server.
Run the Laya server outside the container (another container, or on the host) and point the extension at
it: `SET laya.api_url = 'http://<server-host>:8000/v1/systemone';` — or use the cloud Jev model (below).

### API key

None by default: the local Laya server runs unauthenticated, and the extension only sends an
`Authorization` header when a key is configured. If you enable auth on the server
(`LAYA_API_KEY=secret make install-serve`, or `LAYA_API_KEY` in its environment), give the extension the
same token — per session, per role, or in the environment of the PostgreSQL server process:

```sql
SET laya.api_key = 'secret';
ALTER ROLE analyst SET laya.api_key = 'secret';   -- persistent, per role
```

To use the cloud Jev model instead, set a TypeSafe key the same way
(`SET laya.api_key` / `ALTER ROLE … SET laya.api_key` / `LAYA_API_KEY` in the server environment) together
with `SET laya.api_url = 'https://api.typesafe.ai/v1/systemone';`.

## Functions

| Function | Returns | Purpose |
| --- | --- | --- |
| `laya(row, condition [, threshold])` | boolean | `WHERE` predicate. Threshold: argument → `laya.threshold` → 0.5 |
| `laya_prob(row, condition)` | float8 | Probability 0..1 that the row satisfies the condition |
| `laya_score(row, question, levels text[])` | float8 | Probability-weighted position on ordered levels (0 .. n-1) |
| `laya_score_norm(row, question, levels)` | float8 | Same, normalised to 0..1 |
| `laya_choice(row, question, options text[])` | text | The most likely option for the row |
| `laya_confidence(row, question, kind, options)` | float8 | Confidence of a `score`/`choice` answer |
| `laya_eval(row, question, kind, options)` | jsonb | Full raw answer (probabilities, legend, confidence) |
| `laya_stats()` | jsonb | Requests, tokens, estimated cost, cache hits, in-flight requests and pooled connections for this session |
| `laya_cache_clear()` | void | Forget cached judgments |
| `laya_version()` | text | Extension version |

`row` is the table alias itself (`laya(people, ...)`) or a subquery alias.

## Settings

All settings are plain GUCs: `SET laya.<name> = ...`, `ALTER ROLE ... SET`, `ALTER DATABASE ... SET`, or `postgresql.conf`.

| Setting | Default | Meaning |
| --- | --- | --- |
| `laya.api_key` | env `LAYA_API_KEY` (optional) | API key for the endpoint. Not needed for the default local server (no `LAYA_API_KEY`); needed when the server enables auth or when using the cloud Jev model |
| `laya.model` | `laya-latest` | Model name or pinned version such as `laya-1.13.0` |
| `laya.threshold` | `0.5` | Probability at which `laya()` returns true |
| `laya.batch_size` | `20` | Rows per API request. Accuracy drops measurably above ~20–25 (see above) |
| `laya.concurrency` | `16` | Parallel API requests; up to twice that many are queued ahead of the executor. Keep this low (2-4) when using a local server: it runs one inference at a time, so more connections just queue or get HTTP 503 |
| `laya.max_prefetch_rows` | `5000` | How far past a cache miss the read-ahead scans to find the requested row, and how many skipped rows it keeps for later requests (memory bound) |
| `laya.notices` | `on` | Emit a progress `NOTICE` per finished request and a summary per table with request count, tokens, estimated cost and time |
| `laya.api_url` | `http://127.0.0.1:8000/v1/systemone` | Endpoint. Laya's local server (default) speaks the same `/v1/systemone` protocol as the cloud [TypeSafe Jev](https://docs.typesafe.ai) model; point here for proxies, mocks, or the cloud model (`https://api.typesafe.ai/v1/systemone`) |
| `laya.timeout` | `30` | Seconds per API request. Waits are interruptible: `statement_timeout` and cancel requests apply within 250 ms |
| `laya.keepalive` | `600` | Seconds a pooled API connection may sit idle before it is reconnected. The first request on a fresh connection costs a TLS handshake plus, measured, up to 1.5 s of server-side setup, so keep connections alive across queries; TCP keepalive probes catch silently dropped ones |
| `laya.max_rows_per_statement` | `0` (off) | Abort a statement that would send more rows than this to the API. Spend guard for shared deployments |
| `laya.max_chars_per_statement` | `0` (off) | Same, for characters of row data |

## Writing good conditions

The model answers the question you wrote, literally. A few things that help (more in the
[docs](https://pglaya.com/docs)):

- State the exact condition: `'the customer threatens to leave, dispute a charge, or take legal action'`
  beats `'churn risk'`.
- Keep arithmetic, dates and exact matches in SQL; let the model judge meaning.
- Look at the distribution with `laya_prob()` before picking a threshold. Ambiguous cases really do land
  near 0.5.
- Send only the columns the judgment needs: create a view with the relevant columns (and any pre-filter) and call
  `laya(view_alias, ...)` on the view. Views are read ahead and batched like tables.

## Caveats

- This is a full scan by design: every row the executor asks about goes to the API. Cheaper predicates in the same
  `WHERE` run first and their rejects are skipped; a `LIMIT` stops early; `laya.max_rows_per_statement` caps spend.
- By default row contents stay on the machine: the companion server runs next to Postgres and nothing
  leaves it. If you point `laya.api_url` at the cloud Jev model, rows are sent to TypeSafe — do not use
  that on data you may not share.
- The cache lives in the backend session (PL/Python `GD`). Connection pools with many sessions each warm their
  own cache.
- `plpython3u` is an untrusted language: only superusers can create the extension, and functions run with the
  server's OS privileges.

## Development

```bash
make docker-test                 # builds test/Dockerfile and runs the regression suite (PG_MAJOR=16 by default)
make docker-test PG_MAJOR=17
```

Locally with a running server and `pg_config` on `PATH`:

```bash
make install
python3 test/mock_api.py &       # deterministic stand-in for any /v1/systemone API (Laya or TypeSafe)
make installcheck                # pg_regress, tests in test/sql, expected output in test/expected
```

The regression tests never call the live API. To try the real thing, start the local server
(`make serve`, or it is already running as a service if you used `make install`) and run any query.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/PUBLISHING.md](docs/PUBLISHING.md) for release steps.

## License

[PostgreSQL License](LICENSE). Jev and TypeSafe and Laya are trademarks of their respective owners; this project is not
affiliated with TypeSafe or Laya.
