# Route by language, with a human fallback

**Category:** Business · **Functions:** `laya_choice`, `laya_confidence`

Assign each inbound message to the right language team — but route the
low-confidence ones to a human instead of guessing. This pairs `laya_choice`
with `laya_confidence` on the *same* options, so it costs one model call per
row, not two.

## Scenario

Inbound messages arrive in several languages, and some are mixed or unclear.
You want automatic routing for the clear cases, and a "needs a human" path
when the model is not sure — so a wrong guess never silently lands with the
wrong team.

## How it works

1. `laya_choice(messages, '…', ARRAY[…])` picks a team (or `needs a human`)
   per message.
2. `laya_confidence(messages, '…', 'choice', ARRAY[…])` returns how sure the
   model is about that pick.
3. Because the `(question, kind, options)` triple is identical, both share
   one cache entry — one API call per row.
4. The second query pulls the human queue: confidence below `0.6`.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Add the escape hatch as an option:** `'needs a human'` in the closed set
  gives the model a way to say "I don't know" instead of forcing a wrong
  pick.
- **Tune the cutoff:** `0.6` is a starting point. Lower it to auto-route more
  (and risk more misses); raise it to be safer.
- **Same triple = one call:** if you change the options in one of the two
  calls, they no longer share the cache entry and you pay twice.
