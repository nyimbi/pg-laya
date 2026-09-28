# Manage costs on large tables

**Category:** Pattern · **Settings:** `laya.max_rows_per_statement`, `laya.max_chars_per_statement`, `laya.notices` · **Function:** `laya_stats`

Every row that reaches `laya()` costs tokens and a model pass. On a big table
the difference between "a few seconds" and "an hour and a bill" is discipline:
cheap SQL first, a bounded window, a spend guard, and `laya_stats()` to see
what it actually cost.

## Scenario

You want to count upset customers in the last week, but `events` could be
millions of rows. A bare `WHERE laya(…)` over the whole table would judge
everything. The pattern is: cut the set in SQL, bound it, guard it, and
measure it.

## How it works

1. `SET laya.max_rows_per_statement = 1000` — a hard guard: a statement that
   would send more rows than this is aborted with a clear error, so a missing
   `WHERE` cannot run away.
2. `WHERE channel = 'email'` — a cheap, indexed filter that runs before the
   model.
3. `AND created_at >= now() - interval '7 days'` — bounds the window.
4. Only the surviving rows reach `laya(…)`.
5. `SELECT laya_stats()` reports `rows_evaluated`, `input_tokens` and
   `estimated_cost_usd` for the session.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Order matters:** put every indexed predicate *before* `laya()`. The model
  only sees rows that survive them.
- **The guard is a tripwire, not a budget:** it stops runaway statements; set
  it to a value you are happy paying for.
- **Sample to test wording first:** `TABLESAMPLE SYSTEM (5)` lets you check
  whether a condition works before judging the full set.
- **`laya.notices = on`** prints a per-request progress line and a per-table
   summary, so long runs are not a black box.
