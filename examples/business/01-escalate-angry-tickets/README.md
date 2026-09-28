# Escalate angry tickets

**Category:** Business · **Functions:** `laya_prob`, `ORDER BY`, `LIMIT`, `laya(…, threshold)`

Rank open support tickets by how angry the customer sounds, so the most
urgent ones surface to a human first. The same query, with a threshold
argument, becomes a strict "clearly angry" filter.

## Scenario

A support queue is a mixed bag. You don't want to read every ticket — you
want the five that could turn into churn or a public complaint, right now.
`laya_prob` gives each ticket a 0..1 "anger" score; sorting by it puts the
hot ones on top. Because the score is a calibrated probability, ambiguous
tickets sit near 0.5 and you can see the gradient instead of a hard yes/no.

## How it works

1. `WHERE status = 'open'` is a cheap, indexed filter — it runs first and
   keeps only rows worth judging.
2. `laya_prob(tickets, '…')` returns a 0..1 probability per row.
3. `ORDER BY anger DESC LIMIT 5` ranks and stops at five.
4. The second query reuses the same condition, so it is served from the
   session cache — adding a threshold costs no extra API calls.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Wording:** name the observable behaviour — "angry, frustrated, or about
  to give up" — not a label like "negative sentiment".
- **Cost:** ~6 rows here; ~175 input tokens per row. On a real queue, filter
  by `status`/date first to cut the set.
- **Thresholds:** `0.8` means "clearly angry". Try 0.6/0.7 to loosen it, or
  look at the `anger` column to pick your own cut.
