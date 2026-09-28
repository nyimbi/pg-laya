-- 04 · Segment customers by persona  (business)
-- Put each customer into a marketing persona from their usage and support
-- behaviour, then see the size of each segment.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
  id         serial PRIMARY KEY,
  name       text NOT NULL,
  plan       text NOT NULL,
  usage_note text NOT NULL
);

INSERT INTO customers (name, plan, usage_note) VALUES
  ('Northwind',  'enterprise', 'Runs on the API all day, hits volume limits monthly, asks for SLA and SSO.'),
  ('Contoso',    'free',       'One user, logs in a few times a week, mostly reads the docs.'),
  ('Fabrikam',   'pro',        'Small team of six, power users, requests new features every sprint.'),
  ('Tailwind',   'free',       'Signed up for a discount, has not opened the app twice this month.'),
  ('Globex',     'enterprise', 'Central IT controls access, long procurement, wants a security review.'),
  ('Initech',    'pro',        'Price sensitive, compares plans carefully, churned a competitor last year.');

-- The query: assign a persona, then count the segments.
SELECT name, plan,
       laya_choice(customers, 'which best describes this customer?',
                   ARRAY['enterprise buyer', 'power user', 'self-serve pro', 'window shopper']) AS persona
FROM customers
ORDER BY id;

SELECT laya_choice(customers, 'which best describes this customer?',
                   ARRAY['enterprise buyer', 'power user', 'self-serve pro', 'window shopper']) AS persona,
       count(*) AS customers
FROM customers
GROUP BY 1
ORDER BY 2 DESC;
