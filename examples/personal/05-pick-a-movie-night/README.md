# Pick a movie night

**Category:** Personal · **Functions:** `laya_prob`, `laya(…, threshold)`, `ORDER BY`

Rank your watchlist by how well each film fits the mood you want tonight, so
picking takes seconds instead of scrolling for twenty minutes. The "mood" is
one plain-language condition; the model scores every unwatched film against it.

## Scenario

Six unwatched films, and you want something "relaxed and light" for a
friends' evening — not the somber war film, not the dense thriller. You want
the watchlist ranked by fit for *that* mood, and a top pick.

## How it works

1. `WHERE NOT watched` is a cheap SQL filter — only unwatched films are judged.
2. `laya_prob(watchlist, '…')` scores each film 0..1 on the mood condition.
3. `ORDER BY fit DESC` ranks best-fit first.
4. The second query adds `0.7` and `LIMIT 3` for a confident shortlist.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Change the mood, change the ranking:** swap the condition to "something
  intense and twisty" and the same watchlist ranks completely differently —
  no re-tagging.
- **Pre-filter cheaply first:** `NOT watched` keeps the model from re-scoring
  films you've seen.
- **The whole row is seen:** title, year and blurb together inform the fit.
