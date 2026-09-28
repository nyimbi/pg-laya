-- 02 · Route tickets by team  (business)
-- Classify each open ticket into the team that should own it, and count how
-- many land in each bucket.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS tickets;
CREATE TABLE tickets (
  id      serial PRIMARY KEY,
  subject text NOT NULL,
  body    text NOT NULL,
  status  text NOT NULL DEFAULT 'open'
);

INSERT INTO tickets (subject, body, status) VALUES
  ('Double charged',            'I was billed twice for the same subscription. Please refund the duplicate.', 'open'),
  ('App crashes on startup',    'Since the last update the app crashes every time I open it on my iPhone 14.', 'open'),
  ('Suspicious login',          'I got an email about a login from a city I have never been to. Please secure my account.', 'open'),
  ('Upgrade to Pro',            'How do I upgrade my plan to Pro? Is it per user or per workspace?', 'open'),
  ('Refund not received',       'I was promised a refund two weeks ago and still have not seen it.', 'open'),
  ('Cannot connect to Wi-Fi',   'The dashboard keeps timing out when I load the reports page.', 'open'),
  ('Phishing email',            'This looks like a fake email from your domain asking for my password. Is it real?', 'open');

-- The query: one label per ticket, from a closed set.
SELECT id, subject,
       laya_choice(tickets, 'which team should handle this ticket?',
                   ARRAY['billing', 'technical', 'security', 'sales']) AS team
FROM tickets
WHERE status = 'open'
ORDER BY id;

-- The workload: how many open tickets per team.
SELECT laya_choice(tickets, 'which team should handle this ticket?',
                   ARRAY['billing', 'technical', 'security', 'sales']) AS team,
       count(*) AS open_tickets
FROM tickets
WHERE status = 'open'
GROUP BY 1
ORDER BY 2 DESC;
