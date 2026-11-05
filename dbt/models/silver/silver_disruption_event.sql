-- OCC log. crew_id is blank for flight-only events; unknown crew ids are flagged, not dropped.
select
    trim(e.event_id) as event_id,
    try_cast(e.event_ts_utc as timestamptz) as event_ts_utc,
    trim(e.event_type) as event_type,
    nullif(trim(e.flight_key), '') as flight_key,
    nullif(trim(e.crew_id), '') as crew_id,
    trim(e.reason_code) as reason_code,
    coalesce(nullif(trim(e.resolution_action), ''), 'UNRECORDED') as resolution_action,
    try_cast(e.delay_min_attributed as integer) as delay_min_attributed,
    nullif(trim(e.notes), '') as notes,
    nullif(trim(e.crew_id), '') is not null and c.crew_id is null as dq_unknown_crew
from {{ source('bronze', 'disruption_event') }} as e
left join {{ source('bronze', 'crew') }} as c
    on trim(e.crew_id) = trim(c.crew_id)
