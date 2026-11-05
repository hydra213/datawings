"""Datawings Airlines — Cabin Crew challenge."""

from datawings.config import RAW_DIR, TABLES
from datawings.db import connect, read
from datawings.load import load_all, load_table

__all__ = ["RAW_DIR", "TABLES", "connect", "load_all", "load_table", "read"]
