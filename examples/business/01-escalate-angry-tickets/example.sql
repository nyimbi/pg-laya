-- 01 · Escalate angry tickets  (business)
-- Rank open support tickets by how angry the customer sounds, so the most
-- urgent ones surface to a human first.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   the laya extension installed and the local model server running
--           (see s/install.html for both).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';   -- the shape the local model is trained on
SET laya.concurrency  = 4;
SET laya.notices      = off;

-- Sample data — replace with your own table.
DROP TABLE IF EXISTS tickets;
CREATE TABLE tickets (
  id      serial PRIMARY KEY,
  subject text NOT NULL,
  body    text NOT NULL,
  status  text NOT NULL DEFAULT 'open'
);

INSERT INTO tickets (subject, body, status) VALUES
  ('Can''t log in',            'I have been locked out for two days and losing money every hour. This is unacceptable and I want it fixed now.', 'open'),
  ('Invoice question',         'Could you clarify line 3 on invoice #4412? Just checking the tax amount looks right.', 'open'),
  ('Feature idea',             'Would be great if you supported dark mode. Not urgent, just a thought.', 'open'),
  ('Wrong charge',             'You billed me twice this month. I''ve emailed three times with no reply. I''m done with this product.', 'open'),
  ('Password reset',           'The reset link expired, can you send a new one? No rush.', 'open'),
  ('Data export failed',       'My export failed for the third time. I have a board meeting Monday and need this data today or we will have to switch vendors.', 'open');

-- The query: every open ticket, ranked by anger, top 5.
SELECT id, subject,
       laya_prob(tickets, 'the customer is angry, frustrated, or about to give up') AS anger
FROM tickets
WHERE status = 'open'
ORDER BY anger DESC
LIMIT 5;

-- A stricter cut: only tickets the model is confident about as angry.
SELECT id, subject
FROM tickets
WHERE status = 'open'
  AND laya(tickets, 'the customer is angry, frustrated, or about to give up', 0.8);
