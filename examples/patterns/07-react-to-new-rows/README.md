# React to new rows

**Category:** Pattern · **Functions:** `laya_watch`, `laya_watch_tick`, `laya_watches`, row triggers

Stop scanning old rows and start reacting to new ones. `laya_watch` arms a
rule: a cheap row trigger enqueues every new/changed row, and a scheduled
tick judges the queue and runs your action on the matches. The model is never
called in the write path — inserts stay fast, and the judging happens on your
clock.

## Scenario

You want the system to notice things as they happen: a ticket that smells of
churn, a review that crosses the line, a row that looks wrong. A
`WHERE laya(…)` scan answers "which rows are true right now"; a watch answers
"which new rows should I act on, and do it when they arrive".

## How it works

1. `laya_watch(rel, condition, action)` registers the rule and creates a row
   trigger on the table. Inserts/updates only enqueue the row as `jsonb`
   (deduped by content) — no model call.
2. `laya_watch_tick()` judges the pending rows and runs
   `action(payload jsonb)` on every match. Judgments are cached, so a
   retried tick re-judges nothing; it re-runs actions only.
3. Rows that arrive between ticks are picked up by the next tick — that is
   the point.
4. `laya_watches()` shows what is armed and what is pending;
   `laya_unwatch(watch_id)` disarms (drops the trigger when the last watch on
   the table goes away).

## Scheduling the tick

- **pg_cron:** `SELECT cron.schedule('laya-tick', '* * * * *', 'SELECT laya_watch_tick()');`
- **A worker or systemd timer:** any small job that runs the same statement.
- **By hand:** `SELECT laya_watch_tick();`

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **At-least-once, not exactly-once:** if an action ran but the tick failed
  before marking the row done, the next tick runs it again. Make actions
  idempotent — the example's `ON CONFLICT DO NOTHING` is the pattern.
- **Content dedupe:** a row with the same content as one already queued
  (pending or judged) is not re-enqueued, so a no-op `UPDATE` costs nothing.
- **The action is your code:** it can write an outbox table, queue a webhook
  (pg_net), send mail, … Keep it idempotent and auditable.
- **One tick is atomic:** a failing action rolls the whole tick back; the
  next tick retries. `laya_watch_skip(watch_id)` abandons a watch's pending
  rows if a poison-pill row is stuck.
