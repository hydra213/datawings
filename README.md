# Datawings Airlines — Cabin Crew challenge

Step into Crew Control and trace duties across rosters, qualifications and flight-time-limitation
(FTL) rules. Goal: a clear data product with strong visuals and solid numbers, plus an angle on how
it could be used across Emirates.

## Setup

```powershell
uv sync                      # creates .venv with pandas, duckdb, jupyter, etc.
uv run pytest                # smoke tests: data loads in both pandas and DuckDB
uv run jupyter lab           # open notebooks/01_explore.ipynb
```

## Layout

```
data/raw/          the 7 CSVs, untouched (gitignored)
data/interim/      intermediate outputs (parquet), gitignored
data/processed/    final tables feeding the visuals, gitignored
docs/              data dictionary + data-model notes
notebooks/         exploration, numbered 01_, 02_ …
sql/staging/       stg_<table>.sql: typing + light cleaning, one per raw table
sql/marts/         analysis models (FTL checks, disruption recovery, …)
src/datawings/     config, pandas loaders, DuckDB connection, cleaning rules
tests/             smoke + pandas-vs-DuckDB parity tests
reports/figures/   exported charts
```

## How the two engines fit together

- `load_table("duty")` → pandas DataFrame with UTC timestamps parsed.
- `connect()` → DuckDB connection with `raw_<table>` views over every CSV (all strings), then builds
  every `.sql` in `sql/staging` then `sql/marts`, in filename order.
- Practice loop: solve a question in pandas, solve it again in SQL, assert they match in `tests/`.

## Data

Copy the 7 CSVs from the challenge zip into `data/raw/` and the dictionary into `docs/`. They're
internal challenge data, so they're gitignored — don't push them to a public repo.
