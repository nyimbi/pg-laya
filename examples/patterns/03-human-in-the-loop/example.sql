-- 03 · Human in the loop  (pattern)
-- Auto-apply confident classifications, and send the rest to a review queue
-- instead of guessing. Pairs laya_choice with laya_confidence.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS tickets;
CREATE TABLE tickets (
  id    serial PRIMARY KEY,
  body  text NOT NULL,
  team  text            -- NULL until classified
);

INSERT INTO tickets (body) VALUES
  ('I was charged twice for the same thing, please refund the duplicate.'),
  ('The login button does nothing when I click it on my phone.'),
  ('How do I export my data to a CSV file?'),
  ('I got a warning about a new login I do not recognise.'),
  ('Is there a discount for annual billing?'),
  ('Something is wrong with my account but I cannot say what exactly.');

-- The model's pick + confidence, in one pass (same triple = one call each).
SELECT id,
       laya_choice(tickets, 'which team should handle this ticket?',
                   ARRAY['billing', 'technical', 'sales']) AS team,
       round(laya_confidence(tickets, 'which team should handle this ticket?', 'choice',
                             ARRAY['billing', 'technical', 'sales'])::numeric, 2) AS conf
FROM tickets
ORDER BY id;

-- Auto-apply the confident ones…
UPDATE tickets t
SET team = laya_choice(t, 'which team should handle this ticket?',
                       ARRAY['billing', 'technical', 'sales'])
WHERE laya_confidence(t, 'which team should handle this ticket?', 'choice',
                      ARRAY['billing', 'technical', 'sales']) >= 0.6;

-- …and queue the rest for a human.
SELECT id, body
FROM tickets
WHERE team IS NULL
ORDER BY id;
