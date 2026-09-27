\set VERBOSITY terse
SET laya.api_url = 'http://127.0.0.1:8765/v1/systemone';
SET laya.notices = off;
CREATE TABLE things (id int, v text);
INSERT INTO things VALUES (1, 'a');

-- No key configured anywhere
SET laya.api_key = '';
SELECT laya(things, 'anything') FROM things;

-- Non-retryable HTTP errors surface as SQL errors
SET laya.api_key = 'wrong-key';
SELECT laya(things, 'anything') FROM things;
SET laya.api_key = 'test-key';
SELECT laya(things, 'please trigger422') FROM things;

-- Unknown question kind
SELECT laya_eval(things, 'anything', 'bogus', NULL) FROM things;

-- Errors are counted, and the session keeps working afterwards
SELECT (laya_stats()->>'errors')::int AS errors;
SELECT laya(things, 'the value is a') FROM things;
