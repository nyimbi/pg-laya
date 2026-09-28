-- 04 · Limit what the model sees  (pattern)
-- The whole row is sent to the model. When the table carries PII or big
-- blobs the model does not need, put a view in front of it so only the
-- relevant columns are judged.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

-- The real table: carries PII and a big blob the model does not need.
DROP VIEW IF EXISTS support_text;
DROP TABLE IF EXISTS support;
CREATE TABLE support (
  id          serial PRIMARY KEY,
  customer    text NOT NULL,          -- PII: full name
  email       text NOT NULL,          -- PII: address
  message     text NOT NULL,          -- what the model actually needs
  attachment  bytea                   -- big, irrelevant
);

INSERT INTO support (customer, email, message, attachment) VALUES
  ('Ava Thompson', 'ava@example.com', 'My card was declined at checkout three times today.', decode('00', 'hex')),
  ('Liam Patel',   'liam@example.com','I cannot find my order confirmation email.',            decode('00', 'hex')),
  ('Mia Novak',    'mia@example.com', 'The app logs me out every five minutes.',               decode('00', 'hex')),
  ('Noah Kim',     'noah@example.com','Please cancel my subscription, effective end of month.',decode('00', 'hex'));

-- The view: only the columns the model needs. This is what gets judged.
CREATE OR REPLACE VIEW support_text AS
SELECT id, message FROM support;

-- Judge the view, not the table: no names, no emails, no blobs sent.
SELECT id,
       laya_choice(v, 'which team should handle this message?',
                   ARRAY['billing', 'technical', 'account']) AS team
FROM support_text v
ORDER BY id;

-- A pre-filter inside the view also shrinks the read-ahead.
-- (Example: only judge recent messages.)
-- CREATE OR REPLACE VIEW support_text_recent AS
-- SELECT id, message FROM support WHERE id <= 1000;
