# Plan a move

**Category:** Personal · **Functions:** `laya_choice`, `GROUP BY`

Sort a household inventory into keep / donate / sell / recycle in one pass,
and count how much of each you have — so the big, dreaded decision becomes a
review of a labelled list instead of a hundred small decisions at the
cardboard box.

## Scenario

Moving is mostly the "do I keep this?" question, repeated per item. You want
a first-pass suggestion for each thing, based on the note you wrote about it,
so you spend your energy on the genuinely hard calls.

## How it works

1. `laya_choice(inventory, '…', ARRAY['keep','donate','sell','recycle'])`
   picks a disposition per item from its note.
2. The first query shows each item with its suggested bucket.
3. The second counts items per bucket — how much to box, give, list, or bin.
4. Same `(question, options)` → the counts are a cache hit.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **A first pass, not a verdict:** review the labels — sentimental items
  (grandmother's lamps) are exactly where you override the model.
- **The note does the work:** the model decides from what you wrote. Vague
  notes give vague calls; "barely used", "broken", "sentimental" are
  decisive.
- **Closed set fits the task:** every item has a sensible home among the four
  buckets.
