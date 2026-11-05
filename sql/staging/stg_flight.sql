-- Example staging model: cast raw strings to proper types.
-- Pattern for the others: one stg_<table>.sql per raw table, typing + light cleaning only.
CREATE OR REPLACE VIEW stg_flight AS
SELECT
    flight_key,
    flight_no,
    dep_station,
    arr_station,
    aircraft_type,
    tail,
    CAST(sched_dep_utc AS TIMESTAMPTZ)          AS sched_dep_utc,
    CAST(sched_arr_utc AS TIMESTAMPTZ)          AS sched_arr_utc,
    TRY_CAST(sched_flight_time_min AS INTEGER)  AS sched_flight_time_min,
    TRY_CAST(actual_dep_utc AS TIMESTAMPTZ)     AS actual_dep_utc,
    TRY_CAST(actual_arr_utc AS TIMESTAMPTZ)     AS actual_arr_utc,
    TRY_CAST(dep_delay_min AS INTEGER)          AS dep_delay_min,
    status
FROM raw_flight;
