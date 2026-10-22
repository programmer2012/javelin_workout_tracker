# Seed data

These files hold a real athlete's training data and are **deliberately not in
version control** — see `.gitignore`. This directory is committed only so the
`assets/seed/` entry in `pubspec.yaml` resolves and a fresh clone builds.

Expected files:

| File | What it is | How to produce it |
|---|---|---|
| `season_plan.json` | the season: weeks, phases, SOLL loads, daily sessions, AT-Split, Sprint & Sprung | `python tools/import_plan.py PLAN.xlsx --dry-run --json-out assets/seed/season_plan.json` |
| `test_history.json` | historical test and competition results, imported once per account | parsed from the coach's Testblatt spreadsheet |

Without them the app still runs: the plan tab asks you to get one from your
coach, and the test import simply is not offered. Coaches publish plans to
Firestore with `tools/import_plan.py`, so athletes do not need these files at
all.
