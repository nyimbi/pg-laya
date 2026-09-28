-- 03 · Score inbound leads  (business)
-- Score each inbound lead by purchase intent so the sales team works the
-- hottest ones first.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS leads;
CREATE TABLE leads (
  id        serial PRIMARY KEY,
  company   text NOT NULL,
  contact   text NOT NULL,
  title     text NOT NULL,
  note      text NOT NULL,
  source    text NOT NULL
);

INSERT INTO leads (company, contact, title, note, source) VALUES
  ('Acme Corp',        'Dana',   'CTO',           'Wants a security review before a renewal in Q3. Asked for a pilot this month.', 'webinar'),
  ('Globex',           'Raj',    'Analyst',       'Saw the pricing page and downloaded the data sheet. No reply to two emails.', 'download'),
  ('Initech',          'Mei',    'VP Eng',        'Our current tool is ending in 60 days. Need a quote for 40 seats by the end of the month.', 'outbound'),
  ('Umbrella',         'Sam',    'Intern',        'Is researching tools for a class project. Budget is basically zero.', 'webinar'),
  ('Stark Ind.',       'Ada',    'Head of Data',  'Ran into us at the conference. Wants to compare us against two competitors this quarter.', 'conference'),
  ('Hooli',            'Lee',    'Support Lead',  'Just exploring. Not looking to change anything for at least a year.', 'organic');

-- The query: every lead with an intent score, hottest first.
SELECT company, contact, title, source,
       laya_prob(leads, 'this lead has budget, authority, and intent to buy within a quarter') AS intent
FROM leads
ORDER BY intent DESC;

-- A working list: leads the model is confident are hot.
SELECT company, contact, title
FROM leads
WHERE laya(leads, 'this lead has budget, authority, and intent to buy within a quarter', 0.7);
