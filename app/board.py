"""Crew Control FTL risk board, on the dbt gold layer.

Run from the repo root:   uv run streamlit run app/board.py
Reads data/datawings.duckdb read-only, one short connection per query, so `dbt build` can
still run while the board is open (refresh the page afterwards).
"""

from datetime import date

import duckdb
import pandas as pd
import plotly.graph_objects as go
import streamlit as st

from datawings.config import DB_PATH

# Palette: categorical slots 1-2 of the dataviz reference palette (validated light mode).
BLUE, ORANGE = "#2a78d6", "#eb6834"
INK, INK_2, GRID = "#0b0b0b", "#52514e", "#e7e6e2"

st.set_page_config(page_title="Crew Control: FTL risk", page_icon="✈️", layout="wide")


@st.cache_data(ttl=60)
def q(sql: str, params: tuple = ()) -> pd.DataFrame:
    with duckdb.connect(str(DB_PATH), read_only=True) as con:
        return con.execute(sql, list(params)).df()


def style(fig: go.Figure, height: int = 320) -> go.Figure:
    fig.update_layout(
        height=height,
        margin={"l": 8, "r": 8, "t": 8, "b": 8},
        plot_bgcolor="rgba(0,0,0,0)",
        paper_bgcolor="rgba(0,0,0,0)",
        font={"color": INK_2, "size": 13},
        hoverlabel={"bgcolor": "white", "font_color": INK},
        legend={"orientation": "h", "yanchor": "bottom", "y": 1.02, "x": 0, "title_text": ""},
        bargap=0.35,
    )
    fig.update_xaxes(gridcolor=GRID, zeroline=False, linecolor=GRID)
    fig.update_yaxes(gridcolor=GRID, zeroline=False, linecolor=GRID)
    return fig


# ---------- filters (one row, above everything) ----------
bounds = q("select min(cal_date) lo, max(cal_date) hi from gold.fct_crew_day").iloc[0]
lo, hi = bounds["lo"].date(), bounds["hi"].date()

st.title("Crew Control: flight-time-limitation risk")
st.caption(
    f"Datawings Airlines, hub DWB · roster window {lo:%d %b} – {hi:%d %b %Y} · "
    "built on the dbt gold layer"
)

f1, f2, f3 = st.columns([1, 1, 2])
fleet = f1.selectbox("Fleet", ["All", "A380", "B777"])
group = f2.selectbox("Crew group", ["All", "FLIGHT", "CABIN"])
as_of: date = f3.slider("Roster as of", min_value=lo, max_value=hi, value=hi, format="DD MMM")

FILTER = """
    (? = 'All' or c.fleet = ?) and (? = 'All' or c.crew_group = ?)
"""
fp = (fleet, fleet, group, group)

# ---------- KPI row ----------
duty = q(
    f"""select count(*) duties, sum(is_fdp_breach::int) breaches,
               sum(is_planned_breach::int) planned, sum((is_fdp_breach and not is_planned_breach)::int) ran_over,
               count(distinct crew_id) filter (where is_fdp_breach) crew
        from gold.fct_duty d join gold.dim_crew c using (crew_id)
        where not dq_negative_duty and {FILTER}""",
    fp,
).iloc[0]
qual = q(
    f"""select count(distinct duty_leg_id) legs, count(distinct l.crew_id) crew,
               count(distinct duty_leg_id) filter (where validity = 'MISSING') missing
        from gold.fct_leg_qualification l join gold.dim_crew c using (crew_id)
        where not is_valid and {FILTER}""",
    fp,
).iloc[0]
cum = q(
    f"""select count(distinct d.crew_id) filter (where is_duty_7d_breach) duty7,
               count(distinct d.crew_id) filter (where is_block_28d_breach) block28,
               count(distinct d.crew_id) filter (where is_days_off_7d_breach) off7
        from gold.fct_crew_day d join gold.dim_crew c using (crew_id) where {FILTER}""",
    fp,
).iloc[0]
tight = q(
    f"""select count(*) n from gold.fct_crew_day d join gold.dim_crew c using (crew_id)
        where d.cal_date = ? and c.status = 'ACTIVE'
          and (duty_7d_headroom_h < 8 or block_28d_headroom_h < 10) and {FILTER}""",
    (as_of, *fp),
).iloc[0]["n"]

