"""pandas loaders. These do the *mechanical* typing only (ids as strings, timestamps as
UTC datetimes). Business cleaning — rank spellings, qualification validity, etc. — belongs
in clean.py so you can see exactly what you changed."""

import pandas as pd

from datawings.config import RAW_DIR, TABLES

# Columns to parse as UTC timestamps, per table
UTC_COLS: dict[str, list[str]] = {
    "flight": ["sched_dep_utc", "sched_arr_utc", "actual_dep_utc", "actual_arr_utc"],
    "duty": [
        "planned_report_utc",
        "planned_release_utc",
        "actual_report_utc",
        "actual_release_utc",
    ],
    "disruption_event": ["event_ts_utc"],
}

# Plain dates (ISO yyyy-mm-dd)
DATE_COLS: dict[str, list[str]] = {
    "duty": ["duty_date"],
    "qualification": ["issue_date", "expiry_date"],
}

# Dates in dd/mm/yyyy — watch out, these are not ISO like the rest
DAYFIRST_DATE_COLS: dict[str, list[str]] = {
    "crew": ["join_date", "leave_date"],
}


def load_table(name: str, parse: bool = True) -> pd.DataFrame:
    """Load one raw CSV. parse=False gives you everything as strings, for profiling."""
    if name not in TABLES:
        raise ValueError(f"Unknown table {name!r}. Expected one of {TABLES}")
    path = RAW_DIR / f"{name}.csv"

    if not parse:
        return pd.read_csv(path, dtype=str, keep_default_na=False)

    df = pd.read_csv(path, dtype={c: "string" for c in ("crew_id", "flight_key", "duty_id")})

    for col in UTC_COLS.get(name, []):
        df[col] = pd.to_datetime(df[col], utc=True, errors="coerce")
    for col in DATE_COLS.get(name, []):
        df[col] = pd.to_datetime(df[col], format="%Y-%m-%d", errors="coerce")
    for col in DAYFIRST_DATE_COLS.get(name, []):
        df[col] = pd.to_datetime(df[col], format="%d/%m/%Y", errors="coerce")

    return df


def load_all(parse: bool = True) -> dict[str, pd.DataFrame]:
    return {t: load_table(t, parse=parse) for t in TABLES}
