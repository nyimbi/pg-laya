---
name: pglaya
description: Install, configure, query and explain pglaya (the `laya` PostgreSQL extension that filters, ranks and classifies rows with plain-language conditions via TypeSafe's Jev model). Use this skill whenever a user mentions pglaya, pg-laya, the laya extension, `laya()`, `laya_prob`, `laya_choice`, `laya_score`, a "natural-language WHERE clause", "ask my Postgres table a question", classifying or scoring rows with AI inside Postgres, or hits an error starting with `laya:`. Covers "install pglaya on my server / in Docker", "write a query that picks rows where …", "what can laya do", cost and performance questions, and troubleshooting, with scripts that check the server, install the extension and run a smoke test.
---

# pglaya — plain-language predicates for PostgreSQL

`laya(table, 'condition')` is an ordinary boolean SQL function. Every row is sent to TypeSafe's Jev model
(a "System One" model that returns calibrated probabilities, not text) and judged against the condition.
No index, no embeddings, no vector column. The sibling functions return a probability (`laya_prob`), a class
(`laya_choice`), a rubric score (`laya_score`) or the raw answer (`laya_eval`).

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
| to know what laya can do / how it works / what it costs | follow **Explain** below | `references/how-it-works.md` |
| to tune batching, timeouts, spend limits, model pin | look up the GUC | `references/settings.md` |
| help with an error or unexpected result | **Troubleshoot** table below | `references/install.md` (troubleshooting section) |

## Install

Hard requirement first, because it decides whether install is possible at all: pglaya needs
**self-hosted PostgreSQL 14–17 with `plpython3u`** and a **superuser** to run `CREATE EXTENSION`. It does not
run on Supabase, Neon, RDS/Aurora or other managed hosts that withhold superuser or untrusted Python. Tell the
user this early rather than after a failed build. Docker is the way to try it without touching a host.

1. Check the target server: `bash scripts/check_server.sh [psql connection args]`. It reports the version,
   whether `plpython3u` is available, whether you are superuser, whether `laya` is already installed and whether
   an API key is configured, then prints a verdict.
2. Install the extension files (nothing to compile; PGXS just copies `laya.control` + SQL). Pick one:
   - From PGXN (preferred when `pgxn` is available or `pip install pgxnclient` is acceptable; no clone to manage):
     `bash scripts/install.sh --pgxn [--pg-config /path/to/pg_config] [--db mydb]`, which runs
     `pgxn install laya` (pinned with `--ref X.Y.Z`) and then `CREATE EXTENSION IF NOT EXISTS laya CASCADE`.
     By hand: `pgxn install laya [--pg_config PATH]` (`sudo` if the extension dir is root-owned).
   - From source: `bash scripts/install.sh [--pg-config /path/to/pg_config] [--db mydb]`. It clones the repo
     into a temp dir (or uses `--source DIR` / the current checkout), runs `make install`, then
     `CREATE EXTENSION IF NOT EXISTS laya CASCADE` in `--db`. Pass `--no-create` to stop after `make install`.
   - Docker: `docker build -t pg-laya .` in a clone, then `docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=pw
     -e TYPESAFE_API_KEY=... pg-laya` and `CREATE EXTENSION laya CASCADE` against it. `--build-arg PG_MAJOR=17` for
     another major.
3. Configure the API key. The default backend is the local Laya server, which needs no key; the cloud
   [TypeSafe Jev](https://docs.typesafe.ai) model does (get one from https://console.typesafe.ai) — set
   `SET laya.api_url = 'https://api.typesafe.ai/v1/systemone';` to use it. Three options for the key, pick
   what fits the deployment: `SET laya.api_key = '...'` (session), `ALTER ROLE analyst SET laya.api_key = '...'
   ` (persistent per role), or `TYPESAFE_API_KEY` in the environment of the **server** process (not the
   psql client). Never paste a user's real key into files you commit; put it in a role setting or the
   server environment. To run the local server: `make serve` or `make install-serve` (see README).
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
- **Look at the distribution before freezing a threshold.** Suggest `laya_prob()` + `width_bucket` or
  `ORDER BY p DESC LIMIT 20` first; ambiguous rows really land near 0.5. Re-running with another threshold is free
  because answers are cached per session.
- **Say what it will cost.** Every row reaching `laya()` goes to the API; ~175 input tokens per row in batches of 20,
  $0.042 per million input tokens (≈ $0.012 for 2,000 rows). On a large table propose an indexed pre-filter and,
  for shared servers, `SET laya.max_rows_per_statement = N` as a spend guard. Row contents leave the database, so
  ask before running it on data that may not be shared.

Worked examples for filter, rank, classify, score, joins, views, GROUP BY and thresholds are in
`references/query-patterns.md`. Read it when the request is more than a one-liner.

## Explain

When asked what pglaya is or can do, lead with the one-sentence version (plain-language predicate, ordinary SQL
function, composes with everything), show one filter and one classify example, and be straight about the three
things people most often get wrong:

1. It is a **full scan by design**: no index, every row that reaches `laya()` is judged (then cached per session).
2. It needs **self-hosted Postgres with `plpython3u` and superuser**: no Supabase/Neon/RDS.
3. **Data leaves Postgres** to TypeSafe's API.

Then link https://pglaya.com/docs. For the pipeline (streaming read-ahead, batches of 20, 2 × concurrency in
flight, keep-alive connections, per-session cache), measured numbers and why 20 rows per request, read
`references/how-it-works.md` instead of guessing.

## Troubleshoot

| Symptom | Cause / fix |
| --- | --- |
| `laya: no API key. SET laya.api_key = '...' or start the server with TYPESAFE_API_KEY set.` | Key not set for this session/role, and the **server** process has no `TYPESAFE_API_KEY`. Setting it in the client shell does nothing. |
| `laya: TypeSafe API error 401 …` | Wrong key. |
| `ERROR: could not open extension control file … laya.control` | `make install` copied into a different Postgres than the one you connect to. Use `make install PG_CONFIG=/path/to/that/pg_config`. |
| `ERROR: could not open extension control file … plpython3u.control` / `language "plpython3u" does not exist` | Install `postgresql-plpython3-NN` (Debian/Ubuntu) or a build that ships it; managed hosts cannot. |
| `required extension "plpython3u" is not installed` | `CREATE EXTENSION laya` without `CASCADE`. Use `CREATE EXTENSION laya CASCADE;`. |
| `permission denied to create extension "laya"` | Only superusers can create it (`plpython3u` is untrusted). |
| `laya: this statement would send N rows to the API, above laya.max_rows_per_statement = M` | Spend guard fired. Add a pre-filter or raise the guard on purpose. |
| Query is slow, one request per row in the `NOTICE`s | `laya()` is called on a CTE/subquery (`record`). Move it onto the base table or a view. |
| Nothing matches | Look at `laya_prob()`; reword the condition literally; lower the threshold. |
| Results differ from single-row checks | `laya.batch_size` was raised above ~20; the model locates `rows[i]` by position and accuracy drops. Set it back. |
| `statement_timeout` or Ctrl-C seems ignored | Fixed in 0.2.0 (waits are interruptible within 250 ms). `SELECT laya_version()`; upgrade with `ALTER EXTENSION laya UPDATE`. |

`SELECT laya_stats();` shows requests, tokens, estimated cost, cache hits, errors, retries, in-flight requests and
pooled connections for the session and is the first thing to look at.

## Files in this skill

- `scripts/check_server.sh` — preflight: version, `plpython3u`, superuser, laya installed, key configured.
- `scripts/install.sh` — `pgxn install laya` (`--pgxn`) or clone + `make install`, then `CREATE EXTENSION … CASCADE`.
- `scripts/smoke_test.sql` — one call per function on a temp table, then `laya_stats()`.
- `references/install.md` — requirements, PGXN/source/Docker details, API key placement, troubleshooting.
- `references/functions.md` — every function, argument, return type, the `laya_eval` jsonb shape.
- `references/settings.md` — every GUC with default and when to change it.
- `references/query-patterns.md` — worked SQL for filter, rank, classify, score, views, joins, thresholds, spend.
- `references/how-it-works.md` — pipeline, cache, cost model, measured numbers, caveats.
