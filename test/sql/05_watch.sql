-- laya_watch: the trigger enqueues, the tick judges and acts. The mock scores 0.9 when the
-- last word of the condition ('angry') appears in the row JSON, else 0.1.
\set VERBOSITY terse
SET laya.api_url = 'http://127.0.0.1:8765/v1/systemone';
SET laya.api_key = 'test-key';
SET laya.notices = off;

CREATE TABLE w_tickets (id int PRIMARY KEY, note text);
CREATE TABLE w_actions (ticket int);
CREATE FUNCTION w_action(r jsonb) RETURNS void AS $$
BEGIN INSERT INTO w_actions VALUES ((r->>'id')::int); END $$ LANGUAGE plpgsql;

SELECT laya_watch('w_tickets', 'the customer is angry', 'w_action');
INSERT INTO w_tickets VALUES (1, 'angry about the charge'), (2, 'all is fine');
SELECT watch_id, payload->>'id' AS id FROM laya_watch_queue() ORDER BY 2;
SELECT laya_watch_tick();
SELECT * FROM w_actions ORDER BY 1;
SELECT watch_id, pending FROM laya_watches();

-- Content dedupe: the same content is not re-enqueued; a different row is.
UPDATE w_tickets SET note = 'all is fine' WHERE id = 2;
SELECT laya_watch_tick();
SELECT count(*) AS actions FROM w_actions;
INSERT INTO w_tickets VALUES (3, 'angry about the charge');
SELECT laya_watch_tick();
SELECT * FROM w_actions ORDER BY 1;

-- Disarming: the watch and its trigger go, so nothing is enqueued any more.
SELECT laya_unwatch(watch_id) FROM laya_watch WHERE rel = 'w_tickets'::regclass;
INSERT INTO w_tickets VALUES (4, 'angry');
SELECT count(*) AS queued FROM laya_watch_queue();
SELECT count(*) AS watches FROM laya_watches();

-- Judging a row you already have.
SELECT laya_row('{"id": 9, "note": "angry"}'::jsonb, 'the customer is angry');
SELECT laya_row('{"id": 10, "note": "calm"}'::jsonb, 'the customer is angry');
SELECT laya_row_prob('{"id": 9, "note": "angry"}'::jsonb, 'the customer is angry');

-- Validation: the relation must be a table, the action a jsonb function.
SELECT laya_watch('no_such_table', 'the customer is angry', 'w_action');
SELECT laya_watch('w_tickets', 'the customer is angry', 'no_such_action');
CREATE VIEW w_view AS SELECT * FROM w_tickets;
SELECT laya_watch('w_view', 'the customer is angry', 'w_action');

-- Two watches on one table: a changed UPDATE re-enqueues; every watch is judged.
CREATE FUNCTION w_action2(r jsonb) RETURNS void AS $$
BEGIN INSERT INTO w_actions VALUES ((r->>'id')::int * 100); END $$ LANGUAGE plpgsql;
SELECT laya_watch('w_tickets', 'the customer is angry', 'w_action2', 'second');
UPDATE w_tickets SET note = 'angry about the new charge' WHERE id = 2;
SELECT laya_watch_tick();
SELECT * FROM w_actions ORDER BY 1;

-- laya_watch_skip abandons one watch's pending rows.
INSERT INTO w_tickets VALUES (5, 'angry again');
SELECT laya_watch_skip('second');
SELECT laya_watch_tick();
SELECT * FROM w_actions ORDER BY 1;

-- A failing action rolls the whole tick back; the next tick retries.
CREATE FUNCTION w_boom(r jsonb) RETURNS void AS $$
BEGIN RAISE EXCEPTION 'boom'; END $$ LANGUAGE plpgsql;
SELECT laya_watch('w_tickets', 'the customer is angry', 'w_boom', 'boom');
INSERT INTO w_tickets VALUES (6, 'angry once more');
SELECT laya_watch_tick();
SELECT laya_watch_skip('boom');
SELECT laya_watch_tick();
SELECT * FROM w_actions ORDER BY 1;

-- Re-arming with the same watch_id updates the watch in place.
SELECT laya_watch('w_tickets', 'the customer is angry', 'w_action2', 'w47a6e3d9');
SELECT action FROM laya_watches() WHERE watch_id = 'w47a6e3d9';

-- Disarming in stages: the trigger drops only when the last watch goes away.
-- ('second', 'w47a6e3d9' and 'boom' are armed on w_tickets.)
SELECT laya_unwatch('second');
SELECT count(*) AS trigger_alive FROM pg_trigger
WHERE tgrelid = 'w_tickets'::regclass AND tgname = '_laya_watch_enqueue';
SELECT laya_unwatch('w47a6e3d9');
SELECT count(*) AS trigger_alive FROM pg_trigger
WHERE tgrelid = 'w_tickets'::regclass AND tgname = '_laya_watch_enqueue';
INSERT INTO w_tickets VALUES (7, 'angry');
SELECT count(*) AS queued FROM laya_watch_queue();
SELECT laya_unwatch('boom');
SELECT count(*) AS trigger_alive FROM pg_trigger
WHERE tgrelid = 'w_tickets'::regclass AND tgname = '_laya_watch_enqueue';
INSERT INTO w_tickets VALUES (8, 'angry');
SELECT count(*) AS queued FROM laya_watch_queue();

-- A watch on a partitioned root catches rows inserted through a partition.
CREATE TABLE w_parts (id int PRIMARY KEY, note text) PARTITION BY RANGE (id);
CREATE TABLE w_parts_1 PARTITION OF w_parts FOR VALUES FROM (0) TO (100);
SELECT laya_watch('w_parts', 'the customer is angry', 'w_action');
INSERT INTO w_parts VALUES (1, 'angry about the partition'), (2, 'all is fine');
SELECT laya_watch_tick();
SELECT * FROM w_actions ORDER BY 1;
SELECT laya_unwatch(watch_id) FROM laya_watch WHERE rel = 'w_parts'::regclass;
