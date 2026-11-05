{#
  Two small overrides so the warehouse reads cleanly:

  1. Schemas: use the custom schema as-is (silver / gold / ref)
     instead of dbt's default "main_silver".
  2. Table names: strip the layer prefix, so the model silver_crew.sql becomes the
     table silver.crew. (dbt needs model names unique across the project, hence the
     prefix in the filename.) Gold models keep their name: fct_duty -> gold.fct_duty.
#}

{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ custom_schema_name if custom_schema_name else target.schema }}
{%- endmacro %}

{% macro generate_alias_name(custom_alias_name=none, node=none) -%}
    {%- if custom_alias_name -%}
        {{ custom_alias_name | trim }}
    {%- elif node.name.startswith('silver_') -%}
        {{ node.name[7:] }}
    {%- else -%}
        {{ node.name }}
    {%- endif -%}
{%- endmacro %}
