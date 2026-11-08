-- One row per calendar date in the roster window (local DWB dates).
-- The conformed date dimension: every fact's date column joins here.
-- -- Dates based on UAE date since weekend is from SAT-SUN.

with all_dates as (
    select sched_dep_date_local as d from {{ ref('stg_datawings__flight') }}
    union all
    select duty_date as d from {{ ref('stg_datawings__duty') }}
),

bounds as (
    select
        min(d) as first_date,
        max(d) as last_date
    from all_dates
),

days as (
    select cast(g.date_day as date) as date_day
    from bounds as b
    cross join
        generate_series(
            cast(b.first_date as timestamp), cast(b.last_date as timestamp), interval 1 day
        ) as g (date_day)
)

select
    date_day,
    dayofweek(date_day) as day_of_week,          -- 0 = Sunday
    strftime(date_day, '%a') as day_name,
    dayofweek(date_day) in (0, 6) as is_weekend,
    cast(date_trunc('week', date_day) as date) as week_start,  -- Monday
    weekofyear(date_day) as iso_week,
    strftime(date_day, '%Y-%m') as month_label,
    row_number() over (order by date_day) as roster_day_n   -- day 1 = first date
from days
