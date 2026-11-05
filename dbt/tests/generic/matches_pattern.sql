{#
  Bronze is all text. This checks a text column really holds the format we expect
  (a date, a timestamp, an integer). Blanks are ignored: not_null covers those.
#}
{% test matches_pattern(model, column_name, pattern) %}
select {{ column_name }}
from {{ model }}
where
    nullif(trim({{ column_name }}), '') is not null
    and not regexp_matches(trim({{ column_name }}), '{{ pattern }}')
{% endtest %}
