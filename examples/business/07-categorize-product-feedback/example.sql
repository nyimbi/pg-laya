-- 07 · Categorize product feedback  (business)
-- Bucket product reviews by theme so the team can see what users actually
-- talk about, and how much.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS reviews;
CREATE TABLE reviews (
  id      serial PRIMARY KEY,
  rating  int  NOT NULL,
  body    text NOT NULL
);

INSERT INTO reviews (rating, body) VALUES
  (1, 'The app crashed while I was filling the form and I lost everything I had typed. Second time this week.'),
  (5, 'Loved the new dashboard. Setup took ten minutes and it just works.'),
  (2, 'Your pricing jumped 40% with no notice. For what we get, we should look at the competition.'),
  (4, 'Would love a CSV export. Everything else is great.'),
  (1, 'Tried to log in on a new device and it never let me in. Support took two days to answer.'),
  (5, 'The integrations saved our team hours every week. Best tool we use.'),
  (3, 'Solid, but the search is slow on big datasets and sometimes returns nothing.');

-- The query: one theme per review, then the theme counts.
SELECT id, rating,
       laya_choice(reviews, 'what is this review mainly about?',
                   ARRAY['reliability / bugs', 'pricing', 'missing feature', 'praise', 'support experience', 'performance']) AS theme
FROM reviews
ORDER BY id;

SELECT laya_choice(reviews, 'what is this review mainly about?',
                   ARRAY['reliability / bugs', 'pricing', 'missing feature', 'praise', 'support experience', 'performance']) AS theme,
       count(*) AS reviews,
       round(avg(rating::numeric), 2) AS avg_rating
FROM reviews
GROUP BY 1
ORDER BY 2 DESC;
