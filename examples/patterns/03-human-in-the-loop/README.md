# Human in the loop

**Category:** Pattern · **Functions:** `laya_choice`, `laya_confidence`, `UPDATE`

Let the model do the easy 80% and route the hard 20% to a person. Confident
classifications are written straight back to the table; low-confidence ones
are left `NULL` and surfaced as a review queue. The model never has to guess
when it is not sure.

## Scenario

You want automated classification, but you do not want a wrong auto-label on
an ambiguous ticket. So: high confidence → apply it; low confidence → a
human looks. The threshold is the line between "the model can do this" and
"a person should".

## How it works

1. `laya_choice(…)` + `laya_confidence(…)` with the **same**
   `(question, kind, options)` triple share one cache entry — one model call
   per ticket, not two.
2. The first query shows the pick and its confidence for every ticket.
3. `UPDATE … WHERE laya_confidence(…) >= 0.6` writes back only the confident
   labels (reuses the same cached answers).
4. `WHERE team IS NULL` lists what the model declined to auto-apply.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **The threshold is the trust dial:** `0.6` auto-applies most, queues the
  rest. Raise it to be more conservative (more humans), lower it to automate
  more.
- **`NULL` means "unresolved":** leaving `team` NULL is what makes the review
  queue — don't auto-fill it with a low-confidence guess.
- **Idempotent-ish:** re-running only touches rows where `team` is still
  NULL; already-classified rows are not re-judged.
