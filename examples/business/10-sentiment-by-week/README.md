# Sentiment by week

**Category:** Business · **Functions:** `laya`, `count(*) FILTER (WHERE …)`, `GROUP BY`

Count, per week, how many reviews the customer sounds frustrated in — and as
a percentage — to see whether frustration is trending up or down. This is
`laya()` used as a boolean *inside an aggregate*, a common reporting shape.

## Scenario

You want a weekly signal: is customer frustration rising? A single
`WHERE laya(…)` gives you a list; grouping by week with
`count(*) FILTER (WHERE laya(…))` gives you a trend you can chart.

## How it works

1. `laya(reviews, 'the customer sounds frustrated or upset')` is a boolean
   per row.
2. `count(*) FILTER (WHERE …)` counts only the rows where it is true, in the
   same scan as `count(*)`.
3. `GROUP BY date_trunc('week', created_at)` buckets by week.
4. The second query turns the count into a percentage with plain SQL
   (`100.0 * frustrated / total`), so weeks of different sizes compare.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **One condition, one scan:** both `frustrated` and `total` come from the
  same pass; the `FILTER` keeps it to a single evaluation of the condition.
- **Percentages beat raw counts** for trends — a busy week has more reviews
  and thus more frustrated ones even at the same rate.
- **Cost:** every row in the window is judged once per session. Bound the
  window (`created_at >= …`) and pre-filter cheaply first.
