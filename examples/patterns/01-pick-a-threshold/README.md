# Pick a threshold

**Category:** Pattern · **Functions:** `laya_prob`, `width_bucket`, `laya(…, threshold)`

The default threshold is `0.5`, but the right cutoff depends on your data.
This pattern shows the distribution of a probability, lets you see the
ambiguous middle, and applies the cutoff you choose — with the second and
third queries served from the session cache, so it costs one scan total.

## Scenario

You don't know whether "0.5" is the right bar for "frustrated". Maybe 0.6
is, maybe 0.4. Rather than guess, look at where the probabilities actually
fall, inspect the borderline rows, and pick a cutoff you can defend.

## How it works

1. `width_bucket(laya_prob(…), 0, 1, 10)` bins the probability into tenths so
   you see the shape of the distribution.
2. `WHERE laya_prob(…) BETWEEN 0.4 AND 0.6` pulls the ambiguous middle — the
   rows where wording usually needs tightening.
3. `WHERE laya(…, 0.5)` applies your chosen cutoff.
4. All three use the same condition → after the first scan, the rest are
   cache hits. `SELECT laya_stats()` will show `cache_hits` climbing.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **The middle is diagnostic:** a big clump near 0.5 means the condition is
  ambiguous for those rows — tighten the wording, not the threshold.
- **One condition, one cost:** iterating on the threshold is free within a
  session; changing a word in the condition is a new scan.
- **Make it sticky:** once you've chosen, set it per-role or per-database:
  `ALTER DATABASE app SET laya.threshold = 0.6;`