k1, k2, k3, k4 = st.columns(4)


def tile(col, label: str, value: str, note: str) -> None:
    col.metric(label, value)
    col.caption(note)


tile(
    k1,
    "Legs flown without a valid qualification",
    f"{int(qual.legs):,}",
    f"{int(qual.crew)} crew · {int(qual.missing)} legs with no type rating at all",
)
tile(
    k2,
    "Flying duties over the FDP limit",
    f"{int(duty.breaches or 0):,}",
    f"{(duty.breaches or 0) / max(duty.duties, 1):.1%} of {int(duty.duties):,} duties · "
    f"{int(duty.crew)} crew",
)
tile(
    k3,
    "Crew over 60 duty h in 7 days",
    f"{int(cum.duty7):,}",
    f"and {int(cum.block28):,} over 100 block h in 28 days",
)
tile(
    k4,
    f"Crew near a limit on {as_of:%d %b}",
    f"{int(tight):,}",
    "under 8 h duty or 10 block h of headroom",
)

st.divider()

# ---------- 1. qualifications ----------
st.subheader("1 · Legality: crew operating on expired qualifications")
left, right = st.columns([2, 3])

by_type = q(
    f"""select qual_type, count(distinct duty_leg_id) legs, count(distinct l.crew_id) crew,
               median(days_expired) med_days
        from gold.fct_leg_qualification l join gold.dim_crew c using (crew_id)
        where not is_valid and {FILTER}
        group by 1 order by legs""",
    fp,
)
fig = go.Figure(
    go.Bar(
        x=by_type["legs"],
        y=by_type["qual_type"].str.replace("_", " ").str.title(),
        orientation="h",
        marker={"color": BLUE, "cornerradius": 4},
        text=by_type["legs"],
        textposition="outside",
        textfont={"color": INK},
        customdata=by_type[["crew", "med_days"]],
        hovertemplate="<b>%{y}</b><br>%{x} legs · %{customdata[0]} crew"
        "<br>median %{customdata[1]:.0f} days lapsed<extra></extra>",
    )
)
left.caption("Legs operated without a valid qualification, by type")
fig.update_xaxes(showgrid=False, showticklabels=False, range=[0, by_type["legs"].max() * 1.15])
fig.update_yaxes(tickfont={"size": 14, "color": INK})
left.plotly_chart(style(fig, 260))

offenders = q(
    f"""select c.crew_full_name crew, c.rank, c.fleet, l.qual_type qualification,
               count(distinct duty_leg_id) legs, max(days_expired) max_days_lapsed,
               min(leg_date) first_leg, max(leg_date) last_leg
        from gold.fct_leg_qualification l join gold.dim_crew c using (crew_id)
        where not is_valid and {FILTER}
        group by all order by legs desc, max_days_lapsed desc""",
    fp,
)
right.caption("Who, and for how long (sorted by legs flown)")
right.dataframe(
    offenders,
    hide_index=True,
    height=260,
    column_config={
        "first_leg": st.column_config.DateColumn("first leg", format="D MMM"),
        "last_leg": st.column_config.DateColumn("last leg", format="D MMM"),
        "max_days_lapsed": st.column_config.NumberColumn("max days lapsed"),
    },
)

# ---------- 2. FDP ----------
st.subheader("2 · Duty length: FDP breaches by report time")
band = q(
    f"""select fdp_rule_id, min(strftime(planned_report_local, '%H:00')) first_hour,
               count(*) duties,
               avg(is_planned_breach::int) planned_rate, avg(is_fdp_breach::int) actual_rate
        from gold.fct_duty d join gold.dim_crew c using (crew_id)
        where not dq_negative_duty and {FILTER}
        group by 1 order by 1""",
    fp,
)
rules = q(
    "select rule_id, report_band_local, limit_hours from silver.ftl_rule where rule_type = 'MAX_FDP'"
)
band = band.merge(rules, left_on="fdp_rule_id", right_on="rule_id")
band["label"] = band["report_band_local"] + " (" + band["limit_hours"].map("{:.0f} h".format) + ")"

