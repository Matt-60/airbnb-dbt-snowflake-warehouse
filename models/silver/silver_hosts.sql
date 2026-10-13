{{ config(materialized='incremental', unique_key='HOST_ID', incremental_strategy='merge') }}

SELECT
    HOST_ID,
    TRIM(HOST_NAME)                          AS HOST_NAME,
    HOST_SINCE,
    INITCAP(LOWER(TRIM(TO_VARCHAR(IS_SUPERHOST)))) AS IS_SUPERHOST,  -- works for text or BIT/BOOLEAN source
    RESPONSE_RATE,
    CASE
        WHEN RESPONSE_RATE > 95 THEN 'Very Good'
        WHEN RESPONSE_RATE > 80 THEN 'Good'
        WHEN RESPONSE_RATE > 60 THEN 'Fair'
        ELSE 'Poor'
    END                                      AS RESPONSE_RATE_QUALITY,
    CREATED_AT,
    _FIVETRAN_DELETED                        AS IS_DELETED,
    _FIVETRAN_SYNCED
FROM {{ source('fivetran', 'hosts') }}

{% if is_incremental() %}
WHERE {{ incremental_window() }}
{% endif %}
