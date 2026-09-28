-- 07 · Plan a move  (personal)
-- Sort a household inventory into keep / donate / sell / recycle, and count
-- how much of each you have, so the big decision is one pass instead of a
-- hundred small ones.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS inventory;
CREATE TABLE inventory (
  id        serial PRIMARY KEY,
  item      text NOT NULL,
  note      text NOT NULL
);

INSERT INTO inventory (item, note) VALUES
  ('Espresso machine',     'Barely used since we got the better coffee maker. Works fine.'),
  ('Winter coats (x2)',    'Both in good condition, we have three each already.'),
  ('Board games (x5)',     'A few we play every month, the rest have not come out in years.'),
  ('Broken toaster',       'Stopped working last month, keeps tripping the breaker.'),
  ('Vintage lamps (x2)',   'My grandmother''s. Sentimental, but we would not use them in the new place.'),
  ('Yoga mats (x3)',       'Only used one regularly, the other two are boxed up.'),
  ('Cardboard + old papers','Packaging and old paperwork from the last two years.');

-- The query: a disposition per item, then the totals per bucket.
SELECT item,
       laya_choice(inventory, 'for a house move, what should happen to this item?',
                   ARRAY['keep', 'donate', 'sell', 'recycle']) AS disposition
FROM inventory
ORDER BY id;

SELECT laya_choice(inventory, 'for a house move, what should happen to this item?',
                   ARRAY['keep', 'donate', 'sell', 'recycle']) AS disposition,
       count(*) AS items
FROM inventory
GROUP BY 1
ORDER BY 2 DESC;
