# Categorize product feedback

**Category:** Business · **Functions:** `laya_choice`, `GROUP BY`, `avg`

Bucket product reviews by theme — reliability, pricing, missing features,
praise, support, performance — so the team sees what users actually talk
about, and how much. `rating` stays in SQL for the average; only the theme
comes from the model.

## Scenario

Hundreds of reviews a month, no consistent tagging. You want to know whether
the conversation is mostly bugs, price, or a missing feature — and the average
star rating per theme, to spot where sentiment is weakest.

## How it works

1. `laya_choice(reviews, '…', ARRAY[…])` assigns one theme per review.
2. The first query shows each review's theme for spot-checking.
3. The second groups by theme and computes `count(*)` and `avg(rating)` —
   the aggregate part is plain SQL.
4. Same `(question, options)` → the group-by reuses the cached labels.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Mutually exclusive themes:** `laya_choice` picks one. A review that is
  "bugs *and* pricing" gets the dominant one. For multi-label, see
  `examples/patterns/02-multi-label-topics`.
- **Write themes readably:** `'reliability / bugs'` reads better to the model
  than `'bug'` and is unambiguous.
- **Cost:** one label per review. Pre-filter by date or rating if you only
  care about a slice.
