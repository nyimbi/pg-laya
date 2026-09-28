-- 02 · Prioritize the inbox  (personal)
-- Rank your personal emails by how urgently they need a reply, so you start
-- with what actually matters today.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS emails;
CREATE TABLE emails (
  id          serial PRIMARY KEY,
  sender      text NOT NULL,
  subject     text NOT NULL,
  preview     text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO emails (sender, subject, preview, received_at) VALUES
  ('Landlord',        'Lease renewal terms',        'I''m sending over the new lease. Please sign and return by the 15th or the unit re-lists.', now() - interval '5 hours'),
  ('Newsletter',      '50% off everything this week','Our biggest sale of the season is here. Shop now before it ends Sunday.',             now() - interval '1 day'),
  ('Mom',             'Dad''s appointment',         'Can you drive Dad to his checkup Thursday morning? He cannot make it alone.',            now() - interval '8 hours'),
  ('Colleague',       'Re: doc review',             'Thanks for the look at the doc. Two small comments inline when you get a chance.',        now() - interval '2 days'),
  ('Bank',            'Statement ready',            'Your monthly statement is ready to view online.',                                              now() - interval '3 days'),
  ('Friend',          'Dinner Saturday?',           'Are we still on for Saturday? Trying to book a table for six.',                              now() - interval '6 hours');

-- The query: every email scored by "needs a reply soon", most urgent first.
SELECT sender, subject,
       laya_prob(emails, 'this email needs a reply from me soon, or has a deadline I must meet') AS urgency
FROM emails
ORDER BY urgency DESC;

-- Today's must-answers.
SELECT sender, subject
FROM emails
WHERE laya(emails, 'this email needs a reply from me soon, or has a deadline I must meet', 0.7)
ORDER BY received_at;
