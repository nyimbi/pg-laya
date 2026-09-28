-- 02 · Multi-label topics  (pattern)
-- Tag a message with every topic it covers (not just one), using the full
-- probability vector from laya_eval and a per-topic cutoff.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS messages;
CREATE TABLE messages (
  id   serial PRIMARY KEY,
  body text NOT NULL
);

INSERT INTO messages (body) VALUES
  ('My invoice is wrong and the app keeps crashing when I try to export it.'),
  ('Can we talk about upgrading to the enterprise plan and adding SSO?'),
  ('I love the new dashboard, but the search is slow on big datasets.'),
  ('Someone logged into my account from another city — please help, and also send a fresh invoice.'),
  ('The onboarding was smooth, no problems to report.');

-- The raw answer: the probability for every topic at once.
SELECT id,
       laya_eval(messages, 'which topics does this message cover?', 'choice',
                 ARRAY['billing', 'technical', 'security', 'sales', 'praise']) AS topics
FROM messages
ORDER BY id;

-- Multi-label: keep every topic above 0.3, as an array.
SELECT id,
       (SELECT array_agg(k)
          FROM jsonb_object_keys((laya_eval(messages, 'which topics does this message cover?', 'choice',
                                            ARRAY['billing', 'technical', 'security', 'sales', 'praise'])
                                  -> 'probabilities')) AS k
         WHERE (laya_eval(messages, 'which topics does this message cover?', 'choice',
                          ARRAY['billing', 'technical', 'security', 'sales', 'praise'])
                -> 'probabilities' ->> k)::float8 >= 0.3
       ) AS labels
FROM messages
ORDER BY id;
