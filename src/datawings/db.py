"""Read side of the warehouse. ingest.py lands bronze, dbt builds silver -> gold;
Python only reads it.

read_only=True by default, so a notebook doesn't lock the file — DuckDB allows one writer
at a time, and `dbt build` needs to be that writer. If dbt complains the file is locked,
restart the notebook kernel (or call con.close())."""

import duckdb
import pandas as pd

from datawings.config import DB_PATH


def connect(read_only: bool = True) -> duckdb.DuckDBPyConnection:
    if not DB_PATH.exists():
        raise FileNotFoundError(
            f"{DB_PATH} not found — run `uv run ingest`, then `cd dbt; uv run dbt build` first."
        )
    return duckdb.connect(str(DB_PATH), read_only=read_only)


def read(table: str, con: duckdb.DuckDBPyConnection | None = None) -> pd.DataFrame:
    """read('gold.fct_duty') -> DataFrame. Opens and closes its own connection if none given."""
    if con is not None:
        return con.sql(f"select * from {table}").df()
    with connect() as c:
        return c.sql(f"select * from {table}").df()
