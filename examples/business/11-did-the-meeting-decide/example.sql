-- 11 · Did the meeting decide?  (business)
-- Read meeting notes and flag the ones that ended with an actual decision or
-- an owner + date, versus the ones that just talked.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS meetings;
CREATE TABLE meetings (
  id       serial PRIMARY KEY,
  topic    text NOT NULL,
  notes    text NOT NULL,
  held_on  date NOT NULL
);

INSERT INTO meetings (topic, notes, held_on) VALUES
  ('Pricing review',   'Discussed moving to usage-based pricing. Dana to draft the new tiers and share by Friday. Team agreed to pilot with three accounts.', '2026-09-01'),
  ('Q3 planning',      'Went through the roadmap. Lots of open questions, no clear next step. Will revisit next month.',                          '2026-09-03'),
  ('Hiring sync',      'Decided to move forward with the backend role. HR to post the job this week, interviews start next Tuesday.',             '2026-09-08'),
  ('Vendor call',      'Talked about the contract. They need to check with legal, so nothing is settled yet.',                                    '2026-09-10'),
  ('Launch retro',     'Agreed the launch went well. Action: document the on-call runbook, owner is Sam, due end of quarter.',                    '2026-09-15');

-- The query: did it decide? with a confidence score for the yes/no.
SELECT topic, held_on,
       laya(meetings, 'the meeting ended with a concrete decision or an assigned action with an owner and date') AS decided,
       laya_prob(meetings, 'the meeting ended with a concrete decision or an assigned action with an owner and date') AS p
FROM meetings
ORDER BY held_on;

-- The ones that produced an actual decision.
SELECT topic, held_on
FROM meetings
WHERE laya(meetings, 'the meeting ended with a concrete decision or an assigned action with an owner and date', 0.7)
ORDER BY held_on;
