---
name: pglaya
description: Install, configure, query and explain pglaya (the `laya` PostgreSQL extension that filters, ranks and classifies rows with plain-language conditions via Laya, a local System-1 decision model — or the cloud TypeSafe Jev model over the same protocol). Use this skill whenever a user mentions pglaya, pg-laya, the laya extension, `laya()`, `laya_prob`, `laya_choice`, `laya_score`, a "natural-language WHERE clause", "ask my Postgres table a question", classifying or scoring rows with AI inside Postgres, or hits an error starting with `laya:`. Covers "install pglaya on my server / in Docker", "write a query that picks rows where …", "what can laya do", cost and performance questions, and troubleshooting, with scripts that check the server, install the extension and run a smoke test.
---

# pglaya — plain-language predicates for PostgreSQL

`laya(table, 'condition')` is an ordinary boolean SQL function. Every row is judged by
[Laya](https://github.com/NandhaKishorM/laya), a local, non-autoregressive "System One" model that returns
calibrated probabilities, not text — by default by a local model server on the same machine
([Ollaya](https://ollaya.dev) on `http://127.0.0.1:11435/v1/systemone`, installed by `make install` as a system service). The cloud
[TypeSafe Jev](https://docs.typesafe.ai) model speaks the same `/v1/systemone` protocol and can be selected
with `SET laya.api_url = 'https://api.typesafe.ai/v1/systemone';`. No index, no embeddings, no vector column.
The sibling functions return a probability (`laya_prob`), a class (`laya_choice`), a rubric score (`laya_score`)
or the raw answer (`laya_eval`). `laya_watch` goes beyond querying: a row trigger enqueues new/changed rows and
a scheduled `laya_watch_tick()` runs your action on the ones that match.

```sql
SELECT * FROM tickets WHERE status = 'open' AND laya(tickets, 'the customer threatens to cancel');
```

The canonical documentation is **https://pglaya.com/docs**. Every page has a Markdown twin: append `.md`
(`https://pglaya.com/docs.md`, `https://pglaya.com/docs/functions.md`, `https://pglaya.com/docs/settings.md`).
Fetch those when a question goes beyond this skill, and point users there for further reading.
Source: https://github.com/realZachi/pg-laya.

## Figure out which job you have

| The user wants… | Do this | Read |
| --- | --- | --- |
| to install or set up pglaya | follow **Install** below; run `scripts/check_server.sh` first | `references/install.md` |
| a query ("rows where …", "rank by …", "sort tickets into teams") | follow **Write a query** below | `references/query-patterns.md`, `references/functions.md` |
| to react to new rows ("when a matching row arrives, do X") | arm a watch: `laya_watch(rel, condition, action)` + a scheduled `laya_watch_tick()` (pg_cron or a worker) | `references/functions.md` (Reactions section) |
| to know what laya can do / how it works / what it costs | follow **Explain** below | `references/how-it-works.md` |
| to tune batching, timeouts, spend limits, model pin | look up the GUC | `references/settings.md` |
| help with an error or unexpected result | **Troubleshoot** table below | `references/install.md` (troubleshooting section) |

## Install

Hard requirement first, because it decides whether install is possible at all: pglaya needs
**self-hosted PostgreSQL 14–17 with `plpython3u`** and a **superuser** to run `CREATE EXTENSION`. It does not
run on Supabase, Neon, RDS/Aurora or other managed hosts that withhold superuser or untrusted Python. Tell the
user this early rather than after a failed build. Docker is the way to try it without touching a host.

1. Check the target server: `bash scripts/check_server.sh [psql connection args]`. It reports the version,
   whether `plpython3u` is available, whether you are superuser, whether `laya` is already installed, whether
   the local model server is reachable, and whether a key is configured, then prints a verdict.
2. Install the extension files (nothing to compile; PGXS just copies `laya.control` + SQL). **`make install`
    also installs the companion model server ([Ollaya](https://ollaya.dev), a single binary) as a system
    service on that machine** (systemd `ollaya` on Linux, launchd `com.pglaya.ollaya` on macOS; `NO_SERVE=1`
    skips it — e.g. when the server runs elsewhere). Pick one:
   - From PGXN (preferred when `pgxn` is available or `pip install pgxnclient` is acceptable; no clone to manage):
     `bash scripts/install.sh --pgxn [--pg-config /path/to/pg_config] [--db mydb]`, which runs
     `pgxn install laya` (pinned with `--ref X.Y.Z`) and then `CREATE EXTENSION IF NOT EXISTS laya CASCADE`.
     By hand: `pgxn install laya [--pg_config PATH]` (`sudo` if the extension dir is root-owned).
   - From source: `bash scripts/install.sh [--pg-config /path/to/pg_config] [--db mydb]`. It clones the repo
     into a temp dir (or uses `--source DIR` / the current checkout), runs `make install`, then
     `CREATE EXTENSION IF NOT EXISTS laya CASCADE` in `--db`. Pass `--no-create` to stop after `make install`.
   - Docker: `docker build -t pg-laya .` in a clone, then `docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=pw
      pg-laya` and `CREATE EXTENSION laya CASCADE` against it. The container runs no service manager, so the
      model server (Ollaya) must run outside it: `SET laya.api_url = 'http://<server-host>:11435/v1/systemone';` (or a
     cloud endpoint). `--build-arg PG_MAJOR=17` for another major.
3. The API key is optional: the default local model server runs unauthenticated, so nothing to do. If the
   server was started with `OLLAYA_API_KEY`, give the extension the same token (`SET laya.api_key = '...'` for
   the session, `ALTER ROLE analyst SET laya.api_key = '...'` persistent). To use the cloud
   [TypeSafe Jev](https://docs.typesafe.ai) model instead: get a key from https://console.typesafe.ai, set it
   as in the previous sentence, and `SET laya.api_url = 'https://api.typesafe.ai/v1/systemone';`.
4. Verify: `psql -d mydb -f scripts/smoke_test.sql`. It creates a temp table, runs each function once, and
   prints `laya_stats()` so the user sees requests, tokens and estimated cost.

Details, per-platform package names and the troubleshooting list are in `references/install.md`.

## Write a query

Pick the function from the shape of the answer the user needs:

| Need | Function | Example |
| --- | --- | --- |
| yes/no filter | `laya(row, condition [, threshold])` → boolean | `WHERE laya(t, 'the customer is angry')` |
| ranking / a cutoff not chosen yet | `laya_prob(row, condition)` → 0..1 | `ORDER BY laya_prob(t, '…') DESC LIMIT 20` |
| one label from a closed set | `laya_choice(row, question, options text[])` → text | `laya_choice(t, 'which team?', ARRAY['billing','technical','sales'])` |
| position on an ordered rubric | `laya_score(row, question, levels text[])` → 0..n-1 (`laya_score_norm` → 0..1) | `laya_score(p, 'how luxurious?', ARRAY['budget','mid','premium','luxury'])` |
| how sure the model is | `laya_confidence(row, question, kind, options)` → 0..1 | with `'choice'` or `'score'` |
| everything (probabilities, legend) | `laya_eval(row, question, kind, options)` → jsonb | for debugging or custom logic |

`row` is the **table or view alias itself** (`laya(tickets, …)`, `laya(t, …)` after `FROM tickets t`), not a column.
Full signatures and the jsonb shape are in `references/functions.md`.

Rules that make the difference between a good query and an expensive, wrong one:

- **Cheap predicates first, `laya()` last.** Rows rejected by `status = 'open' AND created_at > …` before `laya()`
  runs are never sent to the API. Write the SQL so that happens; the planner does not reorder for cost of an
  external call.
- **Keep arithmetic, dates and exact matches in SQL.** Let the model judge meaning only ("sounds frustrated",
  "is a billing dispute"), never things SQL can compute (`age > 40`, `country = 'DE'`).
- **State the condition literally.** `'the customer threatens to leave, dispute a charge, or take legal action'`
  beats `'churn risk'`. Jev answers the question as written. Name `laya_choice` options the way you would brief a
  person, as a closed set without an `'other'` bucket.
- **Call it on a base table or a view, not on a subquery/CTE.** Tables and views are streamed ahead and batched
  20 rows per request; an anonymous `record` from a CTE is judged one request per row. To limit which columns the
  model sees (privacy, tokens), create a view with just those columns and call `laya(view_alias, …)`.
- **Against the local model server, `SET laya.state_mode = 'native';`** The local model cannot reliably separate
  rows in a shared state (batches smear answers). `native` sends one row per request — the row as the state, the
  condition in the question — the format it was trained on; the default `jev` mode (shared state, `laya.batch_size`
  rows per request) is for the cloud Jev model.
- **Look at the distribution before freezing a threshold.** Suggest `laya_prob()` + `width_bucket` or
  `ORDER BY p DESC LIMIT 20` first; ambiguous rows really land near 0.5. Re-running with another threshold is free
  because answers are cached per session.
- **Say what it will cost.** Every row reaching `laya()` goes to the model; ~175 input tokens per row in
  batches of 20 (`jev` state mode; the local server's `native` mode sends one row per request). Against the
  cloud Jev model that is $0.042 per million input tokens (≈ $0.012 for 2,000
  rows); against the local server it is CPU time — the server runs one inference at a time, so keep
  `laya.concurrency` at 2-4. On a large table propose an indexed pre-filter and, for shared servers,
  `SET laya.max_rows_per_statement = N` as a spend guard. With the default local server row contents stay
  on the machine; with the cloud endpoint they leave the database, so ask before running it on data that
  may not be shared.

Worked examples for filter, rank, classify, score, joins, views, GROUP BY and thresholds are in
`references/query-patterns.md`. Read it when the request is more than a one-liner. For complete,
runnable end-to-end scenarios (seeded tables + query), the repo ships 26 of them in `examples/`
(12 business, 8 personal, 6 patterns) — e.g. `examples/business/01-escalate-angry-tickets/`.

## Explain

When asked what pglaya is or can do, lead with the one-sentence version (plain-language predicate, ordinary SQL
function, composes with everything), show one filter and one classify example, and be straight about the three
things people most often get wrong:

1. It is a **full scan by design**: no index, every row that reaches `laya()` is judged (then cached per session).
2. It needs **self-hosted Postgres with `plpython3u` and superuser**: no Supabase/Neon/RDS.
3. **Data stays on the machine by default** (the companion model server runs next to Postgres). It leaves
   Postgres only if `laya.api_url` is pointed at the cloud Jev endpoint.

Then link https://pglaya.com/docs. For the pipeline (streaming read-ahead, batches of 20, 2 × concurrency in
flight, keep-alive connections, per-session cache), measured numbers and why 20 rows per request, read
`references/how-it-works.md` instead of guessing.

## Troubleshoot

| Symptom | Cause / fix |
| --- | --- |
| `laya: API unreachable after retries: … Connection refused` / timeouts against `127.0.0.1:11435` | The local model server (Ollaya) is not running. Linux: `systemctl status ollaya`; macOS: `launchctl list \| grep com.pglaya.ollaya`; or run `make serve` in the foreground. `make install` normally starts it automatically. |
| `laya: API error 401 …` | The endpoint requires a bearer token that the extension did not send (or sent the wrong one). Set `laya.api_key` to the server's `OLLAYA_API_KEY` (or the TypeSafe key for the cloud model). |
| `laya: API error 422 …` | Request rejected by the model (bad model name, malformed options, or the mock's `trigger422` condition in tests). Check `laya.model`, options arrays. |
| `laya: API error 422 … STATE_TRUNCATED` / `TOO_MANY_OPTIONS` (against Ollaya) | A request exceeded the server's limits (512-token context for `laya:en` including the question, 64 questions, 8 MiB body). Lower `laya.batch_size`, or use a view with fewer/narrower columns, or `laya.max_chars_per_statement`. |
| `laya: API error 429/5xx` after retries (cloud) | Rate limit / outage; the extension retries with `Retry-After`. Lower `laya.concurrency`, retry later |
| `ERROR: could not open extension control file … laya.control` | `make install` copied into a different Postgres than the one you connect to. Use `make install PG_CONFIG=/path/to/that/pg_config`. |
| `ERROR: could not open extension control file … plpython3u.control` / `language "plpython3u" does not exist` | Install `postgresql-plpython3-NN` (Debian/Ubuntu) or a build that ships it; managed hosts cannot. |
| `required extension "plpython3u" is not installed` | `CREATE EXTENSION laya` without `CASCADE`. Use `CREATE EXTENSION laya CASCADE;`. |
| `permission denied to create extension "laya"` | Only superusers can create it (`plpython3u` is untrusted). |
| `laya: this statement would send N rows to the API, above laya.max_rows_per_statement = M` | Spend guard fired. Add a pre-filter or raise the guard on purpose. |
| Query is slow, one request per row in the `NOTICE`s | `laya()` is called on a CTE/subquery (`record`). Move it onto the base table or a view. |
| Nothing matches | Look at `laya_prob()`; reword the condition literally; lower the threshold. |
| Results differ from single-row checks | Against the local server: the default `jev` state mode batches rows into one shared state, which the local model smears — `SET laya.state_mode = 'native'`. Against the cloud: `laya.batch_size` was raised above ~20; the model locates `rows[i]` by position and accuracy drops. Set it back. |
| `statement_timeout` or Ctrl-C seems ignored | Fixed in 0.2.0 (waits are interruptible within 250 ms). `SELECT laya_version()`; upgrade with `ALTER EXTENSION laya UPDATE`. |

`SELECT laya_stats();` shows requests, tokens, estimated cost, cache hits, errors, retries, in-flight requests and
pooled connections for the session and is the first thing to look at.

## Files in this skill

- `scripts/check_server.sh` — preflight: version, `plpython3u`, superuser, laya installed, local server reachable, key.
- `scripts/install.sh` — `pgxn install laya` (`--pgxn`) or clone + `make install`, then `CREATE EXTENSION … CASCADE`.
- `scripts/smoke_test.sql` — one call per function on a temp table, then `laya_stats()`.
- `references/install.md` — requirements, PGXN/source/Docker details, API key (optional), troubleshooting.
- `references/functions.md` — every function, argument, return type, the `laya_eval` jsonb shape.
- `references/settings.md` — every GUC with default and when to change it.
- `references/query-patterns.md` — worked SQL for filter, rank, classify, score, views, joins, thresholds, spend.
- `references/how-it-works.md` — pipeline, cache, cost model, measured numbers, caveats.
- Repo `examples/` — 26 fully-coded, runnable examples (12 business, 8 personal, 6 patterns), each folder a `README.md` + `example.sql`.
