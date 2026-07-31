{{ config(materialized='incremental', unique_key='HOST_ID') }}

WITH source_data AS (

    SELECT 
        HOST_ID,
        HOST_NAME,
        HOST_SINCE,
        initcap(lower(IS_SUPERHOST)) AS IS_SUPERHOST,
        RESPONSE_RATE,
        CASE 
            WHEN RESPONSE_RATE > 95 THEN 'Very Good'
            WHEN RESPONSE_RATE > 80 THEN 'Good'
            WHEN RESPONSE_RATE > 60 THEN 'Fair'
            ELSE 'Poor'
        END AS RESPONSE_RATE_QUALITY,
        CREATED_AT
    FROM {{ ref('bronze_hosts') }}

    {% if is_incremental() %}
    WHERE CREATED_AT > (SELECT COALESCE(MAX(CREATED_AT), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    {% endif %}

),

deduped AS (

    SELECT *
    FROM source_data
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY HOST_ID
        ORDER BY CREATED_AT DESC
    ) = 1

)

SELECT * FROM deduped    