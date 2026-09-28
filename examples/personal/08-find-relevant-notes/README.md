# Find relevant notes

**Category:** Personal · **Functions:** `laya`, `laya_prob`, `WHERE`, `ORDER BY`

Search your notes by *meaning*, not keywords: pull every note about a topic
even when you phrased it differently each time. A keyword `LIKE '%interview%'`
misses "rehearse the opening" and "mock interview feedback" — the model
catches them.

## Scenario

Your notes are scattered and inconsistently worded. You want everything about
"preparing for a job interview" in one place — the prep, the feedback, the
rehearsal — regardless of the exact words you used.

## How it works

1. `laya(notes, 'this note is about preparing for a job interview')` is a
   boolean per note, matching by meaning.
2. The first query returns the matching notes, oldest first.
3. The second scores every note 0..1 by relevance, so you can see the
   borderline ones (a "bookshelf" note scores ~0).
4. Both share the condition → the relevance pass is a cache hit.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Meaning beats keywords:** "rehearse the opening for Friday" and "mock
  interview feedback" are clearly about interview prep to a human — and to the
  model — even without the word "interview".
- **Look at the scores:** `relevance` near 0.5 is worth a human glance; the
  rest is a confident yes/no.
- **Local by default:** private notes stay on your machine.
