# Datawings Airlines — Cabin Crew challenge

Step into Crew Control and trace duties across rosters, qualifications and flight-time-limitation
(FTL) rules. Goal: a clear data product with strong visuals and solid numbers, plus an angle on how
it could be used across Emirates.

## Architecture (ELT)

```
data/raw/*.csv ──ingest──▶ bronze ──dbt──▶ silver ──dbt──▶ gold ──▶ pandas / charts / app
                  (E + L)   as-delivered    typed, clean    facts, dims, marts
                                            ▲
                                   ref.rank_map (dbt seed)
```

- **Ingestion** (`uv run ingest`) lands every source CSV in `bronze` as-is, all text, plus
  `_source_file` and `_loaded_at`. Stand-in for Fivetran / ADF / Snowpipe.
- **dbt** is the T only. It declares bronze as *sources*, tests them, and builds silver and gold.
- **Seeds** are only for reference data *we* own (`rank_map`), versioned in git → schema `ref`.
  The FTL rulebook is external (regulator / policy), so it's ingested like any other source.
- **pandas** reads gold, read-only, for analysis and charts.

## Setup (once)

```powershell
uv sync
uv run pre-commit install        # lint Python + SQL on every commit
```

## Day to day

```powershell
uv run ingest                    # land raw -> bronze (rerun when source files change)
cd dbt
uv run dbt build                 # seeds + silver + gold + tests, in dependency order
uv run dbt build -s silver_crew+ # one model and everything downstream of it
uv run dbt source freshness      # warns if bronze is older than 7 days
uv run dbt docs generate
uv run dbt docs serve            # lineage graph in the browser
cd ..
uv run pytest                    # parity tests: raw vs bronze, pandas vs gold
uv run jupyter lab
```

Always run dbt from inside `dbt/`. DuckDB allows one writer at a time: if ingest or dbt says the
database is locked, a notebook is holding it — run `con.close()` or restart the kernel.

## Layout

```
data/raw/               source CSVs, untouched (gitignored)
data/datawings.duckdb   the warehouse (gitignored, rebuild any time)
src/datawings/
  ingest.py             raw -> bronze landing
  db.py                 read-only warehouse access for notebooks
  load.py               raw CSV -> pandas, for profiling and parity checks
  config.py             paths, table list, hub settings
dbt/
  models/bronze/        _sources.yml only: declares + tests what ingestion landed
  models/silver/        silver_<table>.sql: typed, cleaned, conformed, DQ-flagged → schema silver
  models/gold/          fct_*, dim_*, story marts                                 → schema gold
  seeds/                rank_map (our own mapping)                                → schema ref
  macros/naming.sql     silver_crew.sql → silver.crew, no "main_" schema prefix
  tests/                singular tests (custom SQL checks)
docs/                   data dictionary, data model, findings log
notebooks/              analysis, numbered 01_, 02_ …
tests/                  pytest parity checks
reports/figures/        exported charts
```

## Data

The CSVs and dictionary are internal challenge data and gitignored. Keep the repo private.
