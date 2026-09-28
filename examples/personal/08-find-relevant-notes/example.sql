-- 08 · Find relevant notes  (personal)
-- Search your notes by meaning, not keywords: pull every note about a topic
-- even when you phrased it differently each time.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS notes;
CREATE TABLE notes (
  id      serial PRIMARY KEY,
  body    text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO notes (body, created_at) VALUES
  ('The interview is next Thursday. Prepare three stories about a hard decision I made and what I learned.', now() - interval '20 days'),
  ('Good coffee place by the station — oat latte, no sugar. Ask for the window seat.'                        , now() - interval '12 days'),
  ('Before the talk on Friday: rehearse the opening, check the slides, arrive early to test the projector.'   , now() - interval '8 days'),
  ('Grocery list: oats, eggs, spinach, salmon, blueberries, olive oil.'                                      , now() - interval '5 days'),
  ('Mock interview feedback: answer more concisely, lead with the outcome, then the detail.'                 , now() - interval '3 days'),
  ('Bookshelf reorganization done. Donated ten books, kept the ones I will actually reread.'                 , now() - interval '1 day');

-- The query: every note about "preparing for a job interview", any phrasing.
SELECT id, created_at, body
FROM notes
WHERE laya(notes, 'this note is about preparing for a job interview')
ORDER BY created_at;

-- How sure is each match, for a closer look at the borderline ones.
SELECT id, body,
       round(laya_prob(notes, 'this note is about preparing for a job interview')::numeric, 2) AS relevance
FROM notes
ORDER BY relevance DESC;
