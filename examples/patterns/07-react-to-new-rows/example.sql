-- 07 · React to new rows  (pattern)
-- Arm a watch: a row trigger enqueues new/changed rows (no model call in the
-- write path), and laya_watch_tick() judges the queue and runs your action on
-- the matches. New rows that arrive between ticks are picked up on the next tick.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS priority_queue;
DROP TABLE IF EXISTS tickets;
DROP FUNCTION IF EXISTS route_to_priority(jsonb);

CREATE TABLE tickets (
  id       int PRIMARY KEY,
  customer text NOT NULL,
  message  text NOT NULL
);

CREATE TABLE priority_queue (
  ticket   int PRIMARY KEY,
  customer text NOT NULL
);

-- The action: runs once per matching row. Keep it idempotent — actions are
-- guaranteed at-least-once, not exactly-once.
CREATE FUNCTION route_to_priority(r jsonb) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO priority_queue (ticket, customer)
  VALUES ((r->>'id')::int, r->>'customer')
  ON CONFLICT DO NOTHING;
END $$;

-- Arm the watch: from now on, new/changed tickets are enqueued and judged at tick time.
SELECT laya_watch('tickets', 'the customer is threatening to leave or cancel', 'route_to_priority');

-- A mix of urgent and calm tickets. The trigger only enqueues them — fast, no model.
INSERT INTO tickets VALUES
  (1, 'Ana',    'I want to cancel my subscription, this is unacceptable. I am leaving.'),
  (2, 'Ben',    'How do I change my password? Thanks for the help.'),
  (3, 'Carmen', 'I am very frustrated and I am going to take my business elsewhere.'),
  (4, 'Dan',    'The new feature looks great, any docs?'),
  (5, 'Elena',  'If you do not fix this by Friday I will be switching vendors.'),
  (6, 'Farid',  'Just a quick question about my invoice total.');

-- The tick (pg_cron or a worker in production — see the README): judges the
-- queue, runs the action on every match.
SELECT laya_watch_tick() AS actions_run;
SELECT * FROM priority_queue ORDER BY ticket;
SELECT * FROM laya_watches();

-- The point of a watch: rows that arrive later are picked up too.
INSERT INTO tickets VALUES
  (7, 'Greta',  'Keep this up and I am cancelling tomorrow, I am done here.'),
  (8, 'Hassan', 'Do you support SSO? We are evaluating you next quarter.');

SELECT count(*) AS pending FROM laya_watch_queue();
SELECT laya_watch_tick() AS actions_run;
SELECT * FROM priority_queue ORDER BY ticket;

-- Content dedupe: a no-op UPDATE is not re-enqueued.
UPDATE tickets SET message = message WHERE id = 4;
SELECT count(*) AS pending FROM laya_watch_queue();

-- Disarming (drops the trigger when the last watch on the table goes away):
-- SELECT laya_unwatch(watch_id) FROM laya_watch WHERE rel = 'tickets'::regclass;
