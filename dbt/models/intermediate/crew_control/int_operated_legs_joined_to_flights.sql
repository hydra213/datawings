-- One row per leg a crew member actually OPERATED (not deadheading) on a flight that
-- wasn't cancelled, with the flight's attributes. Shared by fct_leg_qualification
-- (was this person legal on this leg?) and fct_crew_day (block hours per day), which
-- used to repeat this join and filter each.

select
    l.duty_leg_id,
    l.duty_id,
    l.crew_id,
    l.flight_key,
    l.leg_role,
    l.is_flight_crew,
    f.flight_no,
    f.dep_station,
    f.arr_station,
    f.aircraft_type,
    f.actual_block_min,
    f.sched_dep_date_local as leg_date
from {{ ref('stg_datawings__duty_leg') }} as l
inner join {{ ref('stg_datawings__flight') }} as f on l.flight_key = f.flight_key
where
    l.is_operating
    and f.status <> 'CANCEL'
