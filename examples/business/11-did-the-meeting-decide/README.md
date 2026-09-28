# Did the meeting decide?

**Category:** Business · **Functions:** `laya`, `laya_prob`, `laya(…, threshold)`

Read meeting notes and flag the ones that ended with an actual decision or an
owner + date, versus the ones that just talked. A clean yes/no predicate over
free text — hard to do with keywords, easy to state in a sentence.

## Scenario

After a busy week you want to know which meetings moved something forward and
which spun. "Decided" is a judgment about the *content* of the notes, not a
tag someone remembered to set.

## How it works

1. `laya(meetings, '…')` is a boolean: did this meeting end with a concrete
   decision or an assigned action with owner + date?
2. `laya_prob(meetings, '…')` gives the same as a 0..1 so you can see how
   confident the split is.
3. The second query adds `0.7` for a strict "clearly decided" list.
4. All three share one condition → all cached after the first scan.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Make the bar concrete:** "a concrete decision or an assigned action with
  an owner and date" is checkable from the notes. "Was productive" is not.
- **Boolean + probability together:** showing both `decided` and `p` lets you
  see the borderline rows (near 0.5) worth a second look.
- **Wording:** refer to the row as "the meeting" so the model maps the
  condition onto the notes column.
