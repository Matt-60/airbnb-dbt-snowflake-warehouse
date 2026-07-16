{% macro init_cap(column_name) %}
    INITCAP(TRIM({{ column_name }}))
{% endmacro %}