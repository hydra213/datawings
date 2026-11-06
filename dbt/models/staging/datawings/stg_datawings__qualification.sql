-- One row per crew x qualification. The status column is kept as reported, but validity is
-- always derived from the dates against the leg date (gold), never from status.
select
    trim(qual_id) as qual_id,
    trim(crew_id) as crew_id,
    trim(qual_type) as qual_type,
    nullif(trim(aircraft_type), '') as aircraft_type,  -- only set for TYPE_RATING
    try_cast(issue_date as date) as issue_date,
    try_cast(expiry_date as date) as expiry_date,
    trim(status) as status_reported
from {{ source('datawings', 'qualification') }}
