# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **`laya.state_mode` — a `native` request format for the local Laya model.** The default `jev` mode packs
  `laya.batch_size` rows into one shared state (`{"condition", "rows"}`) — what the cloud Jev model is built
  for. The local model cannot reliably separate rows in a shared state (in a 4-row batch, rows with and
  without the target phrase all scored ≈0.8), so `native` sends one row per request: the row itself as the
  state, the condition in the question — the shape it was trained on. `laya.batch_size` is ignored in `native`
  mode (always 1). Measured against the real model, one row per request: "the customer is angry" 0.95/0.72 vs
  0.00/0.00; "the country is in Europe" 0.82 (Germany) vs 0.05 (USA); "the name is European" 0.67–0.89 for
  Pierre/Anna vs 0.07 for the rest — the same queries through the `jev` format score everything ≈0.8 or drift
  by batch position. `SET laya.state_mode = 'native';` (per session, role or database) to use it.
- **`make install` also installs the companion model server as a system service on the Postgres machine.** It
  installs [Ollaya](https://ollaya.dev) — a single binary serving the Laya decision models over a
  TypeSafe-compatible `/v1` API (installed via `curl -fsSL https://ollaya.dev/install.sh | sh` if not already
  present) — and starts it on `http://127.0.0.1:11435`, where the extension's default `laya.api_url` points: a
  systemd unit (`ollaya.service`) on Linux or a launchd agent (`com.pglaya.ollaya`) on macOS. It then pulls the
  `laya` model (a router over `laya:en` / `laya:multilingual`, ~1.5 GB, sha256-verified, resumable; non-fatal if
  it fails — models load on demand). `make install-serve` re-runs just this part; `NO_SERVE=1` skips it
  (containers and CI have no service manager, so it prints how to start the server by hand instead). If a
  server already answers on the address and is not managed by us (the Ollaya desktop app, a manual
  `ollaya serve`), the installer leaves it running, pulls the model and exits.
- **`examples/` — 26 fully-coded, runnable examples.** 12 business (escalate angry tickets, route by team,
  score leads, segment by persona, flag churn, rank applicants, categorize feedback, prioritize the queue,
  detect fraud signals, weekly sentiment, meeting outcomes, language routing), 8 personal (expenses, inbox,
  photos, recipes, movie night, habits, moving, notes) and 6 patterns (picking a threshold, multi-label
  topics, human-in-the-loop, limiting what the model sees, managing costs on large tables, composing with
  plain SQL). Each is a folder with a `README.md` and an `example.sql` that creates a small sample table,
  seeds realistic rows and runs the query, so it works as-is:
  `psql -d mydb -f examples/business/01-escalate-angry-tickets/example.sql`.
- **`s/` — a self-contained static reference site.** The full documentation (install, functions, settings,
  how it works, query patterns, changelog, all examples) as plain HTML with no build step and no
  dependencies, a light/dark theme and SQL highlighting: open `s/index.html`.
- A new README banner: a stylised rhino with the pg-laya wordmark (replaces the old vectorised title).

### Changed
- **Default backend is now the local model server (Ollaya), pluggable to the cloud Jev model.** The default
  `laya.api_url` is `http://127.0.0.1:11435/v1/systemone` (Ollaya, the drop-in replacement for
  `api.typesafe.ai/v1/systemone`) instead of the cloud TypeSafe Jev model, and the default `laya.model` is
  `laya` — Ollaya's router, which picks the English or multilingual checkpoint per request. The same
  `/v1/systemone` wire protocol, so the request/response paths are unchanged. To use the cloud model again,
  `SET laya.api_url = 'https://api.typesafe.ai/v1/systemone';` (and a cloud model name). A loaded model runs
  one inference at a time, so keep `laya.concurrency` low (2-4); more connections just queue.
- **The API key is optional.** The extension only sends an `Authorization` header when a key is configured,
  so the default local server (no `OLLAYA_API_KEY`) works with zero configuration. The server-side environment
  variable is `OLLAYA_API_KEY`; `TYPESAFE_API_KEY` is still honoured as a deprecated fallback for
  `laya.api_key`. The old
  `laya: no API key …` error is gone: a keyless request to an endpoint that requires one now surfaces the
  endpoint's 401.

### Fixed
- A Python syntax error (missing brace) in the 0.2.0 → 0.3.0 upgrade script, which would have aborted
  `ALTER EXTENSION laya UPDATE` from 0.2.0.

## [0.2.0] - 2026-09-18

Measured against the live API on a 2,000-row table (from Europe, ~190 ms RTT to the API): first run
8.5 s → 3.5 s, `LIMIT 3` on a fresh condition 8.4 s → 0.6 s, 12 % fewer input tokens, and answers that
match single-row evaluation instead of drifting.

### Changed
- **Streaming read-ahead.** A table is no longer read whole (up to `laya.max_prefetch_rows`) before the first
  answer. It is streamed in physical order (TID range scans for tables, `OFFSET` pages for views), judged in
  batches with up to 2 × `laya.concurrency` requests in flight, and each row is answered as soon as its batch
  returns. Memory is constant whatever the table size; rows beyond the old 5,000-row limit were previously
  judged one request at a time. A `LIMIT` stops the read-ahead after the in-flight window. Rows that cheaper
  predicates filter out before `laya()` runs are skipped instead of judged. Rows requested out of physical
  order (backward index scans, joins) are batched with their neighbours instead of judged one by one.
- **Persistent HTTPS connections.** Requests reuse keep-alive connections across batches and statements
  (one TLS handshake per connection instead of one per request: 880 ms → 300 ms per request from Europe).
- **`laya.batch_size` default 40 → 20.** Ground-truth tests (job title, EU membership, a phrase in a free-text
  field) are 100 % correct up to 20 rows per request and fall to 92–98 % at 40 and to 77–94 % at 80: the model
  has to find `rows[i]` by position, and that gets unreliable in long arrays. The cost is +4 % input tokens.
- **Noul questions no longer carry the generic `criteria`** ("the record satisfies the condition"): they cost
  16 % of all input tokens and changed no answers.
- **`laya.concurrency` default 6 → 16.** The API handles 16 parallel requests without queueing.
- **`laya.timeout` default 90 → 30 seconds.** Waits are also interruptible now: `statement_timeout` and
  cancel requests take effect within 250 ms instead of after the HTTP timeout.
- `429`/`529`/`5xx` retries honour `Retry-After`. Pooled connections are checked before reuse (closed by the
  server, or idle for more than `laya.keepalive` = 600 s) and carry TCP keepalive probes, so a request is never
  sent into a dead socket; a connection that still fails is retried at once on a fresh one. Keeping connections
  matters: the first request on a fresh connection was measured at 0.9–1.9 s against 0.3 s afterwards.
- `laya.max_prefetch_rows` now bounds how far the read-ahead scans past a cache miss (and how many skipped
  rows it remembers), not the size of the table it can handle.
- Rows are serialised with `to_json` (column order preserved) instead of `to_jsonb` (keys sorted by length).
- A cache hit costs no SPI call at all; settings are read in one query per cache miss.
- `laya_stats()` gains `retries`, `in_flight` and `connections` (idle, pooled).

### Added
- With `laya.notices` on, one `NOTICE` per finished API request while a table is being judged
  (`laya: progress 12/50 requests, 480/2000 rows`), so clients that stream notices can show a live progress bar.
- Setting `laya.keepalive` (default 600 s): how long an idle pooled API connection is kept before it is
  reconnected. Measured: connections stay usable for at least 10–15 minutes of idle time.
- Upgrade script `laya--0.1.0--0.2.0.sql` (`ALTER EXTENSION laya UPDATE`).
- Regression tests for streaming, `LIMIT`, filtered scans, backward index scans and views.

## [0.1.0] - 2026-09-17

### Added
- `laya()`, `laya_prob()`, `laya_score()`, `laya_score_norm()`, `laya_choice()`, `laya_confidence()`, `laya_eval()`.
- Whole-table read-ahead with batched, concurrent requests and a per-session answer cache.
- `laya_stats()` and `laya_cache_clear()`.
- Settings: `laya.api_key`, `laya.model`, `laya.threshold`, `laya.batch_size`, `laya.concurrency`,
  `laya.max_prefetch_rows`, `laya.notices`, `laya.api_url`, `laya.timeout`, and the spend guards
  `laya.max_rows_per_statement`, `laya.max_chars_per_statement`.
- Regression suite against a deterministic mock API; CI for PostgreSQL 14–17.
