# Compose with plain SQL

**Category:** Pattern · **Functions:** `laya` with `JOIN`, CTE, `CASE`, `GROUP BY`

`laya()` is an ordinary `STABLE` function, so it composes with everything in
SQL. The one rule: it takes **one row type**, so judge the side that carries
the text and join the rest. Everything around it — joins, CTEs, `CASE`,
aggregates — is normal Postgres.

## Scenario

You want to know which *enterprise* customers are at risk, total the at-risk
tickets per plan, and route each ticket to a save-offer / account-team /
no-action track. The meaning comes from `laya()`; the structure comes from
SQL.

## How it works

1. **Join:** `laya(tickets, …)` judges the ticket (it carries the text);
   `JOIN customers` brings in the name and plan.
2. **CTE + aggregate:** a `WITH` materialises the boolean, then
   `count(*) FILTER (WHERE at_risk)` counts per plan.
3. **CASE:** the model's boolean drives a plain-SQL routing label.
4. Two different conditions in the `CASE` are two (cached) scans — if they
   are mutually exclusive, a single `laya_choice` would be one.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Judge the text-carrying side:** `laya()` needs one row type. Judge the
  ticket, not the customer; join for the customer's fields.
- **Two tables, one meaning:** to judge a combination of columns from two
  tables, build a **view** over the join and call `laya(view, …)`.
- **`CASE` costs one scan per condition:** each distinct condition is its own
  cache key. Prefer one `laya_choice` when the branches are mutually
  exclusive.
