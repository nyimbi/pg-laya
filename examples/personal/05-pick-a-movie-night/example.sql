-- 05 · Pick a movie night  (personal)
-- Rank your watchlist by how well each film fits the mood you want tonight,
-- so picking takes seconds instead of scrolling for twenty minutes.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS watchlist;
CREATE TABLE watchlist (
  id         serial PRIMARY KEY,
  title      text NOT NULL,
  year       int  NOT NULL,
  blurb      text NOT NULL,
  watched    boolean NOT NULL DEFAULT false
);

INSERT INTO watchlist (title, year, blurb, watched) VALUES
  ('The Long Quiet',   2019, 'A slow, meditative drama about a lighthouse keeper. Gentle, contemplative, very calm.', false),
  ('Neon Heist',        2021, 'A fast, clever caper with a great score. Fun, high energy, lots of twists.',           false),
  ('Winter''s End',     2016, 'A heavy, somber war film. Long, emotionally draining, not for a light evening.',       false),
  ('Small Wonders',     2022, 'A warm, funny family comedy about a chaotic birthday. Light, feel-good, easy.',        false),
  ('The Archivist',     2018, 'A dense, twisty mystery thriller. Needs full attention, keeps you guessing.',           false),
  ('Coastal Air',       2020, 'A breezy, low-stakes romance set on the coast. Relaxing and pleasant.',                 true);

-- The query: rank the unwatched by fit for a "relaxed, light evening".
SELECT title, year,
       laya_prob(watchlist, 'a good fit for a relaxed, light movie night with friends') AS fit
FROM watchlist
WHERE NOT watched
ORDER BY fit DESC;

-- Tonight''s pick: the best fit the model is confident about.
SELECT title, year, blurb
FROM watchlist
WHERE NOT watched
  AND laya(watchlist, 'a good fit for a relaxed, light movie night with friends', 0.7)
ORDER BY laya_prob(watchlist, 'a good fit for a relaxed, light movie night with friends') DESC
LIMIT 3;
