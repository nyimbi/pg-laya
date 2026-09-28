-- 03 · Tag photos by memory  (personal)
-- Give each photo's caption a memory type (family, trip, food, …) so you can
-- browse by the kind of moment, not just by date.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS photos;
CREATE TABLE photos (
  id       serial PRIMARY KEY,
  caption  text NOT NULL,
  taken_on date NOT NULL
);

INSERT INTO photos (caption, taken_on) VALUES
  ('Sunday lunch with the whole family at grandma''s house',            '2026-07-05'),
  ('Sunset over the coast on the road trip to the northern lakes',      '2026-08-12'),
  ('First attempt at the new ramen recipe, a little too salty',         '2026-08-20'),
  ('The team celebrating the product launch at the office',             '2026-06-30'),
  ('Morning run in the park, the cherry trees were just blooming',      '2026-04-02'),
  ('Kids'' first day of school, very nervous faces',                    '2026-09-01'),
  ('Trying the new bistro downtown with two friends',                   '2026-08-28'),
  ('Hiking the ridge trail, great views above the valley',              '2026-07-19');

-- The query: a memory type per photo, then how many of each.
SELECT taken_on, caption,
       laya_choice(photos, 'what kind of memory is this photo of?',
                   ARRAY['family', 'travel', 'food', 'work', 'fitness', 'friends', 'nature', 'milestone']) AS memory
FROM photos
ORDER BY taken_on;

SELECT laya_choice(photos, 'what kind of memory is this photo of?',
                   ARRAY['family', 'travel', 'food', 'work', 'fitness', 'friends', 'nature', 'milestone']) AS memory,
       count(*) AS photos
FROM photos
GROUP BY 1
ORDER BY 2 DESC;
