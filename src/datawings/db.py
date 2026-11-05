"""DuckDB side. `connect()` gives you a connection with a raw_<table> view over every CSV,
then runs any .sql files in sql/staging and sql/marts (in filename order) so your models
build up in layers: raw -> stg -> mart."""

from pathlib import Path

import duckdb

from datawings.config import DB_PATH, RAW_DIR, SQL_DIR, TABLES


def connect(persist: bool = False, build_models: bool = True) -> duckdb.DuckDBPyConnection:
    """persist=False: in-memory (fast, nothing on disk).
    persist=True: data/datawings.duckdb, handy for poking at it from the DuckDB CLI / DBeaver."""
    con = duckdb.connect(str(DB_PATH) if persist else ":memory:")
    con.execute("SET TimeZone = 'UTC'")

    for t in TABLES:
        path = (RAW_DIR / f"{t}.csv").as_posix()
        # all_varchar first: inspect the mess before trusting DuckDB's type sniffing.
        con.execute(
            f"CREATE OR REPLACE VIEW raw_{t} AS "
            f"SELECT * FROM read_csv('{path}', header=true, all_varchar=true)"
        )

    if build_models:
        for layer in ("staging", "marts"):
            for sql_file in sorted((SQL_DIR / layer).glob("*.sql")):
                run_sql_file(con, sql_file)

    return con


def run_sql_file(con: duckdb.DuckDBPyConnection, path: Path) -> None:
    con.execute(path.read_text(encoding="utf-8"))
