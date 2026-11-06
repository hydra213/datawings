with crew as (
    select * from {{ ref('stg_datawings__crew') }}
)

select
    crew_id,
    first_name || ' ' || last_name as crew_full_name,
    rank,
    crew_group,
    crew_group = 'FLIGHT' as is_flight_crew,
    fleet,
    base,
    status,
    join_date,
    leave_date,
    seniority_years,
    case
        when seniority_years < 2 then '0-2 years'
        when seniority_years < 5 then '2-5 years'
        when seniority_years < 10 then '5-10 years'
        else '10+ years'
    end as seniority_band
from crew
