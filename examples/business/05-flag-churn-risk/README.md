# Flag churn risk

**Category:** Business · **Functions:** `laya_prob`, `laya(…, threshold)`, `ORDER BY`

Read each customer's recent support history and flag the accounts showing
churn signals, ranked by strength — and total the revenue at risk. A plain
`WHERE` on "mentions a competitor" would miss most of these; the model reads
the whole history.

## Scenario

You can't scale a human reading every account's support history before
renewal. You want a ranked list of the accounts most likely to churn, and the
dollar amount at stake, so success management calls the right accounts first.

## How it works

1. `laya_prob(accounts, '…')` scores each account 0..1 on churn signals.
2. `ORDER BY churn_risk DESC` ranks strongest first.
3. The second query adds a `0.7` threshold and sorts by `mrr_usd` to show
   the *revenue* at risk among the confident churners.
4. `mrr_usd` is plain SQL — the model only does the meaning part.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Signal, not verdict:** this is an early-warning score, not a prediction.
  "Asked about competitor pricing" and "main user left" both raise it.
- **Combine with SQL:** the churn *value* (`mrr_usd`) stays in SQL; only the
  risk *signal* comes from the model. Keep numbers out of the condition.
- **Wording:** "showing signs it will cancel or not renew" is observable from
  the support text. Avoid "unhappy" — too broad.
