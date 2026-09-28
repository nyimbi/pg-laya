# Rank job applicants

**Category:** Business · **Functions:** `laya_prob`, `laya(…, threshold)`, `ORDER BY`

Rank applicants against a role's must-haves so a human screens the top of
the stack, not all of it. The must-haves live in one plain-language
condition; the model scores each summary against it.

## Scenario

A 40-person applicant stack is too many to read before a first call. You
want a ranked shortlist against the role's real requirements — years, stack,
depth, production experience — not keyword matches on the résumé.

## How it works

1. `laya_prob(applicants, '…')` scores each summary 0..1 against the
   must-haves condition.
2. `ORDER BY fit DESC` ranks the whole stack.
3. The second query adds `0.7` to pull a strict shortlist.
4. Both share the condition → the shortlist is a cache hit.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **This is a screener, not a hire.** It orders the stack for a human; it
  never decides. Keep a person in the loop for any hiring decision.
- **State the bar explicitly:** "5+ years, Go or Rust, deep Postgres,
  production experience" is checkable from the summary. Vague conditions give
  vague rankings.
- **Fairness caveat:** the model may encode biases present in the text.
  Review the shortlist, and consider which fields you actually need the model
  to see (a view can hide name/demographics if that matters to you).
