# Findings & assumptions log

Running log of data issues, decisions and assumptions. This becomes a slide.

| # | date | table / column | finding or assumption | how it's handled | impact |
|---|---|---|---|---|---|
| 1 | 2026-11-05 | crew.rank | ~15 spelling variants of 4 ranks | `rank_map` seed, joined in silver | 45 of 4,070 crew rows |
| 2 | 2026-11-05 | crew.join_date / leave_date | dd/mm/yyyy, unlike every other date (ISO) | parse explicitly in silver | — |
| 3 | 2026-11-05 | (all) | DWB assumed UTC+4, no DST (like DXB) | local times derived once, in silver | drives FDP band choice |
