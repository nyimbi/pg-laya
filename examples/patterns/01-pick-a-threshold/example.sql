-- 01 · Pick a threshold  (pattern)
-- Look at the distribution of a probability, choose a cutoff that makes
-- sense, then apply it — for free, from the session cache.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS reviews;
CREATE TABLE reviews (
  id   serial PRIMARY KEY,
  body text NOT NULL
);

INSERT INTO reviews (body) VALUES
  ('Absolutely furious. I have called four times and nobody has fixed it.'),
  ('A little annoyed it took a day, but it works now. Fine.'),
  ('Everything is great, no complaints at all.'),
  ('Mildly frustrated with the loading speed, otherwise happy.'),
  ('This is the worst experience I have had. I want my money back.'),
  ('Pretty neutral, it does the job.'),
  ('Slightly irritated about the email I got, but not a big deal.');

-- Step 1: the distribution. Bucket the probability into tenths.
SELECT width_bucket(laya_prob(reviews, 'the customer sounds frustrated or upset'), 0, 1, 10) AS bucket,
       count(*) AS reviews
FROM reviews
GROUP BY 1
ORDER BY 1;

-- Step 2: the middle, to see what the model finds ambiguous.
SELECT body,
       round(laya_prob(reviews, 'the customer sounds frustrated or upset')::numeric, 2) AS p
FROM reviews
WHERE laya_prob(reviews, 'the customer sounds frustrated or upset') BETWEEN 0.4 AND 0.6
ORDER BY p;

-- Step 3: apply the cutoff you chose. Cached — no new API calls.
SELECT body
FROM reviews
WHERE laya(reviews, 'the customer sounds frustrated or upset', 0.5)
ORDER BY 1;
