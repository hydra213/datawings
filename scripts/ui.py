"""Open the DuckDB UI on the warehouse, read-only, with the project's own DuckDB version.

Run:  uv run python scripts/ui.py      (press Enter to stop, before running dbt build)
"""

import duckdb

from datawings.config import DB_PATH

con = duckdb.connect()
con.execute(f"attach '{DB_PATH.as_posix()}' as dw (read_only)")
con.execute("use dw")
con.execute("call start_ui()")
input("DuckDB UI running at http://localhost:4213 - press Enter to stop\n")
con.close()
