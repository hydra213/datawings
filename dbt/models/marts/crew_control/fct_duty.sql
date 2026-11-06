-- One row per FLIGHT duty, with its FDP limit from the rulebook and whether it was breached.
--
-- Limit = band limit for the LOCAL report time
--         - 0.5h per sector over 2, never below the band's floor
--         + augmentation (4h with 3 flight crew, 7h with 4) on the duty's flights.
-- Checked twice: planned (was it rostered legal?) and actual (did it run over on the day?).

with flying as (
    select *
    from {{ ref('stg_datawings__duty') }}
    where duty_type = 'FLIGHT'
),

flight_crew_per_flight as (
    select
        flight_key,
        count(*) filter (where is_flight_crew) as flight_crew
    from {{ ref('stg_datawings__duty_leg') }}
    group by flight_key
),

duty_crewing as (
    -- the most heavily crewed flight in the duty sets the augmentation
    select
        l.duty_id,
        max(f.flight_crew) as max_flight_crew
    from {{ ref('stg_datawings__duty_leg') }} as l
    inner join flight_crew_per_flight as f on l.flight_key = f.flight_key
    group by l.duty_id
),

rules as (
    select * from {{ ref('stg_datawings__ftl_rule') }}
),

bands as (
    select * from rules
    where rule_type = 'MAX_FDP'
),

aug as (
    select
        max(limit_hours) filter (where rule_id = 'AUGM-01') as aug_3_crew_h,
        max(limit_hours) filter (where rule_id = 'AUGM-02') as aug_4_crew_h
    from rules
),

prepared as (
    select
        d.*,
        coalesce(c.max_flight_crew, 0) as max_flight_crew,
        extract(hour from d.planned_report_local) * 60
        + extract(minute from d.planned_report_local) as planned_report_min,
        extract(hour from d.actual_report_local) * 60
        + extract(minute from d.actual_report_local) as actual_report_min
    from flying as d
    left join duty_crewing as c on d.duty_id = c.duty_id
),

with_limits as (
    select
        p.*,
        b.rule_id as fdp_rule_id,
        b.limit_hours as band_limit_h,
        case
            when p.max_flight_crew >= 4 then a.aug_4_crew_h
            when p.max_flight_crew = 3 then a.aug_3_crew_h
            else 0
        end as augmentation_h,
        greatest(
            b.limit_hours - b.reduction_per_extra_sector_hours * greatest(p.sectors - 2, 0),
            b.floor_hours
        ) as unaugmented_limit_h
    from prepared as p
    cross join aug as a
    left join bands as b
        on (
            b.band_start_min <= b.band_end_min
            and p.planned_report_min between b.band_start_min and b.band_end_min
        )
        or (
            b.band_start_min > b.band_end_min
            and (p.planned_report_min >= b.band_start_min or p.planned_report_min <= b.band_end_min)
        )
)

select
    duty_id,
    crew_id,
    duty_date,
    rotation_id,
    sectors,
    max_flight_crew,
    planned_report_local,
    actual_report_local,
    planned_duty_h as planned_fdp_h,
    actual_duty_h as actual_fdp_h,
    fdp_rule_id,
    band_limit_h,
    augmentation_h,
    unaugmented_limit_h + augmentation_h as max_fdp_h,
    actual_duty_h - planned_duty_h as overrun_h,
    actual_duty_h - (unaugmented_limit_h + augmentation_h) as fdp_margin_h,
    planned_duty_h > unaugmented_limit_h + augmentation_h as is_planned_breach,
    actual_duty_h > unaugmented_limit_h + augmentation_h as is_fdp_breach,
    sectors > 6 as is_sector_breach,  -- SECT-01
    dq_negative_duty,
    dq_multiple_duties_same_day
from with_limits
