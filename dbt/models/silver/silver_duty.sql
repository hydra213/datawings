-- One row per crew duty period, incl. days off, leave and sick. Timestamps UTC; local = UTC+4.
with typed as (
    select
        trim(duty_id) as duty_id,
        trim(crew_id) as crew_id,
        trim(duty_type) as duty_type,
        try_cast(duty_date as date) as duty_date,
        nullif(trim(rotation_id), '') as rotation_id,
        try_cast(planned_report_utc as timestamptz) as planned_report_utc,
        try_cast(planned_release_utc as timestamptz) as planned_release_utc,
        try_cast(actual_report_utc as timestamptz) as actual_report_utc,
        try_cast(actual_release_utc as timestamptz) as actual_release_utc,
        coalesce(try_cast(sectors as integer), 0) as sectors
    from {{ source('bronze', 'duty') }}
),

same_day as (
    -- F: a crew member with more than one duty on the same date (e.g. LEAVE + FLIGHT)
    select
        crew_id,
        duty_date,
        count(*) as duties_that_day
    from typed
    group by crew_id, duty_date
)

select
    t.*,
    timezone('UTC', t.planned_report_utc) + interval 4 hour as planned_report_local,
    timezone('UTC', t.actual_report_utc) + interval 4 hour as actual_report_local,
    date_diff('minute', t.planned_report_utc, t.planned_release_utc) / 60.0 as planned_duty_h,
    date_diff('minute', t.actual_report_utc, t.actual_release_utc) / 60.0 as actual_duty_h,
    t.duty_type in ('FLIGHT', 'STANDBY', 'GROUND', 'SIM') as is_working,
    t.actual_release_utc < t.actual_report_utc as dq_negative_duty,
    s.duties_that_day > 1 as dq_multiple_duties_same_day
from typed as t
left join same_day as s on t.crew_id = s.crew_id and t.duty_date = s.duty_date
