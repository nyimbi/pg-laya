# Route tickets by team

**Category:** Business · **Functions:** `laya_choice`, `GROUP BY`

Classify each open ticket into the team that should own it, then count the
workload per team. `laya_choice` returns one label from a closed set you
define — no free text, nothing to parse.

## Scenario

Tickets arrive with no consistent tags. You want automatic first-line
routing: billing, technical, security, or sales. Writing the options the way
a person reads them (`'billing'`, not `'BIL'`) matters — the model picks the
option whose meaning best fits the row.

## How it works

1. `laya_choice(tickets, '…', ARRAY[…])` asks the model to pick one of the
   given options for each row.
2. The first query labels every open ticket.
3. The second groups by the label to show the queue depth per team.
4. Both queries share the same `(question, options)`, so the second is
   served from the session cache.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Closed set:** every row must fit one option. There is no "none of the
  above" unless you add one — so choose a set where each ticket has a
  sensible home.
- **Persisting labels:** to write the label back, see
  `examples/patterns/03-human-in-the-loop` for routing only the confident
  ones, or a plain `UPDATE … SET team = laya_choice(…)` for all of them.
- **Options order:** it does not affect the answer, only readability.
