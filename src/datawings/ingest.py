"""Ingestion: the E and L of ELT. Lands every raw CSV in the bronze schema, as delivered.

This is the stand-in for Fivetran / ADF / Snowpipe. dbt never loads source data; it starts
from what this script lands. Swap this for the real roster feed and nothing downstream changes.

Bronze contract:
- one table per source file, same name (bronze.crew, bronze.duty, ...)
- every column as text, exactly as delivered — no fixes, no typing
- plus _source_file and _loaded_at for lineage

Run:  uv run ingest
"""

import duckdb

from datawings.config import DB_PATH, RAW_DIR, TABLES


def ingest(con: duckdb.DuckDBPyConnection) -> dict[str, int]:
    con.execute("create schema if not exists bronze")
    counts = {}
    for table in TABLES:
        path = (RAW_DIR / f"{table}.csv").as_posix()
        con.execute(
            f"""
            create or replace table bronze.{table} as
            select
                * exclude (filename),
                filename          as _source_file,
                current_timestamp as _loaded_at
            from read_csv('{path}', header = true, all_varchar = true, filename = true)
            """
        )
        counts[table] = con.execute(f"select count(*) from bronze.{table}").fetchone()[0]
    return counts


def main() -> None:
    missing = [t for t in TABLES if not (RAW_DIR / f"{t}.csv").exists()]
    if missing:
        raise SystemExit(f"Missing in {RAW_DIR}: {', '.join(m + '.csv' for m in missing)}")

    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with duckdb.connect(str(DB_PATH)) as con:
        counts = ingest(con)

    for table, n in counts.items():
        print(f"bronze.{table:<18} {n:>8,} rows")
    print(f"Landed {len(counts)} tables in {DB_PATH.name}")


if __name__ == "__main__":
    main()
