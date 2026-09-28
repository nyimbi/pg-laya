-- 05 · Manage costs on large tables  (pattern)
-- Every row reaching laya() costs tokens. Put cheap SQL first, bound the
-- window, and turn on a spend guard so a missing WHERE cannot run away.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = on;      -- watch progress + cost per request

-- Spend guards: abort a statement that would send too much to the API.
SET laya.max_rows_per_statement   = 1000;
SET laya.max_chars_per_statement  = 1000000;

DROP TABLE IF EXISTS events;
CREATE TABLE events (
  id         serial PRIMARY KEY,
  channel    text NOT NULL,
  created_at timestamptz NOT NULL,
  message    text NOT NULL
);

-- A realistic slice (in production this table could be millions of rows).
INSERT INTO events (channel, created_at, message)
SELECT 'email', now() - (g || ' hours')::interval,
       CASE (g % 4)
         WHEN 0 THEN 'The customer is very upset about a failed payment.'
         WHEN 1 THEN 'Just checking on the status of my order, thanks.'
         WHEN 2 THEN 'Can you add a feature to export to PDF?'
         ELSE        'Everything works fine, no issues.'
       END
FROM generate_series(1, 50) AS g;

-- The disciplined query: cheap filters first, a bounded window, then laya().
SELECT count(*) FILTER (WHERE laya(events, 'the customer is upset or about to cancel')) AS upset,
       count(*) AS judged
FROM events
WHERE channel = 'email'                          -- 1. cheap, indexed
  AND created_at >= now() - interval '7 days'    -- 2. bound the window
  -- 3. only then does the model see each remaining row
;

-- See what this statement cost.
SELECT (laya_stats ->> 'requests')::int       AS requests,
       (laya_stats ->> 'rows_evaluated')::int AS rows_evaluated,
       (laya_stats ->> 'input_tokens')::int   AS input_tokens,
       laya_stats ->> 'estimated_cost_usd'    AS estimated_cost_usd,
       (laya_stats ->> 'cache_hits')::int     AS cache_hits
FROM laya_stats();

-- If the set is still too big to explore, sample first:
-- SELECT * FROM events
-- WHERE channel = 'email' AND created_at >= now() - interval '7 days'
-- TABLESAMPLE SYSTEM (5)
-- WHERE laya(events, 'the customer is upset or about to cancel');