fig = go.Figure()
for col, name, color in [
    ("planned_rate", "Rostered over the limit", BLUE),
    ("actual_rate", "Over the limit on the day", ORANGE),
]:
    fig.add_bar(
        x=band["label"],
        y=band[col],
        name=name,
        marker={"color": color, "cornerradius": 4},
        customdata=band["duties"],
        hovertemplate="%{x}<br>"
        + name
        + ": <b>%{y:.1%}</b><br>of %{customdata:,} duties<extra></extra>",
    )
fig.update_yaxes(tickformat=".0%")
c1, c2 = st.columns([3, 2])
c1.caption("Share of flying duties over their FDP limit, by local report band (base limit)")
c1.plotly_chart(style(fig))
c2.markdown(
    f"""
**{int(duty.breaches or 0):,} duties** ran past their limit.

- **{int(duty.planned or 0):,}** were already over the limit **in the roster**: a planning problem.
- **{int(duty.ran_over or 0):,}** were legal on paper and ran over **on the day**: a disruption problem.

Early reports (06:00–07:59, 13 h limit) carry most of the risk. Across all bands, two-sector
duties breach about 40× as often as single-sector ones.

*Limit = band limit − 0.5 h per sector over 2 (floored) + 4 h / 7 h with 3 / 4 flight crew.*
"""
)

# ---------- 3. cumulative ----------
st.subheader("3 · Fatigue: cumulative limits and who is close today")
trend = q(
    f"""select cal_date,
               count(distinct d.crew_id) filter (where is_duty_7d_breach) duty7,
               count(distinct d.crew_id) filter (where is_block_28d_breach) block28
        from gold.fct_crew_day d join gold.dim_crew c using (crew_id)
        where {FILTER} group by 1 order by 1""",
    fp,
)
fig = go.Figure()
for col, name, color in [
    ("duty7", "Over 60 duty h in 7 days", BLUE),
    ("block28", "Over 100 block h in 28 days", ORANGE),
]:
    fig.add_scatter(
        x=trend["cal_date"],
        y=trend[col],
        name=name,
        mode="lines",
        line={"color": color, "width": 2},
        hovertemplate="%{x|%d %b}: <b>%{y}</b> crew<extra>" + name + "</extra>",
    )
fig.add_vline(x=pd.Timestamp(as_of), line={"color": INK_2, "width": 1, "dash": "dot"})
fig.update_layout(hovermode="x unified")
c1, c2 = st.columns([3, 2])
c1.caption(
    "Crew over a cumulative limit, per day. The 28-day line climbs late because the data starts "
    "6 Jul: the window only fills up towards the end."
)
c1.plotly_chart(style(fig))

near = q(
    f"""select c.crew_full_name crew, c.rank, c.fleet,
               round(duty_7d_h, 1) duty_7d_h, round(duty_7d_headroom_h, 1) duty_headroom_h,
               round(block_28d_h, 1) block_28d_h, round(block_28d_headroom_h, 1) block_headroom_h,
               days_off_7d
        from gold.fct_crew_day d join gold.dim_crew c using (crew_id)
        where d.cal_date = ? and c.status = 'ACTIVE' and {FILTER}
        order by least(duty_7d_headroom_h / 60, block_28d_headroom_h / 100) limit 50""",
    (as_of, *fp),
)
c2.caption(f"Closest to a limit on {as_of:%d %b}: don't call these out for reserve")
c2.dataframe(
    near,
    hide_index=True,
    height=320,
    column_config={
        "duty_7d_h": st.column_config.NumberColumn("duty h, 7d", format="%.1f"),
        "duty_headroom_h": st.column_config.NumberColumn(
            "duty headroom",
            format="%.1f",
            help="60 h minus duty in the last 7 days; negative = over",
        ),
        "block_28d_h": st.column_config.NumberColumn("block h, 28d", format="%.1f"),
        "block_headroom_h": st.column_config.NumberColumn(
            "block headroom",
            format="%.1f",
            help="100 h minus block in the last 28 days; negative = over",
        ),
        "days_off_7d": st.column_config.NumberColumn("days off, 7d"),
    },
)

st.divider()
st.caption(
    "Method & assumptions: docs/findings.md. Qualification validity is derived from issue/expiry "
    "dates on the day of the flight, not the source status flag. Standby counts at 25% toward "
    "duty hours (dbt var `standby_duty_factor`). Dates with no roster record count as days off."
)
