-- 08 · Prioritize the support queue  (business)
-- Score each ticket on an urgency rubric and blend it with a plain-SQL age,
-- so the queue is ordered by real priority, not arrival time.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS tickets;
CREATE TABLE tickets (
  id         serial PRIMARY KEY,
  subject    text NOT NULL,
  body       text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO tickets (subject, body, created_at) VALUES
  ('Production down',    'Our whole storefront is down. Customers cannot check out. This is blocking sales right now.', now() - interval '2 hours'),
  ('Typo on invoice',    'There is a small typo on the invoice footer. No rush, just noticed it.', now() - interval '3 days'),
  ('Question about API', 'How do I paginate the /orders endpoint? Docs not clear.', now() - interval '1 day'),
  ('Data stuck in import','The nightly import has been failing for two days and our reporting is wrong because of it.', now() - interval '1 day'),
  ('Want a dark theme',  'Would be nice to have a dark theme for the dashboard. Nice to have.', now() - interval '5 days');

-- The query: an urgency score (0..3) blended with how old the ticket is.
SELECT id, subject,
       laya_score(tickets, 'how urgent is this ticket for the customer?',
                  ARRAY['not at all', 'minor', 'important', 'blocking']) AS urgency,   -- 0..3
       round(extract(epoch from age(now(), created_at)) / 3600, 0) AS age_hours
FROM tickets
ORDER BY urgency DESC, created_at ASC;

-- One combined priority: 70% urgency, 30% age (normalised 0..1 each).
SELECT id, subject,
       round(
         (0.7 * laya_score_norm(tickets, 'how urgent is this ticket for the customer?',
                                ARRAY['not at all', 'minor', 'important', 'blocking'])
          + 0.3 * least(1, extract(epoch from age(now(), created_at)) / 172800))::numeric
       , 2) AS priority
FROM tickets
ORDER BY priority DESC;
