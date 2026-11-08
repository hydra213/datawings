"""Project paths and table names. Everything resolves from the repo root, so notebooks
and scripts work no matter where they're run from."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
INTERIM_DIR = DATA_DIR / "interim"
PROCESSED_DIR = DATA_DIR / "processed"
DBT_DIR = ROOT / "dbt"
FIGURES_DIR = ROOT / "reports" / "figures"
DB_PATH = DATA_DIR / "datawings.duckdb"

# Source files in data/raw — each lands as source.<name>. ftl_rule is external (regulator /
# policy) so it's ingested like any other source; only mappings like rank and qualifications are used as dbt sereds
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
# DWB is Dubai (DXB) in disguise: UTC+4, no DST.
HUB = "DWB"
HUB_UTC_OFFSET_HOURS = 4
