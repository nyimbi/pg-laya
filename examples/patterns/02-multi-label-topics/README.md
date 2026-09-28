# Multi-label topics

**Category:** Pattern · **Function:** `laya_eval` (probability vector)

`laya_choice` returns *one* label. But a message can be about several things
at once — "my invoice is wrong *and* the app crashes". This pattern uses
`laya_eval` to get the probability for *every* topic, then keeps the ones
above a cutoff, so a row can carry several labels.

## Scenario

You want to tag each message with all the topics it covers, not force it
into a single bucket. A billing+crash message should be tagged with both, so
the right two teams see it.

## How it works

1. `laya_eval(messages, '…', 'choice', ARRAY[…])` returns the full answer as
   jsonb, including `probabilities` — a map from every option to its
   probability.
2. The first query shows that raw jsonb so you can see the vector.
3. The second extracts `probabilities`, keeps each key whose value is
   `>= 0.3`, and aggregates them into an array of labels.
4. Each message is one `laya_eval` call; the label extraction is plain SQL
   over the returned jsonb.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **`choice` gives the whole vector:** even though it's "choice", the
  `probabilities` field has a number for every option — that's what makes
  multi-label possible.
- **Tune the cutoff:** `0.3` keeps reasonably-supported topics. Raise it to
  be stricter, lower it to capture more.
- **Cost:** one call per message. (The example repeats `laya_eval` in the
  subquery for clarity; in production compute it once into a column/temp
  table, then filter.)
