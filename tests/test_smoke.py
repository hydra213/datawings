"""Smoke tests: raw data is present, and the landing area holds exactly what's in the CSVs."""

import pytest

from datawings import TABLES, connect, load_table
from datawings.config import DB_PATH, RAW_DIR

needs_raw = pytest.mark.skipif(
    not (RAW_DIR / "crew.csv").exists(), reason="raw data not in data/raw/"
)
needs_db = pytest.mark.skipif(not DB_PATH.exists(), reason="run `uv run ingest` first")


@needs_raw
@needs_db
@pytest.mark.parametrize("table", TABLES)
def test_bronze_row_counts_match_raw(table):
    with connect() as con:
        bronze_n = con.execute(f"select count(*) from bronze.{table}").fetchone()[0]
    assert len(load_table(table)) == bronze_n > 0
