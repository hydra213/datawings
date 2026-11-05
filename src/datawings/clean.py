"""Business cleaning rules (pandas). Deliberately left as stubs — this is the practice bit.
Mirror each one in SQL under sql/staging/ and check the two agree (see tests/)."""

import pandas as pd


def normalise_rank(s: pd.Series) -> pd.Series:
    """Map messy rank spellings to CAPT / FO / PURSER / CABIN.
    Start with: load_table('crew')['rank'].value_counts()"""
    raise NotImplementedError


def qualification_valid_on(qual: pd.DataFrame, on_date: pd.Timestamp) -> pd.Series:
    """True where issue_date <= on_date <= expiry_date.
    The data dictionary says don't trust the status flag — compare the two."""
    raise NotImplementedError


def fdp_hours(duty: pd.DataFrame, actual: bool = True) -> pd.Series:
    """Flight duty period = release - report, in hours."""
    raise NotImplementedError
