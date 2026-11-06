-- One row per flight leg. flight_no is NOT unique per day: always join on flight_key.
select
    trim(flight_key) as flight_key,
    trim(flight_no) as flight_no,
    trim(dep_station) as dep_station,
    trim(arr_station) as arr_station,
    trim(aircraft_type) as aircraft_type,
    trim(tail) as tail,
    try_cast(sched_dep_utc as timestamptz) as sched_dep_utc,
    try_cast(sched_arr_utc as timestamptz) as sched_arr_utc,
    try_cast(sched_flight_time_min as integer) as sched_flight_time_min,
    try_cast(actual_dep_utc as timestamptz) as actual_dep_utc,
    try_cast(actual_arr_utc as timestamptz) as actual_arr_utc,
    try_cast(dep_delay_min as integer) as dep_delay_min,
    trim(status) as status,
    date_diff('minute', try_cast(actual_dep_utc as timestamptz), try_cast(actual_arr_utc as timestamptz))
        as actual_block_min,
    cast(timezone('UTC', try_cast(sched_dep_utc as timestamptz)) + interval 4 hour as date)
        as sched_dep_date_local
from {{ source('datawings', 'flight') }}
