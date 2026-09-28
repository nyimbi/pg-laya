-- 05 · Flag churn risk  (business)
-- Read each customer's recent support history and flag the ones showing
-- churn signals, ranked by how strong the signal is.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS accounts;
CREATE TABLE accounts (
  id              serial PRIMARY KEY,
  account         text NOT NULL,
  plan            text NOT NULL,
  mrr_usd         int  NOT NULL,
  recent_support  text NOT NULL
);

INSERT INTO accounts (account, plan, mrr_usd, recent_support) VALUES
  ('Acme',       'enterprise', 4200, 'Asked about competitive pricing three times. One call ended with "we''re not renewing unless the price changes".'),
  ('Globex',     'pro',        320,  'A few questions about the export feature. Overall tone is positive.'),
  ('Initech',    'pro',        280,  'Keeps the data, but the main user left the company. No login activity in three weeks.'),
  ('Umbrella',   'enterprise', 8800, 'Renewed last month, asked to add two more seats.'),
  ('Stark',      'pro',        300,  'Complained twice about latency, said a rival is "much faster" and is evaluating them.');

-- The query: churn signal per account, strongest first.
SELECT account, plan, mrr_usd,
       laya_prob(accounts, 'this account is showing signs it will cancel or not renew') AS churn_risk
FROM accounts
ORDER BY churn_risk DESC;

-- The at-risk revenue: accounts the model is confident will churn.
SELECT account, plan, mrr_usd
FROM accounts
WHERE laya(accounts, 'this account is showing signs it will cancel or not renew', 0.7)
ORDER BY mrr_usd DESC;
