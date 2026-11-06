-- Board section 3 + "near a limit" KPI. fct_crew_day flattened with the crew attributes
-- the board filters on, plus the "near a limit" rule, which is business logic and so
-- lives here (thresholds are dbt vars), not in the Streamlit app.

select
    d.crew_day_id,
    d.crew_id,
    d.cal_date,
    c.crew_full_name,
    c.rank,
    c.fleet,
    c.crew_group,
    c.status,
    d.duty_7d_h,
    d.block_28d_h,
    d.days_off_7d,
    d.duty_7d_headroom_h,
    d.block_28d_headroom_h,
    d.is_duty_7d_breach,
    d.is_block_28d_breach,
    d.is_days_off_7d_breach,
    c.status = 'ACTIVE'
    and (
        d.duty_7d_headroom_h < {{ var('near_limit_duty_7d_h', 8) }}
        or d.block_28d_headroom_h < {{ var('near_limit_block_28d_h', 10) }}
    ) as is_near_limit,
    -- one number to sort by: the tighter of the two limits, as a share of that limit
    -- (limit = used + headroom, so the rulebook values aren't hard-coded here)
    least(
        d.duty_7d_headroom_h / (d.duty_7d_h + d.duty_7d_headroom_h),
        d.block_28d_headroom_h / (d.block_28d_h + d.block_28d_headroom_h)
    ) as tightest_headroom_pct
from {{ ref('fct_crew_day') }} as d
inner join {{ ref('dim_crew') }} as c on d.crew_id = c.crew_id
