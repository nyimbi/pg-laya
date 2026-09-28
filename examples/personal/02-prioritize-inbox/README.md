# Prioritize the inbox

**Category:** Personal · **Functions:** `laya_prob`, `laya(…, threshold)`, `ORDER BY`

Rank your personal emails by how urgently they need a reply, so you start the
day with what actually matters instead of whatever arrived first. Newsletters
and statements drop to the bottom; the landlord and your mom rise to the top.

## Scenario

Your inbox mixes the genuinely urgent (a lease to sign, a parent who needs a
ride) with the ignorable (sales blasts, statements). You want a ranked "what
needs me" list for today, not a star/unstar ritual.

## How it works

1. `laya_prob(emails, '…')` scores each email 0..1 on "needs a reply soon /
   has a deadline".
2. `ORDER BY urgency DESC` puts the urgent first.
3. The second query adds `0.7` for a strict must-answer list.
4. Both share the condition → the second is a cache hit.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Frame it as "needs me":** the condition is about *your* obligation (reply
  soon / deadline), not the sender's importance — that's what separates a
  sales email from a parent's.
- **Privacy:** run against the local model server so email content stays on
  your machine by default. If you point at a cloud endpoint, consider a view
  that omits the preview text.
- **Threshold:** `0.7` = "clearly needs me". Loosen to 0.6 to catch more,
  tighten to 0.8 for only the obvious.
