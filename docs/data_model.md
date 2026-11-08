# Data model

Window: duty dates 2026-07-06 → 2026-08-03 (~4 weeks). Hub: DWB.

| table | rows | grain | key |
|---|---:|---|---|
| crew | 4,070 | one per crew member | crew_id |
| qualification | 16,479 | crew × qualification, effective-dated | qual_id |
| duty | 106,640 | one per crew duty period (incl. days off, leave, sick) | duty_id |
| duty_leg | 37,606 | bridge: duty × flight leg | duty_leg_id |
| flight | 3,248 | one per flight leg | flight_key |
| disruption_event | 1,808 | OCC log entry | event_id |
| ftl_rule | 15 | rulebook | rule_id |

```
crew ─┬─< qualification
      ├─< duty ─< duty_leg >─ flight ─< disruption_event
      └──────────────────────────────< disruption_event (crew-only events)
ftl_rule: applied to duty (per duty) and per-crew rolling 7d / 28d windows
```

## Rules from the dictionary worth remembering

- `duty` is the **authoritative** record for FTL. FDP = release − report; compare **actual** FDP
  to the limit.
- MAX_FDP depends on the **local** report-time band and sector count (−0.5h per sector over 2,
  floored). Augmentation adds 4h (3 flight crew) or 7h (4 flight crew).
- Qualification `status` flag isn't trustworthy — derive validity from issue/expiry vs the leg date.
- `flight_no` is not unique per day — join on `flight_key`.

## First findings  

- `crew.rank` has spelling variants (case, trailing spaces, `f/o`, `CC`, `PSR`, `First Officer` …).
- `crew.join_date` / `leave_date` are dd/mm/yyyy; everything else is ISO.
- `disruption_event.resolution_action` is blank on a chunk of rows.
- Local vs UTC: `duty_date` is DWB local, the timestamps are UTC. Offset assumed +4 (see config.py).
