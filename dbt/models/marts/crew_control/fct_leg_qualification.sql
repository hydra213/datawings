-- One row per operated flight leg x qualification that leg requires of its crew member.
-- Answers: "was this person legal to operate this flight on this day?"
--
-- Requirements come from the qual_requirement seed (our rule, inferred from who holds what):
--   everyone:     LICENCE, MEDICAL, RECURRENT, TYPE_RATING (for the leg's aircraft type)
--   flight crew:  + RECENCY
-- Validity is derived from issue/expiry dates against the leg's local departure date. The
-- source status flag is kept only to compare (status_reported), never to decide.

with legs as (
    select * from {{ ref('int_operated_legs_joined_to_flights') }}
),

required as (
    select * from {{ ref('qual_requirement') }}
),

leg_requirements as (
    select
        lg.*,
        r.qual_type,
        r.per_aircraft
    from legs as lg
    inner join required as r
        on lg.is_flight_crew or not r.flight_crew_only
),

matched as (
    -- every qualification record of the right type (and aircraft, for type ratings)
    select
        lr.duty_leg_id,
        lr.qual_type,
        q.qual_id,
        q.issue_date,
        q.expiry_date,
        q.status_reported,
        lr.leg_date between q.issue_date and q.expiry_date as covers_leg_date
    from leg_requirements as lr
    inner join {{ ref('stg_datawings__qualification') }} as q
        on
            lr.crew_id = q.crew_id
            and lr.qual_type = q.qual_type
            and (not lr.per_aircraft or lr.aircraft_type = q.aircraft_type)
),

best as (
    -- one record per leg x qual: a covering one if any exists, else the latest expired one
    select *
    from matched
    qualify row_number() over (
        partition by duty_leg_id, qual_type
        order by covers_leg_date desc, expiry_date desc
    ) = 1
)

select
    lr.duty_leg_id || '|' || lr.qual_type as leg_qual_id,
    lr.duty_leg_id,
    lr.duty_id,
    lr.crew_id,
    lr.flight_key,
    lr.flight_no,
    lr.dep_station,
    lr.arr_station,
    lr.aircraft_type,
    lr.leg_date,
    lr.leg_role,
    lr.is_flight_crew,
    lr.qual_type,
    b.qual_id,
    b.issue_date,
    b.expiry_date,
    b.status_reported,
    b.qual_id is null as is_missing,
    coalesce(b.covers_leg_date, false) as is_valid,
    case
        when b.qual_id is null then 'MISSING'
        when b.covers_leg_date then 'VALID'
        when lr.leg_date < b.issue_date then 'NOT_YET_ISSUED'
        else 'EXPIRED'
    end as validity,
    case
        when not b.covers_leg_date and lr.leg_date > b.expiry_date
            then date_diff('day', b.expiry_date, lr.leg_date)
    end as days_expired
from leg_requirements as lr
left join best as b
    on lr.duty_leg_id = b.duty_leg_id and lr.qual_type = b.qual_type
