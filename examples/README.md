# pg-laya examples

Fully-coded, runnable examples for the `laya` PostgreSQL extension. Each
folder has a `README.md` (scenario, how it works, notes) and an
`example.sql` you can run as-is:

```bash
psql -d mydb -f examples/business/01-escalate-angry-tickets/example.sql
```

Every `example.sql` creates a small sample table, seeds realistic rows, sets
the local-server defaults (`laya.state_mode = 'native'`,
`laya.concurrency = 4`), and runs the query. Replace the sample data with
your own table to use it for real. Prereq: the `laya` extension installed and
the local model server running (see [`s/install.html`](../s/install.html)).

Counts: **12 business · 8 personal · 7 patterns = 27 examples.**

## Business

| # | Example | What it does | Key function |
| --- | --- | --- | --- |
| 01 | [Escalate angry tickets](business/01-escalate-angry-tickets/) | Rank open tickets by customer anger | `laya_prob` |
| 02 | [Route tickets by team](business/02-route-tickets-by-team/) | Classify tickets into owning teams + workload | `laya_choice` |
| 03 | [Score inbound leads](business/03-score-inbound-leads/) | Score leads by purchase intent (BANT) | `laya_prob` |
| 04 | [Segment customers by persona](business/04-segment-customers-by-persona/) | Bucket customers into marketing personas | `laya_choice` |
| 05 | [Flag churn risk](business/05-flag-churn-risk/) | Rank accounts by churn signal, total at-risk MRR | `laya_prob` |
| 06 | [Rank job applicants](business/06-rank-job-applicants/) | Rank a stack against the role's must-haves | `laya_prob` |
| 07 | [Categorize product feedback](business/07-categorize-product-feedback/) | Bucket reviews by theme + avg rating | `laya_choice` |
| 08 | [Prioritize the support queue](business/08-prioritize-support-queue/) | Urgency rubric blended with ticket age | `laya_score` |
| 09 | [Detect fraud signals](business/09-detect-fraud-signals/) | Rank transactions by fraud signal | `laya_prob` |
| 10 | [Sentiment by week](business/10-sentiment-by-week/) | Weekly frustrated-customer trend | `laya` + `GROUP BY` |
| 11 | [Did the meeting decide?](business/11-did-the-meeting-decide/) | Flag meetings that produced a decision | `laya` |
| 12 | [Route by language + confidence](business/12-route-by-language-and-confidence/) | Route to a language team, human fallback | `laya_choice` + `laya_confidence` |

## Personal

| # | Example | What it does | Key function |
| --- | --- | --- | --- |
| 01 | [Categorize expenses](personal/01-categorize-expenses/) | Auto-tag a month of transactions | `laya_choice` |
| 02 | [Prioritize the inbox](personal/02-prioritize-inbox/) | Rank emails by "needs a reply soon" | `laya_prob` |
| 03 | [Tag photos by memory](personal/03-tag-photos-by-memory/) | Tag photo captions by memory type | `laya_choice` |
| 04 | [Organize recipes](personal/04-organize-recipes/) | Classify by meal + diet, answer real questions | `laya_choice` + `laya` |
| 05 | [Pick a movie night](personal/05-pick-a-movie-night/) | Rank the watchlist by fit for a mood | `laya_prob` |
| 06 | [Track habit notes](personal/06-track-habit-notes/) | Flag journal days where a habit was kept | `laya` |
| 07 | [Plan a move](personal/07-plan-a-move/) | Sort inventory into keep/donate/sell/recycle | `laya_choice` |
| 08 | [Find relevant notes](personal/08-find-relevant-notes/) | Semantic search over personal notes | `laya` + `laya_prob` |

## Patterns & techniques

| # | Example | What it teaches | Key idea |
| --- | --- | --- | --- |
| 01 | [Pick a threshold](patterns/01-pick-a-threshold/) | Read the probability distribution, choose a cutoff | `width_bucket` + cache |
| 02 | [Multi-label topics](patterns/02-multi-label-topics/) | Tag a row with *every* topic it covers | `laya_eval` vector |
| 03 | [Human in the loop](patterns/03-human-in-the-loop/) | Auto-apply confident labels, queue the rest | `laya_confidence` |
| 04 | [Limit what the model sees](patterns/04-limit-model-visibility/) | Use a view to keep PII/blobs out of the model | view as input |
| 05 | [Manage costs on large tables](patterns/05-manage-costs-large-tables/) | Cheap SQL first, spend guards, `laya_stats()` | spend discipline |
| 06 | [Compose with plain SQL](patterns/06-compose-with-plain-sql/) | Joins, CTEs, `CASE`, aggregates around `laya()` | `laya` as `STABLE` fn |
| 07 | [React to new rows](patterns/07-react-to-new-rows/) | Trigger enqueues, scheduled tick judges and acts | `laya_watch` |

## Conventions

- **Whole row is the input.** `laya(table, …)` serializes the row with
  `to_json`; column names are part of what the model sees.
- **Local by default.** The default `laya.api_url` is the local Ollaya model
  server, so row content stays on the machine.
- **`native` state mode.** The examples set `laya.state_mode = 'native'`
  (one row per request) — the shape the local model is trained on. For the
  cloud Jev model, use the default `jev` mode and batches of 20.
- **Cost.** ~175 input tokens per row. Filter cheaply in SQL before `laya()`.
