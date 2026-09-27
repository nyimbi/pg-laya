-- Regression tests run against test/mock_api.py (deterministic answers), not the live API.
\set VERBOSITY terse
CREATE EXTENSION laya;
SET laya.api_url = 'http://127.0.0.1:8765/v1/systemone';
SET laya.api_key = 'test-key';
SET laya.notices = off;

SELECT laya_version();

CREATE TABLE cities (id int PRIMARY KEY, name text, country text);
INSERT INTO cities VALUES
  (1, 'Berlin', 'Germany'), (2, 'Tokyo', 'Japan'), (3, 'Paris', 'France'),
  (4, 'Lima', 'Peru'), (5, 'Munich', 'Germany');

-- Noul predicate (mock: 0.9 when the last word of the condition appears in the row)
SELECT name FROM cities WHERE laya(cities, 'the country is Germany') ORDER BY id;
SELECT name, laya_prob(cities, 'the country is Germany') AS p FROM cities ORDER BY id;

-- Threshold: explicit argument, then the laya.threshold setting
SELECT count(*) AS above_095 FROM cities WHERE laya(cities, 'the country is Germany', 0.95);
SET laya.threshold = 0.05;
SELECT count(*) AS above_005 FROM cities WHERE laya(cities, 'the country is Germany');
RESET laya.threshold;

-- The whole table was judged in one request; every later call was a cache hit
SELECT (laya_stats()->>'requests')::int        AS requests,
       (laya_stats()->>'rows_evaluated')::int  AS rows_evaluated,
       (laya_stats()->>'cached_answers')::int  AS cached_answers,
       (laya_stats()->>'cache_hits')::int > 0  AS had_cache_hits,
       (laya_stats()->>'errors')::int          AS errors;

-- batch_size controls how many rows share one request
SET laya.batch_size = 2;
SELECT count(*) AS paris FROM cities WHERE laya(cities, 'the name is Paris');
SELECT (laya_stats()->>'requests')::int AS requests_after_batched_run;
RESET laya.batch_size;

-- Score and Choice primitives
SELECT name,
       laya_score(cities, 'how big is the city?', ARRAY['small', 'medium', 'large'])      AS score,
       laya_score_norm(cities, 'how big is the city?', ARRAY['small', 'medium', 'large']) AS score_norm
FROM cities ORDER BY id;
SELECT name, laya_choice(cities, 'which continent?', ARRAY['europe', 'asia', 'americas']) AS continent
FROM cities ORDER BY id;
SELECT laya_eval(cities, 'which continent?', 'choice', ARRAY['europe', 'asia', 'americas']) AS raw
FROM cities WHERE id = 1;
SELECT laya_confidence(cities, 'which continent?', 'choice', ARRAY['europe', 'asia', 'americas']) AS confidence
FROM cities WHERE id = 1;

-- Anonymous records (subquery) cannot be read ahead but are still judged correctly
SELECT s.name FROM (SELECT name, country FROM cities WHERE id <= 3) s WHERE laya(s, 'the country is Japan');

-- A row inserted after the read-ahead is judged on its own
INSERT INTO cities VALUES (6, 'Hamburg', 'Germany');
SELECT name FROM cities WHERE laya(cities, 'the country is Germany') ORDER BY id;

-- Combines with ordinary SQL
SELECT name FROM cities WHERE laya(cities, 'the country is Germany') AND id > 1 ORDER BY id;

-- Cache can be cleared
SELECT laya_cache_clear();
SELECT (laya_stats()->>'cached_answers')::int AS cached_after_clear;

-- Per-statement spend guards abort before anything is sent
SET laya.max_rows_per_statement = 3;
SELECT count(*) FROM cities WHERE laya(cities, 'the name is Lima');
RESET laya.max_rows_per_statement;
SET laya.max_chars_per_statement = 50;
SELECT count(*) FROM cities WHERE laya(cities, 'the name is Lima');
RESET laya.max_chars_per_statement;
SELECT (laya_stats()->>'requests')::int AS requests_unchanged_by_guard;
-- With the guard lifted the same statement runs
SELECT count(*) AS lima FROM cities WHERE laya(cities, 'the name is Lima');
