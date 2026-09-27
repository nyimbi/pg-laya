# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- **Default backend is now Laya (local), pluggable to the cloud Jev model.** The default `laya.api_url`
  is `http://127.0.0.1:8000/v1/systemone` (Laya's local server, the drop-in replacement for
  `api.typesafe.ai/v1/systemone`) instead of the cloud TypeSafe Jev model. Laya speaks the same
  `/v1/systemone` wire protocol, so the request/response and auth paths are unchanged. To use the cloud
  model again, `SET laya.api_url = 'https://api.typesafe.ai/v1/systemone';`. Laya runs one inference at a
  time, so keep `laya.concurrency` low (2-4); more connections just queue (or get HTTP 503). Installing
  the companion server is `make install-serve` (see README). See [how to move back](#moving-back-to-the-cloud-laya-model).

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
