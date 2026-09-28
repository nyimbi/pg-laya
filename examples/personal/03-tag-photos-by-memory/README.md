# Tag photos by memory

**Category:** Personal · **Functions:** `laya_choice`, `GROUP BY`

Give each photo's caption a memory type — family, travel, food, work,
fitness, friends, nature, milestone — so you can browse by the kind of moment
instead of only by date. The model reads the caption you wrote (or a generated
one) and picks the best-fitting bucket.

## Scenario

Years of photos, sorted only by date. You want to pull up "all the food
photos" or "every family weekend" quickly. A memory type is something you
infer from the caption, not a field you maintain.

## How it works

1. `laya_choice(photos, '…', ARRAY[…])` assigns one memory type per photo
   from its caption.
2. The first query shows each caption with its tag for spot-checking.
3. The second counts photos per memory type.
4. Same `(question, options)` → the counts are a cache hit.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Pick buckets you'd actually browse:** 6–9 everyday memory types beat a
  long exhaustive taxonomy.
- **One tag per photo:** `laya_choice` returns one. A photo that is both
  "travel" and "food" gets the dominant read. For multi-label, see
  `examples/patterns/02-multi-label-topics`.
- **Local by default:** captions stay on your machine with the local model
  server.
