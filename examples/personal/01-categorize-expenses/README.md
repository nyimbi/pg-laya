# Categorize expenses

**Category:** Personal · **Functions:** `laya_choice`, `GROUP BY`, `sum`

Auto-categorize a month of card transactions — groceries, dining, transport,
utilities, entertainment, subscriptions, travel, … — so you can see where the
money actually went, without tagging each line by hand.

## Scenario

Your bank app's categories are wrong half the time (a "restaurant" that was
actually a work dinner, a "store" that was groceries). You want a sane
category per transaction inferred from the merchant name, and a per-category
total for the month.

## How it works

1. `laya_choice(transactions, '…', ARRAY[…])` assigns one category per row
   from the merchant name.
2. The first query lists each transaction with its category for spot-checking.
3. The second groups by category and sums the amounts — plain SQL.
4. Same `(question, options)` → the totals are a cache hit.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Keep the set small and distinct:** 8–9 everyday categories work well. Too
  many overlapping options blur the picks.
- **Merchant is enough:** you don't need the amount to categorize — but the
  whole row is sent, which is fine for a personal table. For large/PII-heavy
  tables, see `examples/patterns/04-limit-model-visibility`.
- **Privacy:** this runs against your local model server, so the transaction
  text does not leave the machine by default.
