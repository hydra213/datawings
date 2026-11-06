-- One row per flight leg (all statuses, incl. cancelled). Grain = flight_key.
-- Rolls crew, legality and disruption up to the flight, so ops questions
-- ("which flights went out with an illegal crew? what disrupted them?") are one query.

with crew as (
    select
        flight_key,
        count(*) filter (where is_operating) as crew_operating,
        count(*) filter (where is_operating and is_flight_crew) as flight_crew,
        count(*) filter (where is_operating and not is_flight_crew) as cabin_crew,
        count(*) filter (where not is_operating) as crew_deadheading
    from {{ ref('stg_datawings__duty_leg') }}
    group by flight_key
),

legality as (
    select
        flight_key,
        count(distinct crew_id) filter (where not is_valid) as crew_without_valid_qual,
        bool_or(validity = 'MISSING') as has_missing_type_rating
    from {{ ref('fct_leg_qualification') }}
    group by flight_key
),

fdp as (
    -- did anyone on this flight end their duty over the FDP limit?
    select
        l.flight_key,
        count(distinct d.crew_id) filter (where d.is_fdp_breach) as crew_on_fdp_breach_duty
    from {{ ref('stg_datawings__duty_leg') }} as l
    inner join {{ ref('fct_duty') }} as d on l.duty_id = d.duty_id
    group by l.flight_key
),

disruption as (
    select
        flight_key,
        count(*) as disruption_events,
        count(*) filter (where reason_code = 'CREW') as crew_disruption_events,
        sum(coalesce(delay_min_attributed, 0)) as delay_min_attributed,
        bool_or(resolution_action = 'DUTY_EXTENSION') as had_duty_extension,
        bool_or(resolution_action = 'RESERVE_CALLOUT') as had_reserve_callout,
        string_agg(distinct event_type, '+' order by event_type) as event_types
    from {{ ref('stg_datawings__disruption_event') }}
    where flight_key is not null
    group by flight_key
)

select
    f.flight_key,
    f.flight_no,
    f.sched_dep_date_local as flight_date,       -- -> dim_date.date_day
    f.dep_station,
    f.arr_station,
    f.aircraft_type,
    f.tail,
    f.status,
    f.sched_dep_utc,
    f.actual_dep_utc,
    f.sched_flight_time_min,
    f.actual_block_min,
    f.dep_delay_min,
    coalesce(c.crew_operating, 0) as crew_operating,
    coalesce(c.flight_crew, 0) as flight_crew,
    coalesce(c.cabin_crew, 0) as cabin_crew,
    coalesce(c.crew_deadheading, 0) as crew_deadheading,
    coalesce(lg.crew_without_valid_qual, 0) as crew_without_valid_qual,
    coalesce(lg.has_missing_type_rating, false) as has_missing_type_rating,
    coalesce(fd.crew_on_fdp_breach_duty, 0) as crew_on_fdp_breach_duty,
    coalesce(ds.disruption_events, 0) as disruption_events,
    coalesce(ds.crew_disruption_events, 0) as crew_disruption_events,
    coalesce(ds.delay_min_attributed, 0) as delay_min_attributed,
    coalesce(ds.had_duty_extension, false) as had_duty_extension,
    coalesce(ds.had_reserve_callout, false) as had_reserve_callout,
    ds.event_types,
    coalesce(lg.crew_without_valid_qual, 0) > 0 as is_illegal_crew
from {{ ref('stg_datawings__flight') }} as f
left join crew as c on f.flight_key = c.flight_key
left join legality as lg on f.flight_key = lg.flight_key
left join fdp as fd on f.flight_key = fd.flight_key
left join disruption as ds on f.flight_key = ds.flight_key
