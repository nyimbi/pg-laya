# Settings (GUCs)

Docs: https://pglaya.com/docs/settings.md

Every setting is a plain PostgreSQL custom GUC under the `laya.` prefix, so all the usual scopes apply:

```sql
SET laya.threshold = 0.7;                            -- this session
SET LOCAL laya.max_rows_per_statement = 500;         -- this transaction
ALTER ROLE analyst SET laya.api_key = '...';         -- persistent for one role
ALTER DATABASE app SET laya.concurrency = 8;         -- persistent for one database
-- postgresql.conf:  laya.notices = off
SHOW laya.batch_size;                                -- current value ('' if never set → default applies)
```

Settings are read once per cache miss (one SPI query), so changing one takes effect on the next uncached call.

| Setting | Default | Meaning | Change it when |
| --- | --- | --- | --- |
| `laya.api_key` | env `TYPESAFE_API_KEY` of the server | TypeSafe API key | always, unless the server env has it |
| `laya.model` | `laya-latest` | model name or pinned version such as `laya-1.13.0` | you need reproducible answers across model releases |
| `laya.threshold` | `0.5` | probability at which `laya()` returns true (the third argument of `laya()` overrides it) | you want stricter/looser matches without editing every query |
| `laya.batch_size` | `20` | rows per API request | rarely; accuracy drops measurably above ~20–25 because the model finds `rows[i]` by position. Lower it for very wide rows if you see drift |
| `laya.concurrency` | `16` | parallel API requests; up to 2× that many are queued ahead of the executor | lower on 429s or to be gentle on a shared key; raising it beyond 16 gives little |
| `laya.max_prefetch_rows` | `5000` | how far past a cache miss the read-ahead scans to find the requested row, and how many skipped rows it keeps for later (memory bound) | queries with index scans/joins that request rows far apart; memory-constrained servers (lower) |
| `laya.notices` | `on` | `NOTICE` per finished request plus a per-table summary (rows, requests, tokens, ≈cost, ms) | `off` in applications and tests |
| `laya.api_url` | `https://api.typesafe.ai/v1/systemone` | endpoint | proxies, the regression mock (`http://127.0.0.1:8765/v1/systemone`) |
| `laya.timeout` | `30` | seconds per API request. Waits are interruptible: `statement_timeout` and cancel apply within 250 ms | slow networks |
| `laya.keepalive` | `600` | seconds a pooled HTTPS connection may idle before it is reconnected | proxies that drop idle connections sooner |
| `laya.max_rows_per_statement` | `0` (off) | abort a statement that would send more rows than this to the API | shared servers, ad-hoc users, anything where a missing `WHERE` would be expensive |
| `laya.max_chars_per_statement` | `0` (off) | same, for characters of row data | wide rows / token budget |

## Recommended baseline for a shared server

```sql
ALTER DATABASE app SET laya.max_rows_per_statement = 5000;
ALTER DATABASE app SET laya.max_chars_per_statement = 2000000;
ALTER ROLE analyst SET laya.api_key = '...';
ALTER ROLE analyst SET laya.model = 'laya-1.13.0';     -- pin if results feed a report
```

Guard errors read
`laya: this statement would send N rows to the API, above laya.max_rows_per_statement = M`, so users know why and
can add a filter or raise the limit with `SET LOCAL` for one statement.

## Where the API key comes from

Precedence: `laya.api_key` GUC (any scope) → `TYPESAFE_API_KEY` in the **server process** environment. The
client's shell does not count. Setting `laya.api_key = ''` disables the GUC and falls back to the environment.
