{#
  Use the custom schema as-is (staging / marts / ref) instead of dbt's default
  "main_staging". Table names are the model names (stg_datawings__crew, fct_duty).
#}

{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ custom_schema_name if custom_schema_name else target.schema }}
{%- endmacro %}
