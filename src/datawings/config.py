"""Project paths and table names. Everything resolves from the repo root, so notebooks
and scripts work no matter where they're run from."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
INTERIM_DIR = DATA_DIR / "interim"
PROCESSED_DIR = DATA_DIR / "processed"
SQL_DIR = ROOT / "sql"
FIGURES_DIR = ROOT / "reports" / "figures"
DB_PATH = DATA_DIR / "datawings.duckdb"

TABLES = [
    "crew",
    "qualification",
    "duty",
    "duty_leg",
    "flight",
    "disruption_event",
    "ftl_rule",
]

# Hub station. duty_date is a LOCAL (DWB) date; all *_utc columns are UTC.
# Assumption: DWB behaves like DXB, i.e. UTC+4 with no DST. Confirm before relying on it.
HUB = "DWB"
HUB_UTC_OFFSET_HOURS = 4
