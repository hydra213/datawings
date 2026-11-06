-- For the board, section 2. FDP breach COUNTS per report band x fleet x crew group.
-- Counts, not rates: the board filters by fleet / group and re-sums, and you can't
-- average averages. Rates are computed at read time.

select
    d.fdp_rule_id || '|' || c.fleet || '|' || c.crew_group as row_key,
    d.fdp_rule_id,
    r.report_band_local,
    r.limit_hours as band_limit_h,
    c.fleet,
    c.crew_group,
    count(*) as duties,
    count(*) filter (where d.is_planned_breach) as planned_breaches,
    count(*) filter (where d.is_fdp_breach) as actual_breaches,
    count(*) filter (where d.is_fdp_breach and not d.is_planned_breach) as ran_over_breaches
from {{ ref('fct_duty') }} as d
inner join {{ ref('dim_crew') }} as c on d.crew_id = c.crew_id
inner join {{ ref('stg_datawings__ftl_rule') }} as r on d.fdp_rule_id = r.rule_id
where not d.dq_negative_duty
group by all
