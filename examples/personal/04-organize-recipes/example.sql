-- 04 · Organize recipes  (personal)
-- Classify each recipe by meal and by diet so you can filter "quick dinners
-- that are vegetarian" without re-reading every card.
--
-- Run:      psql -d mydb -f example.sql
-- Prereq:   laya extension + local model server (see s/install.html).

CREATE EXTENSION IF NOT EXISTS laya CASCADE;

SET laya.state_mode = 'native';
SET laya.concurrency  = 4;
SET laya.notices      = off;

DROP TABLE IF EXISTS recipes;
CREATE TABLE recipes (
  id        serial PRIMARY KEY,
  name      text NOT NULL,
  description text NOT NULL
);

INSERT INTO recipes (name, description) VALUES
  ('Sheet-pan salmon',    'Salmon, cherry tomatoes and zucchini roasted together. Ready in 25 minutes, three ingredients to chop.'),
  ('Monday lasagna',       'Layered pasta with beef and pork ragù, baked for an hour. Feeds a crowd, best made the day before.'),
  ('Garden stir-fry',      'Tofu and whatever vegetables are in the crisper, quick soy-ginger sauce. Weeknight staple.'),
  ('Sunday roast chicken', 'Whole chicken with potatoes and carrots, slow-roasted. The centrepiece of the weekend lunch.'),
  ('Overnight oats',       'Oats, yogurt, chia and berries soaked overnight. Grab-and-go breakfast, no cooking.'),
  ('Vegan chickpea curry', 'Chickpeas, coconut milk and spinach in a spiced tomato sauce. Plant-based and freezable.');

-- The query: meal and diet per recipe.
SELECT name,
       laya_choice(recipes, 'what meal is this recipe for?',
                   ARRAY['breakfast', 'lunch', 'dinner', 'snack', 'dessert']) AS meal,
       laya_choice(recipes, 'how would you describe the diet of this recipe?',
                   ARRAY['vegetarian', 'vegan', 'meat', 'pescatarian', 'mixed']) AS diet
FROM recipes
ORDER BY id;

-- "Quick vegetarian dinners under an hour" — two model conditions + plain SQL.
SELECT name
FROM recipes
WHERE laya(recipes, 'this is a vegetarian or vegan dish')
  AND laya(recipes, 'this recipe is quick, ready in under an hour');
