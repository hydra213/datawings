-- Board section 1. One row per crew member x qualification type they flew without.

select
    c.crew_id,
    c.crew_full_name,
    c.rank,
    c.fleet,
    c.crew_group,
    l.qual_type,
    count(distinct l.duty_leg_id) as legs,
    count(distinct l.duty_leg_id) filter (where l.validity = 'MISSING') as legs_missing,
    count(distinct l.flight_key) as flights,
    max(l.days_expired) as max_days_lapsed,
    median(l.days_expired) as median_days_lapsed,
    min(l.leg_date) as first_leg,
    max(l.leg_date) as last_leg
from {{ ref('fct_leg_qualification') }} as l
inner join {{ ref('dim_crew') }} as c on l.crew_id = c.crew_id
where not l.is_valid
group by all
