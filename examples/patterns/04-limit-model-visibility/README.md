# Limit what the model sees

**Category:** Pattern · **Function:** `laya_choice` over a **view**

Every row sent to the model is the *whole* row, serialized with `to_json`.
If your table carries PII, tokens, or big blobs the model does not need, a
view in front of it means only the relevant columns are judged — and only
those columns leave Postgres (matters more when `laya.api_url` points at a
cloud endpoint).

## Scenario

A support table has names, emails, the message, and an attachment blob. You
only need the message to route the ticket. Judging the table would send the
PII and the blob to the model for every row; judging a view sends just the
message.

## How it works

1. The real `support` table carries `customer`, `email`, `message`,
   `attachment`.
2. `support_text` exposes only `id` and `message`.
3. `laya_choice(v, …)` is called on the **view alias** `v` — so the model
   sees only the view's columns.
4. Views are streamed and batched exactly like tables, so nothing else
   changes.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Call the model on the view, not the table:** `laya(support, …)` would
  still send every column. The alias you pass is what gets serialized.
- **Views also pre-filter:** a `WHERE` inside the view shrinks the set that
  is judged at all (see the commented example).
- **Cloud endpoints:** this is the main privacy lever when
  `laya.api_url` points off-machine — decide, column by column, what is
  allowed to leave.
- **Avoid the subquery trap:** `SELECT … FROM (SELECT …) s WHERE laya(s, …)`
  yields an anonymous `record` that cannot be read ahead (one request per
  row). A named view (or base table) does not have that problem.
