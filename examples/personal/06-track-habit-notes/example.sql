-- 06 · Track habit notes  (personal)
-- Read daily journal entries and flag the days where a habit was actually
-- kept, to see your real streak without manual check-ins.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS journal;
CREATE TABLE journal (
  id      serial PRIMARY KEY,
  day     date NOT NULL,
  entry   text NOT NULL
);

INSERT INTO journal (day, entry) VALUES
  ('2026-09-01', 'Ran five kilometres before work, then a calm morning. Felt good.'),
  ('2026-09-02', 'Skipped the run, it rained all day. Caught up on emails instead.'),
  ('2026-09-03', 'Did the morning run again, eight kilometres this time. Best stretch yet.'),
  ('2026-09-04', 'Busy day, no time to exercise. Went for a short walk after dinner.'),
  ('2026-09-05', 'Long run in the park, ten kilometres. Legs are happy.'),
  ('2026-09-06', 'Rest day. Read a book and cooked something new. No running.'),
  ('2026-09-07', 'Quick five-k run at dawn before the meeting. Feeling sharp.');

-- The query: did the "run" habit happen, day by day.
SELECT day,
       laya(journal, 'the person went for a run on this day') AS ran,
       entry
FROM journal
ORDER BY day;

-- Streak support: how many days they actually ran.
SELECT count(*) FILTER (WHERE laya(journal, 'the person went for a run on this day')) AS run_days,
       count(*) AS total_days
FROM journal;
