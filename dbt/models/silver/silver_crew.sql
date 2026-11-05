-- One row per crew member. F1: rank spellings mapped via ref.rank_map. F2: dd/mm/yyyy dates.
with rank_map as (
    -- match case- and space-insensitively, so the seed only needs genuinely new spellings
    select distinct
        upper(trim(raw_rank)) as rank_key,
        clean_rank
    from {{ ref('rank_map') }}
)

select
    trim(c.crew_id) as crew_id,
    trim(c.first_name) as first_name,
    trim(c.last_name) as last_name,
    coalesce(r.clean_rank, 'UNMAPPED') as rank,
    trim(c.rank) as rank_raw,
    trim(c.crew_group) as crew_group,
    trim(c.fleet) as fleet,
    trim(c.aircraft_type) as aircraft_type,
    trim(c.base) as base,
    try_cast(c.seniority_years as double) as seniority_years,
    try_strptime(c.join_date, '%d/%m/%Y')::date as join_date,
    try_strptime(nullif(trim(c.leave_date), ''), '%d/%m/%Y')::date as leave_date,
    trim(c.status) as status,
    r.clean_rank is null as dq_rank_unmapped,
    trim(c.rank) <> coalesce(r.clean_rank, '') as dq_rank_variant
from {{ source('bronze', 'crew') }} as c
left join rank_map as r
    on upper(trim(c.rank)) = r.rank_key
