# Prioritize the support queue

**Category:** Business · **Functions:** `laya_score`, `laya_score_norm`, `ORDER BY`

Score each ticket on an urgency rubric and blend it with how old the ticket
is (plain SQL), so the queue is ordered by real priority rather than arrival
time. This is where `laya_score` shines: an *ordered* scale, not a yes/no.

## Scenario

"Oldest first" buries a production outage under a week of typos. "Newest
first" buries an aging data-corruption bug. You want priority = how urgent the
customer is (from the text) + how long it has been waiting (from the clock).

## How it works

1. `laya_score(tickets, '…', ARRAY['not at all','minor','important','blocking'])`
   returns a weighted position 0..3 on the urgency rubric (levels low → high).
2. `laya_score_norm` gives the same as 0..1, so it can be blended with other
   0..1 signals.
3. The age is pure SQL: `age(now(), created_at)`, normalised to 0..1.
4. The combined `priority` is `0.7 · urgency + 0.3 · age` — the weights are a
   business choice, tune them freely.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Rubric order matters:** list levels low → high. The score is a weighted
  index, so `blocking` is 3, `not at all` is 0.
- **Blend, don't replace:** the clock signal is exact SQL; only urgency is
  fuzzy. Keep the two separate and combine them explicitly.
- **Weights:** 0.7/0.3 is a starting point. If aging tickets get lost, raise
  the age weight.
