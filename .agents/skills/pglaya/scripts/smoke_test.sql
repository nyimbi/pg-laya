-- pglaya smoke test: one call per function on a five-row temp table, then session stats.
--   psql -d mydb -f smoke_test.sql
-- Needs the extension created and the Laya server running (make install installs it as a service;
-- 'make serve' runs it in the foreground). No API key is needed by default.
-- Sends 5 small rows to the model once (a few hundred tokens). Nothing is left behind.
\set ON_ERROR_STOP on
\set QUIET on
\pset footer off

SELECT laya_version() AS laya_version;

CREATE TEMP TABLE laya_smoke (id int, product text, review text);
INSERT INTO laya_smoke VALUES
  (1, 'Espresso machine', 'Broke after two weeks, support never answered. Never buying from them again.'),
  (2, 'Hiking boots',     'Comfortable from day one, survived a rainy week in Scotland.'),
  (3, 'Desk lamp',        'Does what it says. Nothing special, nothing wrong.'),
  (4, 'Headphones',       'Sound is fine but the left ear cup cracked; I want a refund.'),
  (5, 'Notebook',         'Paper is thick and the binding lies flat. Lovely.');

\echo
\echo '-- laya(): rows where the customer is unhappy'
SELECT id, product FROM laya_smoke WHERE laya(laya_smoke, 'the customer is unhappy with the product') ORDER BY id;

\echo
\echo '-- laya_prob(): the same condition as a probability (cached, no new API call)'
SELECT id, round(laya_prob(laya_smoke, 'the customer is unhappy with the product')::numeric, 2) AS p
FROM laya_smoke ORDER BY p DESC;

\echo
\echo '-- laya_choice(): what the review is mainly about'
SELECT id, laya_choice(laya_smoke, 'what is this review mainly about?',
                      ARRAY['durability', 'comfort or quality', 'customer service', 'nothing in particular']) AS topic
FROM laya_smoke ORDER BY id;

\echo
\echo '-- laya_score(): sentiment on an ordered rubric (0 = very negative .. 4 = very positive)'
SELECT id, round(laya_score(laya_smoke, 'how positive is this review?',
                           ARRAY['very negative', 'negative', 'neutral', 'positive', 'very positive'])::numeric, 2) AS sentiment
FROM laya_smoke ORDER BY sentiment;

\echo
\echo '-- laya_watch(): arm a watch, enqueue a new row, tick it, disarm'
CREATE TEMP TABLE laya_smoke_watched (id int, message text);
CREATE FUNCTION laya_smoke_action(r jsonb) RETURNS void LANGUAGE sql AS
  $$ SELECT 'queued: ' || (r->>'message') $$;
SELECT laya_watch('laya_smoke_watched', 'the customer is threatening to leave', 'laya_smoke_action');
INSERT INTO laya_smoke_watched VALUES (1, 'I am done with you, I am leaving.');
SELECT laya_watch_tick() AS actions_run;
SELECT * FROM laya_watches();
SELECT laya_unwatch(watch_id) FROM laya_watch WHERE rel = 'laya_smoke_watched'::regclass;
DROP FUNCTION laya_smoke_action;

\echo
\echo '-- laya_stats(): requests, tokens, estimated cost for this session'
SELECT jsonb_pretty(laya_stats() - 'api_ms') AS stats;

DROP TABLE laya_smoke;
\echo
\echo 'Smoke test finished. If errors = 0 above, pglaya is working.'
