-- 12 · Route by language, with a human fallback  (business)
-- Assign each inbound message to the right language team, but send the
-- low-confidence ones to a human instead of guessing.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS messages;
CREATE TABLE messages (
  id     serial PRIMARY KEY,
  body   text NOT NULL
);

INSERT INTO messages (body) VALUES
  ('Can you send me the invoice for my last order? I need it for my accountant.'),
  ('Hola, necesito saber si mi pedido llegará esta semana. Gracias.'),
  ('Bonjour, je n''arrive pas à réinitialiser mon mot de passe depuis hier.'),
  ('My package arrived damaged. How do I start a return?'),
  ('Ich habe eine Frage zu meiner Rechnung. Die Position ist mir nicht klar.'),
  ('Something is off with my account but I cannot tell you in which words, the email is mixed English and Spanish.');

-- The query: a language team per message, plus the model's confidence.
SELECT id,
       laya_choice(messages, 'which language team should reply first?',
                   ARRAY['english', 'spanish', 'french', 'german', 'needs a human']) AS team,
       round(laya_confidence(messages, 'which language team should reply first?', 'choice',
                            ARRAY['english', 'spanish', 'french', 'german', 'needs a human'])::numeric, 2) AS conf
FROM messages
ORDER BY id;

-- The human queue: anything the model is not confident enough to auto-route.
SELECT id, body
FROM messages
WHERE laya_confidence(messages, 'which language team should reply first?', 'choice',
                      ARRAY['english', 'spanish', 'french', 'german', 'needs a human']) < 0.6
ORDER BY id;
