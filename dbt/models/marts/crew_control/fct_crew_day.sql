-- One row per crew member per calendar date in the roster window, INCLUDING days with no duty.
-- Answers the cumulative FTL rules a single duty can't:
--   DUTY7-01  max duty hours in any 7 consecutive days
--   FLT28-01  max block hours in any 28 consecutive days
--   OFF7-01   min days off in any 7 consecutive days
--   OFF28-01  min days off in any 28 consecutive days
--
-- Assumptions:
--   - a duty's hours count on its duty_date, even if it runs past midnight
--   - block hours count on the flight's local scheduled departure date
--   - STANDBY counts toward duty hours at var('standby_duty_factor') (default 0.25, the usual
--     treatment of home standby; airport standby would be 1.0). This one choice moves the
--     7-day breach count by more than 30x, so it's a dbt var, not a buried constant
--   - DAYOFF and LEAVE count as days off; SICK doesn't count as day off
--   - a date with NO roster record
--     nothing rostered = not working. Counting them as worked would invent ~650 extra
--     days-off breaches. has_roster_record lets you see them
--   - a window is only judged once it has its full length of history

with window_bounds as (
    select
        min(duty_date) as first_date,
        max(duty_date) as last_date
    from {{ ref('stg_datawings__duty') }}
),

spine as (
    -- every crew x every date: this is what makes "6 rows back" mean "6 days back"
    select
        c.crew_id,
        cast(d.cal_date as date) as cal_date
    from {{ ref('dim_crew') }} as c
    cross join window_bounds as w
    cross join
        generate_series(
            cast(w.first_date as timestamp),
            cast(w.last_date as timestamp),
            interval 1 day
        ) as d (cal_date)
),

daily_duty as (
    select
        crew_id,
        duty_date as cal_date,
        sum(
            case
                when duty_type = 'STANDBY'
                    then coalesce(actual_duty_h, 0) * {{ var('standby_duty_factor', 0.25) }}
                when is_working then coalesce(actual_duty_h, 0)
                else 0
            end
        ) as duty_h,
        bool_or(duty_type in ('DAYOFF', 'LEAVE')) as is_day_off,
        string_agg(distinct duty_type, '+' order by duty_type) as duty_types
    from {{ ref('stg_datawings__duty') }}
    group by crew_id, duty_date
),

daily_block as (
    select
        crew_id,
        leg_date as cal_date,
        sum(actual_block_min) / 60.0 as block_h,
        count(*) as legs
    from {{ ref('int_operated_legs_joined_to_flights') }}
    group by crew_id, leg_date
),

limits as (
    select
        max(limit_hours) filter (where rule_id = 'DUTY7-01') as max_duty_7d_h,
        max(limit_hours) filter (where rule_id = 'FLT28-01') as max_block_28d_h,
        max(limit_hours) filter (where rule_id = 'OFF7-01') as min_days_off_7d,
        max(limit_hours) filter (where rule_id = 'OFF28-01') as min_days_off_28d
    from {{ ref('stg_datawings__ftl_rule') }}
),

daily as (
    select
        s.crew_id,
        s.cal_date,
        coalesce(dd.duty_types, 'NONE') as duty_types,
        coalesce(dd.duty_h, 0) as duty_h,
        coalesce(db.block_h, 0) as block_h,
        coalesce(db.legs, 0) as legs,
        dd.crew_id is not null as has_roster_record,
        coalesce(dd.is_day_off, true) as is_day_off
    from spine as s
    left join daily_duty as dd on s.crew_id = dd.crew_id and s.cal_date = dd.cal_date
    left join daily_block as db on s.crew_id = db.crew_id and s.cal_date = db.cal_date
),

rolling as (
    select
        *,
        row_number() over w_all as day_n,
        sum(duty_h) over w7 as duty_7d_h,
        sum(case when is_day_off then 1 else 0 end) over w7 as days_off_7d,
        sum(block_h) over w28 as block_28d_h,
        sum(case when is_day_off then 1 else 0 end) over w28 as days_off_28d
    from daily
    window
        w_all as (partition by crew_id order by cal_date),
        w7 as (partition by crew_id order by cal_date rows between 6 preceding and current row),
        w28 as (partition by crew_id order by cal_date rows between 27 preceding and current row)
)

select
    r.crew_id || '|' || strftime(r.cal_date, '%Y-%m-%d') as crew_day_id,
    r.crew_id,
    r.cal_date,
    r.duty_types,
    r.duty_h,
    r.block_h,
    r.legs,
    r.is_day_off,
    r.has_roster_record,
    r.duty_7d_h,
    r.block_28d_h,
    r.days_off_7d,
    r.days_off_28d,
    r.day_n >= 7 as has_full_7d,
    r.day_n >= 28 as has_full_28d,

    -- headroom: how much more this crew member can take before breaking the rule
    l.max_duty_7d_h - r.duty_7d_h as duty_7d_headroom_h,
    l.max_block_28d_h - r.block_28d_h as block_28d_headroom_h,

    -- breaches. Cumulative hours can only go over, so they're judged from day 1.
    -- "at least N days off" needs a full window, or every early day would look like a breach
    r.duty_7d_h > l.max_duty_7d_h as is_duty_7d_breach,
    r.block_28d_h > l.max_block_28d_h as is_block_28d_breach,
    r.day_n >= 7 and r.days_off_7d < l.min_days_off_7d as is_days_off_7d_breach,
    r.day_n >= 28 and r.days_off_28d < l.min_days_off_28d as is_days_off_28d_breach
from rolling as r
cross join limits as l
