-- 06 · Rank job applicants  (business)
-- Rank applicants against a role's must-haves so a human screens the top of
-- the stack, not all of it.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS applicants;
CREATE TABLE applicants (
  id       serial PRIMARY KEY,
  name     text NOT NULL,
  summary  text NOT NULL
);

INSERT INTO applicants (name, summary) VALUES
  ('Priya',   'Backend engineer, 6 years. Built and scaled a Go/Postgres order service to 2k rps. Led the move to a typed API.'),
  ('Tom',     'Full-stack, 2 years. Strong at React and Figma. Some Node. Looking to move into a more senior role.'),
  ('Yuki',    'Data engineer, 5 years. Python, Airflow, dbt. Built the warehouse and the metrics layer for a 200-person company.'),
  ('Sam',     'Career changer, 1 year of self-taught Python. Enthusiastic, did a couple of freelance ticketing projects.'),
  ('Lena',    'Backend, 7 years. Postgres, Go and Rust. Cut p99 latency 60% on a payment path. Comfortable on-call.'),
  ('Omar',    'ML engineer, 4 years. Ships recommendation models, but most of the role would be API and data plumbing.');

-- The role's must-haves, in one condition.
-- Rank the whole stack by fit, best first.
SELECT name,
       laya_prob(applicants, 'a strong match for a senior backend role: 5+ years, Go or Rust, deep Postgres, production experience') AS fit
FROM applicants
ORDER BY fit DESC;

-- The shortlist: the model's confident top matches.
SELECT name
FROM applicants
WHERE laya(applicants, 'a strong match for a senior backend role: 5+ years, Go or Rust, deep Postgres, production experience', 0.7);
