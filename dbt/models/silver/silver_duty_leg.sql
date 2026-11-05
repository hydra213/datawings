-- Bridge: which crew worked which flight leg within a duty.
select
    trim(l.duty_leg_id) as duty_leg_id,
    trim(l.duty_id) as duty_id,
    trim(l.flight_key) as flight_key,
    trim(l.crew_id) as crew_id,
    try_cast(l.leg_seq as integer) as leg_seq,
    trim(l.role) as leg_role,  -- 'role' is a SQL keyword
    trim(l.role) in ('CAPT', 'FO') as is_flight_crew,
    upper(trim(l.is_operating)) = 'Y' as is_operating,
    f.flight_key is null as dq_orphan_flight
from {{ source('bronze', 'duty_leg') }} as l
left join {{ source('bronze', 'flight') }} as f
    on trim(l.flight_key) = trim(f.flight_key)
