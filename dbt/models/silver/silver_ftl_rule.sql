-- The FTL rulebook. report_band_local 'HH:MM-HH:MM' is split into minutes after local midnight;
-- a band that wraps midnight (22:00-04:59) has band_end_min < band_start_min.
select
    trim(rule_id) as rule_id,
    trim(rule_type) as rule_type,
    nullif(trim(report_band_local), '') as report_band_local,
    try_cast(split_part(report_band_local, ':', 1) as integer) * 60
    + try_cast(split_part(split_part(report_band_local, '-', 1), ':', 2) as integer)
        as band_start_min,
    try_cast(split_part(split_part(report_band_local, '-', 2), ':', 1) as integer) * 60
    + try_cast(split_part(report_band_local, ':', 3) as integer)
        as band_end_min,
    try_cast(sectors_min as integer) as sectors_min,
    try_cast(sectors_max as integer) as sectors_max,
    try_cast(limit_hours as double) as limit_hours,
    try_cast(reduction_per_extra_sector_hours as double) as reduction_per_extra_sector_hours,
    try_cast(floor_hours as double) as floor_hours,
    nullif(trim(notes), '') as notes
from {{ source('bronze', 'ftl_rule') }}
