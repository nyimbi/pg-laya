-- 01 · Categorize expenses  (personal)
-- Auto-categorize a month of card transactions so you can see where the
-- money actually went, without tagging each one by hand.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
  id          serial PRIMARY KEY,
  date        date NOT NULL,
  merchant    text NOT NULL,
  amount_usd  numeric(10,2) NOT NULL
);

INSERT INTO transactions (date, merchant, amount_usd) VALUES
  ('2026-09-01', 'Whole Foods Market',  82.40),
  ('2026-09-02', 'Shell Gas Station',   54.10),
  ('2026-09-03', 'Blue Bottle Coffee',   6.75),
  ('2026-09-05', 'Netflix',             15.49),
  ('2026-09-06', 'City Power & Light',  98.30),
  ('2026-09-08', 'Chipotle',            13.20),
  ('2026-09-10', 'CVS Pharmacy',        27.60),
  ('2026-09-12', 'Spotify',              11.99),
  ('2026-09-14', 'Trader Joe''s',       63.85),
  ('2026-09-18', 'Delta Airlines',     412.00);

-- The query: a category per transaction, then the spending per category.
SELECT date, merchant, amount_usd,
       laya_choice(transactions, 'what category is this purchase?',
                   ARRAY['groceries', 'dining', 'transport', 'utilities', 'entertainment', 'health', 'subscriptions', 'travel', 'other']) AS category
FROM transactions
ORDER BY date;

SELECT laya_choice(transactions, 'what category is this purchase?',
                   ARRAY['groceries', 'dining', 'transport', 'utilities', 'entertainment', 'health', 'subscriptions', 'travel', 'other']) AS category,
       round(sum(amount_usd), 2) AS total,
       count(*) AS transactions
FROM transactions
GROUP BY 1
ORDER BY 2 DESC;
