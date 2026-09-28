# Track habit notes

**Category:** Personal · **Functions:** `laya`, `count(*) FILTER (WHERE …)`

Read daily journal entries and flag the days where a habit was actually kept,
so you can see your real streak without a manual check-in on every single
day. The habit is a one-sentence condition over free text.

## Scenario

You journal every day but don't tick a "ran today" box. You want to know your
actual running days this week — inferred from what you wrote, not from a form
you have to remember to fill in.

## How it works

1. `laya(journal, 'the person went for a run on this day')` is a boolean per
   day, read from the free-text entry.
2. The first query shows the flag next to each entry for spot-checking.
3. The second counts run days vs total days with `count(*) FILTER (WHERE …)`.
4. A single condition → a single cached scan for both queries.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Phrase it as the observable event:** "went for a run on this day" matches
  "ran five kilometres" and "did the morning run", and correctly ignores
  "skipped the run".
- **Near-misses are a human call:** "went for a short walk" is not a run — the
  model should say no. Review the borderline days.
- **Local by default:** journal text is private; it stays on your machine with
  the local model server.
