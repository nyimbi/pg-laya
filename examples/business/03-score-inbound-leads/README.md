# Score inbound leads

**Category:** Business · **Functions:** `laya_prob`, `laya(…, threshold)`, `ORDER BY`

Score each inbound lead by purchase intent so the sales team works the
hottest ones first. The condition encodes a compact version of BANT
(budget, authority, need, timeline) in plain language.

## Scenario

Leads arrive from webinars, downloads, outbound and organic channels, each
with a free-text note. You want a single 0..1 "intent" score per lead so
reps start with the most promising. The model reads the note, title and
company together — the whole row is what it sees.

## How it works

1. `laya_prob(leads, '…')` scores each lead 0..1 on the intent condition.
2. `ORDER BY intent DESC` puts the hottest first — no threshold needed just
   to rank.
3. The second query adds `0.7` to get a strict "working list" of leads the
   model is confident about.
4. Both queries share the condition, so the second is a cache hit.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Wording:** "budget, authority, and intent to buy within a quarter" is
  observable from the note. Avoid vague labels like "qualified".
- **Whole row:** the model sees `company`, `title` and `note` together, so a
  "VP Eng" with a hard deadline scores higher than the same note from an
  intern.
- **Cost:** one score per lead. On a large CRM, pre-filter by
  `created_at` or channel before scoring.
