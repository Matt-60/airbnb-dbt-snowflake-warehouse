{{ config(materialized='table') }}

SELECT
    {{ dbt_utils.generate_surrogate_key(['HOST_ID']) }} AS HOST_KEY,
    HOST_ID,
    HOST_NAME,
    HOST_SINCE,
    IS_SUPERHOST,
    RESPONSE_RATE,
    RESPONSE_RATE_QUALITY
FROM {{ ref('silver_hosts') }}