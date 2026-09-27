-- Native state mode (laya.state_mode = 'native'): state is the row itself, the condition goes in the
-- question, and one row is sent per request. The format the local Laya model is trained on.
\set VERBOSITY terse
SET laya.api_url = 'http://127.0.0.1:8765/v1/systemone';
SET laya.api_key = 'test-key';
SET laya.notices = off;
SET laya.state_mode = 'native';

CREATE TABLE towns (id int PRIMARY KEY, name text, country text);
INSERT INTO towns VALUES
  (1, 'Berlin', 'Germany'), (2, 'Tokyo', 'Japan'), (3, 'Paris', 'France'),
  (4, 'Lima', 'Peru'), (5, 'Munich', 'Germany');

-- laya.batch_size is ignored in native mode: every row goes out as its own request
SET laya.batch_size = 3;
SELECT name FROM towns WHERE laya(towns, 'the country is Germany') ORDER BY id;
SELECT (laya_stats()->>'requests')::int AS requests_one_per_row;
RESET laya.batch_size;

-- The probability wrapper and a threshold run share the cached answers: no new requests
SELECT name, laya_prob(towns, 'the country is Germany') AS p FROM towns ORDER BY id;
SELECT count(*) AS germanies FROM towns WHERE laya(towns, 'the country is Germany', 0.5);
SELECT (laya_stats()->>'requests')::int AS requests_unchanged;

-- Choice and score work in native mode too (mock: index = len(row_json) % number of levels)
SELECT name, laya_choice(towns, 'which continent?', ARRAY['europe', 'asia', 'americas']) AS continent
FROM towns ORDER BY id;
SELECT name, round(laya_score(towns, 'how big is the city?', ARRAY['small', 'medium', 'large'])::numeric, 1) AS score
FROM towns ORDER BY id;

-- An unknown state_mode is rejected before anything is sent
SET laya.state_mode = 'bogus';
SELECT laya(towns, 'anything') FROM towns;
SET laya.state_mode = 'native';

-- Back in jev mode the shared-state format is used again: 5 rows in one batch of 20
SELECT (laya_stats()->>'requests')::int AS requests_before \gset
SET laya.state_mode = 'jev';
SELECT count(*) AS paris FROM towns WHERE laya(towns, 'the name is Paris');
SELECT (laya_stats()->>'requests')::int - :requests_before AS requests_jev;
