# Detect fraud signals

**Category:** Business · **Functions:** `laya_prob`, `laya(…, threshold)`, `ORDER BY`

Read each transaction's context and flag the ones that look fraudulent, so a
human reviews a short list instead of every charge. The model weighs the
narrative (new device, different city, card reported safe) that rigid rules
miss.

## Scenario

Rules catch obvious cases (same card, two cities, 20 minutes apart). But a
lot of fraud is subtle and contextual. You want a second, meaning-based
signal that ranks *all* transactions by risk, so the review team works the
top of a ranked list.

## How it works

1. `laya_prob(transactions, '…')` scores each transaction 0..1 on fraud
   signals from the context text.
2. `ORDER BY risk DESC` ranks every transaction.
3. The second query adds `0.7` for a strict review queue, ordered by amount
   (bigger losses first).
4. The numeric fields (`amount_usd`, `customer_id`) stay in SQL.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Complement, don't replace, rules.** Use this alongside velocity/geo
  rules; the model adds the contextual signal.
- **It is a signal, not a verdict.** A high score means "a human should look
  at this" — never auto-decline on the model alone.
- **Wording:** "shows signs of fraud or unauthorised use" is what the context
  can actually evidence. Avoid "is fraudulent" — too strong for a probability.
