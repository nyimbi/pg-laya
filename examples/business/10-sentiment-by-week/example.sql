-- 10 · Sentiment by week  (business)
-- Count how many reviews per week the customer sounds frustrated in, to see
-- whether frustration is trending up or down.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS reviews;
CREATE TABLE reviews (
  id         serial PRIMARY KEY,
  body       text NOT NULL,
  created_at timestamptz NOT NULL
);

INSERT INTO reviews (body, created_at) VALUES
  ('The export broke again and I lost an hour of work. Third time this month.', now() - interval '2 days'),
  ('Glad to be back, the new search is so much faster.',                        now() - interval '3 days'),
  ('Waiting two days for a reply and still no answer. Frustrating.',            now() - interval '9 days'),
  ('Smooth onboarding, no issues so far.',                                     now() - interval '10 days'),
  ('The app froze while I was typing and I lost my draft. Again.',              now() - interval '16 days'),
  ('Pricing feels steep for what it does lately.',                              now() - interval '17 days'),
  ('Really happy with the support team this week.',                             now() - interval '23 days'),
  ('Bugs are piling up and updates keep breaking things.',                      now() - interval '24 days');

-- The query: per week, how many reviews are frustrated vs total.
SELECT date_trunc('week', created_at) AS week,
       count(*) FILTER (WHERE laya(reviews, 'the customer sounds frustrated or upset')) AS frustrated,
       count(*) AS total
FROM reviews
WHERE created_at >= now() - interval '30 days'
GROUP BY 1
ORDER BY 1 DESC;

-- A share, so the trend is comparable week to week.
SELECT date_trunc('week', created_at) AS week,
       round((100.0 * count(*) FILTER (WHERE laya(reviews, 'the customer sounds frustrated or upset'))
             / nullif(count(*), 0))::numeric, 0) AS pct_frustrated
FROM reviews
WHERE created_at >= now() - interval '30 days'
GROUP BY 1
ORDER BY 1 DESC;
