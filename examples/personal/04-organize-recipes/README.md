# Organize recipes

**Category:** Personal · **Functions:** `laya_choice`, `laya`, `WHERE`

Classify each recipe by meal and by diet, then combine those with plain
language to answer a real question: "what quick vegetarian dinners do I
have?" Two independent `laya` conditions joined by `AND`.

## Scenario

Your recipe box has no consistent tags. You want to ask it questions like
"quick vegetarian dinner for tonight" and get the matching cards — without
having tagged meal type and diet on every single one.

## How it works

1. `laya_choice(recipes, 'what meal…', ARRAY[…])` tags each recipe with a
   meal; a second `laya_choice` tags the diet.
2. The first query shows both tags per recipe for spot-checking.
3. The second query answers the real question with two boolean conditions:
   vegetarian/vegan **and** quick (under an hour).
4. Each distinct condition is its own cache key, so the two booleans are two
   (cached) scans.

## Try it

```bash
psql -d mydb -f example.sql
```

## Notes

- **Two conditions = two scans.** They are independent, so each is judged
  once per session and cached. For mutually exclusive buckets, prefer one
  `laya_choice`; here the two axes (diet, speed) genuinely differ.
- **State the bar concretely:** "ready in under an hour" is checkable from
  the description; "quick" alone is not.
- **Local by default:** recipe text stays on your machine.
