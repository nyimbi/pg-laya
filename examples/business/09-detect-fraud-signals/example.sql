-- 09 · Detect fraud signals  (business)
-- Read each transaction's context and flag the ones that look fraudulent,
-- so a human reviews a short list instead of every charge.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
  id           serial PRIMARY KEY,
  customer_id  int  NOT NULL,
  amount_usd   numeric(10,2) NOT NULL,
  merchant     text NOT NULL,
  context      text NOT NULL
);

INSERT INTO transactions (customer_id, amount_usd, merchant, context) VALUES
  (101,  48.20, 'Corner Grocery',      'Regular weekly shop, same store and day as usual.'),
  (101, 2100.00,'QuickCash Electronics','First purchase from this customer, high value, new device, different city.'),
  (102,  12.50, 'Metro Transit',       'Daily commute pass top-up.'),
  (103,  95.00, 'Bookstore',           'Monthly book order, matches history.'),
  (102, 330.00, 'JetTravel',           'Two charges 20 minutes apart from two different airports, customer reports the card is safe.'),
  (104,  67.99, 'Gym & Wellness',      'Annual membership, renewed as last year.');

-- The query: fraud signal per transaction, strongest first.
SELECT id, customer_id, amount_usd, merchant,
       laya_prob(transactions, 'this transaction shows signs of fraud or unauthorised use') AS risk
FROM transactions
ORDER BY risk DESC;

-- The review queue: transactions the model is confident are suspicious.
SELECT id, customer_id, amount_usd, merchant, context
FROM transactions
WHERE laya(transactions, 'this transaction shows signs of fraud or unauthorised use', 0.7)
ORDER BY amount_usd DESC;
