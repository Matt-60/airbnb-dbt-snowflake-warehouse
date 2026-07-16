{{ config(materialized='incremental',
        on_schema_change='append_new_columns')}}

SELECT *, CURRENT_TIMESTAMP() AS bronze_loaded_at FROM {{source('staging','bookings')}}

{% if is_incremental() %}
    WHERE CREATED_AT > (SELECT COALESCE(MAX(CREATED_AT), '1900-01-01') FROM {{ this }})
{% endif %}