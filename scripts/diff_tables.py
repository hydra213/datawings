"""Diff two warehouse tables on their shared columns.

    uv run python scripts/diff_tables.py marts.fct_crew_day marts.fct_crew_day_v2 crew_day_id

Prints row counts, rows only in one side, and per-column mismatch counts on the key.
Floats compare to 1e-6, so a different summation order isn't a "difference".
"""

import sys

import duckdb

from datawings.config import DB_PATH

a, b, key = sys.argv[1:4]
con = duckdb.connect(str(DB_PATH), read_only=True)


def cols(t: str) -> dict[str, str]:
    schema, name = t.split(".")
    rows = con.execute(
        "select column_name, data_type from information_schema.columns "
        "where table_schema = ? and table_name = ? order by ordinal_position",
        [schema, name],
    ).fetchall()
    return dict(rows)


ca, cb = cols(a), cols(b)
shared = [c for c in ca if c in cb and c != key]
print(f"only in {a}: {sorted(set(ca) - set(cb))}")
print(f"only in {b}: {sorted(set(cb) - set(ca))}")

na, nb = (con.execute(f"select count(*) from {t}").fetchone()[0] for t in (a, b))
print(f"rows: {a}={na:,}  {b}={nb:,}")
for left, right in ((a, b), (b, a)):
    n = con.execute(
        f"select count(*) from {left} l anti join {right} r on l.{key} = r.{key}"
    ).fetchone()[0]
    print(f"keys only in {left}: {n:,}")


def differs(c: str) -> str:
    if ca[c] in ("DOUBLE", "FLOAT") or ca[c].startswith("DECIMAL"):
        return f"coalesce(abs(l.{c} - r.{c}) > 1e-6, l.{c} is null <> r.{c} is null)"
    return f"l.{c} is distinct from r.{c}"


sums = ", ".join(f"count(*) filter (where {differs(c)}) as {c}" for c in shared)
row = con.execute(f"select {sums} from {a} l join {b} r on l.{key} = r.{key}").df().iloc[0]
bad = row[row > 0]
print("column mismatches:", "none" if bad.empty else "")
for c, n in bad.items():
    print(f"  {c}: {n:,} rows")
    print(
        con.sql(
            f"select l.{key}, l.{c} as {a.split('.')[1]}, r.{c} as {b.split('.')[1]} "
            f"from {a} l join {b} r on l.{key} = r.{key} where {differs(c)} limit 5"
        )
    )
