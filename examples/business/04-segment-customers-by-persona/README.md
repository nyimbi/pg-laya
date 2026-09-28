# Segment customers by persona

**Category:** Business · **Functions:** `laya_choice`, `GROUP BY`

Put each customer into a marketing persona from their usage and support
behaviour, then see the size of each segment. Personas are a closed set, so
`laya_choice` is the right shape — every customer lands in exactly one bucket.

## Scenario

Marketing wants segments it can target: enterprise buyers (long procurement,
SSO/SLA), power users (feature-hungry), self-serve pros (independent,
technical), and window shoppers (low commitment). The persona is not a
column — it is something you infer from the usage note.

## How it works

1. `laya_choice(customers, '…', ARRAY[…])` maps each row to one persona.
2. The first query shows the label next to each customer for spot-checking.
3. The second groups by persona to size each segment.
4. Same `(question, options)` → the group-by is a cache hit.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Closed set, sensible home:** each persona should be distinct enough that
  a given note clearly fits one. If two personas overlap, merge or reword
  them.
- **Plan is a hint, not the answer:** the model weighs `plan` and
  `usage_note` together — a "free" plan with enterprise behaviour can still
  be scored an enterprise buyer.
- **Stable reporting:** personas can shift between model releases; pin
  `laya.model` if these numbers feed a report.
