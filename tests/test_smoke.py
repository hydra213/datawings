"""Smoke tests: the data is where we expect and both engines can read it.
Add parity tests here as you go (pandas result == DuckDB result)."""

import pytest

from datawings import TABLES, connect, load_table
from datawings.config import RAW_DIR

pytestmark = pytest.mark.skipif(
    not (RAW_DIR / "crew.csv").exists(), reason="raw data not in data/raw/"
)


@pytest.mark.parametrize("table", TABLES)
def test_pandas_and_duckdb_row_counts_match(table):
    con = connect(build_models=False)
    duck_n = con.execute(f"SELECT count(*) FROM raw_{table}").fetchone()[0]
    assert len(load_table(table)) == duck_n > 0


def test_staging_models_build():
    con = connect()
    assert con.execute("SELECT count(*) FROM stg_flight").fetchone()[0] > 0
