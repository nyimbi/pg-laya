-- 06 · Compose with plain SQL  (pattern)
-- laya() is just a STABLE function. Join it with the relation that carries
-- the text, use it in CTEs, CASE and aggregates — the rest stays ordinary
-- SQL.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
  id   serial PRIMARY KEY,
  name text NOT NULL,
  plan text NOT NULL
);

DROP TABLE IF EXISTS tickets;
CREATE TABLE tickets (
  id          serial PRIMARY KEY,
  customer_id int  NOT NULL REFERENCES customers(id),
  body        text NOT NULL
);

INSERT INTO customers (name, plan) VALUES
  ('Northwind', 'enterprise'),
  ('Contoso',   'pro'),
  ('Globex',    'enterprise');

INSERT INTO tickets (customer_id, body) VALUES
  (1, 'We are evaluating leaving for a competitor; the pricing does not add up.'),
  (2, 'Happy with everything, just a question about the API limits.'),
  (3, 'Our renewal is coming up and we are not confident in staying.'),
  (1, 'The new feature is great, thanks for the quick fix.'),
  (2, 'Please invoice our finance team at the new address.');

-- 1) Join: judge the ticket (carries the text), keep the customer from the join.
SELECT c.name, c.plan,
       laya(t, 'this customer is threatening to cancel or mentions a competitor') AS at_risk
FROM tickets t
JOIN customers c ON c.id = t.customer_id
ORDER BY c.name, t.id;

-- 2) CTE + aggregate: at-risk revenue per plan.
WITH judged AS (
  SELECT c.plan,
         laya(t, 'this customer is threatening to cancel or mentions a competitor') AS at_risk
  FROM tickets t
  JOIN customers c ON c.id = t.customer_id
)
SELECT plan,
       count(*) FILTER (WHERE at_risk) AS at_risk_tickets,
       count(*) AS total_tickets
FROM judged
GROUP BY 1
ORDER BY 1;

-- 3) CASE: a plain-SQL label driven by the model's boolean.
SELECT c.name,
       CASE
         WHEN laya(t, 'this customer is threatening to cancel or mentions a competitor')
           THEN 'save offer'
         WHEN laya(t, 'this is a billing or account administration request')
           THEN 'account team'
         ELSE 'no action'
       END AS routing
FROM tickets t
JOIN customers c ON c.id = t.customer_id
ORDER BY c.name, t.id;
